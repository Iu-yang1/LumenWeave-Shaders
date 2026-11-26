vec3 overworldEnvironment(float up, float day) {
    vec3 radiance = mix(vec3(0.037, 0.045, 0.067), vec3(0.19, 0.25, 0.34), day);
    radiance *= mix(0.24, 1.0, up * 0.5 + 0.5);
    return radiance * mix(1.0, 1.20, rainStrength * day);
}
