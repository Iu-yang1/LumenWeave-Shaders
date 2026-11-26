#version 330 compatibility
#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
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
        float darkness = 1.0 - smoothstep(-0.25, -0.08, sun.y);
        float visibility = darkness * (1.0 - rainStrength) * smoothstep(0.0, 0.22, direction.y);
        if (visibility <= 0.0) {
            discard;
        }
        gl_FragData[0] = vec4(vec3(0.70, 0.78, 0.92), vertexColor.a * visibility);
        return;
    } else if (hasSkylight && renderStage != MC_RENDER_STAGE_VOID) {
        float alignment = dot(direction, sun);
        float edge = max(fwidth(alignment), 0.00001);
        float disc = smoothstep(0.99972 - edge, 0.99972 + edge, alignment);
        float glow = pow(max(alignment, 0.0), 34.0) * 0.18;
        radiance += (disc * 6.0 + glow) * sunTint(sun)
            * smoothstep(-0.025, 0.025, sun.y) * (1.0 - rainStrength);
    }
    gl_FragData[0] = vec4(radiance, 1.0);
}
