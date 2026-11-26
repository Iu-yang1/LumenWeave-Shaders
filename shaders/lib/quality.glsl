#ifndef LW_QUALITY_SETTINGS
#define LW_QUALITY_SETTINGS

//#define LITE_LIGHTING
#define SCENE_SHADOWS
#define DEFERRED_LIGHTING
#define SCREEN_AO
#define SOFT_SHADOWS
#define ADVANCED_WATER
#define AA_MODE 2 // [0 1 2 3]
#define PROJECTION_JITTER 0 // [0 1 2]
//#define INCREMENTAL_VOXELS
#define VOXEL_FUSION 1 // [0 1]
//#define PHYSICAL_ATMOSPHERE
//#define MATERIAL_SSR
#define HIZ_MODE 1 // [0 1 2]
#define ADAPTIVE_SHADING
#define OVERWORLD_BUDGET 1 // [0 1 2]
#define NETHER_BUDGET 1 // [0 1 2]
#define END_BUDGET 1 // [0 1 2]
#if defined(LW_DIMENSION_NETHER)
#define LW_DIMENSION_BUDGET NETHER_BUDGET
#elif defined(LW_DIMENSION_END)
#define LW_DIMENSION_BUDGET END_BUDGET
#else
#define LW_DIMENSION_BUDGET OVERWORLD_BUDGET
#endif
#define TEMPORAL_REUSE
#define GI_REUSE_MODE 1 // [0 1 2]
#ifdef TEMPORAL_REUSE
#define LW_TEMPORAL_REUSE
#endif
#define ADAPTIVE_SHADOWS
//#define DH_SHADOWS
//#define VOLUME_EFFECTS
#define VOLUME_RECONSTRUCTION 1 // [0 1]
#define HDR_REUSE 1 // [0 1]
//#define VOXEL_LIGHTING
//#define SCREEN_GI
//#define SCREEN_GI_HISTORY
//#define SCREEN_GI_SPATIAL
//#define VOXEL_GI
#define SHADOW_MAP 2048 // [0 512 1024 2048 4096]
#define SHADOW_RANGE 128.0 // [48.0 64.0 96.0 128.0 160.0 192.0]
#define EXPOSURE 0 // [-2 -1 0 1 2]
//#define SHOW_COLOR_CHART
#define AERIAL_DENSITY 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]
#define SUNLIGHT_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define AMBIENT_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define BLOCKLIGHT_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define EMISSION_STRENGTH 1.5 // [1.0 1.25 1.5 1.75 2.0]
#define GLOW_SOFTNESS 1.0 // [0.0 0.5 1.0 1.5]
#define LOCAL_GLOW_STRENGTH 1.7 // [0.0 0.75 1.0 1.35 1.7 2.0 2.5]
#define DARK_AMBIENT 0.65 // [0.35 0.5 0.65 0.8 1.0]
#define NETHER_AMBIENT 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define END_AMBIENT 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define WATER_BIOME_TINT 0.15 // [0.0 0.15 0.3 0.5 0.75 1.0]
#define WATER_DENSITY 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define WATER_TURBIDITY 0.01 // [0.0 0.01 0.025 0.05 0.1 0.2]
#define WATER_WAVE_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]
#define WATER_WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_WAVE_DETAIL 8 // [2 4 8]
#define WATER_ROUGHNESS 0.18 // [0.08 0.12 0.18 0.24 0.32]
#define WATER_REFRACTION 1.0 // [0.0 0.5 0.75 1.0 1.5]
#define WATER_REFLECTION_STEPS 16 // [0 8 16 24 32]
#define MATERIAL_REFLECTION_STEPS 16 // [0 8 16 24 32]
#define CLOUD_STEPS 12 // [8 10 12 16]
#define SHAFT_STEPS 6 // [4 6 8]
#define DH_SHADOW_STEPS 14 // [8 10 14]
#define WAVING_LEAVES
#define WAVING_GRASS
#define WIND_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]
#define WIND_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WIND_DISTANCE 96.0 // [32.0 48.0 64.0 96.0 128.0 192.0]
//#define MOTION_BLUR
#define MOTION_BLUR_STRENGTH 0.5 // [0.25 0.5 0.75 1.0]
#define MOTION_BLUR_SAMPLES 8 // [4 8 12]
#define BLOOM_FILTER 1 // [0 1 2]
//#define BLOOM
#define BLOOM_STRENGTH 0.08 // [0.02 0.04 0.08 0.12 0.16 0.2]
#define BLOOM_THRESHOLD 1.5 // [0.5 1.0 1.5 2.0 3.0 4.0]
#define COLOR_SATURATION 1.0 // [0.7 0.85 1.0 1.1 1.2]
#define COLOR_CONTRAST 1.0 // [0.85 0.95 1.0 1.05 1.15]
#define WHITE_BALANCE 0.0 // [-0.1 -0.05 0.0 0.05 0.1]
#define IMAGE_SHARPENING 0.0 // [0.0 0.15 0.3 0.5 0.75]
#define SHADOW_HYBRID 1 // [0 1]
#define SHADOW_FILTER_TAPS 8 // [4 8]
#define AO_SLICES 3 // [2 3 4]
#define AO_RECONSTRUCTION 1 // [0 1]
#define AO_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.25]

