#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
layout(rgba16f) writeonly uniform image3D lwVoxelStage0;
layout(r16ui) uniform uimage3D lwVoxelPrevSeed;
layout(r8ui) coherent uniform uimage3D lwVoxelDirtyTiles;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
#include "/lib/voxel/cache_coordinates.glsl"
uniform int frameCounter;
shared ivec4 lwPreviousMeta;
shared ivec3 lwCacheOrigin;
shared ivec3 lwMovement;
shared bool lwFullRebuild;
shared bool lwStationary;
shared uint lwGroupFlags[64];
#else
layout(rgba16f) writeonly uniform image3D lwVoxelFirst;
#endif

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    if(gl_LocalInvocationIndex==0u) {
        lwPreviousMeta=imageLoad(lwVoxelMeta,ivec2(0));
        lwCacheOrigin=voxelCacheOrigin();
        lwMovement=cameraPositionInt-lwPreviousMeta.xyz;
        lwFullRebuild=lwPreviousMeta.w != frameCounter - 1;
        lwStationary=all(equal(lwMovement,ivec3(0)));
    }
    barrier();
    ivec3 movement=lwMovement;
    ivec3 previousLocal = cell + movement;
    ivec3 cacheCell = voxelWrapNear(cell+lwCacheOrigin);
    bool fullRebuild=lwFullRebuild;
    bool stationary=lwStationary;
    bool entered = !stationary && !withinVoxelGrid(previousLocal);
    // A new boundary can lose a neighbour that existed in the old domain,
    // even if the retained voxel seed itself did not change.
    bool lostNeighbor = false;
    if(!stationary) for (int axis=0;axis<3;++axis) {
        lostNeighbor = lostNeighbor ||
            (cell[axis]==0 && previousLocal[axis]>0) ||
            (cell[axis]==LW_GRID_SIZE-1 && previousLocal[axis]<LW_GRID_SIZE-1);
    }
    bool seedChanged = fullRebuild || entered || imageLoad(lwVoxelPrevSeed,cacheCell).r != seed;
    if (seedChanged) {
        vec3 source=seed < LW_VOXEL_WALL ? voxelSeedEmission(seed) : vec3(0.0);
        imageStore(lwVoxelStage0,cacheCell,vec4(source,float(any(greaterThan(source,vec3(0.0))))));
        imageStore(lwVoxelPrevSeed,cacheCell,uvec4(seed));
    }
    uint flags=(seedChanged || lostNeighbor) ? 1u : 0u;
    // Any emitting seed can reach at most four cells in the four stencil passes.
    if(seed>0u && seed<LW_VOXEL_WALL) flags|=4u;
    if(seed>=LW_VOXEL_WALL) flags|=8u;
    // No contended shared atomics, even in dense solid terrain.
    // Each of eight reducers ORs one group of eight independent flags.
    uint lane=gl_LocalInvocationIndex;
    lwGroupFlags[lane]=flags;
    barrier();
    if(lane<8u) {
        uint mask=0u;
        for(uint i=0u;i<8u;++i) mask|=lwGroupFlags[lane*8u+i];
        lwGroupFlags[lane*8u]=mask;
    }
    barrier();
    if(lane==0u) {
        uint mask=0u;
        for(int i=0;i<8;++i) mask|=lwGroupFlags[i*8];
        imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(mask));
    }
#else
    vec3 source=seed < LW_VOXEL_WALL ? voxelSeedEmission(seed) : vec3(0.0);
    imageStore(lwVoxelFirst, cell, vec4(source,float(any(greaterThan(source,vec3(0.0))))));
#endif
}
