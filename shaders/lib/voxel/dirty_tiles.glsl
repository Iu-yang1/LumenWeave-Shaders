// The propagation radius is four cells. A 4^3 workgroup therefore needs
// only its own tile and immediate neighbours. Diffuse gathering adds two cells.
layout(r32ui) readonly uniform uimage3D lwVoxelDirtyTiles;
shared uint lwTileNeedsUpdate;

bool voxelTileNeedsUpdate(int radius) {
    if (gl_LocalInvocationIndex == 0u) {
        lwTileNeedsUpdate = 0u;
        ivec3 tile = ivec3(gl_WorkGroupID);
        ivec3 limit = ivec3(LW_GRID_SIZE / 4);
        for (int z = -radius; z <= radius; ++z) {
            for (int y = -radius; y <= radius; ++y) {
                for (int x = -radius; x <= radius; ++x) {
                    ivec3 neighbor = tile + ivec3(x,y,z);
                    if (all(greaterThanEqual(neighbor,ivec3(0))) && all(lessThan(neighbor,limit))) {
                        lwTileNeedsUpdate |= imageLoad(lwVoxelDirtyTiles,neighbor).r;
                    }
                }
            }
        }
    }
    barrier();
    return lwTileNeedsUpdate != 0u;
}
