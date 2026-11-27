#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
#include "/lib/voxel/seed_source.glsl"
layout(rgba16f) readonly uniform image3D lwVoxelFirst;
layout(rgba16f) writeonly uniform image3D lwVoxelSecond;

#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/cache_coordinates.glsl"
#endif
vec3 wallReflectance(uint wall) {
    const vec3 colors[4] = vec3[4](
        vec3(0.32), vec3(0.76), vec3(0.52, 0.038, 0.03), vec3(0.45, 0.26, 0.11)
    );
    return colors[wall & 3u];
}

vec3 gatherFace(ivec3 cell, ivec3 direction, vec3 localLight) {
    ivec3 neighbor = cell + direction;
    if (!withinVoxelGrid(neighbor)) {
        return vec3(0.0);
    }
    uint seed = voxelSeedAt(neighbor);
    if (seed >= LW_VOXEL_WALL) {
        return wallReflectance(seed) * localLight;
    }
    ivec3 farther = neighbor + direction;
    if (withinVoxelGrid(farther)) {
        seed = voxelSeedAt(farther);
        if (seed >= LW_VOXEL_WALL) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            return wallReflectance(seed)*imageLoad(lwVoxelFirst,voxelCacheCell(neighbor)).rgb*0.35;
#else
            return wallReflectance(seed) * imageLoad(lwVoxelFirst, neighbor).rgb * 0.35;
#endif
        }
    }
    return vec3(0.0);
}

#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/dirty_tiles.glsl"
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
#endif
#endif

void main() {
#ifdef LW_GPU_COMPACTION
    ivec3 tile=activeTile(2);
#else
    ivec3 tile=ivec3(gl_WorkGroupID);
#endif
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    uint tileMask=voxelTileMask(tile);
    if((tileMask&2u)==0u) return;
#endif
    ivec3 cell=tile*4+ivec3(gl_LocalInvocationID);
    vec3 bounce = vec3(0.0);
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec3 storageCell=voxelCacheCell(cell);
#else
    ivec3 storageCell=cell;
#endif
    #ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    // No wall within the two-cell gather reach: the diffuse target is
    // identically zero even when direct emitters are present.
    if((tileMask&4u)==0u || (tileMask&16u)==0u) {
        imageStore(lwVoxelSecond,storageCell,vec4(0.0));
        return;
    }
    #endif
    initializeVoxelSeedSource();
    if (voxelSeedAt(cell) < LW_VOXEL_WALL) {
        vec3 localLight = imageLoad(lwVoxelFirst, storageCell).rgb;
        for (int axis = 0; axis < 6; ++axis) {
            bounce += gatherFace(cell, LW_VOXEL_DIRECTIONS[axis], localLight);
        }
    }
    imageStore(lwVoxelSecond, storageCell, vec4(min(bounce * 0.12, vec3(0.25)), 0.0));
}
