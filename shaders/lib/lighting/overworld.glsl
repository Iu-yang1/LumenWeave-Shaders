#include "/lib/color/scene.glsl"

const float LW_PI = 3.14159265;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform bool hasSkylight;
uniform bool hasCeiling;
uniform float ambientLight;
uniform vec3 fogColor;

vec3 worldDirection(vec3 viewDirection) {
    return mat3(gbufferModelViewInverse) * viewDirection;
}

vec3 sunDirection() {
    if (!hasSkylight) {
        return vec3(0.0, 1.0, 0.0);
    }
    return normalize(worldDirection(sunPosition));
}

float daylight(vec3 sun) {
    return hasSkylight ? smoothstep(-0.16, 0.18, sun.y) : 0.0;
}

vec3 sunTint(vec3 sun) {
    return mix(vec3(1.0, 0.45, 0.20), vec3(1.0, 0.94, 0.84), smoothstep(0.0, 0.48, sun.y));
}

vec3 celestialIrradiance(vec3 sun) {
    if (!hasSkylight) {
        return vec3(0.0);
    }
    return sun.y >= 0.0 ? sunTint(sun) * 4.2 : vec3(0.16, 0.20, 0.27);
}

vec3 skyRadiance(vec3 direction, vec3 sun) {
    if (!hasSkylight) {
        vec3 fog = decodeSrgb(fogColor);
        return hasCeiling ? fog : mix(fog, vec3(0.004, 0.003, 0.012), max(direction.y, 0.0));
    }
    float height = max(direction.y, 0.0);
    float cosine = max(dot(direction, sun), 0.0);
    float twilight = 1.0 - smoothstep(0.06, 0.36, abs(sun.y));
    float day = daylight(sun);
    vec3 horizon = mix(vec3(0.029, 0.037, 0.054), vec3(0.63, 0.77, 0.94), day);
    vec3 zenith = mix(vec3(0.007, 0.011, 0.024), vec3(0.12, 0.34, 0.80), day);
#ifdef LITE_LIGHTING
    float skyGradient = (3.2 * height) / (1.0 + 2.35 * height);
#else
    float skyGradient = 1.0 - exp(-3.2 * height);
#endif
    vec3 color = mix(horizon, zenith, skyGradient);
    color += vec3(0.56, 0.19, 0.05) * twilight * pow(cosine, 5.0) * exp(-5.0 * height);
    color = mix(color, mix(vec3(0.024), vec3(0.45, 0.51, 0.57), day), rainStrength * 0.83);
    return color;
}

vec3 ambientIrradiance(vec2 light, float up, vec3 sun) {
    float sky = light.y * light.y;
    float block = light.x * light.x;
    if (!hasSkylight) {
        vec3 environment = hasCeiling
            ? mix(vec3(0.045, 0.018, 0.012), vec3(0.16, 0.08, 0.05), clamp(ambientLight * 8.0, 0.0, 1.0))
            : vec3(0.16, 0.13, 0.24);
        environment *= mix(0.55, 1.0, up * 0.5 + 0.5);
        return vec3(0.015) + environment + block * vec3(1.12, 0.65, 0.33);
    }
    vec3 hemisphere = mix(vec3(0.064, 0.070, 0.086), vec3(0.30, 0.39, 0.53), daylight(sun));
    hemisphere *= mix(0.30, 1.0, up * 0.5 + 0.5);
    hemisphere = mix(hemisphere, hemisphere * 1.28, rainStrength * daylight(sun));
    return vec3(0.015) + sky * hemisphere + block * vec3(1.12, 0.65, 0.33);
}
