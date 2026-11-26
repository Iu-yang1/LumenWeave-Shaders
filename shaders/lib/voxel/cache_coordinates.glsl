#ifndef LW_VOXEL_CACHE_COORDINATES
#define LW_VOXEL_CACHE_COORDINATES
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif

ivec3 voxelWrap(ivec3 cell) {
    return (cell % LW_GRID_SIZE + LW_GRID_SIZE) % LW_GRID_SIZE;
}

ivec3 voxelCacheOrigin() {
    return voxelWrap(cameraPositionInt - ivec3(LW_GRID_SIZE / 2));
}

ivec3 voxelCacheCell(ivec3 localCell) {
    return voxelWrap(localCell + voxelCacheOrigin());
}
#endif
