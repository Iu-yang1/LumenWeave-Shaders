
#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

/* RENDERTARGETS: 0 */

#ifdef VOLUME_EFFECTS
#include "/lib/lighting/overworld.glsl"
#include "/lib/atmosphere/volume_depth.glsl"
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif
#include "/lib/atmosphere/volume.glsl"
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
    vec4 scene = texture(colortex0, texCoord);
#ifdef VOLUME_EFFECTS
    if (isEyeInWater == 0
#ifndef LW_LOCAL_SCATTER_ACTIVE
            && hasSkylight
#endif
    ) {
        vec3 direction;
        float distanceToSurface;
        volumeRay(texCoord,direction,distanceToSurface);
        if (hasSkylight) {
            vec3 sun = sunDirection();
            vec3 origin = vec3(cameraPositionInt) + cameraPositionFract;
            scene.rgb = applyCloudVolume(scene.rgb, origin, direction, sun, distanceToSurface);
            scene.rgb = applyLightShafts(scene.rgb, origin, direction, sun, distanceToSurface);
        }
#ifdef LW_LOCAL_SCATTER_ACTIVE
#ifdef LW_SCATTER_UPSAMPLE_ACTIVE
        scene.rgb += upsampleLocalScatter(texCoord,direction,distanceToSurface);
#else
        scene.rgb += integrateLocalScatter(direction, distanceToSurface);
#endif
#endif
    }
#endif
    outputColor = scene;
}
