#ifndef LW_REFLECTION_TRACE
#define LW_REFLECTION_TRACE
#ifndef LW_REFLECTION_DEPTH
#define LW_REFLECTION_DEPTH depthtex1
#endif
uniform sampler2D colortex8;
uniform mat4 gbufferProjection;

bool insideScreen(vec2 uv) {
    return all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)));
}

bool reflectionRayDepth(vec3 ray, out vec2 uv, out float delta) {
    vec4 projected = gbufferProjection * vec4(ray, 1.0);
    uv = projected.xy / projected.w * 0.5 + 0.5;
#ifdef LW_TAA_ACTIVE
    uv += jitterOffset(frameCounter);
#endif
    if (!insideScreen(uv)) {
        return false;
    }
    ivec2 size = textureSize(LW_REFLECTION_DEPTH, 0);
    ivec2 pixel = clamp(ivec2(uv * vec2(size)), ivec2(0), size - 1);
    float depth = texelFetch(LW_REFLECTION_DEPTH, pixel, 0).r;
    vec2 pixelUv = (vec2(pixel) + 0.5) / vec2(size);
    delta = depth < 1.0 ? reconstructViewPosition(pixelUv, depth).z - ray.z : -1.0;
    return true;
}

vec4 traceScreenReflection(vec3 origin, vec3 direction, int steps) {
    float travel = 0.30;
    float previousTravel = 0.0;
    float previousDelta = -1.0;
    for (int tap = 0; tap < steps; ++tap) {
        vec3 ray = origin + direction * travel;
        if (ray.z > -0.12 || travel > 48.0) {
            break;
        }
        vec2 uv;
        float delta;
        if (!reflectionRayDepth(ray, uv, delta)) {
            break;
        }
        if (previousDelta < 0.0 && delta >= 0.0) {
            float lo = previousTravel;
            float hi = travel;
            // Resolve the crossing rather than rejecting long marching steps.
            for (int refine = 0; refine < 4; ++refine) {
                float mid = (lo + hi) * 0.5;
                vec2 midUv;
                float midDelta;
                if (!reflectionRayDepth(origin + direction * mid, midUv, midDelta) || midDelta < 0.0) {
                    lo = mid;
                } else {
                    hi = mid;
                    uv = midUv;
                    delta = midDelta;
                }
            }
            float thickness = 0.20 + hi * 0.035;
            if (delta < thickness && hi > 0.12) {
                vec2 edge = min(uv, 1.0 - uv);
                float confidence = smoothstep(0.0, 0.08, min(edge.x, edge.y));
                confidence *= 1.0 - smoothstep(18.0, 48.0, hi);
                confidence *= 1.0 - smoothstep(thickness * 0.65, thickness, delta);
                return vec4(texture(colortex8, uv).rgb, confidence);
            }
        }
        previousTravel = travel;
        previousDelta = delta;
        travel += 0.28 + travel * 0.26;
    }
    return vec4(0.0);
}

#endif
