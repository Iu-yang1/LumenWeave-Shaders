#include "/lib/reflection/trace.glsl"

vec3 physicalWater(vec3 tint, vec3 originalNormal, vec3 viewPosition, vec3 view, vec3 sun, float skyAccess) {
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
    vec3 normal = waveNormal(originalNormal, position);
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec3 reflected = reflect(-view, normal);
    bool submerged = isEyeInWater == 1;
    float fresnel = waterFresnel(clamp(dot(view, normal), 0.0, 1.0), submerged);
    vec3 scatter = waterScatteringColor(tint)
        * (ambientIrradiance(vec2(0.0, skyAccess), 1.0, sun) + celestialIrradiance(sun) * (0.16 * skyAccess));
    vec3 reflection = submerged ? scatter : skyRadiance(reflected, sun);
#if WATER_REFLECTION_STEPS > 0
    if (fresnel > 0.021) {
        vec4 hit = traceScreenReflection(viewPosition, toView * reflected, WATER_REFLECTION_STEPS);
        if (submerged) {
            hit.rgb = mix(scatter, hit.rgb, exp(-waterExtinction() * 3.0));
        }
        reflection = mix(reflection, hit.rgb, hit.a * smoothstep(0.021, 0.033, fresnel));
    }
#endif
    if (submerged && fresnel >= 0.9999) {
        return reflection;
    }

    vec2 screen = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
#ifdef LW_STABLE_DYNAMIC
    screen = clamp(screen + jitterOffset(frameCounter),vec2(0.0),vec2(1.0));
#endif
    ivec2 originalPixel = depthPixelAtUv(depthtex1,screen);
    float originalDepth = texelFetch(depthtex1,originalPixel,0).r;
    vec3 background = reconstructViewPosition(depthPixelUv(depthtex1,originalPixel), originalDepth);
    float depthGap = max(viewPosition.z - background.z, 0.0);
    vec2 refractedUv = screen + (toView * (normal - originalNormal)).xy
        * min(depthGap * 0.008, 0.025) * WATER_REFRACTION;
    if (!insideScreen(refractedUv)) {
        refractedUv = screen;
    }
    ivec2 samplePixel = depthPixelAtUv(depthtex1,refractedUv);
    float sampledDepth = texelFetch(depthtex1,samplePixel,0).r;
    vec3 refractedBackground = reconstructViewPosition(depthPixelUv(depthtex1,samplePixel),sampledDepth);
    if (refractedBackground.z >= viewPosition.z) {
        refractedUv = screen;
        sampledDepth = originalDepth;
        background = reconstructViewPosition(depthPixelUv(depthtex1,originalPixel),originalDepth);
    } else {
        background = refractedBackground;
    }
    float thickness = sampledDepth >= 1.0 ? 48.0
        : clamp(dot(background - viewPosition, normalize(viewPosition)), 0.0, 48.0);
    if (isEyeInWater == 1) {
        thickness = 0.0;
    }
    vec3 transmission = exp(-waterExtinction() * thickness);
    vec3 through = mix(scatter, texture(colortex8, refractedUv).rgb, transmission);
    if (submerged && sampledDepth >= 1.0 && originalDepth >= 1.0) {
        vec3 airDirection = waterToAirDirection(-view, normal);
        if (dot(airDirection, airDirection) > 0.0) {
            through = skyRadiance(airDirection, sun);
        }
    }
#ifdef SCENE_SHADOWS
    skyAccess *= sceneShadow(position - cameraPosition, originalNormal, sun.y >= 0.0 ? sun : -sun);
#endif
    return mix(through, reflection, fresnel) + (submerged ? vec3(0.0) : waterSunGlint(normal, view, sun, skyAccess));
}
