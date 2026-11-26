#ifndef LW_QUALITY_SETTINGS
#define LW_QUALITY_SETTINGS

//#define LITE_LIGHTING
#define SCENE_SHADOWS
#define DEFERRED_LIGHTING
#define SCREEN_AO
#define SOFT_SHADOWS
#define ADVANCED_WATER
#define AA_MODE 2 // [0 1 2 3]
#define SCENE_TAAU_SCALE 100 // [50 67 75 85 100]
#define GEOMETRY_TAAU_SCALE 100 // [50 67 75 85 100]
#define PROJECTION_JITTER 0 // [0 1 2]
//#define INCREMENTAL_VOXELS
#define VOXEL_FUSION 1 // [0 1]
//#define PHYSICAL_ATMOSPHERE
//#define MATERIAL_SSR
#define HIZ_MODE 1 // [0 1 2]
#define ADAPTIVE_SHADING
#define APPROX_REUSE 1 // [0 1]
#define PERCEPTUAL_GI 1 // [0 1 2]
#define MULTIRATE_VOLUME 1 // [0 1 2]
#define SSR_FOOTPRINT 1 // [0 1 2]
#define LOW_FREQ_CACHE 1 // [0 1]
#define DIFFUSE_SH 1 // [0 1]
#define SCENE_BUDGET 1 // [0 1]
#define SKY_ENV_REUSE 1 // [0 1]
#define WATER_PHASE_LUT 0 // [0 1]
#define WATER_HYBRID_WAVES 1 // [0 1]
#define RAIN_RIPPLES 1 // [0 1 2]
#define WET_SURFACES
#define PUDDLE_STRENGTH 0.65 // [0.0 0.25 0.5 0.65 0.8 1.0]
#define AUTO_EXPOSURE
#define EXPOSURE_ADAPTATION 0.65 // [0.25 0.5 0.65 0.8 1.0]
#define SMOOTH_LIGHTING
#define RAIN_GEOMETRY 1 // [0 1]
#define VOXEL_DIFFUSE_SMOOTHING 1 // [0 1]
#define DIRECT_RISE_HALF 0.10 // [0.05 0.10 0.16 0.25 0.40]
#define DIRECT_FALL_HALF 0.18 // [0.05 0.10 0.18 0.28 0.50]
#define DIFFUSE_RISE_HALF 0.16 // [0.05 0.10 0.16 0.25 0.40]
#define DIFFUSE_FALL_HALF 0.28 // [0.10 0.18 0.28 0.40 0.60]
#define RAIN_RISE_TIME 20.0 // [2.0 5.0 10.0 20.0 40.0]
#define RAIN_FALL_TIME 40.0 // [5.0 10.0 20.0 40.0 60.0]
#define DOF_MODE 0 // [0 1 2 3]
#define DOF_FOCUS 8.0 // [2.0 4.0 8.0 16.0 32.0 64.0]
#define DOF_STRENGTH 0.25 // [0.10 0.15 0.25 0.5 0.75 1.0]
#define DOF_IDLE 1 // [0 1]
#define DOF_IDLE_DELAY 8.0 // [3.0 5.0 8.0 15.0 30.0]
#define DOF_IDLE_STRENGTH 0.5 // [0.25 0.5 0.75 1.0]
#define PERIPHERAL_OPTICS 0 // [0 1]
#define PERIPHERAL_STRENGTH 0.5 // [0.25 0.5 0.75 1.0]
#define DOF_AF_SPEED 0.22 // [0.10 0.16 0.22 0.35 0.50]
#define DOF_AF_AREA 1.0 // [0.5 1.0 1.5 2.0]
#define DOF_QUALITY 1 // [0 1 2]
#define DOF_FILTER 0 // [0 1 2]
#define SOLAR_GLARE
#define GLARE_STRENGTH 0.25 // [0.1 0.25 0.5 0.75 1.0]
//#define LENS_GHOSTS
//#define LENS_STAR
#define BRDF_REUSE 1 // [0 1]
#define ATMO_PREBAKED 1 // [0 1]
#define END_NEBULA_ASSET 1 // [0 1]
#define ATMO_UPDATE_MODE 1 // [0 1]
#define CLOUD_DENSITY_CACHE 1 // [0 1]
#define CLOUD_OPTICAL_CACHE 1 // [0 1]
#define CLOUD_NOISE_MODE 1 // [0 1]
#define CLOUD_ADAPTIVE 1 // [0 1]
#define CLOUD_EMPTY_SKIP 1 // [0 1]
#define SHAFT_ADAPTIVE 1 // [0 1]
#define CLOUD_LIGHT_REUSE 1 // [0 1]
#define VOLUME_TEMPORAL 1 // [0 1]
#define LOCAL_SCATTER_ADAPTIVE 1 // [0 1]
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
#define SSR_HALF_RES 1 // [0 1]
#define CLOUD_STEPS 12 // [8 10 12 16 20 24]
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

