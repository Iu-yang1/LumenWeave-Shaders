#version 330 compatibility

#include "/lib/quality.glsl"

layout(location = 0) out vec4 skyTrace;
in vec2 texCoord;

#if defined(SCREEN_GI_SPATIAL) && defined(SCREEN_GI) && defined(DEFERRED_LIGHTING)
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/surface.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#endif
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_surface.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;

#include "/lib/lighting/screen_gi.glsl"
#ifdef LW_AO_SPATIAL
#include "/lib/lighting/gtao.glsl"
/*
const int colortex3Format = RG16F;
const vec4 colortex3ClearColor = vec4(1.0,0.0,0.0,0.0);
*/
#endif
#if defined(LW_TEMPORAL_REUSE) && defined(SCREEN_GI_HISTORY) && defined(LW_TAA_ACTIVE) && !defined(LW_DYNAMIC_JITTER)
#if GI_REUSE_MODE == 2 || (GI_REUSE_MODE == 1 && (defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)))
#define LW_GI_REUSE
#include "/lib/temporal/reproject.glsl"
uniform sampler2D colortex9;
uniform sampler2D colortex7;
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler2D colortex10;
#endif
#endif
#endif

/*
const int colortex9Format = RGBA16F;
const vec4 colortex9ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#ifdef LW_GI_REUSE
const bool colortex9Clear = false;
#endif
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
layout(location = 1) out vec4 blockTrace;
#ifdef LW_AO_SPATIAL
layout(location = 2) out vec2 aoTrace;
/* RENDERTARGETS: 9,10,3 */
#else
/* RENDERTARGETS: 9,10 */
#endif
/*
const int colortex10Format = RGBA16F;
const vec4 colortex10ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#ifdef LW_GI_REUSE
const bool colortex10Clear = false;
#endif
#else
#ifdef LW_AO_SPATIAL
layout(location = 1) out vec2 aoTrace;
/* RENDERTARGETS: 9,3 */
#else
/* RENDERTARGETS: 9 */
#endif
#endif

void main() {
    ivec2 fullSize = textureSize(depthtex0, 0);
    // The fullscreen UV reflects the actual half-size viewport, including odd
    // framebuffer dimensions; do not assume integer division matches Iris.
    ivec2 pixel = clamp(ivec2(texCoord * vec2(fullSize)), ivec2(0), fullSize - 1);
    vec2 sampleUv = (vec2(pixel) + 0.5) / vec2(fullSize);
    float depth = texelFetch(depthtex0, pixel, 0).r;
    float terrainDepth = texelFetch(colortex2, pixel, 0).r;
    skyTrace = vec4(0.0);
#ifdef LW_AO_SPATIAL
    aoTrace=vec2(1.0,0.0);
#endif
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    blockTrace = vec4(0.0);
#endif
    if (depth >= 1.0 || abs(depth - terrainDepth) > 0.00000012) {
        return;
    }
    vec3 viewPosition = reconstructViewPosition(sampleUv, depth);
    float viewDepth=-viewPosition.z;
#ifdef LW_AO_SPATIAL
    if(viewDepth>=52.0) return;
#else
    if(viewDepth>=30.0) return;
#endif
    vec3 normal = decodeNormal(texelFetch(colortex1, pixel, 0).xy);
#ifdef LW_AO_SPATIAL
    if(viewDepth>=4.0) {
        vec3 normalView=transpose(mat3(gbufferModelViewInverse))*normal;
        aoTrace=vec2(groundTruthOcclusion(sampleUv,viewPosition,normalView),viewDepth);
    }
    if(viewDepth>=30.0) return;
#endif
#ifdef LW_STABLE_DYNAMIC
    viewPosition = stableViewSurfacePosition(viewPosition, sampleUv,
        transpose(mat3(gbufferModelViewInverse)) * normal, gbufferProjectionInverse);
#endif
#ifdef LW_GI_REUSE
    // Every tile receives a fresh trace at least every other frame.
    ivec2 tile=ivec2(gl_FragCoord.xy);
    vec2 previousUv;float expectedDepth;
    vec3 cameraDelta=vec3(cameraPositionInt-previousCameraPositionInt)
        +cameraPositionFract-previousCameraPositionFract;
    if(((tile.x+tile.y+frameCounter)&1)==0 && -viewPosition.z>3.0 &&
        dot(cameraDelta,cameraDelta)<0.0004 &&
        reprojectStableTerrain(viewPosition,previousUv,expectedDepth,gbufferPreviousProjection) &&
        length((previousUv-sampleUv)*vec2(fullSize))<0.35 &&
        all(lessThan(tile,textureSize(colortex9,0)))) {
        vec4 previous=texelFetch(colortex9,tile,0);
        vec4 metadata=texelFetch(colortex7,pixel,0);
        if(matchesHistoryDepth(previous.a,expectedDepth) &&
            all(lessThanEqual(abs(metadata.zw-vec2(fullSize)),vec2(1.0))) &&
            dot(normal,decodeNormal(metadata.xy))>0.92) {
            skyTrace=vec4(previous.rgb,-viewPosition.z);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
            blockTrace=texelFetch(colortex10,tile,0);
#endif
            return;
        }
    }
#endif
    ScreenBounce bounce = screenDiffuseBounce(viewPosition, normal, sunDirection());
    skyTrace = vec4(bounce.sky, -viewPosition.z);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    blockTrace = vec4(bounce.block, bounce.blockConfidence);
#endif
}
#elif defined(LW_AO_SPATIAL)
#include "/lib/lighting/overworld.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
#include "/lib/lighting/gtao.glsl"
/* RENDERTARGETS: 3 */
/*
const int colortex3Format = RG16F;
const vec4 colortex3ClearColor = vec4(1.0,0.0,0.0,0.0);
*/
void main() {
    skyTrace=vec4(1.0,0.0,0.0,0.0);
    ivec2 pixel=depthPixelAtUv(depthtex0,texCoord);
    float depth=texelFetch(depthtex0,pixel,0).r;
    if(depth>=1.0 || abs(depth-texelFetch(colortex2,pixel,0).r)>0.00000012) return;
    vec2 uv=depthPixelUv(depthtex0,pixel);
    vec3 position=reconstructViewPosition(uv,depth);
    if(-position.z<4.0 || -position.z>=52.0) return;
    vec3 normal=transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,pixel,0).xy);
    skyTrace=vec4(groundTruthOcclusion(uv,position,normal),-position.z,0.0,0.0);
}
#else
/* RENDERTARGETS: 0 */
void main() {
    skyTrace = vec4(0.0);
}
#endif
