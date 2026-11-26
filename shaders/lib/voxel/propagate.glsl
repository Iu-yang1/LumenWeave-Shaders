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
shared vec3 lwStencil[160];
shared uint lwOpenMask[2];

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
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && !defined(LW_GPU_COMPACTION)
    if (!voxelTileNeedsUpdate(1)) {
        return;
    }
#endif
#ifdef LW_GPU_COMPACTION
    ivec3 cell=activeTile(1)*4+ivec3(gl_LocalInvocationID);
#else
    ivec3 cell = ivec3(gl_GlobalInvocationID);
#endif
    ivec3 local = ivec3(gl_LocalInvocationID);
    ivec3 base = cell-local;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec3 origin = voxelCacheOrigin();
    ivec3 storageCell = voxelWrap(cell+origin);
#else
    ivec3 storageCell = cell;
#endif
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;

    // Dense open tiles benefit from cooperative halo reads; solid/sparse
    // tiles keep the direct stencil instead of loading an unused halo.
    if (gl_LocalInvocationIndex < 2u) lwOpenMask[gl_LocalInvocationIndex] = 0u;
    barrier();
    if (seed < LW_VOXEL_WALL)
        atomicOr(lwOpenMask[gl_LocalInvocationIndex/32u],1u << (gl_LocalInvocationIndex%32u));
    barrier();
    int openCount = bitCount(lwOpenMask[0]) + bitCount(lwOpenMask[1]);
    if (openCount < 32) {
        if (seed >= LW_VOXEL_WALL) {
            imageStore(LW_VOXEL_WRITE,storageCell,vec4(0.0));
            return;
        }
        vec3 source = seed == 0u ? vec3(0.0) : voxelSeedEmission(seed);
        vec3 incoming = vec3(0.0);
        for (int stepIndex=0; stepIndex<6; ++stepIndex) {
            ivec3 neighbor=cell+LW_VOXEL_DIRECTIONS[stepIndex];
            if (withinVoxelGrid(neighbor)) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
                incoming=max(incoming,imageLoad(LW_VOXEL_READ,voxelWrap(neighbor+origin)).rgb);
#else
                incoming=max(incoming,imageLoad(LW_VOXEL_READ,neighbor).rgb);
#endif
            }
        }
        imageStore(LW_VOXEL_WRITE,storageCell,vec4(max(source,incoming*0.73),0.0));
        return;
    }

    // Every lane participates before any wall early return.
    for (int i=int(gl_LocalInvocationIndex); i<160; i+=64) {
        ivec3 sampleCell = base + stencilCell(i);
        vec3 light = vec3(0.0);
        if (withinVoxelGrid(sampleCell)) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            light = imageLoad(LW_VOXEL_READ,voxelWrap(sampleCell+origin)).rgb;
#else
            light = imageLoad(LW_VOXEL_READ,sampleCell).rgb;
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
    vec3 incoming = vec3(0.0);
    for (int stepIndex = 0; stepIndex < 6; ++stepIndex) {
        incoming = max(incoming,lwStencil[stencilIndex(local+LW_VOXEL_DIRECTIONS[stepIndex])]);
    }
    imageStore(LW_VOXEL_WRITE, storageCell, vec4(max(source, incoming * 0.73), 0.0));
}
