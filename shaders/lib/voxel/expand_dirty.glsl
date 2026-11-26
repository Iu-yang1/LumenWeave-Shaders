#include "/lib/quality.glsl"
#include "/lib/voxel/settings.glsl"

layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups = ivec3(8, 8, 8);
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
// Each axis reads only the preceding 32^3 slab and writes a disjoint slab.
// Iris executes prepare, prepare_a, prepare_b, prepare_c serially.
layout(r32ui) uniform uimage3D lwVoxelDirtyTiles;
void main(){
    ivec3 tile=ivec3(gl_GlobalInvocationID);
    int limit=VOXEL_GRID_SIZE/4;
    if(any(greaterThanEqual(tile,ivec3(limit)))) return;
    uint mask=0u;
    for(int d=-2;d<=2;++d){
        ivec3 other=tile;
        other[LW_DIRTY_AXIS]+=d;
        if(other[LW_DIRTY_AXIS]<0 || other[LW_DIRTY_AXIS]>=limit) continue;
        uint value=imageLoad(lwVoxelDirtyTiles,other+ivec3(32*LW_DIRTY_AXIS,0,0)).r;
#if LW_DIRTY_AXIS == 0
        value=(value&1u)*3u | (value&4u);
#endif
        mask|=value & (abs(d)<=1 ? 7u : 6u);
        if(mask==7u) break;
    }
#if LW_DIRTY_AXIS == 2
    // Wall classification belongs to the original local tile, not its halo.
    mask|=imageLoad(lwVoxelDirtyTiles,tile).r&8u;
#endif
    imageStore(lwVoxelDirtyTiles,tile+ivec3(32*(LW_DIRTY_AXIS+1),0,0),uvec4(mask));
}
#else
void main(){}
#endif
