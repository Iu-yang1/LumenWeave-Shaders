uniform sampler2D colortex9;
#ifdef LW_HALF_GI_HISTORY
uniform sampler2D colortex6;
#define LW_GI_SPATIAL_SOURCE colortex6
#else
#define LW_GI_SPATIAL_SOURCE colortex9
#endif
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler2D colortex10;
#endif

ScreenBounce spatialScreenBounce(vec3 viewPosition, vec3 normal, vec2 encodedNormal, vec3 sun, vec2 uv) {
    float sceneDepth = -viewPosition.z;
    ScreenBounce bounce = ScreenBounce(vec3(0.0), vec3(0.0), 0.0);
    if (sceneDepth >= 30.0) {
        return bounce;
    }
    ivec2 traceSize = lwRasterSize(LW_GI_SPATIAL_SOURCE);
    ivec2 fullSize = lwRasterSize(colortex1);
    vec2 samplePosition = uv * vec2(traceSize) - 0.5;
    ivec2 base = ivec2(floor(samplePosition));
    vec2 fraction = fract(samplePosition);
    float tolerance = max(0.12, sceneDepth * 0.022);
#if defined(LW_HALF_GI_HISTORY) && GI_EDGE_RECONSTRUCTION == 1
    vec3 planeNormal=transpose(mat3(gbufferModelViewInverse))*normal;
    float planeDistance=dot(planeNormal,viewPosition);
#endif
    float coverage = 0.0;
#if LOW_FREQ_CACHE == 1
    // Order by bilinear weight. At an exact 2x upscale, the first two
    // donors carry 75% (not 80% for a single donor), so this path is usable.
    ivec2 nearestOffset=ivec2(greaterThanEqual(fraction,vec2(0.5)));
    vec2 dominant=max(fraction,1.0-fraction);
    ivec2 minorAxis=dominant.x<dominant.y?ivec2(1,0):ivec2(0,1);
    vec3 firstSky=vec3(0.0);
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
    vec4 firstBlock=vec4(0.0);
#endif
    bool cacheCoherent=true;
    int accepted=0;
    for(int donorIndex=0;donorIndex<4;++donorIndex){
        ivec2 offset=nearestOffset;
        if(donorIndex==1) offset=ivec2(notEqual(offset,minorAxis));
        if(donorIndex==2) offset=ivec2(notEqual(offset,ivec2(1)-minorAxis));
        if(donorIndex==3) offset=ivec2(1)-offset;
        ivec2 texel=base+offset;
        int column=offset.x,row=offset.y;
#else
    for (int row = 0; row < 2; ++row) {
        for (int column = 0; column < 2; ++column) {
            ivec2 texel = base + ivec2(column, row);
#endif
            if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, traceSize))) {
                continue;
            }
            vec2 weights = mix(1.0 - fraction, fraction, vec2(column, row));
            if (weights.x * weights.y <= 0.00001) continue;
            vec4 sky = texelFetch(LW_GI_SPATIAL_SOURCE, texel, 0);
            ivec2 pixel = clamp(ivec2((vec2(texel) + 0.5) * vec2(fullSize) / vec2(traceSize)),ivec2(0),fullSize-1);
            float donorDepth=sceneDepth;
#if defined(LW_HALF_GI_HISTORY) && GI_EDGE_RECONSTRUCTION == 1
            if(abs(sky.a-sceneDepth)>=tolerance*0.35) {
                vec2 donorUv=(vec2(pixel)+0.5)/vec2(fullSize);
#ifdef LW_STABLE_DYNAMIC
                vec2 rayUv=donorUv;
#else
                vec2 rayUv=unjitteredUv(donorUv,true);
#endif
                vec3 donorRay=(gbufferProjectionInverse*vec4(rayUv*2.0-1.0,1.0,1.0)).xyz;
                float denominator=dot(planeNormal,donorRay);
                if(denominator*denominator>0.0004*dot(donorRay,donorRay)) {
                    float intersection=-donorRay.z*planeDistance/denominator;
                    if(intersection>0.0 && abs(intersection-sceneDepth)<max(0.25,sceneDepth*0.12))
                        donorDepth=intersection;
                }
            }
#endif
            float depthDifference = abs(sky.a - donorDepth);
            if (sky.a <= 0.0 || depthDifference >= tolerance) {
                continue;
            }
            float alignment=geometryNormalAlignment(normal,encodedNormal,texelFetch(colortex1,pixel,0).xy);
#if defined(LW_HALF_GI_HISTORY) && GI_EDGE_RECONSTRUCTION == 1
            if(alignment<=0.90) continue;
#endif
            if (alignment <= 0.82) {
                continue;
            }
            float weight = weights.x * weights.y * (1.0 - smoothstep(0.35, 1.0, depthDifference / tolerance));
#if defined(LW_HALF_GI_HISTORY) && GI_EDGE_RECONSTRUCTION == 1
            weight*=smoothstep(0.90,0.99,alignment);
#endif
            coverage += weight;
            bounce.sky += sky.rgb * weight;
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
            vec4 block = texelFetch(colortex10, texel, 0);
            bounce.block += block.rgb * weight;
            bounce.blockConfidence += block.a * weight;
#endif
#if LOW_FREQ_CACHE == 1
            cacheCoherent=cacheCoherent && depthDifference<tolerance*0.35 && alignment>0.96;
            if(accepted==0){
                firstSky=sky.rgb;
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
                firstBlock=block;
#endif
            }else{
                cacheCoherent=cacheCoherent && all(lessThanEqual(abs(sky.rgb-firstSky),vec3(0.002)+max(abs(sky.rgb),abs(firstSky))*0.04));
#ifdef LW_VOXEL_DIFFUSE_ACTIVE
                cacheCoherent=cacheCoherent && all(lessThanEqual(abs(block-firstBlock),vec4(0.002)+max(abs(block),abs(firstBlock))*0.04));
#endif
            }
            ++accepted;
            if(accepted>=2 && donorIndex==1 && cacheCoherent && coverage>=0.72)
                return ScreenBounce(bounce.sky/coverage,bounce.block/coverage,bounce.blockConfidence/coverage);
#endif
        }
