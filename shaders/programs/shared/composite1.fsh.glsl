#version 330 compatibility

#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 sceneColor;

#ifdef LW_TAA_ACTIVE
#if defined(DEFERRED_LIGHTING)

#include "/lib/coordinates/reconstruct.glsl"
#include "/lib/materials/geometry_buffer.glsl"

/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex5ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
/* RENDERTARGETS: 0,4,5 */

layout(location = 1) out vec4 colorHistory;
layout(location = 2) out vec4 normalHistory;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferModelViewInverse;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
#endif

#include "/lib/temporal/reproject.glsl"

vec3 clipHistory(ivec2 pixel, vec3 history) {
    ivec2 limit = textureSize(colortex0, 0) - 1;
    vec3 lower = texelFetch(colortex0, pixel, 0).rgb;
    vec3 upper = lower;
    for (int row = -1; row <= 1; ++row) {
        for (int column = -1; column <= 1; ++column) {
            if (row == 0 && column == 0) {
                continue;
            }
            ivec2 adjacent = clamp(pixel + ivec2(column, row), ivec2(0), limit);
            vec3 sampleColor = texelFetch(colortex0, adjacent, 0).rgb;
            lower = min(lower, sampleColor);
            upper = max(upper, sampleColor);
        }
    }
    return clamp(history, lower, upper);
}

vec4 filteredHistory(vec2 uv, float expectedDepth, vec2 normal, bool water) {
    ivec2 size = textureSize(colortex4, 0);
    vec2 position = uv * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(position));
    vec2 fraction = fract(position);
    vec4 result = vec4(0.0);
    vec3 currentNormal = decodeNormal(normal);
    float normalThreshold = water ? 0.86 : mix(0.86, 0.25, smoothstep(32.0, 128.0, expectedDepth));
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 samplePixel = base + ivec2(column, row);
            if (any(lessThan(samplePixel, ivec2(0))) || any(greaterThanEqual(samplePixel, size))) {
                continue;
            }
            vec4 history = texelFetch(colortex4, samplePixel, 0);
            if ((history.a < 0.0) != water || !matchesHistoryDepth(abs(history.a), expectedDepth)) {
                continue;
            }
            vec4 metadata = texelFetch(colortex5, samplePixel, 0);
            // Half-float stores common display dimensions exactly. Allow one pixel
            // for rounding odd widths above 2048; reject resized/stale history.
            if (any(greaterThan(abs(metadata.zw - vec2(size)), vec2(1.0)))
                    || dot(currentNormal, decodeNormal(metadata.xy)) < normalThreshold) {
                continue;
            }
            vec2 weights = mix(1.0 - fraction, fraction, vec2(column, row));
            float weight = weights.x * weights.y;
            result += vec4(history.rgb, 1.0) * weight;
        }
    }
    if (result.a > 0.0) {
        result.rgb /= result.a;
    }
    return result;
}

vec3 temporalColor(vec3 current, vec3 viewPosition, vec2 normal, ivec2 pixel, mat4 previousProjection, bool water) {
    vec2 previousUv;
    float expectedDepth;
    if (!reprojectStableTerrain(viewPosition, previousUv, expectedDepth, previousProjection)) {
        return current;
    }
    vec2 size = vec2(textureSize(colortex4, 0));
    vec4 historySample = filteredHistory(previousUv, expectedDepth, normal, water);
    if (historySample.a <= 0.0) {
        return current;
    }
    vec3 clipped = clipHistory(pixel, historySample.rgb);
    float motion = length((previousUv - texCoord) * size);
    float stationaryWeight = mix(0.92, 0.97, smoothstep(32.0, 128.0, -viewPosition.z));
    float weight = water ? mix(0.78, 0.55, smoothstep(2.0, 20.0, motion))
        : mix(stationaryWeight, 0.72, smoothstep(2.0, 20.0, motion));
    weight *= smoothstep(0.0, 0.5, historySample.a);
    float materialId = texelFetch(colortex2, pixel, 0).y;
    if (materialId >= 10030.0 && materialId <= 10033.0) {
        weight *= 0.45;
    }
    return mix(current, clipped, weight);
}

