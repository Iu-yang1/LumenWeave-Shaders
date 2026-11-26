uniform sampler2D colortex8;
uniform mat4 gbufferProjection;

bool insideScreen(vec2 uv) {
    return all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)));
}

bool waterRayDepth(vec3 ray, out vec2 uv, out float delta) {
    vec4 projected = gbufferProjection * vec4(ray, 1.0);
    uv = projected.xy / projected.w * 0.5 + 0.5;
#ifdef LW_TAA_ACTIVE
    uv += jitterOffset(frameCounter);
#endif
    if (!insideScreen(uv)) {
        return false;
    }
    ivec2 size = textureSize(depthtex1, 0);
    ivec2 pixel = clamp(ivec2(uv * vec2(size)), ivec2(0), size - 1);
    float depth = texelFetch(depthtex1, pixel, 0).r;
    vec2 pixelUv = (vec2(pixel) + 0.5) / vec2(size);
    delta = depth < 1.0 ? reconstructViewPosition(pixelUv, depth).z - ray.z : -1.0;
    return true;
}

vec4 traceWaterReflection(vec3 origin, vec3 direction) {
    float travel = 0.30;
    float previousTravel = 0.0;
    float previousDelta = -1.0;
    for (int tap = 0; tap < WATER_REFLECTION_STEPS; ++tap) {
        vec3 ray = origin + direction * travel;
        if (ray.z > -0.12 || travel > 48.0) {
            break;
        }
        vec2 uv;
        float delta;
        if (!waterRayDepth(ray, uv, delta)) {
            break;
        }
        if (previousDelta < 0.0 && delta >= 0.0) {
            float lo = previousTravel;
            float hi = travel;
            // Resolve the crossing rather than rejecting long marching steps.
            for (int refine = 0; refine < 4; ++refine) {
                float mid = (lo + hi) * 0.5;
                vec2 midUv;
                float midDelta;
                if (!waterRayDepth(origin + direction * mid, midUv, midDelta) || midDelta < 0.0) {
                    lo = mid;
                } else {
                    hi = mid;
                    uv = midUv;
                    delta = midDelta;
                }
            }
            float thickness = 0.20 + hi * 0.035;
            if (delta < thickness && hi > 0.12) {
                vec2 edge = min(uv, 1.0 - uv);
                float confidence = smoothstep(0.0, 0.08, min(edge.x, edge.y));
                confidence *= 1.0 - smoothstep(18.0, 48.0, hi);
                confidence *= 1.0 - smoothstep(thickness * 0.65, thickness, delta);
                return vec4(texture(colortex8, uv).rgb, confidence);
            }
        }
        previousTravel = travel;
        previousDelta = delta;
        travel += 0.28 + travel * 0.26;
    }
    return vec4(0.0);
}

vec3 physicalWater(vec3 tint, vec3 originalNormal, vec3 viewPosition, vec3 view, vec3 sun, float skyAccess) {
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
    vec3 normal = waveNormal(originalNormal, position);
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec3 reflected = reflect(-view, normal);
    bool submerged = isEyeInWater == 1;
    float fresnel = waterFresnel(clamp(dot(view, normal), 0.0, 1.0), submerged);
    vec3 scatter = waterScatteringColor(tint)
        * (ambientIrradiance(vec2(0.0, skyAccess), 1.0, sun) + celestialIrradiance(sun) * 0.16);
    vec3 reflection = submerged ? scatter : skyRadiance(reflected, sun);
#if WATER_REFLECTION_STEPS > 0
    if (fresnel > 0.021) {
        vec4 hit = traceWaterReflection(viewPosition, toView * reflected);
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
    float originalDepth = texture(depthtex1, screen).r;
    vec3 background = reconstructViewPosition(screen, originalDepth);
    float depthGap = max(viewPosition.z - background.z, 0.0);
    vec2 refractedUv = screen + (toView * (normal - originalNormal)).xy
        * min(depthGap * 0.008, 0.025) * WATER_REFRACTION;
    if (!insideScreen(refractedUv)) {
        refractedUv = screen;
    }
    float sampledDepth = texture(depthtex1, refractedUv).r;
    vec3 refractedBackground = reconstructViewPosition(refractedUv, sampledDepth);
    if (refractedBackground.z >= viewPosition.z) {
        refractedUv = screen;
        sampledDepth = originalDepth;
        background = reconstructViewPosition(screen, originalDepth);
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
