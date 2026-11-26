#version 330 compatibility

#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

/* RENDERTARGETS: 0 */

#ifdef VOLUME_EFFECTS
#include "/lib/coordinates/reconstruct.glsl"
#ifdef LW_STABLE_DYNAMIC
#include "/lib/coordinates/sample_owner.glsl"
#endif
#include "/lib/lighting/overworld.glsl"
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif
#include "/lib/atmosphere/volume.glsl"
#ifdef LW_LOCAL_SCATTER_ACTIVE
#include "/lib/atmosphere/local_scatter.glsl"
#endif

uniform sampler2D depthtex0;
#ifdef LW_STABLE_DYNAMIC
#include "/lib/materials/geometry_buffer.glsl"
uniform sampler2D colortex1;
#endif
uniform int isEyeInWater;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
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
        float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        // Sky geometry has no jitter. Surface depth is reconstructed with its own projection.
        vec3 view;
        if (depth < 1.0) {
#ifdef LW_STABLE_DYNAMIC
            int kind = sampleOwner(texCoord, depth, false);
            view = reconstructProjection(texCoord,depth,gbufferProjectionInverse,kind!=0);
            if (kind!=0) {
                vec3 n = transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,ivec2(gl_FragCoord.xy),0).xy);
                view = stableViewSurfacePosition(view,texCoord,n,gbufferProjectionInverse);
            }
#else
            view = reconstructViewPosition(texCoord, depth);
#endif
        } else {
            view = (gbufferProjectionInverse * vec4(texCoord * 2.0 - 1.0, 1.0, 1.0)).xyz;
        }
        float distanceToSurface = depth >= 1.0 ? 680.0 : length(view);
#ifdef DISTANT_HORIZONS
        if (depth >= 1.0) {
            ivec2 dhPixel = depthPixelAtUv(dhDepthTex0,texCoord);
            float distantDepth = texelFetch(dhDepthTex0,dhPixel,0).r;
            if (distantDepth < 1.0) {
                vec2 distantUv = depthPixelUv(dhDepthTex0,dhPixel);
#ifdef LW_STABLE_DYNAMIC
                int kind = sampleOwner(texCoord,distantDepth,true);
                view = reconstructProjection(distantUv,distantDepth,dhProjectionInverse,kind!=0);
                if (kind!=0) {
                    vec3 n = transpose(mat3(gbufferModelViewInverse))*decodeNormal(texelFetch(colortex1,ivec2(gl_FragCoord.xy),0).xy);
                    view = stableViewSurfacePosition(view,texCoord,n,dhProjectionInverse);
                }
#else
                view = reconstructProjection(distantUv,distantDepth,dhProjectionInverse,true);
#endif
                distanceToSurface = length(view);
            }
        }
#endif
        // Integrate along the current geometry sample. The following TAA pass
        // reconstructs it onto the fixed output pixel grid; bare sky is unjittered.
        vec3 direction = normalize(worldDirection(view));
        if (hasSkylight) {
            vec3 sun = sunDirection();
            vec3 origin = vec3(cameraPositionInt) + cameraPositionFract;
            scene.rgb = applyCloudVolume(scene.rgb, origin, direction, sun, distanceToSurface);
            scene.rgb = applyLightShafts(scene.rgb, origin, direction, sun, distanceToSurface);
        }
#ifdef LW_LOCAL_SCATTER_ACTIVE
        scene.rgb += integrateLocalScatter(direction, distanceToSurface);
#endif
    }
#endif
    outputColor = scene;
}
