struct ScreenBounce {
    vec3 sky;
    vec3 block;
    float blockConfidence;
};

ScreenBounce screenBounceRay(vec3 origin, vec3 direction, mat3 toView, vec3 sun) {
    float travel = 0.16;
    ivec2 resolution = textureSize(depthtex0, 0);
    for (int tap = 0; tap < 8; ++tap) {
        vec3 position = origin + direction * travel;
        if (position.z >= -0.12) {
            break;
        }
        vec4 clip = gbufferProjection * vec4(position, 1.0);
        vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
#ifdef LW_TAA_ACTIVE
        uv += jitterOffset(frameCounter);
#endif
        vec2 edge = min(uv, 1.0 - uv);
        if (min(edge.x, edge.y) <= 0.0) {
            break;
        }
        ivec2 pixel = ivec2(uv * vec2(resolution));
        float depth = texelFetch(depthtex0, pixel, 0).r;
        if (depth < 1.0) {
            vec2 pixelUv = (vec2(pixel) + 0.5) / vec2(resolution);
            vec3 hitPosition;
#ifdef LW_STABLE_DYNAMIC
            int kind = sampleOwner(pixelUv, depth, false);
            hitPosition = reconstructProjection(pixelUv,depth,gbufferProjectionInverse,kind!=0);
            if (kind == 1) {
                vec3 sampleNormal = toView * decodeNormal(texelFetch(colortex1,pixel,0).xy);
                hitPosition = stableViewSurfacePosition(hitPosition, unjitteredUv(uv,true), sampleNormal, gbufferProjectionInverse);
            }
#else
            hitPosition = reconstructViewPosition(pixelUv, depth);
#endif
            float delta = hitPosition.z - position.z;
            if (delta >= 0.0) {
                float thickness = 0.12 + travel * 0.07;
                if (delta >= thickness) {
                    break;
                }
                vec4 materialDepth = texelFetch(colortex2, pixel, 0);
                if (abs(materialDepth.x - depth) > 0.00000012) {
                    break;
                }
                vec4 geometry = texelFetch(colortex1, pixel, 0);
                vec3 hitNormal = decodeNormal(geometry.xy);
                float facing = max(0.0, dot(toView * hitNormal, -direction));
                if (facing <= 0.0) {
                    break;
                }
                vec3 albedo = texelFetch(colortex0, pixel, 0).rgb;
                Material source = vanillaMaterial(int(materialDepth.y), albedo);
#ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
                source = labMaterial(source, albedo, materialDepth.z, materialDepth.w);
#endif
                vec3 diffuse = albedo * (1.0 - source.metallic) * (1.0 - source.f0);
                vec3 light = sun.y >= 0.0 ? sun : -sun;
                vec3 direct = celestialIrradiance(sun);
                float daylightWeight = max(dot(hitNormal, light), 0.0) * smoothstep(0.56, 1.0, geometry.w);
                daylightWeight *= smoothstep(0.0, 0.18, abs(sun.y)) * mix(1.0, 0.19, rainStrength);
#if defined(SCENE_SHADOWS) || defined(LW_VOXEL_DIFFUSE_ACTIVE)
                vec3 worldPosition = (gbufferModelViewInverse * vec4(hitPosition, 1.0)).xyz;
#endif
#ifdef SCENE_SHADOWS
                if (hasSkylight && daylightWeight > 0.0) {
                    daylightWeight *= sceneShadow(worldPosition, hitNormal, light);
                }
#endif
                vec3 sky = max(ambientIrradiance(vec2(0.0, geometry.w), hitNormal.y, sun)
                    - vec3((hasSkylight ? 0.010 : 0.008) * AMBIENT_STRENGTH), vec3(0.0));
                float confidence = facing * smoothstep(0.0, 0.08, min(edge.x, edge.y));
                confidence *= (1.0 - smoothstep(1.3, 3.9, travel)) * (1.0 - smoothstep(0.6, 1.0, delta / thickness));
                ScreenBounce hit = ScreenBounce(diffuse * (direct * daylightWeight / LW_PI + sky * 0.5) * confidence, vec3(0.0), 0.0);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
                vec3 blockLight = voxelIrradiance(worldPosition, hitNormal);
                float strength = max(blockLight.r, max(blockLight.g, blockLight.b));
                hit.blockConfidence = confidence * smoothstep(0.01, 0.12, strength);
                hit.block = blockLight * diffuse * hit.blockConfidence;
#endif
                return hit;
            }
        }
        travel = travel * 1.32 + 0.16;
    }
    return ScreenBounce(vec3(0.0), vec3(0.0), 0.0);
}

ScreenBounce screenDiffuseBounce(vec3 viewPosition, vec3 normal, vec3 sun) {
    float distanceFade = 1.0 - smoothstep(12.0, 30.0, -viewPosition.z);
    ScreenBounce bounce = ScreenBounce(vec3(0.0), vec3(0.0), 0.0);
    if (distanceFade <= 0.0) {
        return bounce;
    }
    mat3 toView = transpose(mat3(gbufferModelViewInverse));
    vec3 reference = abs(normal.y) < 0.85 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(reference, normal));
    vec3 bitangent = cross(normal, tangent);
    vec3 origin = viewPosition + 0.07 * (toView * normal);
    for (int ray = 0; ray < 4; ++ray) {
        float angle = (float(ray) + 0.5) * (LW_PI * 0.5);
        vec3 direction = normalize(normal + tangent * cos(angle) + bitangent * sin(angle));
        ScreenBounce hit = screenBounceRay(origin, toView * direction, toView, sun);
        bounce.sky += hit.sky;
        bounce.block += hit.block;
        bounce.blockConfidence += hit.blockConfidence;
    }
    bounce.sky = min(bounce.sky * 0.125, vec3(0.35)) * distanceFade;
    bounce.block *= 0.125 * distanceFade;
    bounce.blockConfidence *= 0.25 * distanceFade;
    return bounce;
}
