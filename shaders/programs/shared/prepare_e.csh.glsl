#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(8,8,8);
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
layout(r8ui) uniform uimage3D lwVoxelDirtyTiles;
#ifdef LW_VOXEL_SMOOTH_ACTIVE
#include "/lib/voxel/grid.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
layout(rgba16f) uniform image3D lwVoxelFirst;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
uniform int frameCounter;
#include "/lib/voxel/history_tiles.glsl"
shared ivec4 historyPrevious;
#endif
shared uint localCount1,localCount2,localCount3,base1,base2,base3;
void main() {
    if(gl_LocalInvocationIndex==0u){
        localCount1=0u;localCount2=0u;localCount3=0u;
#ifdef LW_VOXEL_SMOOTH_ACTIVE
        historyPrevious=imageLoad(lwVoxelMeta,ivec2(0));
#endif
    }
    barrier();
    ivec3 tile=ivec3(gl_GlobalInvocationID);
    int n=VOXEL_GRID_SIZE/4;
    uint flags=0u;
    if(all(lessThan(tile,ivec3(n)))) flags=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
    uint i1=0u,i2=0u,i3=0u;
    bool updateHistory=false;
#ifdef LW_VOXEL_SMOOTH_ACTIVE
    if(all(lessThan(tile,ivec3(n)))){
        uint support;
        updateHistory=!historyTileReusable(tile,historyPrevious,flags,support);
        if(!updateHistory) retainHistoryTile(tile,support);
        else i3=atomicAdd(localCount3,1u);
    }
#endif
    if((flags&1u)!=0u) i1=atomicAdd(localCount1,1u);
    if((flags&2u)!=0u) i2=atomicAdd(localCount2,1u);
    barrier();
    if(gl_LocalInvocationIndex==0u){
        base1=0u;base2=0u;base3=0u;
        if(localCount1!=0u)base1=atomicAdd(count1,localCount1);
        if(localCount2!=0u)base2=atomicAdd(count2,localCount2);
        if(localCount3!=0u)base3=atomicAdd(count3,localCount3);
    }
    barrier();
    uint index=uint(tile.x+n*(tile.y+n*tile.z));
    if((flags&1u)!=0u)tasks1[base1+i1]=index;
    if((flags&2u)!=0u)tasks2[base2+i2]=index;
    if(updateHistory)tasks3[base3+i3]=index;
}
#else
void main(){}
#endif
