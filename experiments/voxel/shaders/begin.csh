#version 430 core

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;
const ivec3 workGroups = ivec3(8, 8, 8);

layout(rgba16f) writeonly uniform image3D lwSeed;
layout(std430, binding = 0) buffer ProbeStatus {
    uint signature;
};

#include "/lib/scene.glsl"

void main() {
    ivec3 cell = ivec3(gl_GlobalInvocationID);
    int center = imageSize(lwSeed).x / 2;
    imageStore(lwSeed, cell, vec4(emission(cell, center), isWall(cell, center) ? 1.0 : 0.0));
    if (all(equal(cell, ivec3(0)))) {
        signature = 0x4c575630u;
    }
}
