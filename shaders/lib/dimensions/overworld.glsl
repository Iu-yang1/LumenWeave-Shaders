vec3 overworldEnvironment(float up, float day) {
    vec3 radiance = mix(vec3(0.060, 0.067, 0.080), vec3(0.32, 0.38, 0.46), day);
    radiance *= mix(0.30, 1.0, up * 0.5 + 0.5);
    return radiance * mix(1.0, 1.20, rainStrength * day);
}
