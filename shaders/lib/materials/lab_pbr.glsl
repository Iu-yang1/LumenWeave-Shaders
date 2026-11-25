float encodeLabSpecular(vec4 specularData) {
    vec3 bytes = round(specularData.rga * 255.0);
    return dot(bytes, vec3(1.0, 256.0, 65536.0));
}

vec3 labWorldNormal(vec3 normal, vec4 tangent, vec2 packedNormal) {
    vec3 corrected = tangent.xyz - normal * dot(tangent.xyz, normal);
    float tangentLength = dot(corrected, corrected);
    if (tangentLength < 0.00001) {
        return normal;
    }
    vec3 axis = corrected * inversesqrt(tangentLength);
    vec3 bitangent = cross(normal, axis) * tangent.w;
    vec2 offset = packedNormal * 2.0 - 1.0;
    offset = mix(offset, vec2(0.0), lessThan(abs(offset), vec2(0.004)));
    float height = sqrt(max(1.0 - dot(offset, offset), 0.0));
    return normalize(axis * offset.x + bitangent * offset.y + normal * height);
}

vec3 labReflectance(int green, vec3 albedo) {
    if (green < 230) {
        return vec3(float(green) / 255.0);
    }
    if (green > 237) {
        return albedo;
    }
    const vec3 indices[8] = vec3[8](
        vec3(2.9114, 2.9497, 2.5845),
        vec3(0.18299, 0.42108, 1.3734),
        vec3(1.3456, 0.96521, 0.61722),
        vec3(3.1071, 3.1812, 2.3230),
        vec3(0.27105, 0.67693, 1.3164),
        vec3(1.9100, 1.8300, 1.4400),
        vec3(2.3757, 2.0847, 1.8453),
        vec3(0.15943, 0.14512, 0.13547)
    );
    const vec3 extinction[8] = vec3[8](
        vec3(3.0893, 2.9318, 2.7670),
        vec3(3.4242, 2.3459, 1.7704),
        vec3(7.4746, 6.3995, 5.3031),
        vec3(3.3314, 3.3291, 3.1350),
        vec3(3.6092, 2.6248, 2.2921),
        vec3(3.5100, 3.4000, 3.1800),
        vec3(4.2655, 3.7153, 3.1365),
        vec3(3.9291, 3.1900, 2.3808)
    );
    vec3 index = indices[green - 230];
    vec3 lossSquared = extinction[green - 230] * extinction[green - 230];
    vec3 lower = index - 1.0;
    vec3 upper = index + 1.0;
    return albedo * (lower * lower + lossSquared) / (upper * upper + lossSquared);
}