#if LOW_FREQ_CACHE == 0
    }
#endif
#if APPROX_REUSE == 1
    // Reuse only depth/normal-compatible donors. A genuine disocclusion
    // uses two opposed rays rather than four full retraces.
    if(coverage>=0.012) return ScreenBounce(bounce.sky/coverage,bounce.block/coverage,bounce.blockConfidence/coverage);
    ScreenBounce reduced=screenDiffuseBounceBudget(viewPosition,normal,sun,2);
    if(coverage<=0.003) return reduced;
    float trust=smoothstep(0.003,0.012,coverage);
    return ScreenBounce(mix(reduced.sky,bounce.sky/coverage,trust),
        mix(reduced.block,bounce.block/coverage,trust),
        mix(reduced.blockConfidence,bounce.blockConfidence/coverage,trust));
#else
    // Compatible donors are normalized even if only one contributes.
    // Preserve an exact near-field fallback only for true disocclusions.
    if (coverage <= 0.003) {
        return screenDiffuseBounce(viewPosition, normal, sun);
    }
    ScreenBounce filtered = ScreenBounce(bounce.sky / coverage, bounce.block / coverage, bounce.blockConfidence / coverage);
    if (coverage < 0.035) {
        ScreenBounce full = screenDiffuseBounce(viewPosition, normal, sun);
        float confidence = smoothstep(0.003, 0.035, coverage);
        filtered.sky = mix(full.sky, filtered.sky, confidence);
        filtered.block = mix(full.block, filtered.block, confidence);
        filtered.blockConfidence = mix(full.blockConfidence, filtered.blockConfidence, confidence);
    }
    return filtered;
#endif
}
