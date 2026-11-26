#include "/lib/quality.glsl"
#include "/lib/color/scene.glsl"
#include "/lib/lighting/overworld.glsl"
#include "/lib/lighting/fog.glsl"
#ifdef LW_TERRAIN
#include "/lib/lighting/surface.glsl"
#endif
#ifdef LW_WATER
#include "/lib/water/surface.glsl"
#endif
#if defined(DEFERRED_LIGHTING) && (defined(LW_OPAQUE_TERRAIN) || defined(LW_WATER))
#include "/lib/materials/geometry_buffer.glsl"
#endif
#if defined(ADVANCED_WATER) && defined(DEFERRED_LIGHTING) && defined(LW_WATER)
#include "/lib/water/screen_space.glsl"
#endif
#if defined(DEFERRED_LIGHTING) && defined(LW_OPAQUE_TERRAIN)
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
#include "/lib/materials/lab_pbr.glsl"
uniform sampler2D normals;
uniform sampler2D specular;
in vec4 viewTangent;
#endif
#endif

uniform sampler2D gtexture;
uniform int renderStage;
in vec2 texCoord;
in vec2 lightLevels;
in vec4 vertexColor;
in vec3 viewPosition;
#ifdef LW_TERRAIN
in vec3 viewNormal;
flat in int blockId;
#endif

#if defined(DEFERRED_LIGHTING) && defined(LW_OPAQUE_TERRAIN)
/* RENDERTARGETS: 0,1,2 */
#elif defined(DEFERRED_LIGHTING) && defined(LW_WATER)
/* RENDERTARGETS: 0,1 */
#else
/* RENDERTARGETS: 0 */
#endif

void main() {
    vec4 base = vertexColor;
#ifndef LW_BASIC
#ifdef LW_WATER
    if (blockId != 10004) {
        base *= texture(gtexture, texCoord);
    } else {
        base.a = 1.0;
    }
#else
    base *= texture(gtexture, texCoord);
#endif
#endif
    if (base.a <= 0.0 || renderStage == MC_RENDER_STAGE_SUN) {
        discard;
    }

    vec3 radiance = decodeSrgb(base.rgb);
#if defined(LW_TERRAIN)
    vec3 view = normalize(worldDirection(-viewPosition));
    vec3 normal = normalize(worldDirection(viewNormal));
    normal = faceforward(normal, -view, normal);
#if defined(DEFERRED_LIGHTING) && defined(LW_WATER)
    gl_FragData[1] = vec4(encodeNormal(normal), blockId == 10004 ? -1.0 : -2.0, 0.0);
#endif
#if defined(DEFERRED_LIGHTING) && defined(LW_OPAQUE_TERRAIN)
    vec2 mappedMaterial = vec2(0.0, 1.0);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
    vec3 normalData = texture(normals, texCoord).rgb;
    vec4 tangent = vec4(worldDirection(viewTangent.xyz), viewTangent.w);
    normal = labWorldNormal(normal, tangent, normalData.rg);
    mappedMaterial = vec2(encodeLabSpecular(texture(specular, texCoord)), normalData.b);
#endif
    gl_FragData[0] = vec4(radiance, base.a);
    gl_FragData[1] = vec4(encodeNormal(normal), lightLevels);
    gl_FragData[2] = vec4(gl_FragCoord.z, float(blockId), mappedMaterial);
#else
    vec3 sun = sunDirection();
#ifdef LW_WATER
    if (blockId == 10004) {
#if defined(ADVANCED_WATER) && defined(DEFERRED_LIGHTING)
        vec3 water = physicalWater(radiance, normal, viewPosition, view, sun,
            smoothstep(0.56, 1.0, lightLevels.y));
        gl_FragData[0] = vec4(applySceneFog(water, viewPosition), 1.0);
        return;
#else
        vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
        normal = waveNormal(normal, position);
        float fresnel = waterFresnel(clamp(dot(normal, view), 0.0, 1.0), isEyeInWater == 1);
        vec3 reflection = skyRadiance(reflect(-view, normal), sun);
        float thickness = isEyeInWater == 1 ? 0.0
            : waterThickness(viewPosition, gl_FragCoord.xy / vec2(textureSize(depthtex1, 0)));
        float opacity = 1.0 - luminance(exp(-waterExtinction() * thickness));
        vec3 scatter = waterScatteringColor(radiance)
            * (ambientIrradiance(lightLevels, 1.0, sun) + celestialIrradiance(sun) * 0.16);
        if (isEyeInWater == 1) {
            vec2 screen = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
            if (texture(depthtex1, screen).r >= 1.0) {
                vec3 airDirection = waterToAirDirection(-view, normal);
                vec3 air = dot(airDirection, airDirection) > 0.0 ? skyRadiance(airDirection, sun) : scatter;
                gl_FragData[0] = vec4(applySceneFog(mix(air, scatter, fresnel), viewPosition), 1.0);
                return;
            }
            reflection = scatter;
        }
        base.a = max(mix(opacity, 1.0, fresnel), 0.001);
        radiance = (scatter * opacity * (1.0 - fresnel) + reflection * fresnel
            + (isEyeInWater == 1 ? vec3(0.0) : waterSunGlint(normal, view, sun, smoothstep(0.56, 1.0, lightLevels.y)))) / base.a;
        gl_FragData[0] = vec4(applySceneFog(radiance, viewPosition), base.a);
        return;
#endif
    }
#endif
    Material material = vanillaMaterial(blockId, radiance);
    radiance = surfaceRadiance(radiance, material, normal, view, sun, lightLevels, viewPosition);
#endif
#elif defined(LW_LIT)
    radiance *= ambientIrradiance(lightLevels, 0.35, sunDirection());
#endif

#if !defined(DEFERRED_LIGHTING) || !defined(LW_OPAQUE_TERRAIN)
    if (renderStage == MC_RENDER_STAGE_MOON) {
        radiance *= 0.65;
    } else if (renderStage != MC_RENDER_STAGE_CUSTOM_SKY) {
        radiance = applySceneFog(radiance, viewPosition);
    }
    gl_FragData[0] = vec4(radiance, base.a);
#endif
}
