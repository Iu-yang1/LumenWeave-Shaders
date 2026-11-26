#version 430 core
#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"
#include "/lib/voxel/settings.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups = ivec3(8,8,8);
#if defined(LW_VOXEL_SMOOTH_ACTIVE) || (defined(LW_LOCAL_SCATTER_ACTIVE) && defined(LW_VOXEL_INCREMENTAL_ACTIVE))
layout(r8ui) uniform uimage3D lwVoxelDirtyTiles;
void main() {
    ivec3 tile = ivec3(gl_GlobalInvocationID);
    int limit = VOXEL_GRID_SIZE/4;
    if (any(greaterThanEqual(tile,ivec3(limit)))) return;
    // Only nonzero support is consumed by the sampling paths. Try the
    // tile itself before scanning its halo; lit interiors need one fetch.
    uint occupied = imageLoad(lwVoxelDirtyTiles,tile).r;
    // Trilinear sampling straddles tile boundaries; include all 26
    // neighbouring tiles to prove an entire sampling tile is black.
    for (int z=-1; z<=1 && occupied==0u; ++z)
        for (int y=-1; y<=1 && occupied==0u; ++y)
            for (int x=-1; x<=1 && occupied==0u; ++x) {
                ivec3 p=tile+ivec3(x,y,z);
                if (all(greaterThanEqual(p,ivec3(0))) && all(lessThan(p,ivec3(limit))))
                    occupied |= imageLoad(lwVoxelDirtyTiles,p).r;
            }
    imageStore(lwVoxelDirtyTiles,tile+ivec3(32,0,0),uvec4(occupied));
}
#else
void main(){}
#endif
