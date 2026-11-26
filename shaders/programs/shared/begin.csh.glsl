#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
layout(r32ui) writeonly uniform uimage3D lwVoxelOccupancy;

void main() {
    imageStore(lwVoxelOccupancy, ivec3(gl_GlobalInvocationID), uvec4(0u));
}
