const ivec3 neighborOffsets[6] = ivec3[6](
    ivec3(1, 0, 0), ivec3(-1, 0, 0), ivec3(0, 1, 0),
    ivec3(0, -1, 0), ivec3(0, 0, 1), ivec3(0, 0, -1)
);

vec4 propagate(ivec3 cell, ivec3 size) {
    vec4 seed = imageLoad(lwSeed, cell);
    if (seed.a > 0.5) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    vec3 radiance = seed.rgb;
    for (int neighborIndex = 0; neighborIndex < 6; ++neighborIndex) {
        ivec3 neighbor = cell + neighborOffsets[neighborIndex];
        if (all(greaterThanEqual(neighbor, ivec3(0))) && all(lessThan(neighbor, size))) {
            radiance = max(radiance, imageLoad(LW_PREVIOUS, neighbor).rgb * 0.75);
        }
    }
    return vec4(radiance, 0.0);
}
