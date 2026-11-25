uniform mat4 gbufferProjectionInverse;

#if defined(TEMPORAL_AA) && defined(DEFERRED_LIGHTING)
#include "/lib/temporal/jitter.glsl"
#endif

vec3 reconstructViewPosition(vec2 uv, float depth) {
#if defined(TEMPORAL_AA) && defined(DEFERRED_LIGHTING)
    uv -= jitterOffset(frameCounter);
#endif
    vec4 view = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return view.xyz / view.w;
}
