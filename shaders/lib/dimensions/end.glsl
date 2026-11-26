vec3 endEnvironment(float up) {
    return vec3(0.14, 0.13, 0.19) * mix(0.55, 1.0, up * 0.5 + 0.5) * END_AMBIENT;
}
