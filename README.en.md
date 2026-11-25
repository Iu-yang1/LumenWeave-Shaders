# LumenWeave Shaders

[简体中文](README.md)

LumenWeave is a Minecraft Java shader pack for Iris/OpenGL. The P5 preview provides linear HDR lighting with Lite forward and Standard hybrid deferred paths across all three vanilla dimensions. Standard supports LabPBR and screen-space water. Six quality presets range from Potato to Extreme. Potato and Low use fast spatial anti-aliasing. Ultra and Extreme enable experimental lighting. The tested stack is Minecraft 1.21.1, Fabric Loader 0.16.5, Iris 1.8.8, Sodium 0.6.13, and Java 21.

Run `python tools/package.py` and place `dist/LumenWeave-Shaders-P5-Preview.zip` in the instance's `shaderpacks` folder. New installations default to High, with shadows, advanced water, and TAA enabled. Iris retains existing settings: select High or Extreme to test the full effects. Natural remains an early comparison preset without shadows. Use `python tools/package.py --p0` for the separate Neutral and Soft baseline pack.

Ultra and Extreme enable an optional temporal filter for the sky and sunlight bounce in screen-space GI. You can toggle it independently of temporal anti-aliasing in Shader Pack Settings.

Screen-space diffuse bounce requires deferred lighting. Voxel diffuse bounce also requires colored voxel light. Voxel grid size is independently selectable between 32³, 64³, 96³, and 128³. Ultra defaults to 96³ and Extreme to 128³. High selects 64³ while leaving colored voxel light disabled. The voxel path requires loader support for compute shaders, custom images, the block emission attribute, and reversed shadow culling.

Each voxel represents one block. Larger grids increase coverage around the camera; propagation remains four steps. The three voxel images together use 0.625, 5, 16.875, or 40 MiB, excluding shadow maps, screen buffers, and other cached dimensions. Disabling colored voxel light removes these image allocations.

The Nether and End share the material, local lighting, and temporal paths. The Nether retains biome fog colors and native fog distances; the End uses a violet ambient light. Dimension skylight metadata disables celestial direct light, highlights, sunlight shafts, and clouds where appropriate. Potato and Low retain vanilla block lighting, while Ultra and Extreme can use colored voxel lighting.

Distant Horizons has dedicated distant terrain and water passes. With deferred lighting and TAA enabled, terrain and water accumulate history separately, rejecting samples by depth, normal, and surface class. Water uses multiple wave scales filtered by pixel footprint, with sunlight highlights. Version 2.3.2-b completed background runtime checks on an RTX 4070 Laptop across near and far river views, dawn, night, rain, and thunder. Chunk loading and LOD transitions during sustained movement still need full visual acceptance.

Run `python tools/check_shaders.py` with `glslang` available, followed by `python -m unittest discover -s tests -v`. `python tools/package.py --voxel-probe` creates a separate compute experiment. It requires Iris compute shaders, custom images, and SSBOs. A green status stripe indicates that the synthetic scene passes its GPU checks.

## Automated and manual builds

The **Build shader packs** GitHub Actions workflow runs on pushes to `main` and pull requests targeting `main`. It checks configuration and locales, compiles GLSL offline, runs numerical and tooling tests, and packages three independent shader ZIPs. To start a build manually, open **Actions → Build shader packs → Run workflow**, select a branch, and run it.

After a successful run, download `LumenWeave-Shaders-P5-Preview` from **Artifacts**. Extract the downloaded artifact and copy the inner `LumenWeave-Shaders-P5-Preview.zip` intact into Minecraft's `shaderpacks` directory. The P0 baseline and voxel probe are separate artifacts. Artifacts are retained for 30 days.

Each pack includes a `.zip.sha256` checksum file. The run summary records the source commit and checksums; local packaging also generates checksum files. Iris compiles the shaders for the active GPU when loading the pack in-game. Actions performs offline compilation checks and builds installable ZIPs; it does not replace in-game GPU validation.

This remains a preview with incomplete compatibility and visual acceptance. Iris 1.8.8 with Distant Horizons 2.3.2-b has logged a startup combined-render-pass diagnostic whose first-frame impact is unresolved. First-frame behavior when returning to a cached dimension, sustained LOD transitions, and Intel/AMD hardware remain unverified.

The code is independently implemented and licensed under LGPL-3.0-only. See [third-party notices](THIRD_PARTY_NOTICES.md) for the upstream reference.
