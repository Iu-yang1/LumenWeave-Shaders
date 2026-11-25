#version 430 core

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
const ivec3 workGroups = ivec3(8, 8, 8);

layout(rgba16f) readonly uniform image3D lwSeed;
layout(rgba16f) writeonly uniform image3D lwFirst;
#define LW_PREVIOUS lwSeed
#include "/lib/propagate.glsl"

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    imageStore(lwFirst, cell, propagate(cell, imageSize(lwFirst)));
}
