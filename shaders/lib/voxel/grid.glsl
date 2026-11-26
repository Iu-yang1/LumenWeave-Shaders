#include "/lib/lighting/emitter_palette.glsl"
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

// 4-bit palette + 4-bit vanilla emission level. Walls start at 256.
uint packVoxelEmitter(uint kind,uint strength) {
    return (min(strength,15u)<<4u) | min(kind,15u);
}
vec3 voxelEmission(uint kind,uint strength) {
    float level = float(strength)/15.0;
    float power = kind==5u ? 1.65 : ((kind==6u || kind==11u) ? 1.45 : 1.5);
    // Lift high-level sources without flooding dim emitters.
    float shaped=level*mix(0.62,1.15,level);
    return emitterColor(kind) * shaped * power;
}
vec3 voxelSeedEmission(uint seed) {
    return voxelEmission(seed & 15u, seed >> 4u);
}
