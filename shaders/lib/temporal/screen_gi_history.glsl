#include "/lib/temporal/reproject.glsl"

#ifndef LW_GI_HISTORY_SAMPLERS
#define LW_GI_HISTORY_SAMPLERS
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#endif

#ifdef LW_HALF_GI_HISTORY
uniform float lwGiHistoryTime;
vec2 giHistoryFrameTag(int frame) { return vec2((frame&1023)+1,((frame>>10)&1023)+1); }
bool giHistoryFresh() {
    vec4 state=texelFetch(colortex7,ivec2(0),0);
    vec2 clock=texelFetch(colortex7,ivec2(1,0),0).xy;
    float age=abs(clock.x+64.0*clock.y-lwGiHistoryTime);
    age=min(age,3600.0-age);
    return all(equal(state.xy,vec2(lwRasterSize(colortex6)))) &&
        all(equal(state.zw,giHistoryFrameTag(frameCounter-1))) && age<0.10;
}
#endif

vec3 temporalScreenBounce(vec3 current, vec3 viewPosition, vec3 normal, vec2 encodedNormal, vec2 uv) {
#ifdef LW_HALF_GI_HISTORY
    if(!giHistoryFresh()) return current;
#endif
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
    vec2 motionSize=vec2(lwRasterSize(depthtex0));
#if APPROX_REUSE == 1
    if (length((previousUv - uv) * motionSize) < 0.20) {
        ivec2 nearest = clamp(ivec2(previousUv * vec2(size)), ivec2(0), size - 1);
        vec4 history = texelFetch(colortex6, nearest, 0);
        vec4 metadata = texelFetch(colortex7, nearest, 0);
        if (matchesHistoryDepth(history.a, expectedDepth) &&
            all(lessThanEqual(abs(metadata.zw - vec2(size)), vec2(1.0))) &&
            geometryNormalAlignment(normal, encodedNormal, metadata.xy) > 0.96 &&
            all(lessThanEqual(abs(history.rgb - current), vec3(0.001) + abs(current) * 0.008))) {
            float weight = 0.78 * (1.0 - smoothstep(26.0, 30.0, expectedDepth));
            return mix(current, history.rgb, weight);
        }
    }
#endif
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
                geometryNormalAlignment(normal, encodedNormal, metadata.xy) < 0.90) {
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
    float motion = length((previousUv - uv) * motionSize);
    float weight = 0.78 * coverage * (1.0 - smoothstep(2.0, 20.0, motion));
#if defined(LW_HALF_GI_HISTORY) && GI_EDGE_RECONSTRUCTION == 1
    weight*=smoothstep(0.25,0.75,coverage);
    weight*=1.0-smoothstep(0.5,8.0,motion)*0.35;
#endif
    weight *= 1.0 - smoothstep(26.0, 30.0, expectedDepth);
    return mix(current, min(history, current * 1.45 + vec3(0.002)), weight * agreement);
}
