#include "/lib/voxel/grid.glsl"
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/occupancy_tiles.glsl"
#endif

in vec4 at_midBlock;
in vec4 mc_Entity;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPositionFract;
layout(r32ui) coherent uniform uimage3D lwVoxelOccupancy;

void injectTerrainVoxel(vec3 shadowView) {
    int blockId = int(mc_Entity.x);
    bool wall = blockId >= 10020 && blockId <= 10023;
    uint strength = uint(clamp(at_midBlock.w + 0.5, 0.0, 15.0));
    if (strength == 0u && !wall) {
        return;
    }
    #ifdef LW_EXTERNAL_VOXEL_ACTIVE
    if(imageLoad(lwVoxelOccupancy,lwExternalSeedFlagAddress()).r==uint(EXTENSION_VOXELS)) return;
    #endif
    vec3 position = (shadowModelViewInverse * vec4(shadowView, 1.0)).xyz;
    vec3 center = position + at_midBlock.xyz / 64.0;
    ivec3 cell = voxelCell(center, cameraPositionFract);
    if (!withinVoxelGrid(cell)) {
        return;
    }
    uint kind = emitterKind(blockId);
    uint seed = strength > 0u ? packVoxelEmitter(kind,strength) : LW_VOXEL_WALL | uint(blockId - 10020);
#ifdef LW_VOXEL_SUBGROUP
    // The grid is at most 128^3 and seeds are at most 259. This is an
    // injective 30-bit key. Remove only identical submissions; distinct
    // seeds and cells retain the same atomic-max arbitration.
    uint key=uint(cell.x)|(uint(cell.y)<<7u)|(uint(cell.z)<<14u)|(seed<<21u);
    uint firstKey=readFirstInvocationARB(key);
    uint firstLane=readFirstInvocationARB(gl_SubGroupInvocationARB);
    if(key==firstKey && gl_SubGroupInvocationARB!=firstLane) return;
#endif
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    // Publish occupied tiles on the first writer, retaining atomic seed arbitration.
    uint previous = imageAtomicMax(lwVoxelOccupancy, cell, seed);
    if (previous == 0u) {
        imageAtomicOr(lwVoxelOccupancy, lwOccupancyTileAddress(cell / 4), 1u);
    }
#else
    imageAtomicMax(lwVoxelOccupancy, cell, seed);
#endif
}
