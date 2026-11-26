#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/occupancy_tiles.glsl"
layout(r32ui) uniform uimage3D lwVoxelOccupancy;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
uniform int frameCounter;
shared bool clearTile;
void main() {
    if (gl_LocalInvocationIndex == 0u) {
        ivec3 address = lwOccupancyTileAddress(ivec3(gl_WorkGroupID));
        bool fresh = imageLoad(lwVoxelMeta, ivec2(0)).w == frameCounter - 1;
        uint last = fresh ? imageLoad(lwVoxelOccupancy, address).r & 1u : 0u;
        clearTile = !fresh || last != 0u;
        imageStore(lwVoxelOccupancy, address, uvec4(last << 1u));
    }
    barrier();
    if (clearTile) imageStore(lwVoxelOccupancy, ivec3(gl_GlobalInvocationID), uvec4(0u));
}
#else
layout(r32ui) writeonly uniform uimage3D lwVoxelOccupancy;

void main() {
    imageStore(lwVoxelOccupancy, ivec3(gl_GlobalInvocationID), uvec4(0u));
}
#endif
