#include "/lib/voxel/grid.glsl"

layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) readonly uniform image3D LW_VOXEL_READ;
layout(rgba16f) writeonly uniform image3D LW_VOXEL_WRITE;

#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#include "/lib/voxel/dirty_tiles.glsl"
#include "/lib/voxel/cache_coordinates.glsl"
#endif

void main() {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    if (!voxelTileNeedsUpdate(1)) {
        return;
    }
#endif
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
    ivec3 storageCell = voxelCacheCell(cell);
#else
    ivec3 storageCell = cell;
#endif
    if (seed >= LW_VOXEL_WALL) {
        imageStore(LW_VOXEL_WRITE, storageCell, vec4(0.0));
        return;
    }
    vec3 source = seed == 0u ? vec3(0.0) : voxelSeedEmission(seed);
    vec3 incoming = vec3(0.0);
    for (int stepIndex = 0; stepIndex < 6; ++stepIndex) {
        ivec3 neighbor = cell + LW_VOXEL_DIRECTIONS[stepIndex];
        if (withinVoxelGrid(neighbor)) {
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
            // A valid local neighbour differs by one cell. Wrap only this
            // storage offset rather than rebuilding the camera origin.
            ivec3 wrapped = storageCell + LW_VOXEL_DIRECTIONS[stepIndex];
            wrapped += ivec3(lessThan(wrapped,ivec3(0))) * LW_GRID_SIZE;
            wrapped -= ivec3(greaterThanEqual(wrapped,ivec3(LW_GRID_SIZE))) * LW_GRID_SIZE;
            incoming = max(incoming,imageLoad(LW_VOXEL_READ,wrapped).rgb);
#else
            incoming = max(incoming, imageLoad(LW_VOXEL_READ, neighbor).rgb);
#endif
        }
    }
    imageStore(LW_VOXEL_WRITE, storageCell, vec4(max(source, incoming * 0.73), 0.0));
}
