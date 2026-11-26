#version 330 compatibility

#include "/lib/quality.glsl"

layout(location = 0) out vec4 skyTrace;

#if defined(SCREEN_GI_SPATIAL) && defined(SCREEN_GI) && defined(DEFERRED_LIGHTING)
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/surface.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_surface.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;

#include "/lib/lighting/screen_gi.glsl"

/*
const int colortex9Format = RGBA16F;
*/
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
layout(location = 1) out vec4 blockTrace;
/* RENDERTARGETS: 9,10 */
/*
const int colortex10Format = RGBA16F;
*/
#else
/* RENDERTARGETS: 9 */
#endif

void main() {
    ivec2 fullSize = textureSize(depthtex0, 0);
    ivec2 traceSize = max(fullSize / 2, ivec2(1));
    ivec2 pixel = ivec2(gl_FragCoord.xy * vec2(fullSize) / vec2(traceSize));
    vec2 sampleUv = (vec2(pixel) + 0.5) / vec2(fullSize);
    float depth = texelFetch(depthtex0, pixel, 0).r;
    float terrainDepth = texelFetch(colortex2, pixel, 0).r;
    skyTrace = vec4(0.0);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    blockTrace = vec4(0.0);
#endif
    if (depth >= 1.0 || abs(depth - terrainDepth) > 0.00000012) {
        return;
    }
    vec3 viewPosition = reconstructViewPosition(sampleUv, depth);
    if (-viewPosition.z >= 30.0) {
        return;
    }
    vec3 normal = decodeNormal(texelFetch(colortex1, pixel, 0).xy);
    ScreenBounce bounce = screenDiffuseBounce(viewPosition, normal, sunDirection());
    skyTrace = vec4(bounce.sky, -viewPosition.z);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    blockTrace = vec4(bounce.block, bounce.blockConfidence);
#endif
}
#else
/* RENDERTARGETS: 0 */
void main() {
    skyTrace = vec4(0.0);
}
#endif
