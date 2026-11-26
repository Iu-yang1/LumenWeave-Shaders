float horizonCosine(vec2 originUv, vec2 stepUv, vec3 position, vec3 observer, vec3 normal) {
    float horizon = -1.0;
    for (int tap = 1; tap <= 4; ++tap) {
        vec2 uv = originUv + stepUv * (float(tap * tap) * (1.0 / 16.0));
        if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
            break;
        }
        ivec2 pixel = depthPixelAtUv(depthtex0, uv);
        vec2 pixelUv = depthPixelUv(depthtex0, pixel);
        float depth = texelFetch(depthtex0, pixel, 0).r;
        if (depth >= 1.0) {
            continue;
        }
#ifdef LW_STABLE_DYNAMIC
        int kind = sampleOwner(pixelUv, depth, false);
        vec3 samplePosition = reconstructProjection(pixelUv, depth, gbufferProjectionInverse, kind != 0);
        if (kind == 1) {
            vec3 sampleNormal = transpose(mat3(gbufferModelViewInverse)) * decodeNormal(texelFetch(colortex1,pixel,0).xy);
            samplePosition = stableViewSurfacePosition(samplePosition, unjitteredUv(uv,true), sampleNormal, gbufferProjectionInverse);
        }
#else
        vec3 samplePosition = reconstructViewPosition(pixelUv, depth);
#endif
        vec3 delta = samplePosition - position;
        float distanceSquared = dot(delta, delta);
        if (distanceSquared <= 0.0001 || distanceSquared >= 2.56 || dot(delta, normal) <= 0.025) {
            continue;
        }
        float cosine = dot(delta, observer) * inversesqrt(distanceSquared);
        float weight = 1.0 - smoothstep(0.36, 2.56, distanceSquared);
        horizon = max(horizon, mix(-1.0, cosine, weight));
    }
    return clamp(horizon, -1.0, 1.0);
}

float visibleArc(float horizon, float gamma) {
    float bound = min(horizon, max(gamma + LW_PI * 0.5, 0.0));
    return 0.25 * (cos(gamma) - cos(2.0 * bound - gamma) + 2.0 * bound * sin(gamma));
}

float groundTruthOcclusion(vec2 uv, vec3 position, vec3 normal) {
    vec3 observer = normalize(-position);
#ifdef LW_STABLE_DYNAMIC
    uv += jitterOffset(frameCounter);
#endif
    vec2 resolution = vec2(textureSize(depthtex0, 0));
    float scale = min(1.6 / max(-position.z, 0.01), 56.0 / resolution.y);
    vec2 projectionScale = 0.5 * vec2(gbufferProjection[0][0], gbufferProjection[1][1]);
    float visible = 0.0;
    float unoccluded = 0.0;
    for (int slice = 0; slice < AO_SLICES; ++slice) {
        float angle = (float(slice) + 0.5) * (LW_PI / float(AO_SLICES));
        vec2 axis = vec2(cos(angle), sin(angle));
        vec3 sliceAxis = vec3(axis, 0.0);
        sliceAxis = normalize(sliceAxis - dot(sliceAxis, observer) * observer);
        vec2 projectedNormal = vec2(dot(normal, observer), dot(normal, sliceAxis));
        float weight = length(projectedNormal);
        if (weight < 0.0001) {
            continue;
        }
        float gamma = atan(projectedNormal.y, max(projectedNormal.x, 0.00001));
        vec2 stepUv = axis * projectionScale * scale;
        float positive = acos(horizonCosine(uv, stepUv, position, observer, normal));
        float negative = acos(horizonCosine(uv, -stepUv, position, observer, normal));
        visible += weight * (visibleArc(positive, gamma) + visibleArc(negative, -gamma));
        unoccluded += weight * (visibleArc(LW_PI, gamma) + visibleArc(LW_PI, -gamma));
    }
    float visibility = clamp(visible / max(unoccluded, 0.0001), 0.0, 1.0);
    visibility = 1.0 - clamp((1.0 - visibility) * AO_STRENGTH, 0.0, 1.0);
    return mix(visibility, 1.0, smoothstep(20.0, 52.0, -position.z));
}
