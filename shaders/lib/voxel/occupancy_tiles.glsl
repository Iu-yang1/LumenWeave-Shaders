#ifndef LW_OCCUPANCY_TILES
#define LW_OCCUPANCY_TILES
// Bit 0: current observation. Bit 1: previous observation.
// Disjoint tail of the seed atlas, outside the physical grid.
ivec3 lwOccupancyTileAddress(ivec3 tile) {
    const int side = VOXEL_GRID_SIZE / 4;
    const int n = VOXEL_GRID_SIZE;
    int index = tile.x + side * (tile.y + side * tile.z);
    return ivec3(index % n, (index / n) % n, n + index / (n * n));
}
#ifdef LW_EXTERNAL_VOXEL_ACTIVE
ivec3 lwExternalSeedFlagAddress() {
    const int n=VOXEL_GRID_SIZE;
    return ivec3(0,0,n+(n+63)/64);
}
#endif
#endif
