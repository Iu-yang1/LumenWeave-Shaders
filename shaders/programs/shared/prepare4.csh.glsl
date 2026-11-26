#version 430 core
#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && VOXEL_FUSION == 1
#define LW_VOXEL_READ lwVoxelStage2
#define LW_VOXEL_WRITE lwVoxelFirst
#include "/lib/voxel/propagate_pair.glsl"
#else
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#define LW_VOXEL_READ lwVoxelStage3
#define LW_VOXEL_WRITE lwVoxelFirst
#else
#define LW_VOXEL_READ lwVoxelSecond
#define LW_VOXEL_WRITE lwVoxelFirst
#endif
#include "/lib/voxel/propagate.glsl"
#endif
