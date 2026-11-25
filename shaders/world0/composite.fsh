#version 330 compatibility

#include "/lib/quality.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 sceneColor;

#ifdef TEMPORAL_AA
#if defined(DEFERRED_LIGHTING)

#include "/lib/coordinates/reconstruct.glsl"
#include "/lib/materials/geometry_buffer.glsl"

/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RG16F;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
/* RENDERTARGETS: 0,4,5 */

layout(location = 1) out vec4 colorHistory;
layout(location = 2) out vec2 normalHistory;
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
    float normalThreshold = water ? 0.86 : mix(0.86, -0.05, smoothstep(32.0, 128.0, expectedDepth));
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
            vec2 previousNormal = texelFetch(colortex5, samplePixel, 0).rg;
            if (dot(currentNormal, decodeNormal(previousNormal)) < normalThreshold) {
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
    if (!reprojectTerrain(viewPosition, previousUv, expectedDepth, previousProjection)) {
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

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    sceneColor = texelFetch(colortex0, pixel, 0);
    colorHistory = vec4(0.0);
    normalHistory = vec2(0.0);
    vec3 viewPosition;
    mat4 previousProjection;
    bool water;
    bool valid = temporalGeometry(pixel, texCoord, viewPosition, normalHistory, previousProjection, water);
    bool sky = texelFetch(depthtex0, pixel, 0).r >= 1.0;
#ifdef DISTANT_HORIZONS
    sky = sky && texelFetch(dhDepthTex0, pixel, 0).r >= 1.0;
#endif
    if (!valid && !sky) {
        return;
    }
    if (sky || (valid && !water && -viewPosition.z > 32.0)) {
        const ivec2 neighbors[4] = ivec2[4](ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1));
        ivec2 size = textureSize(colortex0, 0);
        float closest = valid ? -viewPosition.z : 1e10;
        for (int tap = 0; tap < 4; ++tap) {
            ivec2 neighbor = pixel + neighbors[tap];
            if (any(lessThan(neighbor, ivec2(0))) || any(greaterThanEqual(neighbor, size))) {
                continue;
            }
            vec3 neighborPosition;
            vec2 neighborNormal;
            mat4 neighborProjection;
            bool neighborWater;
            if (temporalGeometry(neighbor, texCoord, neighborPosition, neighborNormal, neighborProjection, neighborWater)
                    && !neighborWater && -neighborPosition.z < closest - (valid ? max(0.1, closest * 0.012) : 0.0)) {
                closest = -neighborPosition.z;
                viewPosition = neighborPosition;
                normalHistory = neighborNormal;
                previousProjection = neighborProjection;
                water = false;
                valid = true;
            }
        }
    }
    if (!valid) {
        return;
    }
    sceneColor.rgb = temporalColor(sceneColor.rgb, viewPosition, normalHistory, pixel, previousProjection, water);
    colorHistory = vec4(sceneColor.rgb, water ? viewPosition.z : -viewPosition.z);
}

#endif
#endif

#if !defined(TEMPORAL_AA) || !defined(DEFERRED_LIGHTING)
/* RENDERTARGETS: 0 */

void main() {
    sceneColor = texture(colortex0, texCoord);
}
#endif
