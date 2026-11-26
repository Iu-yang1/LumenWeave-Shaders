#include "/lib/materials/vanilla.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/voxel/features.glsl"
#ifdef LW_VOXEL_ACTIVE
#include "/lib/voxel/irradiance.glsl"
#endif
#ifdef SCENE_SHADOWS
#include "/lib/lighting/lite_shadows.glsl"
#endif

vec3 surfaceRadiance(vec3 albedo, Material material, vec3 normal, vec3 view, vec3 sun, vec2 lightLevels, vec3 viewPosition, out vec4 specularMetadata, out vec4 specularEnvironment) {
    specularMetadata = vec4(0.0);
    specularEnvironment = vec4(0.0);
    vec3 f0 = material.f0;
    float skyAccess = smoothstep(0.56, 1.0, lightLevels.y);
    vec3 light = sun.y >= 0.0 ? sun : -sun;
    float normalLight = max(dot(normal, light), 0.0);
    float visibility = hasSkylight ? smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength) : 0.0;
    float shadow = 1.0;
#if defined(SCENE_SHADOWS) || defined(LW_VOXEL_ACTIVE)
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
#endif
#ifdef SCENE_SHADOWS
    if (skyAccess * visibility * normalLight > 0.0) {
        shadow = sceneShadow(position, normal, light);
    }
#endif
    // Shadowed surfaces still receive sky light; direct occlusion moderately reduces its diffuse approximation.
    vec3 skyAmbient = ambientIrradiance(vec2(0.0, lightLevels.y), normal.y, sun);
    float occludedSky = mix(1.0, mix(0.40, 1.0, shadow), daylight(sun) * (1.0 - rainStrength));
    skyAmbient *= occludedSky;
    vec3 blockAmbient = blockLightIrradiance(lightLevels.x);
#ifdef LW_VOXEL_ACTIVE
    vec3 coloredLight = voxelIrradiance(position, normal) * BLOCKLIGHT_STRENGTH;
    float influence = smoothstep(0.025, 0.65, max(coloredLight.r, max(coloredLight.g, coloredLight.b)));
    blockAmbient = mix(blockAmbient, coloredLight * 1.45, influence);
#endif
    vec3 diffuse = albedo * (1.0 - material.metallic) * (1.0 - f0);
    vec3 ambient = (skyAmbient + blockAmbient) * material.occlusion;
    vec3 indirect = diffuse * ambient;
    vec3 environmentContribution = vec3(0.0);
#ifdef LITE_LIGHTING
    indirect += f0 * mix(0.27, 0.50, material.roughness) * ambient;
#else
    // Analytic environment specular for smooth materials; no additional screen-space pass.
    if (hasSkylight && material.roughness < 0.65 && lightLevels.y > 0.0) {
        vec3 reflected = reflect(-view, normal);
        vec3 fresnel = fresnelSchlick(clamp(dot(normal, view), 0.0, 1.0), f0);
        vec3 environment = mix(skyRadiance(reflected, sun), skyAmbient,
            material.roughness * material.roughness);
        vec3 specularWeight = fresnel * (lightLevels.y * lightLevels.y)
            * material.occlusion * smoothstep(-0.12, 0.08, reflected.y)
            * mix(0.55, 1.0, shadow);
        environmentContribution = environment * specularWeight;
        indirect += environmentContribution;
    } else {
        environmentContribution = f0 * mix(0.27, 0.50, material.roughness) * ambient;
        indirect += environmentContribution;
    }
    specularEnvironment = vec4(environmentContribution,1.0);
#ifdef LW_MATERIAL_SSR_ACTIVE
    // The screen ray has its own visibility; do not attenuate it by sky access.
    // Store the exact existing fallback separately, including indoor materials.
    if (material.roughness < 0.65) {
        vec3 reflectance = fresnelSchlick(clamp(dot(normal,view),0.0,1.0),f0) * material.occlusion;
        specularMetadata = vec4(reflectance,material.roughness);
    }
#endif
#endif
    if (skyAccess * visibility * normalLight * shadow <= 0.0) {
        return indirect + material.emission;
    }
#ifdef LITE_LIGHTING
    vec3 directResponse = diffuse * (normalLight / LW_PI);
#else
    vec3 directResponse = directBrdf(albedo, material, normal, view, light, f0);
#endif
    return indirect + material.emission + directResponse * celestialIrradiance(sun) * (skyAccess * visibility * shadow);
}

vec3 surfaceRadiance(vec3 albedo, Material material, vec3 normal, vec3 view, vec3 sun, vec2 lightLevels, vec3 viewPosition) {
    vec4 unusedMetadata, unusedEnvironment;
    return surfaceRadiance(albedo, material, normal, view, sun, lightLevels, viewPosition, unusedMetadata, unusedEnvironment);
}
