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
    if (isEyeInWater == 1) {
        radiance = waterScatteringColor(decodeSrgb(fogColor))
            * (ambientIrradiance(vec2(0.0, 0.7), 1.0, sun) + celestialIrradiance(sun) * 0.08);
    } else if (isEyeInWater != 0) {
        radiance = decodeSrgb(fogColor);
    } else if (renderStage == MC_RENDER_STAGE_STARS) {
        gl_FragData[0] = vec4(vec3(0.32), vertexColor.a);
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
