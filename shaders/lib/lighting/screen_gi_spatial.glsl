uniform sampler2D colortex9;
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler2D colortex10;
#endif

ScreenBounce spatialScreenBounce(vec3 viewPosition, vec3 normal, vec3 sun, vec2 uv) {
    float sceneDepth = -viewPosition.z;
    ScreenBounce bounce = ScreenBounce(vec3(0.0), vec3(0.0), 0.0);
    if (sceneDepth >= 30.0) {
        return bounce;
    }
    ivec2 traceSize = lwRasterSize(colortex9);
    ivec2 fullSize = lwRasterSize(colortex1);
    vec2 samplePosition = uv * vec2(traceSize) - 0.5;
    ivec2 base = ivec2(floor(samplePosition));
    vec2 fraction = fract(samplePosition);
    float tolerance = max(0.12, sceneDepth * 0.022);
    float coverage = 0.0;
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 texel = base + ivec2(column, row);
            if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, traceSize))) {
                continue;
            }
            vec2 weights = mix(1.0 - fraction, fraction, vec2(column, row));
            if (weights.x * weights.y <= 0.00001) continue;
            vec4 sky = texelFetch(colortex9, texel, 0);
            float depthDifference = abs(sky.a - sceneDepth);
            if (sky.a <= 0.0 || depthDifference >= tolerance) {
                continue;
            }
            ivec2 pixel = ivec2((vec2(texel) + 0.5) * vec2(fullSize) / vec2(traceSize));
            vec3 donorNormal = decodeNormal(texelFetch(colortex1, pixel, 0).xy);
            if (dot(normal, donorNormal) <= 0.82) {
                continue;
            }
            float weight = weights.x * weights.y * (1.0 - smoothstep(0.35, 1.0, depthDifference / tolerance));
            coverage += weight;
            bounce.sky += sky.rgb * weight;
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
            vec4 block = texelFetch(colortex10, texel, 0);
            bounce.block += block.rgb * weight;
            bounce.blockConfidence += block.a * weight;
#endif
        }
    }
#if APPROX_REUSE == 1
    // Reuse only depth/normal-compatible donors. A genuine disocclusion
    // uses two opposed rays rather than four full retraces.
    if(coverage>0.003) return ScreenBounce(bounce.sky/coverage,bounce.block/coverage,bounce.blockConfidence/coverage);
    return screenDiffuseBounceBudget(viewPosition,normal,sun,2);
#else
    // Compatible donors are normalized even if only one contributes.
    // Preserve an exact near-field fallback only for true disocclusions.
    if (coverage <= 0.003) {
        return screenDiffuseBounce(viewPosition, normal, sun);
    }
    ScreenBounce filtered = ScreenBounce(bounce.sky / coverage, bounce.block / coverage, bounce.blockConfidence / coverage);
    if (coverage < 0.035) {
        ScreenBounce full = screenDiffuseBounce(viewPosition, normal, sun);
        float confidence = smoothstep(0.003, 0.035, coverage);
        filtered.sky = mix(full.sky, filtered.sky, confidence);
        filtered.block = mix(full.block, filtered.block, confidence);
        filtered.blockConfidence = mix(full.blockConfidence, filtered.blockConfidence, confidence);
    }
    return filtered;
#endif
}
