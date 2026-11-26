uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec2 jitterOffset(int frame) {
    const vec2 sequence[8] = vec2[8](
        vec2(0.0, -0.16667), vec2(-0.25, 0.16667),
        vec2(0.25, -0.38889), vec2(-0.375, -0.05556),
        vec2(0.125, 0.27778), vec2(-0.125, -0.27778),
        vec2(0.375, 0.05556), vec2(-0.4375, 0.38889)
    );
    // Center the finite sequence, not only its theoretical Halton distribution.
    const vec2 mean = vec2(-0.0546875, 0.0);
    return (sequence[frame & 7] - mean) / max(vec2(viewWidth, viewHeight), vec2(1.0));
}
