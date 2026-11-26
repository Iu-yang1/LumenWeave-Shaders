// Single scattering from the existing RGB voxel light field, not bloom.
// The scene has already received atmospheric extinction in applySceneFog.
// Integrate only the additional source term; no second scene attenuation.
#include "/lib/voxel/irradiance.glsl"

vec3 integrateLocalScatter(vec3 direction, float surfaceDistance) {
    float radius = float(LW_GRID_SIZE) * 0.5;
    float end = min(max(surfaceDistance - 0.08, 0.0), radius - 1.0);
    if (end <= 0.001 || BLOCKLIGHT_STRENGTH == 0.0 || LOCAL_GLOW_STRENGTH == 0.0) return vec3(0.0);
    float extinction = hasSkylight
        ? mix(0.006, 0.018, rainStrength) * AERIAL_DENSITY
        : dimensionFogDensity(direction);
    if (extinction <= 0.0) return vec3(0.0);

    // Midpoint quadrature, more samples only for longer visible segments.
    // A fixed grid avoids introducing a frame-varying noise pattern.
    int steps = clamp(int(ceil(end / 1.5)), 1, 24);
    float regionStart=0.0,regionEnd=end;
    int regionCount=1;
#if LOCAL_SCATTER_ADAPTIVE == 1 && LW_DIMENSION_BUDGET != 0
    if(end>24.0) regionCount=2;
#endif
    vec3 result=vec3(0.0);
    for(int region=0;region<regionCount;++region) {
    if(regionCount==2) {
        regionStart=region==0 ? 0.0 : 12.0;
        regionEnd=region==0 ? 12.0 : end;
        float farStep=2.5;
#if defined(LW_DIMENSION_NETHER)
        farStep=2.0;
#endif
        steps=region==0 ? 8 : clamp(int(ceil((end-12.0)/farStep)),1,16);
    }
    float stepSize = (regionEnd-regionStart) / float(steps);
    float segmentTransmission = exp(-extinction * stepSize);
    // Exact constant-source segment integral: sigma_s / sigma_t = 0.75.
    float segmentWeight = (1.0 - segmentTransmission) * (0.75 * 0.90 * BLOCKLIGHT_STRENGTH * LOCAL_GLOW_STRENGTH);
    float transmission = exp(-extinction*regionStart);
    vec3 cell = cameraPositionFract + vec3(radius);
    vec3 delta = direction * stepSize;
    cell += direction*regionStart + delta*0.5;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    vec3 cacheOrigin = vec3(voxelCacheOrigin());
    ivec3 lastTile=ivec3(-1);
    bool tileLit=true;
    bvec3 moving=greaterThan(abs(direction),vec3(0.000001));
    vec3 inverseDirection=1.0/mix(vec3(1.0),direction,moving);
#endif
    int i = 0;
    while (i < steps) {
        float travel = regionStart+(float(i)+0.5)*stepSize;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
        ivec3 tile = clamp(ivec3(floor(cell/4.0)),ivec3(0),ivec3(LW_GRID_SIZE/4-1));
        if(any(notEqual(tile,lastTile))) {
            tileLit=(texelFetch(lwVoxelDirtySampler,tile+ivec3(96,0,0),0).r&4u)!=0u;
            lastTile=tile;
        }
        if (!tileLit) {
            vec3 low = vec3(tile)*4.0;
            vec3 boundary = mix(low,low+4.0,greaterThan(direction,vec3(0.0)));
            vec3 exitDistance = (boundary-cell)*inverseDirection;
            exitDistance = mix(vec3(1e6),exitDistance,moving);
            float exitTravel = min(exitDistance.x,min(exitDistance.y,exitDistance.z));
            // Skip only sample centres strictly inside the proven-black tile.
            int skip = clamp(int(ceil(max(exitTravel-0.001,0.0)/stepSize)),1,steps-i);
            transmission *= skip==1 ? segmentTransmission : exp(-extinction*stepSize*float(skip));
            cell += delta*float(skip);
            i += skip;
            continue;
        }
#endif
        vec3 edge = min(cell, vec3(float(LW_GRID_SIZE)) - cell);
        float coverage = smoothstep(0.8, 4.5, min(edge.x,min(edge.y,edge.z)))
            * (1.0 - smoothstep(radius - 12.0, radius - 1.0, travel));
        if (coverage > 0.0) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            vec4 field = sampleWrappedVoxelRgbaAtOrigin(lwVoxelLight,cell,cacheOrigin);
#else
            vec4 field = textureLod(lwVoxelLight,cell/float(LW_GRID_SIZE),0.0);
#endif
            // Alpha carries distance-to-emitter support, propagated with the RGB.
            // A smooth support taper suppresses the finite Manhattan frontier.
            float support=smoothstep(0.02,0.88,field.a);
            vec3 light=field.rgb*support;
            // Empty samples contribute exactly zero.
            if (max(light.r,max(light.g,light.b)) > 0.0) {
                result += light * (coverage * transmission * segmentWeight);
            }
        }
        transmission *= segmentTransmission;
        cell += delta;
        ++i;
    }

    }
    // Smoothly compress only dense accumulated local scattering. This
    // leaves weak distant halos linear, preserves hue and avoids a flat veil.
    float peak=max(result.r,max(result.g,result.b));
    return result/(1.0+GLOW_SOFTNESS*0.65*peak);
}
