#version 430 core
#include "/lib/quality.glsl"
layout(local_size_x=1,local_size_y=1) in;
const ivec3 workGroups=ivec3(1,1,1);
#ifdef LW_VOXEL_SMOOTH_ACTIVE
layout(rgba32i) writeonly uniform iimage2D lwVoxelMeta;
uniform ivec3 cameraPositionInt;
uniform int frameCounter;
void main(){imageStore(lwVoxelMeta,ivec2(0),ivec4(cameraPositionInt,frameCounter));}
#else
void main(){}
#endif
