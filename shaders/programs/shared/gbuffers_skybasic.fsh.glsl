#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/dimensions/celestial_sky.glsl"
#include "/lib/water/optics.glsl"

uniform int renderStage;
uniform int isEyeInWater;
in vec3 viewPosition;
in vec4 vertexColor;

/* RENDERTARGETS: 0 */

void main() {
    if (renderStage == MC_RENDER_STAGE_SUNSET) {
        discard;
    }
    vec3 direction = normalize(worldDirection(viewPosition));
    vec3 sun = sunDirection();
    vec3 radiance = skyRadiance(direction, sun);
    // Preserve air radiance for transmission at the water interface.
    if (isEyeInWater != 0 && isEyeInWater != 1) {
        radiance = decodeSrgb(fogColor);
    } else if (renderStage == MC_RENDER_STAGE_STARS) {
        if (!hasSkylight) discard;
        float darkness = 1.0 - smoothstep(-0.25, -0.08, sun.y);
        float visibility = darkness * (1.0 - rainStrength) * smoothstep(0.0, 0.22, direction.y);
        if (visibility <= 0.0) {
            discard;
        }
        gl_FragData[0] = vec4(vec3(0.70, 0.78, 0.92), vertexColor.a * visibility);
        return;
    } else if (hasSkylight && renderStage != MC_RENDER_STAGE_VOID) {
        radiance += celestialSkyGlow(direction,sun);
    } else if (!hasSkylight && !hasCeiling) {
        radiance += endSkyDetail(direction);
    }
    gl_FragData[0] = vec4(radiance, 1.0);
}