#ifdef INCREMENTAL_VOXELS
#if defined(VOXEL_LIGHTING) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && defined(IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE) && defined(IRIS_FEATURE_REVERSED_CULLING)
#define LW_VOXEL_INCREMENTAL_ACTIVE
#endif
#endif

#ifdef PHYSICAL_ATMOSPHERE
#if defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS)
#define LW_ATMOSPHERE_LUT_ACTIVE
#endif
#endif

#ifdef DH_SHADOWS
#define LW_DH_SHADOWS_REQUESTED
#if defined(SCENE_SHADOWS) && defined(DEFERRED_LIGHTING) && defined(DISTANT_HORIZONS)
#define LW_DH_DEFERRED_SHADOWS
#endif
#endif

#ifdef MATERIAL_SSR
#if defined(DEFERRED_LIGHTING) && defined(ADVANCED_WATER) && !defined(LITE_LIGHTING)
#define LW_MATERIAL_SSR_ACTIVE
#endif
#endif

#if AA_MODE >= 2 && defined(DEFERRED_LIGHTING)
#define LW_TAA_ACTIVE
// Auto: preserve dynamic sampling on the verified Medium/High path.
// The user-tested fixed-grid mode preserves both TAA and SSGI histories.
#if PROJECTION_JITTER == 2 || (PROJECTION_JITTER == 0 && !defined(VOLUME_EFFECTS) && !defined(SCREEN_GI) && !defined(VOXEL_LIGHTING))
#define LW_DYNAMIC_JITTER
#if defined(VOLUME_EFFECTS) || defined(SCREEN_GI) || defined(VOXEL_LIGHTING) || defined(MATERIAL_SSR) || defined(PHYSICAL_ATMOSPHERE)
#define LW_STABLE_DYNAMIC
#endif
#endif
#endif
#if AA_MODE == 1 || AA_MODE == 3 || (AA_MODE == 2 && !defined(DEFERRED_LIGHTING))
#define LW_FXAA_ACTIVE
#endif

// Only the explicit fixed-grid path can safely share the unused ownership
// attachment with half-resolution AO; dynamic projection keeps it full size.
#if AO_RECONSTRUCTION == 1 && PROJECTION_JITTER == 1 && defined(DEFERRED_LIGHTING) && defined(SCREEN_AO) && defined(SCREEN_GI) && defined(SCREEN_GI_SPATIAL) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#define LW_AO_SPATIAL
#endif

// GI's half-size transient texture is free after deferred shading, provided
// no cross-frame raw GI reuse is requested. No additional color attachment.
#if VOLUME_RECONSTRUCTION == 1 && PROJECTION_JITTER == 1 && defined(VOLUME_EFFECTS) && defined(SCREEN_GI) && defined(SCREEN_GI_SPATIAL) && defined(DEFERRED_LIGHTING) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && !(defined(TEMPORAL_REUSE) && GI_REUSE_MODE == 2 && defined(SCREEN_GI_HISTORY) && defined(LW_TAA_ACTIVE)) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#define LW_CELESTIAL_VOLUME_SPATIAL
#endif
#if HDR_REUSE == 1 && defined(LW_TAA_ACTIVE) && !defined(MOTION_BLUR)
#define LW_TAA_DIRECT
#endif

// Stable native depth only; dynamic reanchoring can shift hit depth.
#if defined(DEFERRED_LIGHTING) && !defined(LW_DYNAMIC_JITTER) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS)
#if HIZ_MODE > 0 && (defined(SCREEN_GI) || defined(LW_MATERIAL_SSR_ACTIVE) || (HIZ_MODE == 2 && defined(ADVANCED_WATER)))
#define LW_HIZ_ACTIVE
#endif
#endif
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && defined(IRIS_VERSION) && IRIS_VERSION >= 11107 && MC_VERSION >= 260100 && defined(IRIS_FEATURE_SSBO)
#define LW_GPU_COMPACTION
#endif
#endif
