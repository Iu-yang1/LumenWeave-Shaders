#include "/lib/voxel/settings.glsl"

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
#if VOXEL_GRID_SIZE == 128
const ivec3 workGroups = ivec3(32, 32, 32);
#elif VOXEL_GRID_SIZE == 96
const ivec3 workGroups = ivec3(24, 24, 24);
#elif VOXEL_GRID_SIZE == 64
const ivec3 workGroups = ivec3(16, 16, 16);
#else
const ivec3 workGroups = ivec3(8, 8, 8);
#endif
