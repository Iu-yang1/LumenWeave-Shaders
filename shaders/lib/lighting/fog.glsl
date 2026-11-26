uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int isEyeInWater;

#include "/lib/water/optics.glsl"

#ifdef DISTANT_HORIZONS
#include "/lib/lighting/dh_fog.glsl"
#endif

vec3 applySceneFog(vec3 lit, vec3 viewPosition) {
    float distanceToEye = length(viewPosition);
    if (isEyeInWater == 1) {
        vec3 transmission = exp(-waterExtinction() * distanceToEye);
        vec3 scatter = waterScatteringColor(decodeSrgb(fogColor))
            * (ambientIrradiance(vec2(0.0, 0.7), 1.0, sunDirection())
                + celestialIrradiance(sunDirection()) * 0.08);
        return lit * transmission + scatter * (1.0 - transmission);
    }
#ifdef DISTANT_HORIZONS
    if (isEyeInWater == 0 && !hasCeiling) {
        vec3 direction = normalize(worldDirection(viewPosition));
        return mix(lit, skyRadiance(direction, sunDirection()), distantHaze(distanceToEye));
    }
#endif
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
