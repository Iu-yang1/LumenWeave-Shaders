#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=4,local_size_y=4,local_size_z=4) in;
#if VOXEL_GRID_SIZE == 128
const ivec3 workGroups=ivec3(8,8,8);
#elif VOXEL_GRID_SIZE == 96
const ivec3 workGroups=ivec3(6,6,6);
#elif VOXEL_GRID_SIZE == 64
const ivec3 workGroups=ivec3(4,4,4);
#else
const ivec3 workGroups=ivec3(2,2,2);
#endif
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/grid.glsl"
#include "/lib/voxel/active_tiles.glsl"
#include "/lib/voxel/occupancy_tiles.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
layout(r8ui) writeonly uniform uimage3D lwVoxelDirtyTiles;
uniform int frameCounter;
shared uint localCount,baseIndex;
shared bool reuseEmpty;
void main() {
    if(gl_LocalInvocationIndex==0u) {
        localCount=0u;
        ivec4 meta=imageLoad(lwVoxelMeta,ivec2(0));
        reuseEmpty=meta.w==frameCounter-1 && all(equal(meta.xyz,cameraPositionInt));
    }
    barrier();
    ivec3 tile=ivec3(gl_GlobalInvocationID);
    // One invocation per brick. Motion or stale metadata must scan all bricks.
    bool scan=!reuseEmpty || imageLoad(lwVoxelOccupancy,lwOccupancyTileAddress(tile)).r!=0u;
    uint slot=0u;
    if(scan) slot=atomicAdd(localCount,1u);
    else imageStore(lwVoxelDirtyTiles,tile,uvec4(0u));
    barrier();
    if(gl_LocalInvocationIndex==0u) {
        baseIndex=0u;
        if(localCount!=0u) baseIndex=atomicAdd(count0,localCount);
    }
    barrier();
    if(scan) {
        int n=VOXEL_GRID_SIZE/4;
        tasks0[baseIndex+slot]=uint(tile.x+n*(tile.y+n*tile.z));
    }
}
#else
void main(){}
#endif
