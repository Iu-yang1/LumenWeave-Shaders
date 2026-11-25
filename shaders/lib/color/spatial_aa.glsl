float spatialBrightness(vec3 color, float exposureScale) {
    float brightness = max(luminance(color) * exposureScale, 0.0);
    return sqrt(brightness / (1.0 + brightness));
}

vec3 spatialAntialias(sampler2D image, vec2 uv, vec3 center, float exposure) {
    vec2 texel = 1.0 / vec2(textureSize(image, 0));
    vec2 lower = texel * 0.5;
    vec2 upper = 1.0 - lower;
    float exposureScale = exp2(exposure);
    vec3 bottomLeft = texture(image, clamp(uv + texel * vec2(-1.0, -1.0), lower, upper)).rgb;
    vec3 bottomRight = texture(image, clamp(uv + texel * vec2(1.0, -1.0), lower, upper)).rgb;
    vec3 topLeft = texture(image, clamp(uv + texel * vec2(-1.0, 1.0), lower, upper)).rgb;
    vec3 topRight = texture(image, clamp(uv + texel * vec2(1.0, 1.0), lower, upper)).rgb;
    vec4 values = vec4(
        spatialBrightness(bottomLeft, exposureScale), spatialBrightness(bottomRight, exposureScale),
        spatialBrightness(topLeft, exposureScale), spatialBrightness(topRight, exposureScale)
    );
    float middle = spatialBrightness(center, exposureScale);
    float darkest = min(middle, min(min(values.x, values.y), min(values.z, values.w)));
    float brightest = max(middle, max(max(values.x, values.y), max(values.z, values.w)));
    float contrast = brightest - darkest;
    if (contrast < max(0.032, brightest * 0.12)) {
        return center;
    }
    vec2 edge = vec2(values.z + values.w - values.x - values.y, values.x + values.z - values.y - values.w);
    float magnitude = max(abs(edge.x), abs(edge.y));
    if (magnitude < contrast * 0.15) {
        return mix(center, (bottomLeft + bottomRight + topLeft + topRight) * 0.25, 0.18);
    }
    vec2 weight = abs(edge) * (0.65 / magnitude);
    vec3 left = texture(image, clamp(uv - vec2(texel.x, 0.0), lower, upper)).rgb;
    vec3 right = texture(image, clamp(uv + vec2(texel.x, 0.0), lower, upper)).rgb;
    vec3 bottom = texture(image, clamp(uv - vec2(0.0, texel.y), lower, upper)).rgb;
    vec3 top = texture(image, clamp(uv + vec2(0.0, texel.y), lower, upper)).rgb;
    vec3 diagonal = edge.x * edge.y >= 0.0 ? (bottomLeft + topRight) * 0.5 : (bottomRight + topLeft) * 0.5;
    vec3 horizontal = mix(center, (left + right) * 0.5, weight.x);
    vec3 vertical = mix((bottom + top) * 0.5, diagonal, weight.x);
    return mix(center, mix(horizontal, vertical, weight.y), 0.65);
}
