// The three separable expansion passes store radius-one and radius-two
// masks in the final slab of the existing tile image. All stages reuse it.
layout(r32ui) readonly uniform uimage3D lwVoxelDirtyTiles;
shared uint lwTileNeedsUpdate;

bool voxelTileNeedsUpdate(int radius) {
    if (gl_LocalInvocationIndex == 0u) {
        uint mask=imageLoad(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID)+ivec3(96,0,0)).r;
        lwTileNeedsUpdate=mask & (radius==1 ? 1u : 2u);
    }
    barrier();
    return lwTileNeedsUpdate != 0u;
}
