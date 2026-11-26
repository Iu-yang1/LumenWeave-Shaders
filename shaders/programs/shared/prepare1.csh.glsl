#version 430 core
#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#define LW_VOXEL_READ lwVoxelStage0
#define LW_VOXEL_WRITE lwVoxelStage1
#else
#define LW_VOXEL_READ lwVoxelFirst
#define LW_VOXEL_WRITE lwVoxelSecond
#endif
#include "/lib/voxel/propagate.glsl"
