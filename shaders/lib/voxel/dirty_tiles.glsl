// The expanded flags are uniform within a workgroup. Radius bits 0/1,
// conservative emitter support bit 2, and original tile wall bit 3.
layout(r8ui) readonly uniform uimage3D lwVoxelDirtyTiles;
shared uint lwTileNeedsUpdate;
uint voxelTileMask(ivec3 tile) {
    if(gl_LocalInvocationIndex==0u)
        lwTileNeedsUpdate=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
    barrier();
    return lwTileNeedsUpdate;
}
bool voxelTileNeedsUpdate(int radius) {
    return (voxelTileMask(ivec3(gl_WorkGroupID)) & (radius==1?1u:2u))!=0u;
}
