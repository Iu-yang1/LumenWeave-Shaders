#include "/lib/voxel/grid.glsl"

layout(r32ui) readonly uniform uimage3D lwVoxelOccupancy;
layout(rgba16f) readonly uniform image3D LW_VOXEL_READ;
layout(rgba16f) writeonly uniform image3D LW_VOXEL_WRITE;

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    uint seed = imageLoad(lwVoxelOccupancy, cell).r;
    if (seed >= LW_VOXEL_WALL) {
        imageStore(LW_VOXEL_WRITE, cell, vec4(0.0));
        return;
    }
    vec3 source = voxelEmission(seed & 7u, seed >> 3u);
    vec3 incoming = vec3(0.0);
    for (int stepIndex = 0; stepIndex < 6; ++stepIndex) {
        ivec3 neighbor = cell + LW_VOXEL_DIRECTIONS[stepIndex];
        if (withinVoxelGrid(neighbor)) {
            incoming = max(incoming, imageLoad(LW_VOXEL_READ, neighbor).rgb);
        }
    }
    imageStore(LW_VOXEL_WRITE, cell, vec4(max(source, incoming * 0.73), 0.0));
}
