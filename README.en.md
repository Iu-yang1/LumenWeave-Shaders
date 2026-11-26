# LumenWeave Shaders

[简体中文](README.md) · [Releases](https://github.com/Iu-yang1/LumenWeave-Shaders/releases) · [Issues](https://github.com/Iu-yang1/LumenWeave-Shaders/issues)

LumenWeave is a Minecraft Java Edition shader pack for Iris and OpenGL. It focuses on natural soft lighting, clear water, atmospheric skies and colored artificial lights that preserve dark surroundings. Quality settings range from a lightweight forward renderer to advanced hybrid deferred lighting.

## Gallery

<!-- Add actual in-game screenshots from screenshots/ -->
| Overworld — daylight and clouds | Overworld — water and sunset |
| :---: | :---: |
| Screenshot pending | Screenshot pending |
| Nether — lava and colored light | End — purple nebula |
| Screenshot pending | Screenshot pending |

## Features

- Natural daylight and night lighting, soft shadows, GTAO and HDR tone mapping.
- Physical atmosphere LUTs, volumetric clouds, light shafts and depth-aware reconstruction.
- Colored voxel lighting, local scattering, SSGI and material SSR on advanced presets.
- Multi-scale waves, depth-dependent water absorption and scattering, reflections and refraction.
- LabPBR, vegetation wind, TAA / FXAA, adjustable bloom and color.
- Distinct vanilla dimensions and optional Distant Horizons integration.
- Precomputed assets, incremental caches, adaptive sampling and temporal reuse.

## Installation

1. Install Iris and Sodium appropriate for your Minecraft version and mod loader.
2. Download the matching inner shader ZIP from [Releases](https://github.com/Iu-yang1/LumenWeave-Shaders/releases).
3. Place that ZIP in your instance's `shaderpacks` directory. Extract the All-Versions bundle first if using it.
4. Select LumenWeave in Options → Video Settings → Shader Packs.
5. Start with **High** and adjust quality for your GPU. Reselect a preset if upgrading from a development build.

## Quality presets

| Preset | Focus | Shadows / AA |
| --- | --- | --- |
| Potato | Lightweight / integrated graphics | No scene shadows / FXAA |
| Low | Basic lighting | 1024 hard / FXAA |
| Medium | Deferred lighting, AO, advanced water | 1024 hard / TAA + FXAA |
| High | Recommended everyday balance | 2048 soft / TAA + FXAA |
| Ultra | Physical atmosphere, volumes, SSGI, SSR, colored voxels | 2048 soft / TAA |
| Extreme | Largest default coverage and voxel diffuse GI | 4096 soft / TAA |


