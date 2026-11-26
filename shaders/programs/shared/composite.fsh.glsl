#version 330 compatibility

#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;

/* RENDERTARGETS: 0 */

#ifdef VOLUME_EFFECTS
#include "/lib/coordinates/reconstruct.glsl"
#include "/lib/lighting/overworld.glsl"
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif
#include "/lib/atmosphere/volume.glsl"

uniform sampler2D depthtex0;
uniform int isEyeInWater;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif
#endif

void main() {
    vec4 scene = texture(colortex0, texCoord);
#ifdef VOLUME_EFFECTS
    if (isEyeInWater == 0) {
        float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
        // Sky geometry has no jitter. Surface depth is reconstructed with its own projection.
        vec4 ray = gbufferProjectionInverse * vec4(texCoord * 2.0 - 1.0, 1.0, 1.0);
        vec3 view = depth < 1.0 ? reconstructViewPosition(texCoord, depth) : ray.xyz;
        float distanceToSurface = depth >= 1.0 ? 680.0 : length(view);
#ifdef DISTANT_HORIZONS
        if (depth >= 1.0) {
            float distantDepth = texelFetch(dhDepthTex0, ivec2(gl_FragCoord.xy), 0).r;
            if (distantDepth < 1.0) {
                vec2 distantUv = texCoord;
#ifdef LW_TAA_ACTIVE
                distantUv -= jitterOffset(frameCounter);
#endif
                vec4 distantView = dhProjectionInverse * vec4(vec3(distantUv, distantDepth) * 2.0 - 1.0, 1.0);
                view = distantView.xyz / distantView.w;
                distanceToSurface = length(view);
            }
        }
#endif
        // Use an unjittered angular ray for the volume; geometry still supplies its true distance.
        vec3 direction = normalize(worldDirection(ray.xyz));
        vec3 sun = sunDirection();
        vec3 origin = vec3(cameraPositionInt) + cameraPositionFract;
        scene.rgb = applyCloudVolume(scene.rgb, origin, direction, sun, distanceToSurface);
        scene.rgb = applyLightShafts(scene.rgb, origin, direction, sun, distanceToSurface);
    }
#endif
    outputColor = scene;
}
