
#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"
#include "/lib/voxel/features.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
#ifdef LW_SCENE_TAAU
#include "/lib/temporal/scene_grid.glsl"
uniform int lwTaauFrame;
#endif
layout(location = 0) out vec4 outputColor;

/* RENDERTARGETS: 0 */

#ifdef VOLUME_EFFECTS
#include "/lib/lighting/overworld.glsl"
#include "/lib/atmosphere/volume_depth.glsl"
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif
#include "/lib/atmosphere/volume.glsl"
#ifdef LW_CELESTIAL_VOLUME_SPATIAL
/*
const int colortex9Format = RGBA16F;
*/
#define LW_VOLUME_SPATIAL_READER
#include "/lib/atmosphere/volume_spatial.glsl"
#endif
#ifdef LW_LOCAL_SCATTER_ACTIVE
#include "/lib/atmosphere/local_scatter.glsl"
#include "/lib/atmosphere/scatter_upsample.glsl"
#endif
#ifdef LW_SCATTER_UPSAMPLE_ACTIVE
/*
const int colortex11Format = RGBA16F;
*/
#endif
#endif

void main() {
    vec2 uv=texCoord;
#ifdef LW_SCENE_TAAU
    ivec2 fullSize=textureSize(colortex0,0);
    ivec2 donor=lwSceneDonorPixel(ivec2(gl_FragCoord.xy),fullSize,lwTaauFrame);
    uv=(vec2(donor)+0.5)/vec2(fullSize);
    vec4 scene=texelFetch(colortex0,donor,0);
#else
    vec4 scene = lwRasterTexture(colortex0, texCoord);
#endif
#ifdef VOLUME_EFFECTS
    if (isEyeInWater == 0
#ifndef LW_LOCAL_SCATTER_ACTIVE
            && hasSkylight
#endif
    ) {
        vec3 direction;
        float distanceToSurface;
        volumeRay(uv,direction,distanceToSurface);
        if (hasSkylight) {
#ifdef LW_CELESTIAL_VOLUME_SPATIAL
            vec4 transfer=upsampleCelestialVolume(uv,direction,distanceToSurface);
            scene.rgb=scene.rgb*transfer.a+transfer.rgb;
#else
            vec3 sun = sunDirection();
            vec3 origin = vec3(cameraPositionInt) + cameraPositionFract;
            scene.rgb = applyCloudVolume(scene.rgb, origin, direction, sun, distanceToSurface);
            scene.rgb = applyLightShafts(scene.rgb, origin, direction, sun, distanceToSurface);
#endif
        }
#ifdef LW_LOCAL_SCATTER_ACTIVE
#ifdef LW_SCATTER_UPSAMPLE_ACTIVE
        scene.rgb += upsampleLocalScatter(uv,direction,distanceToSurface);
#else
        scene.rgb += integrateLocalScatter(direction, distanceToSurface);
#endif
#endif
    }
#endif
    outputColor = scene;
}
