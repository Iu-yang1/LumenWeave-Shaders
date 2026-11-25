#version 430 core

#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) writeonly uniform image3D lwVoxelFirst;

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
    vec3 source = seed < LW_VOXEL_WALL ? voxelEmission(seed & 7u, seed >> 3u) : vec3(0.0);
    imageStore(lwVoxelFirst, cell, vec4(source, 0.0));
}
