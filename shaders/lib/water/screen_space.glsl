#include "/lib/coordinates/reconstruct.glsl"

uniform sampler2D colortex8;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjection;

bool insideScreen(vec2 uv) {
    return all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)));
}

vec4 traceWaterReflection(vec3 origin, vec3 direction) {
    float travel = 0.34;
    float lastDelta = -0.3;
    for (int tap = 0; tap < 16; ++tap) {
        vec3 ray = origin + direction * travel;
        if (ray.z > -0.12) {
            break;
        }
        vec4 projected = gbufferProjection * vec4(ray, 1.0);
        vec2 uv = projected.xy / projected.w * 0.5 + 0.5;
#if defined(TEMPORAL_AA) && defined(DEFERRED_LIGHTING)
        uv += jitterOffset(frameCounter);
#endif
        if (!insideScreen(uv)) {
            break;
        }
        float depth = texture(depthtex1, uv).r;
        if (depth < 1.0) {
            float delta = reconstructViewPosition(uv, depth).z - ray.z;
            if (lastDelta < 0.0 && delta >= 0.0 && delta < 0.32 + travel * 0.075) {
                vec2 edge = min(uv, 1.0 - uv);
                float confidence = smoothstep(0.0, 0.12, min(edge.x, edge.y));
                confidence *= 1.0 - smoothstep(6.0, 15.0, travel);
                return vec4(texture(colortex8, uv).rgb, confidence);
            }
            lastDelta = delta;
        } else {
            lastDelta = -0.3;
        }
        travel += 0.22 + travel * 0.18;
    }
    return vec4(0.0);
}

vec3 physicalWater(vec3 tint, vec3 originalNormal, vec3 viewPosition, vec3 view, vec3 sun, float skyAccess) {
    vec3 position = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz + cameraPosition;
    vec3 normal = waveNormal(originalNormal, position);
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec3 reflected = reflect(-view, normal);
    vec4 hit = traceWaterReflection(viewPosition, toView * reflected);
    vec3 reflection = mix(skyRadiance(reflected, sun), hit.rgb, hit.a);
    float fresnel = fresnelSchlick(clamp(dot(view, normal), 0.0, 1.0), vec3(0.0204)).r;

    vec2 screen = gl_FragCoord.xy / vec2(textureSize(depthtex1, 0));
    float originalDepth = texture(depthtex1, screen).r;
    vec3 background = reconstructViewPosition(screen, originalDepth);
    float depthGap = max(viewPosition.z - background.z, 0.0);
    vec2 refractedUv = screen + (toView * (normal - originalNormal)).xy * min(depthGap * 0.012, 0.035);
    if (!insideScreen(refractedUv)) {
        refractedUv = screen;
    }
    float sampledDepth = texture(depthtex1, refractedUv).r;
    vec3 refractedBackground = reconstructViewPosition(refractedUv, sampledDepth);
    if (refractedBackground.z >= viewPosition.z) {
        refractedUv = screen;
    } else {
        background = refractedBackground;
    }
    float thickness = clamp(dot(background - viewPosition, normalize(viewPosition)), 0.0, 48.0);
    vec3 transmission = exp(-vec3(0.31, 0.14, 0.074) * thickness);
    vec3 scatter = mix(vec3(0.015, 0.055, 0.07), tint * 0.28, 0.42);
    vec3 through = mix(scatter, texture(colortex8, refractedUv).rgb, transmission);
#ifdef SCENE_SHADOWS
    skyAccess *= sceneShadow(position - cameraPosition, originalNormal, sun.y >= 0.0 ? sun : -sun);
#endif
    return mix(through, reflection, fresnel) + waterSunGlint(normal, view, sun, skyAccess);
}
