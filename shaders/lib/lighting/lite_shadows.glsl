const float shadowDistance = SHADOW_RANGE;
const float shadowDistanceRenderMul = 1.0;
#if SHADOW_MAP != 0
const int shadowMapResolution = SHADOW_MAP;
#elif defined(DEFERRED_LIGHTING)
const int shadowMapResolution = 1024;
#else
const int shadowMapResolution = 512;
#endif
#ifdef SOFT_SHADOWS
const bool shadowHardwareFiltering = false;
uniform sampler2D shadowtex0;
#else
const bool shadowHardwareFiltering = true;
uniform sampler2DShadow shadowtex0;
#endif

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;

#ifdef SOFT_SHADOWS
float shadowDepth(vec2 uv, ivec2 resolution) {
    ivec2 pixel = clamp(ivec2(uv * vec2(resolution)), ivec2(0), resolution - 1);
    return texelFetch(shadowtex0, pixel, 0).r;
}

float filteredShadow(vec2 uv, float receiverDepth, ivec2 resolution) {
    vec2 position = uv * vec2(resolution) - 0.5;
    ivec2 base = ivec2(floor(position));
    vec2 fraction = fract(position);
    ivec2 limit = resolution - 1;
    float lowerLeft = step(receiverDepth, texelFetch(shadowtex0, clamp(base, ivec2(0), limit), 0).r);
    float lowerRight = step(receiverDepth, texelFetch(shadowtex0, clamp(base + ivec2(1, 0), ivec2(0), limit), 0).r);
    float upperLeft = step(receiverDepth, texelFetch(shadowtex0, clamp(base + ivec2(0, 1), ivec2(0), limit), 0).r);
    float upperRight = step(receiverDepth, texelFetch(shadowtex0, clamp(base + ivec2(1, 1), ivec2(0), limit), 0).r);
    return mix(mix(lowerLeft, lowerRight, fraction.x), mix(upperLeft, upperRight, fraction.x), fraction.y);
}

float softShadow(vec3 receiver) {
    const vec2 taps[8] = vec2[8](
        vec2(-0.59, -0.57), vec2(-0.22, -0.11), vec2(-0.87, 0.20), vec2(-0.17, 0.82),
        vec2(0.39, 0.42), vec2(0.62, -0.54), vec2(0.12, -0.85), vec2(0.89, 0.14)
    );
    ivec2 resolution = textureSize(shadowtex0, 0);
    vec2 texel = 1.0 / vec2(resolution);
    float sum = 0.0;
    float count = 0.0;
    for (int index = 0; index < SHADOW_FILTER_TAPS; ++index) {
        float depth = shadowDepth(receiver.xy + taps[index] * texel * 3.5, resolution);
        if (depth < receiver.z) {
            sum += depth;
            count += 1.0;
        }
    }
    if (count == 0.0) {
        return filteredShadow(receiver.xy, receiver.z, resolution);
    }
    float separation = (receiver.z - sum / count) * (2.0 / abs(shadowProjection[2][2]));
    float radius = clamp(separation * 0.018 / (2.0 * shadowDistance * texel.x), 1.0, 8.0);
    float samples = filteredShadow(receiver.xy, receiver.z, resolution);
    for (int index = 0; index < SHADOW_FILTER_TAPS; ++index) {
        samples += filteredShadow(receiver.xy + taps[index] * texel * radius, receiver.z, resolution);
    }
    return samples / float(SHADOW_FILTER_TAPS + 1);
}
#endif

float sceneShadow(vec3 position, vec3 normal, vec3 light) {
    vec3 shadowLight = normalize(worldDirection(shadowLightPosition));
    if (dot(shadowLight, light) < 0.9 || dot(normal, light) <= 0.0) {
        return 1.0;
    }
    float grazing = 1.0 - max(dot(normal, light), 0.0);
    float worldTexel = 2.0 * shadowDistance / float(shadowMapResolution);
    vec3 offset = normal * clamp(worldTexel * mix(0.22, 0.60, grazing), 0.012, 0.095);
    vec4 clip = shadowProjection * shadowModelView * vec4(position + offset, 1.0);
    vec3 samplePosition = clip.xyz / clip.w * 0.5 + 0.5;
    vec2 edge = abs(samplePosition.xy - 0.5);
    float range = max(edge.x, edge.y);
    if (range >= 0.49 || samplePosition.z <= 0.0 || samplePosition.z >= 1.0) {
        return 1.0;
    }
    samplePosition.z -= clamp(0.16 / float(shadowMapResolution), 0.00004, 0.00020);
#ifdef SOFT_SHADOWS
    float visibility = softShadow(samplePosition);
#else
    float visibility = texture(shadowtex0, samplePosition);
#endif
    return mix(visibility, 1.0, smoothstep(0.39, 0.49, range));
}
