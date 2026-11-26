
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
layout(location = 5) out vec4 specularEnvironment;
/* RENDERTARGETS: 0,6,7,8,12,13 */
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
layout(location = 3) out vec4 specularEnvironment;
/* RENDERTARGETS: 0,8,12,13 */
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
const int colortex13Format = R11F_G11F_B10F;
*/
#endif

#ifdef LW_STABLE_DYNAMIC
/*
const int colortex3Format = RG32F;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#endif

#if defined(DEFERRED_LIGHTING) || defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)

#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#ifdef LW_DIMENSION_END
#include "/lib/dimensions/celestial_sky.glsl"
#endif
#include "/lib/lighting/fog.glsl"
#include "/lib/coordinates/reconstruct.glsl"
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
#define LW_DH_DEPTH0_DECLARED
uniform sampler2D dhDepthTex0;
#endif
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
vec4 dimensionBackground(vec2 uv) {
    vec3 direction=normalize(worldDirection((gbufferProjectionInverse*vec4(uv*2.0-1.0,1.0,1.0)).xyz));
    vec3 color=skyRadiance(direction,vec3(0,1,0));
#ifdef LW_DIMENSION_END
    color+=endSkyDetail(direction,96.0/max(float(textureSize(depthtex0,0).y),1.0));
#endif
    if(isEyeInWater!=0 && isEyeInWater!=1) color=decodeSrgb(fogColor);
    return vec4(color,1.0);
}
bool dimensionBackgroundPixel(vec2 uv,float depth) {
    if(depth<1.0) return false;
#ifdef DISTANT_HORIZONS
    if(depthAtUv(dhDepthTex0,uv)<1.0) return false;
#endif
    return true;
}
#endif
#endif

#ifdef DEFERRED_LIGHTING
#include "/lib/lighting/surface.glsl"
#ifdef LW_VOXEL_ACTIVE
#if VOXEL_GRID_SIZE == 128
const float voxelDistance = 64.0;
#elif VOXEL_GRID_SIZE == 96
const float voxelDistance = 48.0;
#elif VOXEL_GRID_SIZE == 64
const float voxelDistance = 32.0;
#else
const float voxelDistance = 16.0;
#endif
#endif
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
#ifdef LW_DH_DEFERRED_SHADOWS
#include "/lib/lighting/dh_terrain_shadows.glsl"

#endif

#if defined(SCREEN_AO) || defined(SCREEN_GI)
uniform mat4 gbufferProjection;
#endif
#ifdef SCREEN_AO
#include "/lib/lighting/gtao.glsl"
#ifdef LW_AO_SPATIAL
#include "/lib/lighting/gtao_spatial.glsl"
#endif
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
    specularEnvironment = vec4(0.0);
#endif
#ifdef LW_DH_DEFERRED_SHADOWS
    if (depth>=1.0) {
        ivec2 dhPixel=depthPixelAtUv(dhDepthTex0,texCoord);
        float distantDepth=texelFetch(dhDepthTex0,dhPixel,0).r;
        if(distantDepth<1.0) {
            vec4 distantGeometry=texelFetch(colortex1,pixel,0);
            vec3 distantPosition=reconstructProjection(depthPixelUv(dhDepthTex0,dhPixel),distantDepth,dhProjectionInverse,true);
#ifdef LW_STABLE_DYNAMIC
            vec3 distantNormal=transpose(mat3(gbufferModelViewInverse))*decodeNormal(distantGeometry.xy);
            distantPosition=stableViewSurfacePosition(distantPosition,texCoord,distantNormal,dhProjectionInverse);
#endif
            vec3 distantLit=shadeDistantTerrain(scene.rgb,distantGeometry,distantPosition);
            writeScene(vec4(applySceneFog(distantLit,distantPosition),scene.a));
#ifdef ADVANCED_WATER
            opaqueScene=vec4(distantLit,scene.a);
#endif
            return;
        }
    }
#endif
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
    // Always fill uncovered native/DH background, independent of sky geometry.
    if(dimensionBackgroundPixel(texCoord,depth)) {
        writeScene(dimensionBackground(texCoord));
        return;
    }
#endif
    if (depth >= 1.0 || abs(depth - materialDepth.x) > 0.00000012) {
        writeScene(scene);
        return;
    }
    vec3 viewPosition = reconstructViewPosition(texCoord, depth);
    float visibleWeight=1.0;
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
    if(isEyeInWater==0) {
        vec3 displacement=worldDirection(viewPosition);
        float distanceToEye=length(displacement);
        float boundary=dimensionBorder(displacement);
        vec3 direction=displacement/max(distanceToEye,0.001);
        visibleWeight=dimensionTransmission(direction,distanceToEye,boundary);
        // Skip all shading only when the scene contribution is exactly zero.
        if(boundary>=1.0) {
            writeScene(vec4(dimensionFogHaze(direction,1.0),scene.a));
            return;
        }
    }
#endif
    vec4 geometry = texelFetch(colortex1, pixel, 0);
    vec3 normal = decodeNormal(geometry.xy);
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
    // In dense fog the AO contrast is already attenuated; keep full near detail.
    if(visibleWeight>0.035) {
        #ifdef LW_AO_SPATIAL
        float ao=spatialGroundTruthOcclusion(texCoord,viewPosition,normal,normalInView);
        #else
        float ao=groundTruthOcclusion(texCoord,viewPosition,normalInView);
        #endif
        material.occlusion*=mix(1.0,mix(0.23,1.0,ao),smoothstep(0.035,0.12,visibleWeight));
    }
#endif
    vec3 sun = sunDirection();
#ifdef LW_MATERIAL_SSR_ACTIVE
    vec3 lit = surfaceRadiance(scene.rgb, material, normal, eyeDirection, sun, geometry.zw, viewPosition, specularMetadata, specularEnvironment);
    // Fade both terms of the SSR replacement, not just reflected radiance.
    float reflectionFade=smoothstep(0.025,0.10,visibleWeight);
    specularMetadata.rgb*=reflectionFade;
    specularEnvironment.rgb*=reflectionFade;
#else
    vec3 lit = surfaceRadiance(scene.rgb, material, normal, eyeDirection, sun, geometry.zw, viewPosition);
#endif
#if defined(SCREEN_GI) || defined(LW_VOXEL_DIFFUSE_ACTIVE)
    if(visibleWeight>0.025) {
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
    lit += diffuse * bounce * smoothstep(0.025,0.10,visibleWeight);
    }
#endif
    writeScene(vec4(applySceneFog(lit, viewPosition), scene.a));
#ifdef ADVANCED_WATER
    opaqueScene = vec4(lit, scene.a);
#endif
}

#else

void main() {
    outputColor = texture(colortex0, texCoord);
#if defined(LW_DIMENSION_END) || defined(LW_DIMENSION_NETHER)
    if(dimensionBackgroundPixel(texCoord,depthAtUv(depthtex0,texCoord)))
        outputColor=dimensionBackground(texCoord);
#endif
}

#endif
