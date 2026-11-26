#include "/lib/color/scene.glsl"

const float LW_PI = 3.14159265;
const float sunPathRotation = -30.0;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform bool hasSkylight;
uniform bool hasCeiling;
uniform float ambientLight;
uniform vec3 fogColor;

#include "/lib/dimensions/overworld.glsl"
#include "/lib/dimensions/nether.glsl"
#include "/lib/dimensions/end.glsl"
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
#include "/lib/atmosphere/physical_lookup.glsl"
uniform sampler2D lwAtmoSky;
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif
#endif

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
    return mix(vec3(1.0, 0.48, 0.24), vec3(1.0, 0.97, 0.91), smoothstep(0.0, 0.48, sun.y));
}

vec3 celestialIrradiance(vec3 sun) {
    if (!hasSkylight) {
        return vec3(0.0);
    }
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    if(sun.y>=0.0) {
        float radius=atmoRadius(float(cameraPositionInt.y)+cameraPositionFract.y);
        return atmoSolar(radius,sun.y)*(5.4*SUNLIGHT_STRENGTH);
    }
#endif
    return (sun.y >= 0.0 ? sunTint(sun) * 5.4 : vec3(0.095, 0.13, 0.20)) * SUNLIGHT_STRENGTH;
}

float dimensionFogDensity(vec3 direction) {
    float horizon = 1.0 - smoothstep(0.05, 0.70, abs(direction.y));
    return hasCeiling ? mix(0.012, 0.027, horizon)
                      : mix(0.0035, 0.010, horizon);
}

vec3 skyRadiance(vec3 direction, vec3 sun) {
    if (!hasSkylight) {
        vec3 fog = decodeSrgb(fogColor);
        if (hasCeiling) {
            // Preserve biome identity, with a warmer lower horizon and darker ceiling.
            float lower = 1.0-smoothstep(-0.25,0.65,direction.y);
            return mix(fog,vec3(0.14,0.032,0.012),0.10+0.13*lower)*mix(0.68,1.0,lower);
        }
        vec3 horizon = mix(fog,vec3(0.052,0.023,0.105),0.60);
        vec3 zenith = vec3(0.006,0.004,0.019);
        return mix(horizon,zenith,smoothstep(0.0,0.85,abs(direction.y)));
    }
    float height = max(direction.y, 0.0);
    float cosine = max(dot(direction, sun), 0.0);
    float twilight = 1.0 - smoothstep(0.06, 0.36, abs(sun.y));
    float day = daylight(sun);
    vec3 horizon = mix(vec3(0.020, 0.029, 0.050), vec3(0.61, 0.75, 0.94), day);
    vec3 zenith = mix(vec3(0.003, 0.006, 0.018), vec3(0.10, 0.25, 0.57), day);
#ifdef LITE_LIGHTING
    float skyGradient = (3.2 * height) / (1.0 + 2.35 * height);
#else
    float skyGradient = 1.0 - exp(-3.2 * height);
#endif
    vec3 color = mix(horizon, zenith, skyGradient);
    color += vec3(0.56, 0.19, 0.05) * twilight * pow(cosine, 5.0) * exp(-5.0 * height);
    // Low-frequency night-sky band; stars are rendered in the sky pass.
    if (day < 1.0) {
        float band = 1.0 - smoothstep(0.0, 0.24, abs(dot(direction, normalize(vec3(0.36, 0.48, 0.80)))));
        color += vec3(0.010, 0.012, 0.022) * band * band * height * (1.0 - day);
    }
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    vec2 uv = atmoViewUV(direction, sun);
    vec3 physical = texture(lwAtmoSky, atmoTexelUV(uv,textureSize(lwAtmoSky,0))).rgb * (5.4 * SUNLIGHT_STRENGTH);
    color = mix(color, physical, smoothstep(-0.15,0.05,sun.y));
#endif
    color = mix(color, mix(vec3(0.024), vec3(0.45, 0.51, 0.57), day), rainStrength * 0.83);
    return color;
}

// Keep dim light dim, but give level-15 emitters HDR headroom.
vec3 blockLightIrradiance(float level) {
    float x = clamp(level, 0.0, 1.0);
    return x*x*(0.45 + 1.35*x) * vec3(1.04, 0.76, 0.49) * BLOCKLIGHT_STRENGTH;
}

vec3 ambientIrradiance(vec2 light, float up, vec3 sun) {
    float sky = light.y * light.y;
    if (!hasSkylight) {
        vec3 environment = hasCeiling ? netherEnvironment(up) : endEnvironment(up);
        return (vec3(0.008) + environment * (hasCeiling ? 0.48 : 0.58)) * AMBIENT_STRENGTH
            + blockLightIrradiance(light.x);
    }
    vec3 hemisphere = overworldEnvironment(up, daylight(sun));
    return (vec3(0.010) + sky * hemisphere * 0.82) * AMBIENT_STRENGTH
        + blockLightIrradiance(light.x);
}
