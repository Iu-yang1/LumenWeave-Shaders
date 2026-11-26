#include "/lib/voxel/grid.glsl"

layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) readonly uniform image3D LW_VOXEL_READ;
layout(rgba16f) writeonly uniform image3D LW_VOXEL_WRITE;

#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/dirty_tiles.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
#endif
#endif

// 4^3 interior + six 4x4 faces. Corners/edges of the halo are
// never sampled by the six-neighbour stencil.
shared vec4 lwStencil[160];

ivec3 stencilCell(int index) {
    if (index < 64) return ivec3(index%4,(index/4)%4,index/16);
    int face = (index-64)/16;
    int u = (index-64)%4;
    int v = ((index-64)/4)%4;
    int side = face%2 == 0 ? -1 : 4;
    if (face/2 == 0) return ivec3(side,u,v);
    if (face/2 == 1) return ivec3(u,side,v);
    return ivec3(u,v,side);
}

int stencilIndex(ivec3 p) {
    if (p.x < 0 || p.x > 3) return 64 + (p.x>3 ? 16 : 0) + p.y + 4*p.z;
    if (p.y < 0 || p.y > 3) return 96 + (p.y>3 ? 16 : 0) + p.x + 4*p.z;
    if (p.z < 0 || p.z > 3) return 128 + (p.z>3 ? 16 : 0) + p.x + 4*p.y;
    return p.x + 4*p.y + 16*p.z;
}

void main() {
#ifdef LW_GPU_COMPACTION
    ivec3 tile=activeTile(1);
#else
    ivec3 tile=ivec3(gl_WorkGroupID);
#endif
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    uint tileMask=voxelTileMask(tile);
    if((tileMask&1u)==0u) return;
    bool useShared=(tileMask&8u)==0u;
#else
    // Full rebuild has no cached wall classification.
    bool useShared=false;
#endif
    ivec3 cell=tile*4+ivec3(gl_LocalInvocationID);
    ivec3 local = ivec3(gl_LocalInvocationID);
    ivec3 base = cell-local;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec3 origin = voxelCacheOrigin();
    ivec3 storageCell = voxelWrapNear(cell+origin);
#else
    ivec3 storageCell = cell;
#endif
    // No emitter can reach this dirty tile: clear stale light without any
    // source-field reads, including the source halo.
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    if((tileMask&4u)==0u) {
        imageStore(LW_VOXEL_WRITE,storageCell,vec4(0.0));
        return;
    }
#endif
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;

    // Reuse classification from the seed pass rather than doing 64
    // contended atomics and two extra barriers per propagation stage.
    if (!useShared) {
        if (seed >= LW_VOXEL_WALL) {
            imageStore(LW_VOXEL_WRITE,storageCell,vec4(0.0));
            return;
        }
        vec3 source = seed == 0u ? vec3(0.0) : voxelSeedEmission(seed);
        vec4 incoming = vec4(0.0);
        for (int stepIndex=0; stepIndex<6; ++stepIndex) {
            ivec3 neighbor=cell+LW_VOXEL_DIRECTIONS[stepIndex];
            if (withinVoxelGrid(neighbor)) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
                incoming=max(incoming,imageLoad(LW_VOXEL_READ,voxelWrapNear(neighbor+origin)));
#else
                incoming=max(incoming,imageLoad(LW_VOXEL_READ,neighbor));
#endif
            }
        }
        imageStore(LW_VOXEL_WRITE,storageCell,vec4(max(source,incoming.rgb*0.73),max(float(any(greaterThan(source,vec3(0.0)))),incoming.a-0.20)));
        return;
    }

    // Every lane participates before any wall early return.
    for (int i=int(gl_LocalInvocationIndex); i<160; i+=64) {
        ivec3 sampleCell = base + stencilCell(i);
        vec4 light = vec4(0.0);
        if (withinVoxelGrid(sampleCell)) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            light = imageLoad(LW_VOXEL_READ,voxelWrapNear(sampleCell+origin));
#else
            light = imageLoad(LW_VOXEL_READ,sampleCell);
#endif
        }
        lwStencil[i] = light;
    }
    barrier();
    if (seed >= LW_VOXEL_WALL) {
        imageStore(LW_VOXEL_WRITE, storageCell, vec4(0.0));
        return;
    }
    vec3 source = seed == 0u ? vec3(0.0) : voxelSeedEmission(seed);
    vec4 incoming = vec4(0.0);
    for (int stepIndex = 0; stepIndex < 6; ++stepIndex) {
        incoming = max(incoming,lwStencil[stencilIndex(local+LW_VOXEL_DIRECTIONS[stepIndex])]);
    }
    imageStore(LW_VOXEL_WRITE, storageCell, vec4(max(source,incoming.rgb*0.73),max(float(any(greaterThan(source,vec3(0.0)))),incoming.a-0.20)));
}
