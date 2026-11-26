#include "/lib/reflection/trace.glsl"

vec3 physicalWater(vec3 tint, vec3 originalNormal, vec3 viewPosition, vec3 view, vec3 sun, float skyAccess) {
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
    vec3 normal = faceforward(waveNormal(originalNormal, position,skyAccess),-view,originalNormal);
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec3 reflected = reflect(-view, normal);
    bool submerged = isEyeInWater == 1;
    float fresnel = waterFresnel(clamp(dot(view, normal), 0.0, 1.0), submerged);
    vec3 scatter = waterScatteringColor(tint)
        * (ambientIrradiance(vec2(0.0, skyAccess), 1.0, sun) + celestialIrradiance(sun) * (0.16 * skyAccess));
    vec3 reflection = submerged ? scatter : skyRadiance(reflected, sun);
#if WATER_REFLECTION_STEPS > 0
    if (fresnel > 0.021) {
        vec2 hitUv;float hitTravel;int hitKind;
        int steps=WATER_REFLECTION_STEPS;
#ifdef ADAPTIVE_SHADING
        float projected=0.5*abs(gbufferProjection[1][1])*float(lwRasterSize(depthtex1).y)/max(-viewPosition.z,0.1);
        if(!submerged && projected<9.0 && steps>8) steps=max(8,steps/2);
#endif
        vec4 hit = traceScreenReflection(viewPosition+toView*normal*0.045, toView * reflected, steps,hitUv,hitTravel,hitKind);
        if(submerged && dot(reflected,originalNormal)<=0.0) hit.a=0.0;
        if (submerged && hit.a>0.0) {
            hit.rgb = mix(scatter, hit.rgb, exp(-waterExtinction() * hitTravel));
            float blur=clamp(WATER_ROUGHNESS*WATER_ROUGHNESS*hitTravel*0.16,0.0,0.75);
            hit.a*=1.0-blur;
        }
        reflection = mix(reflection, hit.rgb, hit.a * smoothstep(0.021, 0.033, fresnel));
    }
#endif
    if(submerged) {
        vec3 airDirection=waterToAirDirection(-view,normal);
        if(dot(airDirection,airDirection)<0.000001) return reflection;
        // The perturbed microfacet cannot transmit back into the macro water half-space.
        if(dot(airDirection,originalNormal)>=0.0) return reflection;
        vec3 through=skyRadiance(airDirection,sun);
#if WATER_REFLECTION_STEPS > 0
        vec2 transmissionUv;float transmissionTravel;int transmissionKind;
        vec4 airHit=traceScreenReflection(viewPosition+toView*airDirection*0.08,toView*airDirection,
            min(WATER_REFLECTION_STEPS,16),transmissionUv,transmissionTravel,transmissionKind);
        if(airHit.a>0.0) {
            vec3 hitPosition;
#ifdef DISTANT_HORIZONS
            if(transmissionKind==2) {
                ivec2 p=depthPixelAtUv(dhDepthTex1,transmissionUv);
                hitPosition=reconstructProjection(depthPixelUv(dhDepthTex1,p),texelFetch(dhDepthTex1,p,0).r,dhProjectionInverse,true);
            } else
#endif
            {
                ivec2 p=depthPixelAtUv(depthtex1,transmissionUv);
                hitPosition=reconstructViewPosition(depthPixelUv(depthtex1,p),texelFetch(depthtex1,p,0).r);
            }
            float above=-dot(worldDirection(hitPosition-viewPosition),originalNormal);
            // Reject bottom and wrong-side depth hits; keep directional sky on misses.
            through=mix(through,airHit.rgb,airHit.a*smoothstep(0.02,0.30,above));
        }
#endif
        return mix(through,reflection,fresnel);
    }

    vec2 screen = gl_FragCoord.xy / vec2(lwRasterSize(depthtex1));
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
    bool samePixel=all(equal(samplePixel,originalPixel));
    float sampledDepth=samePixel?originalDepth:texelFetch(depthtex1,samplePixel,0).r;
    vec3 refractedBackground=samePixel?background:reconstructViewPosition(depthPixelUv(depthtex1,samplePixel),sampledDepth);
    if (refractedBackground.z >= viewPosition.z) {
        refractedUv = screen;
        sampledDepth = originalDepth;
        // background still contains the original depth reconstruction.
    } else {
        background = refractedBackground;
    }
    float thickness = sampledDepth >= 1.0 ? 48.0
        : clamp(dot(background - viewPosition, normalize(viewPosition)), 0.0, 48.0);
    vec3 transmission = exp(-waterExtinction() * thickness);
    vec3 through = mix(scatter, lwRasterTexture(colortex8, refractedUv).rgb, transmission);
#ifdef SCENE_SHADOWS
    if (hasSkylight && skyAccess > 0.0) {
        skyAccess *= sceneShadow(position - cameraPosition, originalNormal, sun.y >= 0.0 ? sun : -sun);
    }
#endif
    return mix(through, reflection, fresnel) + (submerged ? vec3(0.0) : waterSunGlint(normal, view, sun, skyAccess));
}
