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
#ifdef LW_STABLE_DYNAMIC
/* RENDERTARGETS: 0,1,2,3 */
#else
/* RENDERTARGETS: 0,1,2 */
#endif
#elif defined(DEFERRED_LIGHTING) && defined(LW_WATER)
#ifdef LW_STABLE_DYNAMIC
/* RENDERTARGETS: 0,1,3 */
#else
/* RENDERTARGETS: 0,1 */
#endif
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
#ifdef LW_OPAQUE_TERRAIN
    // Modest positive mip bias only for distant leaves; preserve near texture detail.
    float leafBias = blockId == 10030 ? 0.35*smoothstep(24.0,80.0,-viewPosition.z) : 0.0;
    base *= texture(gtexture,texCoord,leafBias);
#else
    base *= texture(gtexture, texCoord);
#endif
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
#ifdef LW_STABLE_DYNAMIC
    gl_FragData[2] = vec4(gl_FragCoord.z, blockId == 10004 ? 2.0 : 5.0, 0.0, 0.0);
#endif
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
#ifdef LW_STABLE_DYNAMIC
    gl_FragData[3] = vec4(gl_FragCoord.z, 1.0, 0.0, 0.0);
#endif
#else
    vec3 sun = sunDirection();
#ifdef LW_WATER
    if (blockId == 10004) {
#if defined(ADVANCED_WATER) && defined(DEFERRED_LIGHTING)
        vec3 waterPosition = viewPosition;
#ifdef LW_STABLE_DYNAMIC
        vec2 stableUv=gl_FragCoord.xy/vec2(textureSize(depthtex1,0));
        waterPosition=stableViewSurfacePosition(viewPosition,stableUv,
            transpose(mat3(gbufferModelViewInverse))*normal,gbufferProjectionInverse);
        view=normalize(worldDirection(-waterPosition));
#endif
        vec3 water = physicalWater(radiance, normal, waterPosition, view, sun,
            smoothstep(0.56, 1.0, lightLevels.y));
        gl_FragData[0] = vec4(applySceneFog(water, waterPosition), 1.0);
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
            * (ambientIrradiance(lightLevels, 1.0, sun) + celestialIrradiance(sun) * (0.16 * smoothstep(0.0,1.0,lightLevels.y)));
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
#if defined(LW_WATER) && defined(ADVANCED_WATER) && defined(DEFERRED_LIGHTING)
    // Lava is emitted in the forward fluid pass, not the deferred material SSR pass.
    // Reuse the opaque scene and its bounded water ray, without water refraction.
    if (blockId == 10015) {
        vec3 lavaPosition = viewPosition;
#ifdef LW_STABLE_DYNAMIC
        vec2 stableUv = gl_FragCoord.xy / vec2(textureSize(depthtex1,0));
        lavaPosition = stableViewSurfacePosition(viewPosition,stableUv,
            transpose(mat3(gbufferModelViewInverse))*normal,gbufferProjectionInverse);
        view = normalize(worldDirection(-lavaPosition));
#endif
        vec4 metadata, fallback;
        vec3 lit = surfaceRadiance(radiance, material, normal, view, sun,
            lightLevels, lavaPosition, metadata, fallback);
        vec3 reflected = reflect(-view, normal);
        float fresnel = 0.045 + 0.955 * pow(1.0 - clamp(dot(view,normal),0.0,1.0),5.0);
        vec3 reflectedRadiance = hasSkylight ? skyRadiance(reflected,sun)
            : ambientIrradiance(lightLevels,normal.y,sun) * 0.35;
#if WATER_REFLECTION_STEPS > 0
        if (fresnel > 0.065 && -lavaPosition.z < 48.0 && isEyeInWater == 0) {
            mat3 toView = transpose(mat3(gbufferModelViewInverse));
            vec4 hit = traceScreenReflection(lavaPosition + toView*normal*0.07,
                toView*reflected, min(WATER_REFLECTION_STEPS,8));
            reflectedRadiance = mix(reflectedRadiance,hit.rgb,hit.a);
        }
#endif
        // Replace the prior specular fallback, never attenuate emitted radiance.
        // Molten rock is not a clear water mirror. Keep a warm, bounded
        // reflected component and keep emission separate from reflection.
        vec3 lavaTint=mix(vec3(1.0,0.48,0.15),radiance/max(max(radiance.r,max(radiance.g,radiance.b)),0.001),0.35);
        vec3 reflection=reflectedRadiance*lavaTint*min(fresnel,0.18);
        float emissionPeak=max(material.emission.r,max(material.emission.g,material.emission.b));
        float reflectionPeak=max(reflection.r,max(reflection.g,reflection.b));
        reflection*=min(1.0,(0.12+0.22*emissionPeak)/max(reflectionPeak,0.001));
        vec3 nonEmissive=max(lit - fallback.rgb-material.emission,vec3(0.0));
        // Suppress the broad white diffuse/direct response of molten pixels,
        // but leave dark crust detail and the HDR emission intact.
        lit=material.emission+nonEmissive*lavaTint*0.65+reflection;
        gl_FragData[0] = vec4(applySceneFog(lit,lavaPosition),1.0);
        return;
    }
#endif
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
