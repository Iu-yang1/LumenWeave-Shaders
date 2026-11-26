#ifndef LW_VOXEL_CACHE_COORDINATES
#define LW_VOXEL_CACHE_COORDINATES
#ifndef LW_CAMERA_INT_UNIFORM
#define LW_CAMERA_INT_UNIFORM
uniform ivec3 cameraPositionInt;
#endif

ivec3 voxelWrap(ivec3 cell) {
    return (cell % LW_GRID_SIZE + LW_GRID_SIZE) % LW_GRID_SIZE;
}

// Inputs in [-N,2N) need only one conditional correction, no modulo.
ivec3 voxelWrapNear(ivec3 cell) {
    cell+=ivec3(lessThan(cell,ivec3(0)))*LW_GRID_SIZE;
    return cell-ivec3(greaterThanEqual(cell,ivec3(LW_GRID_SIZE)))*LW_GRID_SIZE;
}

ivec3 voxelCacheOrigin() {
    return voxelWrap(cameraPositionInt - ivec3(LW_GRID_SIZE / 2));
}

ivec3 voxelCacheCell(ivec3 localCell) {
    return voxelWrapNear(localCell + voxelCacheOrigin());
}
#endif
