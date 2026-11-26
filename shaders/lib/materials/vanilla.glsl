#include "/lib/lighting/emitter_palette.glsl"

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

    uint kind = emitterKind(blockId);
    if (kind!=0u) {
        float peak = max(albedo.r,max(albedo.g,albedo.b));
        float mask = smoothstep(0.045,0.65,peak);
        // Keep the emissive texture's luminance and hue detail rather than
        // painting its dark seams and bright pixels a uniform solid color.
        vec3 tint = mix(albedo,emitterColor(kind)*peak,0.45);
        material.emission = tint*emitterRadiance(kind)*mask;
    }
    if (kind==5u) {
        material.roughness = 0.32;
        material.f0 = vec3(0.045);
    }
    return material;
}
