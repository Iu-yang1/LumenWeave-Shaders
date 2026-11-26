#ifndef LW_AERIAL_PERSPECTIVE
#define LW_AERIAL_PERSPECTIVE
uniform ivec3 cameraPositionInt;
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

// Exponential height profile; scene-scaled approximation, not a planetary LUT.
float aerialOpticalDepth(float distanceToEye, float startHeight, float endHeight) {
    float h0 = clamp((startHeight - 63.0) / 110.0, -0.7, 5.0);
    float h1 = clamp((endHeight - 63.0) / 110.0, -0.7, 5.0);
    float delta = h1 - h0;
#ifdef LITE_LIGHTING
    float density = exp(-0.5 * (h0 + h1));
#else
    float density = abs(delta) < 0.01 ? exp(-0.5 * (h0 + h1))
        : (exp(-h0) - exp(-h1)) / delta;
#endif
    return max(distanceToEye - 5.0, 0.0) * density
        * mix(0.0015, 0.0070, rainStrength) * AERIAL_DENSITY;
}

vec3 applyAerialPerspective(vec3 scene, vec3 viewPosition, float boundaryFade) {
    float distanceToEye = length(viewPosition);
    if ((distanceToEye <= 5.0 || AERIAL_DENSITY == 0.0) && boundaryFade <= 0.0) {
        return scene;
    }
    vec3 displacement = worldDirection(viewPosition);
    float height = float(cameraPositionInt.y) + cameraPositionFract.y;
    float opticalDepth = aerialOpticalDepth(distanceToEye, height, height + displacement.y);
    float haze = max(1.0 - exp(-opticalDepth), boundaryFade);
    vec3 direction = displacement / max(distanceToEye, 0.0001);
    vec3 sun = sunDirection();
    vec3 air = skyRadiance(direction, sun);
#ifndef LITE_LIGHTING
    float forward = max(dot(direction, sun), 0.0);
    float phase = forward * forward;
    phase *= phase * phase;
    air += sunTint(sun) * (0.10 * phase * daylight(sun) * (1.0 - rainStrength) * (1.0 - boundaryFade));
#endif
    return mix(scene, air, haze);
}
#endif
