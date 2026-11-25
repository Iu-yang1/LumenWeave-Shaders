#ifndef LW_COLOR_SCENE
#define LW_COLOR_SCENE

vec3 decodeSrgb(vec3 encoded) {
    vec3 low = encoded / 12.92;
    vec3 high = pow((encoded + 0.055) / 1.055, vec3(2.4));
    return mix(high, low, lessThanEqual(encoded, vec3(0.04045)));
}

vec3 encodeSrgb(vec3 linear) {
    vec3 low = linear * 12.92;
    vec3 high = 1.055 * pow(linear, vec3(1.0 / 2.4)) - 0.055;
    return mix(high, low, lessThanEqual(linear, vec3(0.0031308)));
}

float luminance(vec3 rgb) {
    return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec3 displayColor(vec3 radiance, float exposure) {
    vec3 exposed = max(radiance, vec3(0.0)) * exp2(exposure);
    float brightness = luminance(exposed);
    float mapped = brightness / (1.0 + brightness);
    vec3 color = exposed / (1.0 + brightness);
    float peak = max(color.r, max(color.g, color.b));
    if (peak > 1.0) {
        color = mix(vec3(mapped), color, (1.0 - mapped) / (peak - mapped));
    }
    return encodeSrgb(clamp(color, 0.0, 1.0));
}

#endif
