#version 330 compatibility

#include "/lib/quality.glsl"
#include "/lib/coordinates/raster_grid.glsl"

uniform sampler2D colortex0;
in vec2 texCoord;
layout(location = 0) out vec4 outputColor;
/* RENDERTARGETS: 0 */

#ifdef MOTION_BLUR
#include "/lib/coordinates/reconstruct.glsl"
uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
#endif

vec3 motionBlur(vec3 center) {
    vec3 cameraDelta = cameraPosition - previousCameraPosition;
    if (dot(cameraDelta, cameraDelta) > 16.0) {
        return center;
    }
    float depth = lwPostDepth(depthtex0,texCoord);
    if (depth < 0.55) {
        return center;
    }
    bool distant = false;
    mat4 projectionInverse = gbufferProjectionInverse;
    mat4 previousProjection = gbufferPreviousProjection;
#ifdef DISTANT_HORIZONS
    if (depth >= 1.0) {
        depth = lwPostDepth(dhDepthTex0,texCoord);
        distant = depth < 1.0;
        projectionInverse = dhProjectionInverse;
        previousProjection = dhPreviousProjection;
    }
#endif
    vec2 currentUv = texCoord;
#if defined(LW_TAA_ACTIVE) && !defined(LW_GEOMETRY_TAAU)
    currentUv -= jitterOffset(frameCounter);
#endif
    vec4 position = projectionInverse * vec4(vec3(currentUv, min(depth, 0.99999)) * 2.0 - 1.0, 1.0);
    vec3 view = position.xyz / position.w;
    vec3 relative = (gbufferModelViewInverse * vec4(view, 1.0)).xyz;
    vec4 previousView = depth >= 1.0
        ? gbufferPreviousModelView * vec4(mat3(gbufferModelViewInverse) * view, 0.0)
        : gbufferPreviousModelView * vec4(relative + cameraDelta, 1.0);
    vec4 previousClip = previousProjection * previousView;
    if (previousClip.w <= 0.0) {
        return center;
    }
    vec2 velocity = (currentUv - (previousClip.xy / previousClip.w * 0.5 + 0.5)) * MOTION_BLUR_STRENGTH;
    vec2 resolution = vec2(textureSize(colortex0, 0));
    float pixels = length(velocity * resolution);
    if (pixels < 0.35) {
        return center;
    }
    velocity *= min(1.0, 24.0 / pixels);
    vec3 accumulated = center;
    float total = 1.0;
    for (int tap = 0; tap < MOTION_BLUR_SAMPLES; ++tap) {
        float offset = (float(tap) + 0.5) / float(MOTION_BLUR_SAMPLES) - 0.5;
        vec2 uv = texCoord + velocity * offset;
        if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
            continue;
        }
        float adjacentDepth = lwPostDepth(depthtex0,uv);
#ifdef DISTANT_HORIZONS
        if (distant && adjacentDepth >= 1.0) {
            adjacentDepth = lwPostDepth(dhDepthTex0,uv);
        }
#endif
        if ((adjacentDepth >= 1.0) != (depth >= 1.0)) {
            continue;
        }
        if (depth < 1.0) {
            vec4 adjacent = projectionInverse * vec4(vec3(uv, adjacentDepth) * 2.0 - 1.0, 1.0);
            if (abs(adjacent.z / adjacent.w - view.z) > max(0.5, -view.z * 0.035)) {
                continue;
            }
        }
        float weight = 1.0 - abs(offset);
        accumulated += texture(colortex0, uv).rgb * weight;
        total += weight;
    }
    return accumulated / total;
}
#endif

void main() {
    outputColor = texture(colortex0, texCoord);
#ifdef MOTION_BLUR
    outputColor.rgb = motionBlur(outputColor.rgb);
#endif
}
