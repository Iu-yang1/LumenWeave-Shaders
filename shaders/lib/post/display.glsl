vec3 sharpenScene(sampler2D image, vec2 uv, vec3 center) {
    vec2 texel = 1.0 / vec2(textureSize(image, 0));
    vec2 lower = texel * 0.5;
    vec2 upper = 1.0 - lower;
    vec3 left = texture(image, clamp(uv - vec2(texel.x, 0.0), lower, upper)).rgb;
    vec3 right = texture(image, clamp(uv + vec2(texel.x, 0.0), lower, upper)).rgb;
    vec3 top = texture(image, clamp(uv + vec2(0.0, texel.y), lower, upper)).rgb;
    vec3 bottom = texture(image, clamp(uv - vec2(0.0, texel.y), lower, upper)).rgb;
    vec3 low = min(center, min(min(left, right), min(top, bottom)));
    vec3 high = max(center, max(max(left, right), max(top, bottom)));
    vec3 detail = center - (left + right + top + bottom) * 0.25;
    return clamp(center + detail * IMAGE_SHARPENING, low, high);
}

vec3 gradeRadiance(vec3 radiance) {
#if COLOR_STYLE == 1
    radiance*=vec3(1.035,1.005,0.965);
#elif COLOR_STYLE == 2
    float neutral=luminance(radiance);
    radiance=mix(vec3(neutral),radiance,0.88);
#endif
    radiance *= vec3(1.0 + WHITE_BALANCE, 1.0, 1.0 - WHITE_BALANCE);
    float brightness = luminance(radiance);
    radiance = mix(vec3(brightness), radiance, COLOR_SATURATION);
    if (COLOR_CONTRAST != 1.0) {
        float relative = max(brightness, 0.00001) / 0.18;
        radiance *= pow(relative, COLOR_CONTRAST - 1.0);
    }
    return max(radiance, vec3(0.0));
}
