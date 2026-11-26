# LumenWeave Shaders

[Development roadmap and current progress (Chinese)](ROADMAP.md), updated 2026-11-26.

[简体中文](README.md)

LumenWeave is a Minecraft Java shader pack for Iris/OpenGL. The P5 preview provides linear HDR lighting with Lite forward and Standard hybrid deferred paths across all three vanilla dimensions. Standard supports LabPBR and screen-space water. Six quality presets range from Potato to Extreme. Potato and Low use fast spatial anti-aliasing. Ultra and Extreme enable experimental lighting. The tested stack is Minecraft 1.21.1, Fabric Loader 0.16.5, Iris 1.8.8, Sodium 0.6.13, and Java 21.

Run `python tools/package.py` and place `dist/LumenWeave-Shaders-P5-Preview.zip` in the instance's `shaderpacks` folder. New installations default to High, with shadows, advanced water, and TAA enabled. Iris retains existing settings: select High or Extreme to test the full effects. Natural remains an early comparison preset without shadows. Use `python tools/package.py --p0` for the separate Neutral and Soft baseline pack.

Ultra and Extreme enable an optional temporal filter for the sky and sunlight bounce in screen-space GI. You can toggle it independently of temporal anti-aliasing in Shader Pack Settings.

### Water, vegetation, and post processing

Water generates its own wave normals without multiplying vanilla water textures or inheriting vanilla water alpha. The deferred path uses depth-dependent absorption, scattering, Fresnel reflection, and refraction. Shallow water retains the bottom's detail; color changes with the optical path. The Lite path keeps depth-based absorption and alpha blending while avoiding screen-space reflection tracing. Underwater fog uses the same optical parameters. Glass retains its resource-pack texture and transparency.

Settings are grouped into Lighting, Atmosphere, Water, Vegetation, Post Processing, Performance, Advanced, and Debug. Water contains Surface, Optics, and Reflections; Post Processing contains Anti-aliasing, Color, Camera, and Bloom. Controls include biome tint contribution, density, turbidity, wave strength and speed, roughness, refraction, and reflection steps.

- Anti-aliasing offers Off, Fast Spatial, TAA, and TAA plus Spatial. TAA requires deferred lighting; selecting it on the forward path uses spatial anti-aliasing.
- Leaves, grass, flowers, and crops move with a shared gust field. Grass roots remain anchored, tall plants share seam displacement, and shadows use the same deformation. Leaf and grass animation can be toggled independently and fades at distance.
- Camera motion blur exposes shutter fraction and sample count, caps streak length, and rejects depth edges. It currently uses camera motion only, without independent entity motion vectors.
- HDR bloom uses a buffer at one quarter of each screen dimension, with strength and threshold controls. Sharpening, saturation, contrast, and white balance are independent. Motion blur, bloom, and sharpening default to off.

Potato and Low reduce wave layers, shadow filtering, and AO samples. Non-vegetation vertices skip wind calculations; water bypasses ordinary material shading. Compile-time branches and disabled passes remove work for effects that are off. HD 630 remains a target rather than verified hardware: runtime checks in this iteration use an RTX 4070 Laptop.

Dimension entry points live in `shaders/world0/`, `shaders/world-1/`, and `shaders/world1/`. Shared stages live in `shaders/programs/shared/`, while environment lighting lives in `shaders/lib/dimensions/`. The old `TEMPORAL_AA` and `SPATIAL_AA` settings are replaced by `AA_MODE`; select an anti-aliasing mode again after upgrading.

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

### Projection sampling and flicker compatibility

V2.2 runtime isolation identified dynamic projection jitter as a necessary trigger in the tested Ultra configuration: fixed pixel centers eliminated the flicker while TAA, volume effects, SSGI and voxel lighting stayed enabled. V2.3 separates projection sampling from AA. Auto uses fixed centers whenever volume effects, SSGI or voxel lighting are selected; Medium/High retain their dynamic sampling. Fixed mode retains history reprojection, rejection and temporal filtering, but not subpixel supersampling. Temporal + spatial AA is available for additional edge smoothing. Dynamic sampling remains selectable. Exact underlying interaction, Extreme fixed mode and the new build still require runtime validation.
