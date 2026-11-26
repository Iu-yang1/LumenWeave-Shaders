#ifndef LW_RECONSTRUCT_VIEW
#define LW_RECONSTRUCT_VIEW

uniform mat4 gbufferProjectionInverse;

#ifdef LW_TAA_ACTIVE
#include "/lib/temporal/jitter.glsl"
#endif

vec3 reconstructViewPosition(vec2 uv, float depth) {
#ifdef LW_TAA_ACTIVE
    uv -= jitterOffset(frameCounter);
#endif
    vec4 view = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return view.xyz / view.w;
}

#endif
