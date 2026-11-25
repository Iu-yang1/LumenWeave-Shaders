vec3 applySoftColor(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec3 muted = mix(vec3(luma), color, 0.92);
    return mix(vec3(0.5), muted, 0.94);
}
