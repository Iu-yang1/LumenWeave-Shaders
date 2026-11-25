#include "/lib/materials/lab_pbr.glsl"

Material labMaterial(Material defaults, vec3 albedo, float packedSpecular, float occlusion) {
    defaults.occlusion = occlusion;
    if (packedSpecular == 0.0) {
        return defaults;
    }
    uint bits = uint(packedSpecular);
    float smoothness = float(bits & 255u) / 255.0;
    int green = int((bits >> 8u) & 255u);
    float emissionCode = float(bits >> 16u);
    float emission = emissionCode < 255.0 ? emissionCode / 254.0 : 0.0;
    return Material(
        max(1.0 - smoothness, 0.11),
        green < 230 ? 0.0 : 1.0,
        labReflectance(green, albedo),
        albedo * (emission * 2.5),
        occlusion
    );
}
