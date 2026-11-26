#version 430 core
#include "/lib/quality.glsl"
#include "/lib/voxel/features.glsl"
#include "/lib/voxel/dispatch.glsl"
#if defined(LW_LOCAL_SCATTER_ACTIVE) && defined(LW_VOXEL_INCREMENTAL_ACTIVE)
#include "/lib/voxel/grid.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
layout(rgba16f) readonly uniform image3D lwVoxelFirst;
layout(r8ui) writeonly uniform uimage3D lwVoxelDirtyTiles;
shared uint occupied;
void main() {
    if (gl_LocalInvocationIndex == 0u) occupied = 0u;
    barrier();
    vec3 light = imageLoad(lwVoxelFirst,voxelCacheCell(ivec3(gl_GlobalInvocationID))).rgb;
    if (max(light.r,max(light.g,light.b)) > 0.0) atomicOr(occupied,1u);
    barrier();
    // Dirty seed slab is dead after propagation. Reuse it for light occupancy.
    if (gl_LocalInvocationIndex == 0u)
        imageStore(lwVoxelDirtyTiles,ivec3(gl_WorkGroupID),uvec4(occupied));
}
#else
void main(){}
#endif
