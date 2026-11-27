#ifndef LW_VOXEL_SEED_SOURCE
#define LW_VOXEL_SEED_SOURCE
#if defined(LW_EXTERNAL_VOXEL_ACTIVE) && EXTENSION_VOXELS == 2
#include "/lib/voxel/cache_coordinates.glsl"
#include "/lib/voxel/occupancy_tiles.glsl"
shared bool lwPersistentSeedSource;
shared ivec3 lwPersistentSeedOrigin;
void initializeVoxelSeedSource() {
    if(gl_LocalInvocationIndex==0u) {
        lwPersistentSeedSource=imageLoad(lwVoxelOccupancy,lwExternalSeedFlagAddress()).r==2u;
        if(lwPersistentSeedSource) lwPersistentSeedOrigin=voxelCacheOrigin();
    }
    barrier();
}
uint voxelSeedAt(ivec3 cell) {
    if(lwPersistentSeedSource) {
        cell=voxelWrapNear(lwPersistentSeedOrigin+cell);
        cell.z+=LW_GRID_SIZE+(LW_GRID_SIZE+63)/64+1;
    }
    return imageLoad(lwVoxelOccupancy,cell).r;
}
#else
void initializeVoxelSeedSource() {}
uint voxelSeedAt(ivec3 cell) { return imageLoad(lwVoxelOccupancy,cell).r; }
#endif
#endif
