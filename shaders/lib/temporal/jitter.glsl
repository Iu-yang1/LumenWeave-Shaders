uniform int frameCounter;
#ifndef LW_VIEW_SIZE_UNIFORMS
#define LW_VIEW_SIZE_UNIFORMS
uniform float viewWidth;
uniform float viewHeight;
#endif
#include "/lib/coordinates/raster_grid.glsl"

vec2 jitterOffset(int frame) {
#ifdef LW_GEOMETRY_TAAU
    return lwGeometryJitter(frame,lwRasterExtent(max(ivec2(viewWidth,viewHeight),ivec2(1))));
#elif !defined(LW_DYNAMIC_JITTER)
    return vec2(0.0);
#else
    const vec2 sequence[8] = vec2[8](
        vec2(0.0, -0.16667), vec2(-0.25, 0.16667),
        vec2(0.25, -0.38889), vec2(-0.375, -0.05556),
        vec2(0.125, 0.27778), vec2(-0.125, -0.27778),
        vec2(0.375, 0.05556), vec2(-0.4375, 0.38889)
    );
    // Center the finite sequence, not only its theoretical Halton distribution.
    const vec2 mean = vec2(-0.0546875, 0.0);
    return (sequence[frame & 7] - mean) / vec2(lwRasterExtent(max(ivec2(viewWidth,viewHeight),ivec2(1))));
#endif
}
