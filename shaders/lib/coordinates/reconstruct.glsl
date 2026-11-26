#ifndef LW_RECONSTRUCT_VIEW
#define LW_RECONSTRUCT_VIEW

uniform mat4 gbufferProjectionInverse;
#include "/lib/coordinates/raster_grid.glsl"

#ifdef LW_TAA_ACTIVE
#include "/lib/temporal/jitter.glsl"
#endif

vec2 unjitteredUv(vec2 uv, bool jittered) {
#ifdef LW_TAA_ACTIVE
    if (jittered) {
        uv -= jitterOffset(frameCounter);
    }
#endif
    return uv;
}

vec3 reconstructProjection(vec2 uv, float depth, mat4 inverseProjection, bool jittered) {
    vec4 view = inverseProjection * vec4(vec3(unjitteredUv(uv, jittered), depth) * 2.0 - 1.0, 1.0);
    return view.xyz / view.w;
}

vec3 reconstructViewPosition(vec2 uv, float depth) {
    return reconstructProjection(uv, depth, gbufferProjectionInverse, true);
}

ivec2 depthPixelAtUv(sampler2D tex, vec2 uv) {
    ivec2 size = lwRasterSize(tex);
    return clamp(ivec2(uv * vec2(size)), ivec2(0), size - 1);
}

vec2 depthPixelUv(sampler2D tex, ivec2 pixel) {
    return (vec2(pixel) + 0.5) / vec2(lwRasterSize(tex));
}

float depthAtUv(sampler2D tex, vec2 uv) {
    return texelFetch(tex, depthPixelAtUv(tex, uv), 0).r;
}

// Shared screen-ray projection for native depth, reflection and GI.
vec2 lwProjectedRayUv(vec3 position,mat4 projection,out float rayDepth) {
    vec4 clip=projection*vec4(position,1.0);
    rayDepth=clip.z/clip.w*0.5+0.5;
    vec2 uv=clip.xy/clip.w*0.5+0.5;
#ifdef LW_TAA_ACTIVE
    uv+=jitterOffset(frameCounter);
#endif
    return uv;
}

// A common plane intersection for raster coverage, lighting and history.
vec3 stableViewSurfacePosition(vec3 samplePosition, vec2 stableUv, vec3 normalView, mat4 projectionInverse) {
    vec4 clip = projectionInverse * vec4(stableUv * 2.0 - 1.0, 1.0, 1.0);
    vec3 ray = normalize(clip.xyz);
    float denominator = dot(normalView, ray);
    if (abs(denominator) > 0.02) {
        float distance = dot(normalView, samplePosition) / denominator;
        vec3 position = ray * distance;
        if (distance > 0.0 && abs(position.z - samplePosition.z) < max(0.10, -samplePosition.z * 0.03)) {
            return position;
        }
    }
    return ray * (samplePosition.z / min(ray.z, -0.00001));
}

#endif
