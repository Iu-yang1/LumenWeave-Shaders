#ifndef LW_AERIAL_PERSPECTIVE
#define LW_AERIAL_PERSPECTIVE
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

#ifdef LW_ATMOSPHERE_LUT_ACTIVE
uniform sampler3D lwAtmoScatter;
uniform sampler3D lwAtmoThrough;
#endif

// Scene-scale exponential atmosphere. Rayleigh and aerosol optical depths are separate.
float aerialColumn(float distanceToEye, float startHeight, float endHeight, float scaleHeight) {
    float h0 = clamp((startHeight - 63.0) / scaleHeight, -0.7, 5.0);
    float h1 = clamp((endHeight - 63.0) / scaleHeight, -0.7, 5.0);
    float delta = h1 - h0;
#ifdef LITE_LIGHTING
    float density = exp(-0.5 * (h0 + h1));
#else
    float density = abs(delta) < 0.01 ? exp(-0.5 * (h0 + h1))
        : (exp(-h0) - exp(-h1)) / delta;
#endif
    return max(distanceToEye - 8.0, 0.0) * density * AERIAL_DENSITY;
}

vec3 applyAerialPerspective(vec3 scene, vec3 viewPosition, float boundaryFade) {
    float distanceToEye = length(viewPosition);
    if ((distanceToEye <= 8.0 || AERIAL_DENSITY == 0.0) && boundaryFade <= 0.0) {
        return scene;
    }
    vec3 displacement = worldDirection(viewPosition);
    float height = float(cameraPositionInt.y) + cameraPositionFract.y;
    vec3 direction = displacement / max(distanceToEye, 0.0001);
    vec3 sun = sunDirection();
    vec3 sky = skyRadiance(direction, sun);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    // Blend twilight/weather continuously; no abrupt branch at sunrise.
    float physicalWeight = smoothstep(-0.15,0.05,sun.y)*(1.0-rainStrength);
    vec3 physical = scene;
    if (physicalWeight > 0.0) {
        vec3 uv = vec3(atmoViewUV(direction,sun),atmoDistanceUV(max(distanceToEye-8.0,0.0)*ATMO_KM_PER_BLOCK*AERIAL_DENSITY));
        vec3 through = texture(lwAtmoThrough,atmoTexelUVW(uv,textureSize(lwAtmoThrough,0))).rgb;
        vec3 scatter = texture(lwAtmoScatter,atmoTexelUVW(uv,textureSize(lwAtmoScatter,0))).rgb * (5.4 * SUNLIGHT_STRENGTH);
        physical = mix(scene*through+scatter,sky,boundaryFade);
        if(physicalWeight>=0.9999) return physical;
    }
#endif
    float day = daylight(sun);
    float cosine = clamp(dot(direction, sun), -1.0, 1.0);
    float rayleighPhase = 0.75 * (1.0 + cosine * cosine);
    float rayleigh = aerialColumn(distanceToEye, height, height + displacement.y, 180.0) * 0.00065;
#ifdef LITE_LIGHTING
    float aerosol = rayleigh * mix(0.45, 6.0, rainStrength);
    float forward = max(cosine, 0.0);
    float miePhase = 0.35 + 2.1 * forward * forward * forward * forward;
#else
    float aerosol = aerialColumn(distanceToEye, height, height + displacement.y, 65.0)
        * mix(0.00032, 0.0042, rainStrength);
    // Bounded Henyey-Greenstein lobe, not an isotropic screen fog.
    float g = mix(0.68, 0.48, rainStrength);
    float denominator = max(1.0 + g*g - 2.0*g*cosine, 0.04);
    float miePhase = min((1.0 - g*g) / (denominator * sqrt(denominator)), 5.0);
#endif
    vec3 rayleighDepth = rayleigh * vec3(0.47, 0.88, 1.55);
    vec3 aerosolDepth = vec3(aerosol);
    vec3 opticalDepth = rayleighDepth + aerosolDepth;
    vec3 transmission = exp(-opticalDepth);
    vec3 molecularLight = sky * mix(0.55, rayleighPhase, day);
    vec3 aerosolLight = mix(sky * 0.60, sunTint(sun) * (0.27 + 0.40 * miePhase), day * (1.0 - rainStrength));
    vec3 source = (molecularLight * rayleighDepth + aerosolLight * aerosolDepth)
        / max(opticalDepth, vec3(0.000001));
    vec3 analytic = mix(scene * transmission + source * (1.0 - transmission), sky, boundaryFade);
#ifdef LW_ATMOSPHERE_LUT_ACTIVE
    return mix(analytic,physical,physicalWeight);
#else
    return analytic;
#endif
}
#endif
