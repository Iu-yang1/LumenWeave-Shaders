#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
#if defined(DH_SHADOWS) && defined(SCENE_SHADOWS)
#include "/lib/lighting/lite_shadows.glsl"
#endif
#ifdef LW_DH_WATER
#include "/lib/water/surface.glsl"
#endif

in vec3 viewPosition;
in vec3 viewNormal;
in vec2 lightLevels;
in vec4 vertexColor;
layout(location = 0) out vec4 outputColor;

#ifdef LW_TAA_ACTIVE
#include "/lib/materials/geometry_buffer.glsl"
layout(location = 1) out vec4 distantNormal;
/* RENDERTARGETS: 0,1 */
#else
/* RENDERTARGETS: 0 */
#endif

void main() {
    vec3 normal = normalize(worldDirection(viewNormal));
#ifdef LW_TAA_ACTIVE
    distantNormal = vec4(encodeNormal(normal), 0.0, 0.0);
#ifdef LW_DH_WATER
    distantNormal.z = -1.0;
#endif
#endif
    vec3 sun = sunDirection();
    vec3 albedo = decodeSrgb(vertexColor.rgb);
#ifdef LW_DH_WATER
    albedo = waterScatteringColor(albedo);
#endif
    vec3 light = sun.y >= 0.0 ? sun : -sun;
    vec3 direct = celestialIrradiance(sun);
    float lighting = smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength);
    lighting *= max(dot(normal, light), 0.0) * smoothstep(0.56, 1.0, lightLevels.y);
    float shadow = 1.0;
#if defined(DH_SHADOWS) && defined(SCENE_SHADOWS)
    if (hasSkylight && lighting > 0.0) {
        vec3 shadowPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
        shadow = volumeShadow(shadowPosition + normal * 0.06);
    }
#endif
    vec3 lit = albedo * (ambientIrradiance(lightLevels, normal.y, sun) + direct * lighting * shadow / LW_PI);
#ifdef LW_DH_WATER
    vec3 eyeDirection = normalize(worldDirection(-viewPosition));
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
    normal = faceforward(normal, -eyeDirection, normal);
    normal = waveNormal(normal, position);
    float fresnel = waterFresnel(clamp(dot(normal, eyeDirection), 0.0, 1.0), isEyeInWater == 1);
    vec3 reflected = reflect(-eyeDirection, normal);
    if (isEyeInWater == 1) {
        vec3 airDirection = waterToAirDirection(-eyeDirection, normal);
        vec3 air = dot(airDirection, airDirection) > 0.0 ? skyRadiance(airDirection, sun) : lit;
        lit = mix(air, lit, fresnel);
    } else {
        lit = mix(lit, skyRadiance(reflected, sun), fresnel)
            + waterSunGlint(normal, eyeDirection, sun, smoothstep(0.56, 1.0, lightLevels.y) * shadow);
    }
#endif
    outputColor = vec4(applySceneFog(lit, viewPosition), vertexColor.a);
}
