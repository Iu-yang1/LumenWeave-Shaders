#include "/lib/voxel/grid.glsl"

uniform sampler3D lwVoxelLight;
#ifndef LW_CAMERA_FRACT_UNIFORM
#define LW_CAMERA_FRACT_UNIFORM
uniform vec3 cameraPositionFract;
#endif

vec3 sampleVoxelIrradiance(sampler3D field, vec3 relativePosition, vec3 normal, float offset) {
    vec3 cell = relativePosition + cameraPositionFract + vec3(float(LW_GRID_SIZE) * 0.5);
    vec3 edge = min(cell, float(LW_GRID_SIZE) - cell);
    float weight = smoothstep(0.8, 2.2, min(edge.x, min(edge.y, edge.z)));
    if (weight <= 0.0) {
        return vec3(0.0);
    }
    vec3 uv = (cell + normal * offset) / float(LW_GRID_SIZE);
    return texture(field, uv).rgb * weight;
}

vec3 voxelIrradiance(vec3 relativePosition, vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelLight, relativePosition, normal, 0.52);
}

#ifdef LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler3D lwVoxelDiffuse;

vec3 voxelDiffuseBounce(vec3 relativePosition, vec3 normal) {
    return sampleVoxelIrradiance(lwVoxelDiffuse, relativePosition, normal, 1.05);
}
#endif
