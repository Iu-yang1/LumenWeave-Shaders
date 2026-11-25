uniform int dhRenderDistance;

float distantHaze(float distanceToEye) {
    float range = max(float(dhRenderDistance), 256.0);
    float visibilityRange = min(range * mix(0.85, 0.23, rainStrength), 1800.0);
    float haze = 1.0 - exp(-max(distanceToEye - 24.0, 0.0) / visibilityRange);
    return mix(haze, 1.0, smoothstep(range * 0.79, range, distanceToEye));
}
