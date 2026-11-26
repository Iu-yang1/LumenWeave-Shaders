#include "/lib/lighting/scene_budget.glsl"
float horizonCosine(vec2 originUv, vec2 stepUv, vec3 position, vec3 observer, vec3 normal) {
    float horizon = -1.0;
#if LW_DIMENSION_BUDGET == 0
    int taps=4;
#elif LW_DIMENSION_BUDGET == 2
    int taps=-position.z>24.0 ? 2 : 4;
#else
    int taps=-position.z>32.0 ? 2 : 4;
#endif
#if SCENE_BUDGET == 1 && LW_DIMENSION_BUDGET != 0
    float depth=-position.z;
    float footprint=length(stepUv*vec2(lwRasterSize(depthtex0)));
    float contribution=1.0-smoothstep(20.0,52.0,depth);
    float threshold=LW_DIMENSION_BUDGET==2 ? 24.0 : 32.0;
    taps=lwReduceDistantWork(depth,threshold,contribution,footprint) ? 2 : 4;
#endif
    for (int tap = 1; tap <= taps; ++tap) {
        vec2 uv = originUv + stepUv * (float(tap * tap) / float(taps * taps));
        if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
            break;
        }
        ivec2 pixel = depthPixelAtUv(depthtex0, uv);
        vec2 pixelUv = depthPixelUv(depthtex0, pixel);
        float depth = texelFetch(depthtex0, pixel, 0).r;
        if (depth >= 1.0) {
            continue;
        }
#ifdef LW_STABLE_DYNAMIC
        int kind = sampleOwner(pixelUv, depth, false);
        vec3 samplePosition = reconstructProjection(pixelUv, depth, gbufferProjectionInverse, kind != 0);
        if (kind == 1) {
            vec3 sampleNormal = transpose(mat3(gbufferModelViewInverse)) * decodeNormal(texelFetch(colortex1,pixel,0).xy);
            samplePosition = stableViewSurfacePosition(samplePosition, unjitteredUv(uv,true), sampleNormal, gbufferProjectionInverse);
        }
#else
        vec3 samplePosition = reconstructViewPosition(pixelUv, depth);
#endif
        vec3 delta = samplePosition - position;
        float distanceSquared = dot(delta, delta);
        if (distanceSquared <= 0.0001 || distanceSquared >= 2.56 || dot(delta, normal) <= 0.025) {
            continue;
        }
        float cosine = dot(delta, observer) * inversesqrt(distanceSquared);
        float weight = 1.0 - smoothstep(0.36, 2.56, distanceSquared);
        horizon = max(horizon, mix(-1.0, cosine, weight));
    }
    return clamp(horizon, -1.0, 1.0);
}

float visibleArcCosine(float cosine,float gamma,float cg,float sg) {
    // cos(gamma+pi/2)=-sin(gamma). Avoid acos for a fully open arc;
    // use the double-angle identity otherwise, without more trig calls.
    if(cosine<=-sg) return 0.5*(cg+(gamma+LW_PI*0.5)*sg);
    float h=acos(clamp(cosine,-1.0,1.0));
    float sinH=sqrt(max(1.0-cosine*cosine,0.0));
    float cosDouble=2.0*cosine*cosine-1.0;
    float sinDouble=2.0*cosine*sinH;
    return 0.25*(cg-cosDouble*cg-sinDouble*sg+2.0*h*sg);
}

float groundTruthOcclusion(vec2 uv, vec3 position, vec3 normal) {
    // The existing distance fade is exactly one beyond 52 blocks.
    if (-position.z >= 52.0 || AO_STRENGTH == 0.0) return 1.0;
    vec3 observer = normalize(-position);
#ifdef LW_STABLE_DYNAMIC
    uv += jitterOffset(frameCounter);
#endif
    vec2 resolution = vec2(lwRasterSize(depthtex0));
    float scale = min(1.6 / max(-position.z, 0.01), 56.0 / resolution.y);
    vec2 projectionScale = 0.5 * vec2(gbufferProjection[0][0], gbufferProjection[1][1]);
    float visible = 0.0;
    float unoccluded = 0.0;
    for (int slice = 0; slice < AO_SLICES; ++slice) {
        float angle = (float(slice) + 0.5) * (LW_PI / float(AO_SLICES));
        vec2 axis = vec2(cos(angle), sin(angle));
        vec3 sliceAxis = vec3(axis, 0.0);
        sliceAxis = normalize(sliceAxis - dot(sliceAxis, observer) * observer);
        vec2 projectedNormal = vec2(dot(normal, observer), dot(normal, sliceAxis));
        float weight = length(projectedNormal);
        if (weight < 0.0001) {
            continue;
        }
        vec2 angleVector=vec2(max(projectedNormal.x,0.00001),projectedNormal.y);
        float gamma=atan(angleVector.y,angleVector.x);
        vec2 angleUnit=angleVector*inversesqrt(dot(angleVector,angleVector));
        float cg=angleUnit.x,sg=angleUnit.y;
        vec2 stepUv = axis * projectionScale * scale;
        float positive=horizonCosine(uv,stepUv,position,observer,normal);
        float negative=horizonCosine(uv,-stepUv,position,observer,normal);
        visible+=weight*(visibleArcCosine(positive,gamma,cg,sg)+visibleArcCosine(negative,-gamma,cg,-sg));
        // Analytic sum of the two unobstructed arcs, for |gamma|<=pi/2.
        unoccluded+=weight*(cg+gamma*sg);
    }
    float visibility = clamp(visible / max(unoccluded, 0.0001), 0.0, 1.0);
    visibility = 1.0 - clamp((1.0 - visibility) * AO_STRENGTH, 0.0, 1.0);
    return mix(visibility, 1.0, smoothstep(20.0, 52.0, -position.z));
}
