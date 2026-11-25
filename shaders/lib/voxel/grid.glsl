#include "/lib/voxel/settings.glsl"

const int LW_GRID_SIZE = VOXEL_GRID_SIZE;
const uint LW_VOXEL_WALL = 256u;
const ivec3 LW_VOXEL_DIRECTIONS[6] = ivec3[6](
    ivec3(-1, 0, 0), ivec3(1, 0, 0), ivec3(0, -1, 0),
    ivec3(0, 1, 0), ivec3(0, 0, -1), ivec3(0, 0, 1)
);

ivec3 voxelCell(vec3 relativePosition, vec3 cameraFraction) {
    return ivec3(floor(relativePosition + cameraFraction)) + ivec3(LW_GRID_SIZE / 2);
}

bool withinVoxelGrid(ivec3 cell) {
    return all(greaterThanEqual(cell, ivec3(0))) && all(lessThan(cell, ivec3(LW_GRID_SIZE)));
}

vec3 voxelEmission(uint kind, uint strength) {
    vec3 color = vec3(1.0, 0.63, 0.33);
    if (kind == 2u) {
        color = vec3(0.17, 0.72, 1.0);
    } else if (kind == 3u) {
        color = vec3(0.63, 1.0, 0.78);
    } else if (kind == 4u) {
        color = vec3(1.0, 0.21, 0.07);
    }
    return color * (float(strength) / 15.0) * 1.7;
}
