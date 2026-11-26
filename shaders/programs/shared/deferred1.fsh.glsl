#version 330 compatibility

#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

#ifdef SCREEN_GI_HISTORY
#if defined(SCREEN_GI) && defined(DEFERRED_LIGHTING)
#define LW_SCREEN_GI_HISTORY_ACTIVE
#endif
#endif

#ifdef LW_SCREEN_GI_HISTORY_ACTIVE
layout(location = 1) out vec4 skyBounceHistory;
layout(location = 2) out vec4 bounceNormalHistory;
/*
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const bool colortex6Clear = false;
const bool colortex7Clear = false;
const vec4 colortex6ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#ifdef ADVANCED_WATER
layout(location = 3) out vec4 opaqueScene;
#ifdef LW_MATERIAL_SSR_ACTIVE
layout(location = 4) out vec4 specularMetadata;
/* RENDERTARGETS: 0,6,7,8,12 */
#else
/* RENDERTARGETS: 0,6,7,8 */
#endif
/*
const int colortex8Format = RGBA16F;
*/
#else
/* RENDERTARGETS: 0,6,7 */
#endif
#else
#if defined(ADVANCED_WATER) && defined(DEFERRED_LIGHTING)
layout(location = 1) out vec4 opaqueScene;
#ifdef LW_MATERIAL_SSR_ACTIVE
layout(location = 2) out vec4 specularMetadata;
/* RENDERTARGETS: 0,8,12 */
#else
/* RENDERTARGETS: 0,8 */
#endif
/*
const int colortex8Format = RGBA16F;
*/
#else
/* RENDERTARGETS: 0 */
#endif
#endif

#ifdef LW_MATERIAL_SSR_ACTIVE
/*
const int colortex12Format = RGBA16F;
*/
#endif

#ifdef LW_STABLE_DYNAMIC
/*
const int colortex3Format = RG32F;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#endif

#ifdef DEFERRED_LIGHTING

#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
#include "/lib/lighting/surface.glsl"
#include "/lib/materials/geometry_buffer.glsl"
#include "/lib/coordinates/reconstruct.glsl"
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#endif
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_surface.glsl"
#endif

/*
const int colortex1Format = RGBA16F;
const vec4 colortex2ClearColor = vec4(-1.0, 0.0, 0.0, 0.0);
*/
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
/*
const int colortex2Format = RGBA32F;
*/
#else
/*
const int colortex2Format = RG32F;
*/
#endif

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

#if defined(SCREEN_AO) || defined(SCREEN_GI)
uniform mat4 gbufferProjection;
#endif
#ifdef SCREEN_AO
#include "/lib/lighting/gtao.glsl"
#endif
#ifdef SCREEN_GI
#include "/lib/lighting/screen_gi.glsl"
#ifdef SCREEN_GI_SPATIAL
#include "/lib/lighting/screen_gi_spatial.glsl"
#endif
#endif
#ifdef LW_SCREEN_GI_HISTORY_ACTIVE
#include "/lib/temporal/screen_gi_history.glsl"
#endif

void writeScene(vec4 scene) {
    outputColor = scene;
#ifdef ADVANCED_WATER
    opaqueScene = scene;
#endif
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec4 scene = texelFetch(colortex0, pixel, 0);
    vec4 materialDepth = texelFetch(colortex2, pixel, 0);
    float depth = texelFetch(depthtex0, pixel, 0).r;
#ifdef LW_SCREEN_GI_HISTORY_ACTIVE
    skyBounceHistory = vec4(0.0);
    bounceNormalHistory = vec4(0.0);
#endif
#ifdef LW_MATERIAL_SSR_ACTIVE
    specularMetadata = vec4(0.0);
#endif
    if (depth >= 1.0 || abs(depth - materialDepth.x) > 0.00000012) {
        writeScene(scene);
        return;
    }
    vec4 geometry = texelFetch(colortex1, pixel, 0);
    vec3 normal = decodeNormal(geometry.xy);
    vec3 viewPosition = reconstructViewPosition(texCoord, depth);
#ifdef LW_STABLE_DYNAMIC
    viewPosition = stableViewSurfacePosition(viewPosition, texCoord,
        transpose(mat3(gbufferModelViewInverse)) * normal, gbufferProjectionInverse);
#endif
    vec3 eyeDirection = normalize(worldDirection(-viewPosition));
    Material material = vanillaMaterial(int(materialDepth.y), scene.rgb);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
    material = labMaterial(material, scene.rgb, materialDepth.z, materialDepth.w);
#endif
#ifdef SCREEN_AO
    vec3 normalInView = transpose(mat3(gbufferModelViewInverse)) * normal;
    material.occlusion *= mix(0.23, 1.0, groundTruthOcclusion(texCoord, viewPosition, normalInView));
#endif
    vec3 sun = sunDirection();
#ifdef LW_MATERIAL_SSR_ACTIVE
    vec3 lit = surfaceRadiance(scene.rgb, material, normal, eyeDirection, sun, geometry.zw, viewPosition, specularMetadata);
#else
    vec3 lit = surfaceRadiance(scene.rgb, material, normal, eyeDirection, sun, geometry.zw, viewPosition);
#endif
#if defined(SCREEN_GI) || defined(LW_VOXEL_DIFFUSE_ACTIVE)
    vec3 diffuse = scene.rgb * (1.0 - material.metallic) * (1.0 - material.f0);
    vec3 bounce = vec3(0.0);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 blockBounce = voxelDiffuseBounce(position, normal);
#endif
#ifdef SCREEN_GI
#ifdef SCREEN_GI_SPATIAL
    ScreenBounce screenBounce = spatialScreenBounce(viewPosition, normal, sun, texCoord);
#else
    ScreenBounce screenBounce = screenDiffuseBounce(viewPosition, normal, sun);
#endif
    bounce = screenBounce.sky;
#ifdef LW_SCREEN_GI_HISTORY_ACTIVE
    if (-viewPosition.z < 30.0) {
        bounce = temporalScreenBounce(bounce, viewPosition, normal, texCoord);
        skyBounceHistory = vec4(bounce, -viewPosition.z);
        bounceNormalHistory = vec4(geometry.xy, vec2(textureSize(depthtex0, 0)));
    }
#endif
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    blockBounce = blockBounce * (1.0 - screenBounce.blockConfidence) + screenBounce.block;
#endif
#endif
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    bounce += min(blockBounce, vec3(0.25));
#endif
    lit += diffuse * bounce;
#endif
    writeScene(vec4(applySceneFog(lit, viewPosition), scene.a));
#ifdef ADVANCED_WATER
    opaqueScene = vec4(lit, scene.a);
#endif
}

#else

void main() {
    outputColor = texture(colortex0, texCoord);
}

#endif
