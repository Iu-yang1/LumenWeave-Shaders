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
//#define MATERIAL_SSR
//#define DH_SHADOWS
//#define VOLUME_EFFECTS
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
#define NETHER_AMBIENT 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define END_AMBIENT 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define WATER_BIOME_TINT 0.15 // [0.0 0.15 0.3 0.5 0.75 1.0]
#define WATER_DENSITY 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define WATER_TURBIDITY 0.025 // [0.0 0.01 0.025 0.05 0.1 0.2]
#define WATER_WAVE_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]
#define WATER_WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_WAVE_DETAIL 8 // [2 4 8]
#define WATER_ROUGHNESS 0.18 // [0.08 0.12 0.18 0.24 0.32]
#define WATER_REFRACTION 1.0 // [0.0 0.5 0.75 1.0 1.5]
#define WATER_REFLECTION_STEPS 16 // [0 8 16 24 32]
#define WAVING_LEAVES
#define WAVING_GRASS
#define WIND_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]
#define WIND_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WIND_DISTANCE 96.0 // [32.0 48.0 64.0 96.0 128.0 192.0]
//#define MOTION_BLUR
#define MOTION_BLUR_STRENGTH 0.5 // [0.25 0.5 0.75 1.0]
#define MOTION_BLUR_SAMPLES 8 // [4 8 12]
//#define BLOOM
#define BLOOM_STRENGTH 0.08 // [0.02 0.04 0.08 0.12 0.2]
#define BLOOM_THRESHOLD 1.5 // [0.5 1.0 1.5 2.0 3.0 4.0]
#define COLOR_SATURATION 1.0 // [0.7 0.85 1.0 1.1 1.2]
#define COLOR_CONTRAST 1.0 // [0.85 0.95 1.0 1.05 1.15]
#define WHITE_BALANCE 0.0 // [-0.1 -0.05 0.0 0.05 0.1]
#define IMAGE_SHARPENING 0.0 // [0.0 0.15 0.3 0.5 0.75]
#define SHADOW_FILTER_TAPS 8 // [4 8]
#define AO_SLICES 3 // [2 3 4]
#define AO_STRENGTH 1.0 // [0.0 0.5 0.75 1.0 1.25]

#ifdef DH_SHADOWS
#define LW_DH_SHADOWS_REQUESTED
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
#endif
#endif
#if AA_MODE == 1 || AA_MODE == 3 || (AA_MODE == 2 && !defined(DEFERRED_LIGHTING))
#define LW_FXAA_ACTIVE
#endif

#endif
