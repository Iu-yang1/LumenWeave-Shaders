#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
const ivec3 workGroups=ivec3(8,8,8);
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
layout(r8ui) readonly uniform uimage3D lwVoxelDirtyTiles;
shared uint localCount1,localCount2,base1,base2;
void main() {
    if(gl_LocalInvocationIndex==0u){localCount1=0u;localCount2=0u;}
    barrier();
    ivec3 tile=ivec3(gl_GlobalInvocationID);
    int n=VOXEL_GRID_SIZE/4;
    uint flags=0u;
    if(all(lessThan(tile,ivec3(n)))) flags=imageLoad(lwVoxelDirtyTiles,tile+ivec3(96,0,0)).r;
    uint i1=0u,i2=0u;
    if((flags&1u)!=0u) i1=atomicAdd(localCount1,1u);
    if((flags&2u)!=0u) i2=atomicAdd(localCount2,1u);
    barrier();
    if(gl_LocalInvocationIndex==0u){
        base1=0u;base2=0u;
        if(localCount1!=0u)base1=atomicAdd(count1,localCount1);
        if(localCount2!=0u)base2=atomicAdd(count2,localCount2);
    }
    barrier();
    uint index=uint(tile.x+n*(tile.y+n*tile.z));
    if((flags&1u)!=0u)tasks1[base1+i1]=index;
    if((flags&2u)!=0u)tasks2[base2+i2]=index;
}
#else
void main(){}
#endif
