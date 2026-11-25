#include "/lib/voxel/grid.glsl"

in vec4 at_midBlock;
in vec4 mc_Entity;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPositionFract;
layout(r32ui) coherent uniform uimage3D lwVoxelOccupancy;

void injectTerrainVoxel(vec3 shadowView) {
    int blockId = int(mc_Entity.x);
    bool wall = blockId >= 10020 && blockId <= 10023;
    uint strength = uint(clamp(at_midBlock.w + 0.5, 0.0, 15.0));
    if (strength == 0u && !wall) {
        return;
    }
    vec3 position = (shadowModelViewInverse * vec4(shadowView, 1.0)).xyz;
    vec3 center = position + at_midBlock.xyz / 64.0;
    ivec3 cell = voxelCell(center, cameraPositionFract);
    if (!withinVoxelGrid(cell)) {
        return;
    }
    uint kind = blockId >= 10011 && blockId <= 10014 ? uint(blockId - 10010) : 1u;
    uint seed = strength > 0u ? (strength << 3u) | kind : LW_VOXEL_WALL | uint(blockId - 10020);
    imageAtomicMax(lwVoxelOccupancy, cell, seed);
}
