vec3 endEnvironment(float up) {
    return vec3(0.075, 0.065, 0.115) * mix(0.55, 1.0, up * 0.5 + 0.5) * END_AMBIENT;
}
