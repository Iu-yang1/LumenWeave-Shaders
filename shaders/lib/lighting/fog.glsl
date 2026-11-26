uniform float fogStart;
uniform float far;
uniform float fogEnd;
uniform int fogShape;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/voxel/features.glsl"
#include "/lib/water/optics.glsl"
#include "/lib/atmosphere/aerial.glsl"

#ifdef DISTANT_HORIZONS
#include "/lib/lighting/dh_fog.glsl"
#endif

// Border fog is independent of camera pitch and of environmental fog.
// Iris far is the configured render distance in blocks. fogEnd can be
// shorter (server or biome) or longer (modern separate fog parameters).
float dimensionBorder(vec3 displacement) {
    float horizontal=length(displacement.xz);
    float distanceToBorder=max(horizontal,abs(displacement.y));
    float range=max(far,1.0);
    if(fogEnd>1.0) range=min(range,fogEnd);
#ifdef DISTANT_HORIZONS
    if(!hasCeiling && dhRenderDistance>far+16.0) {
        range=max(float(dhRenderDistance),1.0);
        return smoothstep(range*0.78,range,distanceToBorder);
    }
#endif
    // Finish before the nominal chunk boundary, including short view ranges.
    float end=max(range-8.0,range*0.78);
    float start=max(0.0,min(end*0.72,fogStart));
    return smoothstep(start,max(end,start+0.001),distanceToBorder);
}
float dimensionTransmission(vec3 direction,float distanceToEye,float boundary) {
    float density=dimensionFogDensity(direction);
    float opticalDepth=max(distanceToEye-5.0,0.0)*density;
#ifdef LW_LOCAL_SCATTER_ACTIVE
    opticalDepth = distanceToEye * density;
#endif
    return exp(-opticalDepth)*(1.0-boundary);
}
vec3 dimensionFogHaze(vec3 direction,float boundary) {
    vec3 haze=skyRadiance(direction, sunDirection());
#ifdef LW_DIMENSION_END
    // Match the sky's low-frequency purple nebula at the boundary. Stars
    // belong to the unobstructed background, not to the terrain.
    if(boundary>0.001) haze+=endNebula(direction)*boundary;
#endif
    return haze;
}

// Independent analytic participating medium; no fullscreen ray march.
vec3 dimensionFog(vec3 lit, vec3 viewPosition, float distanceToEye) {
    vec3 displacement=worldDirection(viewPosition);
    vec3 direction=displacement/max(distanceToEye,0.001);
    float boundary=dimensionBorder(displacement);
    float transmission=dimensionTransmission(direction,distanceToEye,boundary);
    vec3 haze=dimensionFogHaze(direction,boundary);
#ifndef LW_LOCAL_SCATTER_ACTIVE
    float eyeBlock = clamp(float(eyeBrightnessSmooth.x) / 240.0, 0.0, 1.0);
    if (hasCeiling) {
        haze += vec3(0.035, 0.019, 0.009) * eyeBlock * eyeBlock * exp(-distanceToEye * 0.035);
    }
#endif
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
