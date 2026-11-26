uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/water/optics.glsl"
#include "/lib/atmosphere/aerial.glsl"

#ifdef DISTANT_HORIZONS
#include "/lib/lighting/dh_fog.glsl"
#endif

// Independent analytic participating-medium approximation: no history,
// ray marching, animated noise or additional fullscreen pass.
vec3 dimensionFog(vec3 lit, vec3 viewPosition, float distanceToEye) {
    vec3 direction = worldDirection(viewPosition) / max(distanceToEye, 0.001);
    float horizon = 1.0 - smoothstep(0.05, 0.70, abs(direction.y));
    float density = hasCeiling ? mix(0.012, 0.027, horizon)
                               : mix(0.0035, 0.010, horizon);
    float opticalDepth = max(distanceToEye - 5.0, 0.0) * density;
    float transmission = exp(-opticalDepth);
    vec3 biomeFog = decodeSrgb(fogColor);
    vec3 haze = hasCeiling ? mix(biomeFog, vec3(0.14, 0.032, 0.012), 0.18)
                          : mix(biomeFog, vec3(0.040, 0.023, 0.083), 0.55);
    float eyeBlock = clamp(float(eyeBrightnessSmooth.x) / 240.0, 0.0, 1.0);
    if (hasCeiling) {
        haze += vec3(0.075, 0.026, 0.008) * eyeBlock * eyeBlock * exp(-distanceToEye * 0.035);
    }
    float shapedDistance = fogShape == 1
        ? max(length(viewPosition.xz), abs(viewPosition.y)) : distanceToEye;
    float boundary = smoothstep(fogStart, max(fogEnd, fogStart + 0.001), shapedDistance);
#ifdef DISTANT_HORIZONS
    if (!hasCeiling) boundary = distantHaze(distanceToEye);
#endif
    transmission *= 1.0 - boundary;
    return lit * transmission + haze * (1.0 - transmission);
}

vec3 applySceneFog(vec3 lit, vec3 viewPosition) {
    float distanceToEye = length(viewPosition);
    if (isEyeInWater == 1) {
        vec3 transmission = exp(-waterExtinction() * distanceToEye);
        vec3 sun = sunDirection();
        vec2 eyeLight = clamp(vec2(eyeBrightnessSmooth) / 240.0,0.0,1.0);
        float skyAccess = smoothstep(0.1,0.8,eyeLight.y);
        // Clear water exposes the already-lit bottom. In-scattering follows
        // actual local light, so a sealed underwater cave is not made luminous.
        vec3 scatter = waterScatteringColor(decodeSrgb(fogColor))
            * (ambientIrradiance(eyeLight,1.0,sun)
                + celestialIrradiance(sun) * (0.14 * skyAccess * daylight(sun)));
        return lit * transmission + scatter * (1.0 - transmission);
    }
    if (isEyeInWater == 0 && hasSkylight) {
        float boundary;
#ifdef DISTANT_HORIZONS
        float range = max(float(dhRenderDistance), 256.0);
        boundary = smoothstep(range * 0.79, range, distanceToEye);
#else
        boundary = smoothstep(max(fogStart, fogEnd * 0.75), max(fogEnd, fogStart + 0.001), distanceToEye);
#endif
        return applyAerialPerspective(lit, viewPosition, boundary);
    }
    if (isEyeInWater == 0 && !hasSkylight) {
        return dimensionFog(lit, viewPosition, distanceToEye);
    }
    if (fogShape == 1) {
        distanceToEye = max(length(viewPosition.xz), abs(viewPosition.y));
    }
#ifdef LITE_LIGHTING
    if (distanceToEye <= fogStart) {
        return lit;
    }
#endif
    float fog = smoothstep(fogStart, max(fogStart + 0.001, fogEnd), distanceToEye);
    vec3 fogRadiance = decodeSrgb(fogColor);
    if (isEyeInWater == 0) {
        vec3 direction = normalize(worldDirection(viewPosition));
        fogRadiance = skyRadiance(direction, sunDirection());
    }
    return mix(lit, fogRadiance, fog);
}