#if RAIN_GEOMETRY == 1 && defined(WET_SURFACES) && defined(LW_VOXEL_INCREMENTAL_ACTIVE) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#define LW_VOXEL_WEATHER_ACTIVE
#ifdef SMOOTH_LIGHTING
#define LW_RAIN_COLUMN_SLICE (2*VOXEL_GRID_SIZE+4)
#else
#define LW_RAIN_COLUMN_SLICE VOXEL_GRID_SIZE
#endif
#endif
#if defined(SMOOTH_LIGHTING) && defined(LW_VOXEL_INCREMENTAL_ACTIVE)
#define LW_VOXEL_SMOOTH_ACTIVE
#if VOXEL_DIFFUSE_SMOOTHING == 1 && defined(VOXEL_GI) && defined(DEFERRED_LIGHTING)
#define LW_VOXEL_DIFFUSE_SMOOTH
#endif
#endif

// The legacy four-stage voxel cache plus runtime static atmosphere tables
// already occupies the loader's 16 custom-image slots.
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && VOXEL_FUSION != 1 && defined(PHYSICAL_ATMOSPHERE) && ATMO_PREBAKED != 1
#define LW_IMAGE_BUDGET_FULL
#endif
#ifdef PHYSICAL_ATMOSPHERE
#if defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS)
#define LW_ATMOSPHERE_LUT_ACTIVE
#if ATMO_UPDATE_MODE == 1 && !defined(LW_IMAGE_BUDGET_FULL) && !defined(LW_DIMENSION_NETHER) && !defined(LW_DIMENSION_END)
#define LW_ATMO_CACHE_ACTIVE
#endif
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
#if GEOMETRY_TAAU_SCALE < 100
#define LW_GEOMETRY_TAAU
#elif SCENE_TAAU_SCALE < 100
#define LW_SCENE_TAAU
#endif
// Auto: preserve dynamic sampling on the verified Medium/High path.
// The user-tested fixed-grid mode preserves both TAA and SSGI histories.
#if !defined(LW_GEOMETRY_TAAU) && (PROJECTION_JITTER == 2 || (PROJECTION_JITTER == 0 && !defined(VOLUME_EFFECTS) && !defined(SCREEN_GI) && !defined(VOXEL_LIGHTING)))
#define LW_DYNAMIC_JITTER
#if defined(VOLUME_EFFECTS) || defined(SCREEN_GI) || defined(VOXEL_LIGHTING) || defined(MATERIAL_SSR) || defined(PHYSICAL_ATMOSPHERE)
#define LW_STABLE_DYNAMIC
#endif
#endif
#endif
#if AA_MODE == 1 || AA_MODE == 3 || (AA_MODE == 2 && !defined(DEFERRED_LIGHTING))
#define LW_FXAA_ACTIVE
#endif

// Fixed-grid and no-TAA paths share the unused ownership attachment.
// AO-only presets can now use the existing deferred prepass without SSGI.
#if AO_RECONSTRUCTION == 1 && (PROJECTION_JITTER == 1 || AA_MODE < 2 || defined(LW_GEOMETRY_TAAU)) && defined(DEFERRED_LIGHTING) && defined(SCREEN_AO) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#define LW_AO_SPATIAL
#endif

