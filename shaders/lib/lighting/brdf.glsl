vec3 fresnelSchlick(float cosine, vec3 f0) {
    float grazing = 1.0 - cosine;
    float squared = grazing * grazing;
    return f0 + (1.0 - f0) * (squared * squared * grazing);
}

vec3 directBrdf(vec3 albedo, Material material, vec3 normal, vec3 view, vec3 light, vec3 f0) {
    float normalLight = dot(normal, light);
    if (normalLight <= 0.0) {
        return vec3(0.0);
    }

    vec3 halfVector = view + light;
    halfVector *= inversesqrt(max(dot(halfVector, halfVector), 0.00001));
    float normalView = max(dot(normal, view), 0.001);
    float normalHalf = max(dot(normal, halfVector), 0.0);
    float viewHalf = max(dot(view, halfVector), 0.0);
    vec3 fresnel = fresnelSchlick(viewHalf, f0);
    float alpha = material.roughness * material.roughness;
    float alphaSquared = alpha * alpha;
    float distributionTerm = normalHalf * normalHalf * (alphaSquared - 1.0) + 1.0;
    float distribution = alphaSquared / (LW_PI * distributionTerm * distributionTerm);
    float mask = (material.roughness + 1.0) * (material.roughness + 1.0) * 0.125;
    float visibility = 0.25 / (mix(normalView, 1.0, mask) * mix(normalLight, 1.0, mask));
    vec3 diffuse = (1.0 - fresnel) * (1.0 - material.metallic) * albedo / LW_PI;
    return (diffuse + fresnel * distribution * visibility) * normalLight;
}
