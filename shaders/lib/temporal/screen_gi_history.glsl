#include "/lib/temporal/reproject.glsl"

uniform sampler2D colortex6;
uniform sampler2D colortex7;

vec3 temporalScreenBounce(vec3 current, vec3 viewPosition, vec3 normal, vec2 uv) {
    vec2 previousUv;
    float expectedDepth;
#ifdef LW_STABLE_DYNAMIC
    // Stable lighting samples are written on the unjittered grid.
    if (!reprojectStableTerrain(viewPosition, previousUv, expectedDepth, gbufferPreviousProjection)) {
#else
    if (!reprojectTerrain(viewPosition, previousUv, expectedDepth)) {
#endif
        return current;
    }
    ivec2 size = lwRasterSize(colortex6);
    vec2 previousTexel = previousUv * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(previousTexel));
    vec2 fraction = fract(previousTexel);
    vec3 accumulated = vec3(0.0);
    float coverage = 0.0;
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 pixel = base + ivec2(column, row);
            if (any(lessThan(pixel, ivec2(0))) || any(greaterThanEqual(pixel, size))) {
                continue;
            }
            vec4 history = texelFetch(colortex6, pixel, 0);
            if (!matchesHistoryDepth(history.a, expectedDepth)) {
                continue;
            }
            vec4 metadata = texelFetch(colortex7, pixel, 0);
            if (any(greaterThan(abs(metadata.zw - vec2(size)), vec2(1.0))) ||
                dot(normal, decodeNormal(metadata.xy)) < 0.90) {
                continue;
            }
            vec2 weights = mix(1.0 - fraction, fraction, vec2(column, row));
            float weight = weights.x * weights.y;
            accumulated += history.rgb * weight;
            coverage += weight;
        }
    }
    if (coverage < 0.25) {
        return current;
    }
    vec3 history = accumulated / coverage;
    vec3 disagreement = abs(history - current) / max(max(history, current), vec3(0.006));
    vec3 agreement = 1.0 - smoothstep(vec3(0.17), vec3(0.45), disagreement);
    float motion = length((previousUv - uv) * vec2(size));
    float weight = 0.78 * coverage * (1.0 - smoothstep(2.0, 20.0, motion));
    weight *= 1.0 - smoothstep(26.0, 30.0, expectedDepth);
    return mix(current, min(history, current * 1.45 + vec3(0.002)), weight * agreement);
}
