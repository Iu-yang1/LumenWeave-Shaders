#version 430 core

#include "/lib/quality.glsl"
#include "/lib/voxel/grid.glsl"

#include "/lib/voxel/dispatch.glsl"
layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
layout(rgba16f) writeonly uniform image3D lwVoxelStage0;
layout(r32ui) uniform uimage3D lwVoxelPrevSeed;
layout(r32ui) coherent uniform uimage3D lwVoxelDirtyTiles;
layout(rgba32i) readonly uniform iimage2D lwVoxelMeta;
uniform ivec3 cameraPositionInt;
uniform int frameCounter;
#else
layout(rgba16f) writeonly uniform image3D lwVoxelFirst;
#endif

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
    vec3 source = seed < LW_VOXEL_WALL ? voxelEmission(seed & 7u, seed >> 3u) : vec3(0.0);
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec4 previous = imageLoad(lwVoxelMeta, ivec2(0));
    bool fullRebuild = any(notEqual(previous.xyz, cameraPositionInt)) ||
        previous.w != frameCounter - 1;
    if (fullRebuild || imageLoad(lwVoxelPrevSeed, cell).r != seed) {
        imageStore(lwVoxelStage0, cell, vec4(source, 0.0));
        imageStore(lwVoxelPrevSeed, cell, uvec4(seed));
        imageAtomicOr(lwVoxelDirtyTiles, ivec3(gl_WorkGroupID), 1u);
    }
#else
    imageStore(lwVoxelFirst, cell, vec4(source, 0.0));
#endif
}
