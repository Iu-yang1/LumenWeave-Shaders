#version 430 core
#include "/lib/voxel/dispatch.glsl"
#define LW_VOXEL_READ lwVoxelFirst
#define LW_VOXEL_WRITE lwVoxelSecond
#include "/lib/voxel/propagate.glsl"
