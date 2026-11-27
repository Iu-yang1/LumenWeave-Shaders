#ifndef LW_CLOUD_NOISE
#define LW_CLOUD_NOISE
#include "/lib/weather/state.glsl"
float cloudHash(vec2 cell) {
    vec3 hash = fract(vec3(cell.xyx) * 0.1031);
    hash += dot(hash, hash.yzx + 33.33);
    return fract((hash.x + hash.y) * hash.z);
}

float proceduralCloudNoise(vec2 position) {
    vec2 cell = floor(position);
    vec2 blend = fract(position);
    blend = blend * blend * (3.0 - 2.0 * blend);
    vec2 high = vec2(cloudHash(cell + vec2(0.0, 1.0)), cloudHash(cell + vec2(1.0, 1.0)));
    vec2 low = vec2(cloudHash(cell), cloudHash(cell + vec2(1.0, 0.0)));
    return mix(mix(low.x, low.y, blend.x), mix(high.x, high.y, blend.x), blend.y);
}

#if CLOUD_NOISE_MODE == 1
uniform sampler2D lwCloudNoise;
#endif
float cloudNoise(vec2 position) {
#if CLOUD_NOISE_MODE == 1
    // 255 periodic lattice cells, four samples/cell and a two-texel pad.
    // Manual coordinate wrapping works even with clamped raw textures.
    return textureLod(lwCloudNoise,(mod(position,255.0)*4.0+2.5)/1024.0,0.0).r;
#else
    return proceduralCloudNoise(position);
#endif
}
vec2 cloudNoisePosition(vec3 position) {
    return cloudWindPosition(position.xz,frameTimeCounter)*0.017;
}
#endif
