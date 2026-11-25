struct Material {
    float roughness;
    float metallic;
    vec3 f0;
    vec3 emission;
    float occlusion;
};

Material vanillaMaterial(int blockId, vec3 albedo) {
    Material material = Material(0.78, 0.0, vec3(0.04), vec3(0.0), 1.0);
    if (blockId == 10001) {
        material.roughness = 0.94;
    } else if (blockId == 10002) {
        material.roughness = 0.38;
        material.metallic = 0.84;
    } else if (blockId == 10003) {
        material.roughness = 0.19;
    }
    material.f0 = mix(material.f0, albedo, material.metallic);

    vec3 emitter = vec3(0.0);
    if (blockId == 10011) {
        emitter = vec3(2.5, 1.40, 0.57);
    } else if (blockId == 10012) {
        emitter = vec3(0.38, 1.68, 2.35);
    } else if (blockId == 10013) {
        emitter = vec3(1.35, 2.0, 1.74);
    } else if (blockId == 10014) {
        emitter = vec3(1.90, 0.68, 0.30);
    }
    material.emission = emitter * smoothstep(0.20, 0.79, max(albedo.r, max(albedo.g, albedo.b)));
    return material;
}