bool temporalGeometry(ivec2 pixel, vec2 uv, out vec3 viewPosition, out vec2 normal,
        out mat4 previousProjection, out bool water) {
    float depth = texelFetch(depthtex0, pixel, 0).r;
    float opaqueDepth = texelFetch(depthtex1, pixel, 0).r;
    float terrainDepth = texelFetch(colortex2, pixel, 0).r;
    vec4 geometry = texelFetch(colortex1, pixel, 0);
    water = geometry.z == -1.0;
    normal = geometry.xy;
    previousProjection = gbufferPreviousProjection;
    if (depth < 1.0) {
        if (!water && (abs(depth - terrainDepth) > 0.00000012 || abs(depth - opaqueDepth) > 0.00000012)) {
            return false;
        }
        viewPosition = reconstructViewPosition(uv, depth);
    } else {
#ifdef DISTANT_HORIZONS
        float distantDepth = texelFetch(dhDepthTex0, pixel, 0).r;
        float distantOpaqueDepth = texelFetch(dhDepthTex1, pixel, 0).r;
        if (distantDepth >= 1.0 || (!water && abs(distantDepth - distantOpaqueDepth) > 0.00000012)) {
            return false;
        }
        vec2 distantUv = uv - jitterOffset(frameCounter);
        vec4 distantView = dhProjectionInverse * vec4(vec3(distantUv, distantDepth) * 2.0 - 1.0, 1.0);
        viewPosition = distantView.xyz / distantView.w;
        previousProjection = dhPreviousProjection;
#else
        return false;
#endif
    }
    return true;
}

vec3 stableSurfacePosition(vec3 samplePosition, vec2 stableUv, vec2 encodedNormal, mat4 projectionInverse) {
    vec4 clip = projectionInverse * vec4(stableUv * 2.0 - 1.0, 1.0, 1.0);
    vec3 ray = normalize(clip.xyz);
    vec3 normal = transpose(mat3(gbufferModelViewInverse)) * decodeNormal(encodedNormal);
    float denominator = dot(normal, ray);
    // Intersect the pixel-center ray with the locally planar surface.
    if (abs(denominator) > 0.02) {
        float distance = dot(normal, samplePosition) / denominator;
        vec3 position = ray * distance;
        if (distance > 0.0 && abs(position.z - samplePosition.z) < max(0.10, -samplePosition.z * 0.03)) {
            return position;
        }
    }
    return ray * (samplePosition.z / min(ray.z, -0.00001));
}

vec3 resolveCurrent(ivec2 pixel, vec2 stableUv, vec3 position, vec2 normal, bool water, bool distant) {
    ivec2 size = textureSize(colortex0, 0);
    vec2 location = (stableUv + jitterOffset(frameCounter)) * vec2(size) - 0.5;
    ivec2 base = ivec2(floor(location));
    vec2 fraction = fract(location);
    vec3 color = vec3(0.0);
    float sum = 0.0;
    vec3 referenceNormal = decodeNormal(normal);
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 neighbor = base + ivec2(column, row);
            if (any(lessThan(neighbor, ivec2(0))) || any(greaterThanEqual(neighbor, size))) {
                continue;
            }
            vec2 neighborUv = (vec2(neighbor) + 0.5) / vec2(size);
            vec3 samplePosition;
            vec2 sampleNormal;
            mat4 sampleProjection;
            bool sampleWater;
            if (!temporalGeometry(neighbor, neighborUv, samplePosition, sampleNormal, sampleProjection, sampleWater)
                    || sampleWater != water
                    || (texelFetch(depthtex0, neighbor, 0).r >= 1.0) != distant
                    || abs(samplePosition.z - position.z) > max(0.08, -position.z * 0.025)
                    || dot(referenceNormal, decodeNormal(sampleNormal)) < 0.60) {
                continue;
            }
            vec2 weight = mix(1.0 - fraction, fraction, vec2(column, row));
            float w = weight.x * weight.y;
            color += texelFetch(colortex0, neighbor, 0).rgb * w;
            sum += w;
        }
    }
    return sum > 0.0001 ? color / sum : texelFetch(colortex0, pixel, 0).rgb;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(colortex0, 0);
    vec2 stableUv = (vec2(pixel) + 0.5) / vec2(size);
    sceneColor = texelFetch(colortex0, pixel, 0);
    colorHistory = vec4(0.0);
    normalHistory = vec4(0.0);
    vec3 viewPosition;
    vec2 normal;
    mat4 previousProjection;
    bool water;
    if (!temporalGeometry(pixel, stableUv, viewPosition, normal, previousProjection, water)) {
        return;
    }

    bool distant = texelFetch(depthtex0, pixel, 0).r >= 1.0;
    mat4 projectionInverse = gbufferProjectionInverse;
#ifdef DISTANT_HORIZONS
    if (distant) {
        projectionInverse = dhProjectionInverse;
    }
#endif
    vec3 stablePosition = stableSurfacePosition(viewPosition, stableUv, normal, projectionInverse);
    vec3 current = resolveCurrent(pixel, stableUv, stablePosition, normal, water, distant);
    sceneColor.rgb = temporalColor(current, stablePosition, normal, pixel, previousProjection, water);
    colorHistory = vec4(sceneColor.rgb, water ? stablePosition.z : -stablePosition.z);
    normalHistory = vec4(normal, vec2(size));
}

#endif
#endif

#ifndef LW_TAA_ACTIVE
/* RENDERTARGETS: 0 */

void main() {
    sceneColor = texture(colortex0, texCoord);
}
#endif
