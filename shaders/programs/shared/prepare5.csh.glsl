#version 430 core

#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) readonly uniform image3D lwVoxelFirst;
layout(rgba16f) writeonly uniform image3D lwVoxelSecond;

vec3 wallReflectance(uint wall) {
    const vec3 colors[4] = vec3[4](
        vec3(0.32), vec3(0.76), vec3(0.52, 0.038, 0.03), vec3(0.45, 0.26, 0.11)
    );
    return colors[wall & 3u];
}

vec3 gatherFace(ivec3 cell, ivec3 direction, vec3 localLight) {
    ivec3 neighbor = cell + direction;
    if (!withinVoxelGrid(neighbor)) {
        return vec3(0.0);
    }
    uint seed = imageLoad(lwVoxelOccupancy, neighbor).r;
    if (seed >= LW_VOXEL_WALL) {
        return wallReflectance(seed) * localLight;
    }
    ivec3 farther = neighbor + direction;
    if (withinVoxelGrid(farther)) {
        seed = imageLoad(lwVoxelOccupancy, farther).r;
        if (seed >= LW_VOXEL_WALL) {
            return wallReflectance(seed) * imageLoad(lwVoxelFirst, neighbor).rgb * 0.35;
        }
    }
    return vec3(0.0);
}

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    vec3 bounce = vec3(0.0);
    if (imageLoad(lwVoxelOccupancy, cell).r < LW_VOXEL_WALL) {
        vec3 localLight = imageLoad(lwVoxelFirst, cell).rgb;
        for (int axis = 0; axis < 6; ++axis) {
            bounce += gatherFace(cell, LW_VOXEL_DIRECTIONS[axis], localLight);
        }
    }
    imageStore(lwVoxelSecond, cell, vec4(min(bounce * 0.12, vec3(0.25)), 0.0));
}
