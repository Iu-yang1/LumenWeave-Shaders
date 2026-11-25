#include "/lib/materials/vanilla.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/voxel/features.glsl"
#ifdef LW_VOXEL_ACTIVE
#include "/lib/voxel/irradiance.glsl"
#endif
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif

vec3 surfaceRadiance(vec3 albedo, Material material, vec3 normal, vec3 view, vec3 sun, vec2 lightLevels, vec3 viewPosition) {
    vec3 f0 = material.f0;
    vec3 ambient;
#ifdef LW_VOXEL_ACTIVE
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 coloredLight = voxelIrradiance(position, normal);
    float influence = smoothstep(0.025, 0.65, max(coloredLight.r, max(coloredLight.g, coloredLight.b)));
    vec3 uncolored = ambientIrradiance(lightLevels, normal.y, sun);
    vec3 colored = ambientIrradiance(vec2(0.0, lightLevels.y), normal.y, sun) + coloredLight;
    ambient = mix(uncolored, colored, influence) * material.occlusion;
#else
    ambient = ambientIrradiance(lightLevels, normal.y, sun) * material.occlusion;
#endif
    float skyAccess = smoothstep(0.56, 1.0, lightLevels.y);
    vec3 light = sun.y >= 0.0 ? sun : -sun;
    vec3 direct = celestialIrradiance(sun);
    float visibility = smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength);
    vec3 diffuse = albedo * (1.0 - material.metallic) * (1.0 - f0);
    vec3 indirect = (diffuse + f0 * mix(0.27, 0.50, material.roughness)) * ambient;
    if (!hasSkylight) {
        return indirect + material.emission;
    }
#ifdef SCENE_SHADOWS
    if (skyAccess * visibility > 0.0) {
        vec3 shadowPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
        visibility *= sceneShadow(shadowPosition, normal, light);
    }
#endif
#ifdef LITE_LIGHTING
    vec3 directResponse = diffuse * (max(dot(normal, light), 0.0) / LW_PI);
#else
    vec3 directResponse = directBrdf(albedo, material, normal, view, light, f0);
#endif
    return indirect + material.emission + directResponse * direct * (skyAccess * visibility);
}
