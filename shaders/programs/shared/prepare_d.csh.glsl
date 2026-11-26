#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=1) in;
const ivec3 workGroups=ivec3(1,1,1);
#ifdef LW_GPU_COMPACTION
#include "/lib/voxel/active_tiles.glsl"
void main() {
    count1=0u; y1=1u; z1=1u; pad1=0u;
    count2=0u; y2=1u; z2=1u; pad2=0u;
}
#else
void main(){}
#endif
