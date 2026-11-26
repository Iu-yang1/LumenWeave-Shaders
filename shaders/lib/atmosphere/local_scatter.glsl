// Single scattering from the existing RGB voxel light field, not bloom.
// The scene has already received atmospheric extinction in applySceneFog.
// Integrate only the additional source term; no second scene attenuation.
#include "/lib/voxel/irradiance.glsl"
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
uniform usampler3D lwVoxelDirtySampler;
#endif

vec3 integrateLocalScatter(vec3 direction, float surfaceDistance) {
    float radius = float(LW_GRID_SIZE) * 0.5;
    float end = min(max(surfaceDistance - 0.08, 0.0), radius - 1.0);
    if (end <= 0.001 || BLOCKLIGHT_STRENGTH == 0.0) return vec3(0.0);
    float extinction = hasSkylight
        ? mix(0.006, 0.018, rainStrength) * AERIAL_DENSITY
        : dimensionFogDensity(direction);
    if (extinction <= 0.0) return vec3(0.0);

    // Midpoint quadrature, more samples only for longer visible segments.
    // A fixed grid avoids introducing a frame-varying noise pattern.
    int steps = clamp(int(ceil(end / 1.5)), 1, 24);
    float stepSize = end / float(steps);
    float segmentTransmission = exp(-extinction * stepSize);
    // Exact constant-source segment integral: sigma_s / sigma_t = 0.75.
    float segmentWeight = (1.0 - segmentTransmission) * (0.75 * 1.45 * BLOCKLIGHT_STRENGTH);
    float transmission = 1.0;
    vec3 cell = cameraPositionFract + vec3(radius);
    vec3 delta = direction * stepSize;
    cell += delta * 0.5;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    vec3 cacheOrigin = vec3(voxelCacheOrigin());
#endif
    vec3 result = vec3(0.0);
    int i = 0;
    while (i < steps) {
        float travel = (float(i) + 0.5) * stepSize;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
        ivec3 tile = clamp(ivec3(floor(cell/4.0)),ivec3(0),ivec3(LW_GRID_SIZE/4-1));
        if (texelFetch(lwVoxelDirtySampler,tile+ivec3(32,0,0),0).r == 0u) {
            vec3 low = vec3(tile)*4.0;
            vec3 boundary = mix(low,low+4.0,greaterThan(direction,vec3(0.0)));
            vec3 exitDistance = (boundary-cell)/mix(vec3(1.0),direction,greaterThan(abs(direction),vec3(0.000001)));
            exitDistance = mix(vec3(1e6),exitDistance,greaterThan(abs(direction),vec3(0.000001)));
            float exitTravel = min(exitDistance.x,min(exitDistance.y,exitDistance.z));
            // Skip only sample centres strictly inside the proven-black tile.
            int skip = clamp(int(ceil(max(exitTravel-0.001,0.0)/stepSize)),1,steps-i);
            transmission *= exp(-extinction*stepSize*float(skip));
            cell += delta*float(skip);
            i += skip;
            continue;
        }
#endif
        vec3 edge = min(cell, vec3(float(LW_GRID_SIZE)) - cell);
        float coverage = smoothstep(0.8, 2.2, min(edge.x,min(edge.y,edge.z)))
            * (1.0 - smoothstep(radius - 5.0, radius - 1.0, travel));
        if (coverage > 0.0) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            vec3 light = sampleWrappedVoxelAtOrigin(lwVoxelLight,cell,cacheOrigin);
#else
            vec3 light = textureLod(lwVoxelLight,cell/float(LW_GRID_SIZE),0.0).rgb;
#endif
            // Empty samples contribute exactly zero.
            if (max(light.r,max(light.g,light.b)) > 0.0) {
                result += light * (coverage * transmission * segmentWeight);
            }
        }
        transmission *= segmentTransmission;
        cell += delta;
        ++i;
    }
    return result;
}
