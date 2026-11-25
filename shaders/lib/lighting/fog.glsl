uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int isEyeInWater;

#ifdef DISTANT_HORIZONS
#include "/lib/lighting/dh_fog.glsl"
#endif

vec3 applySceneFog(vec3 lit, vec3 viewPosition) {
    float distanceToEye = length(viewPosition);
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
