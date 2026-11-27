vec2 encodeNormal(vec3 normal) {
    normal /= abs(normal.x) + abs(normal.y) + abs(normal.z);
    vec2 octant = mix(vec2(-1.0), vec2(1.0), greaterThanEqual(normal.xy, vec2(0.0)));
    return normal.z >= 0.0 ? normal.xy : (1.0 - abs(normal.yx)) * octant;
}

vec3 decodeNormal(vec2 encoded) {
    vec3 normal = vec3(encoded, 1.0 - abs(encoded.x) - abs(encoded.y));
    vec2 octant = mix(vec2(-1.0), vec2(1.0), greaterThanEqual(encoded, vec2(0.0)));
    normal.xy -= octant * max(-normal.z, 0.0);
    return normalize(normal);
}

float geometryNormalAlignment(vec3 normal, vec2 encoded, vec2 donor) {
    return all(equal(encoded, donor)) ? 1.0 : dot(normal, decodeNormal(donor));
}
