#version 430 core
#include "/lib/quality.glsl"
#include "/lib/voxel/dispatch.glsl"
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && VOXEL_FUSION == 1
#define LW_VOXEL_READ lwVoxelStage0
#define LW_VOXEL_WRITE lwVoxelStage2
#include "/lib/voxel/propagate_pair.glsl"
#else
#ifdef LW_VOXEL_INCREMENTAL_ACTIVE
#define LW_VOXEL_READ lwVoxelStage1
#define LW_VOXEL_WRITE lwVoxelStage2
#else
#define LW_VOXEL_READ lwVoxelSecond
#define LW_VOXEL_WRITE lwVoxelFirst
#endif
#include "/lib/voxel/propagate.glsl"
#endif
