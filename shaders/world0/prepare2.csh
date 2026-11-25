#version 430 core
#include "/lib/voxel/dispatch.glsl"
#define LW_VOXEL_READ lwVoxelSecond
#define LW_VOXEL_WRITE lwVoxelFirst
#include "/lib/voxel/propagate.glsl"
