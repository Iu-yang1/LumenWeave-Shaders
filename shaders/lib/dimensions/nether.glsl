vec3 netherEnvironment(float up) {
    vec3 radiance = mix(vec3(0.038, 0.022, 0.016), vec3(0.14, 0.085, 0.06),
        clamp(ambientLight * 8.0, 0.0, 1.0));
    return radiance * mix(0.55, 1.0, up * 0.5 + 0.5) * NETHER_AMBIENT;
}
