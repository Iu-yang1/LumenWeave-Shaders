#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
layout(r32ui) writeonly uniform uimage3D lwVoxelOccupancy;

#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
layout(r32ui) writeonly uniform uimage3D lwVoxelDirtyTiles;
#endif

void main() {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    if (gl_LocalInvocationIndex == 0u) {
        imageStore(lwVoxelDirtyTiles, ivec3(gl_WorkGroupID), uvec4(0u));
    }
#endif
    imageStore(lwVoxelOccupancy, ivec3(gl_GlobalInvocationID), uvec4(0u));
}