// One additional image: ring shape cache with in-image origin metadata.
#if CLOUD_DENSITY_CACHE == 1 && CLOUD_NOISE_MODE == 1 && defined(VOLUME_EFFECTS) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && !defined(LW_DIMENSION_NETHER) && !defined(LW_DIMENSION_END) && !defined(LW_IMAGE_BUDGET_FULL) && !(defined(LW_VOXEL_INCREMENTAL_ACTIVE) && VOXEL_FUSION != 1 && defined(PHYSICAL_ATMOSPHERE)) && !(defined(LW_VOXEL_INCREMENTAL_ACTIVE) && defined(PHYSICAL_ATMOSPHERE) && ATMO_PREBAKED != 1)
#define LW_CLOUD_CACHE_ACTIVE
#endif

// GI's half-size transient texture is free after deferred shading, provided
// no cross-frame raw GI reuse is requested. No additional color attachment.
#if VOLUME_RECONSTRUCTION == 1 && (PROJECTION_JITTER == 1 || AA_MODE < 2 || defined(LW_GEOMETRY_TAAU)) && defined(VOLUME_EFFECTS) && defined(DEFERRED_LIGHTING) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && !(defined(TEMPORAL_REUSE) && GI_REUSE_MODE == 2 && defined(SCREEN_GI) && defined(SCREEN_GI_SPATIAL) && defined(SCREEN_GI_HISTORY) && defined(LW_TAA_ACTIVE)) && !defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)
#define LW_CELESTIAL_VOLUME_SPATIAL
#endif
#if defined(LW_CELESTIAL_VOLUME_SPATIAL) && defined(LW_TAA_ACTIVE) && VOLUME_TEMPORAL == 1 && !defined(LW_IMAGE_BUDGET_FULL)
#define LW_VOLUME_TEMPORAL_ACTIVE
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
#if defined(AUTO_EXPOSURE) || DOF_MODE == 1 || DOF_MODE == 3 || (DOF_MODE != 0 && DOF_IDLE == 1)
#if defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && !(defined(INCREMENTAL_VOXELS) && defined(VOXEL_LIGHTING) && defined(IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE) && defined(IRIS_FEATURE_REVERSED_CULLING) && defined(PHYSICAL_ATMOSPHERE) && (VOXEL_FUSION != 1 || ATMO_PREBAKED != 1))
#define LW_CAMERA_STATE
#if DOF_MODE != 0 && DOF_IDLE == 1
#define LW_IDLE_FOCUS
#endif
#ifdef AUTO_EXPOSURE
#define LW_EXPOSURE_METER
#endif
#if DOF_MODE == 1 || DOF_MODE == 3
#define LW_AUTO_FOCUS
#endif
#endif
#endif
// Raw GI history owns colortex9 in specific dimensions. Never overwrite it.
#if defined(LW_MATERIAL_SSR_ACTIVE) && SSR_HALF_RES == 1 && defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && (PROJECTION_JITTER == 1 || AA_MODE < 2 || defined(LW_GEOMETRY_TAAU)) && !(defined(TEMPORAL_REUSE) && defined(SCREEN_GI) && defined(SCREEN_GI_SPATIAL) && defined(SCREEN_GI_HISTORY) && AA_MODE >= 2 && (GI_REUSE_MODE == 2 || (GI_REUSE_MODE == 1 && (defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)))))
#define LW_SSR_HALF
#endif
// colortex10 is transient except when the raw block GI trace is retained.
#if DOF_MODE != 0 && !(defined(TEMPORAL_REUSE) && defined(SCREEN_GI) && defined(SCREEN_GI_SPATIAL) && defined(SCREEN_GI_HISTORY) && defined(VOXEL_GI) && defined(DEFERRED_LIGHTING) && AA_MODE >= 2 && (PROJECTION_JITTER != 2 || defined(LW_GEOMETRY_TAAU)) && defined(VOXEL_LIGHTING) && defined(IRIS_FEATURE_CUSTOM_IMAGES) && defined(IRIS_FEATURE_COMPUTE_SHADERS) && defined(IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE) && defined(IRIS_FEATURE_REVERSED_CULLING) && (GI_REUSE_MODE == 2 || (GI_REUSE_MODE == 1 && (defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)))))
#define LW_DOF_HALF
#endif
#if defined(LW_VOXEL_INCREMENTAL_ACTIVE) && defined(IRIS_VERSION) && IRIS_VERSION >= 11107 && MC_VERSION >= 260100 && defined(IRIS_FEATURE_SSBO)
#define LW_GPU_COMPACTION
#endif
#endif
