#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
layout(rgba16f) writeonly uniform image3D lwVoxelStage0;
layout(r32ui) uniform uimage3D lwVoxelPrevSeed;
layout(r32ui) coherent uniform uimage3D lwVoxelDirtyTiles;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
#include "/lib/voxel/cache_coordinates.glsl"
uniform int frameCounter;
#else
layout(rgba16f) writeonly uniform image3D lwVoxelFirst;
#endif

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
    vec3 source = seed < LW_VOXEL_WALL ? voxelEmission(seed & 7u, seed >> 3u) : vec3(0.0);
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec4 previous = imageLoad(lwVoxelMeta, ivec2(0));
    ivec3 previousLocal = cell + (cameraPositionInt - previous.xyz);
    ivec3 cacheCell = voxelCacheCell(cell);
    bool fullRebuild = previous.w != frameCounter - 1;
    bool entered = !withinVoxelGrid(previousLocal);
    // A new boundary can lose a neighbour that existed in the old domain,
    // even if the retained voxel seed itself did not change.
    bool lostNeighbor = false;
    for (int axis=0;axis<3;++axis) {
        lostNeighbor = lostNeighbor ||
            (cell[axis]==0 && previousLocal[axis]>0) ||
            (cell[axis]==LW_GRID_SIZE-1 && previousLocal[axis]<LW_GRID_SIZE-1);
    }
    bool seedChanged = fullRebuild || entered || imageLoad(lwVoxelPrevSeed,cacheCell).r != seed;
    if (seedChanged) {
        imageStore(lwVoxelStage0,cacheCell,vec4(source,0.0));
        imageStore(lwVoxelPrevSeed,cacheCell,uvec4(seed));
    }
    if (seedChanged || lostNeighbor) {
        imageAtomicOr(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),1u);
    }
#else
    imageStore(lwVoxelFirst, cell, vec4(source, 0.0));
#endif
}
