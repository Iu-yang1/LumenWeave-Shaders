# Rendering Efficiency V3

Baseline: 73e51790c7e87fb6c03d401b559bb47faa18d8a7 (all three CI workflows passed). Develop-only changes; public main remains unchanged.

## P0/P1
- P0-1/P61: original RG8 periodic gradient asset, 64 and 32 texel levels with explicit box prefilter and wrap gutters. No MakeUp textures copied. Rain rings use polynomial hash and skip zero envelope.
- P0-2: dielectric Snell window retained; microfacet normal faces the viewer, classify hits against the macro interface and use directional sky on misses. Native/DH depth visible only: cannot reconstruct geometry hidden from the camera. Above-water UV refraction remains approximate.
- P0-3/P68: wet material response on direct and indirect diffuse, wet puddle normals, reflection uses same ripple function; explicit weather program fades alpha with smoothed rain. Sky-light and procedural basins approximate precipitation/topography; vanilla particle spawn/stop remains game controlled.
- P0-4/P65: original propagation retained, world-space temporal field in second Z slab of lwVoxelFirst, metadata in two extra slices. Surface and air share field; wall reset immediate; newly entered regions initialized from current target; stationary black tiles skip only after proven zero history and target. Raw voxel GI bounce still derives from current field, not full independent smoothed bounce. No additional image slot; extra bytes=8*N*N*(N+2).
- P1-1/P67: 81 stratified samples, geometry-weighted log luminance, old exposure state used by both Bloom and final; solar state shares 1x1 RGBA32F. P1-2: separated near coverage and far disk with depth-aware reconstruction; hand depth exclusion remains approximate for translucent hand. P1-3: FOV-aware solar disk, cloud transfer alpha when available, current-frame occlusion clamps temporal glare.

## P60–P69
P60: colortex8 pure nonnegative opaque RGB becomes R11F_G11F_B10F; colortex11 uses it only when local scatter does not own alpha. Signed corrections, history and depth remain RGBA16F.
P62: rough SSR traces into transient half-resolution colortex9 after deferred1. Full-resolution mirror and uncovered receiver fallback; depth/normal/material compatibility; full-resolution history still valid. Disable only the half-res reuse path when raw GI history owns the attachment; retain full SSR. 
P63: shared projection, Hi-Z and depth coordinate contract for SSGI/SSR. Keep each tracing algorithm's distinct termination/visibility semantics.
P64: effect-level temporal reconstruction (P62 plus existing TAA history) is not full-scene TAAU. Full-scene render viewport scaling requires all native/hand/sky/DH/transparent geometry entry points, every depth/Hi-Z lookup, histories, weather and final camera coordinates to use a new paired render/output grid. See docs/taau-v1.md. Do not advertise full-scene upscaling until end-to-end Iris runtime proof.
P66: AO skips zero-weight donors before texture loads; existing exact fallback retained.
P67: unified exposure frame state and shared camera visibility; no new fullscreen exposure pass.
P68: wet/ripple/precipitation improvements above; material coverage and roof detection require further visual validation.
P69: cross-pack benchmark manifest/analysis tool, real game captures still required. 
No FPS figures inferred from resource size. Preserve all prior quality settings. macOS issue remains deferred by request.

Cross-pack benchmark: `python tools/shader_benchmark.py manifest.json --output comparison.json`. Manifest requires common GPU/CPU/driver/game/loader/resolution/FOV/resource-pack metadata; pinned pack ID/version/profile/SHA256; scenes with world seed, camera path, time, weather, dimension and comparison mode; three measured repeats with 300 warm-up and at least 300 GPU/presentation frames each, distinct screenshot and capture files. The tool reports per-pack timing percentiles and operator quality acceptance. No hardware results are shipped.

V4 follow-up: independent diffuse temporal slab, geometric rain columns and optional scene HDR composition scaling are integrated on the development branch. See docs/taau-v1.md for scope; full raster-grid port and runtime acceptance remain pending.

## V4 follow-up details
- Weather: vertical highest known opaque cell per local XZ column, capped by reversed-culling sphere; actual roof suppresses wetness. A surface at the column top uses four-neighbour elevation/drainage; unknown cells retain prior approximation. Columns use one additional slice and work with incremental voxels independently of SMOOTH_LIGHTING. This is not a world-wide heightmap or fluid solver; transparent/partial or unmapped blocks and roofs outside the cache remain limited.
- Diffuse: separate raw and smoothed `lwVoxelSecond` slabs, 0.16 s rise/0.28 s fall, world overlap validation, immediate wall reset, shared occupancy union and no additional image slot. 8*N^3 extra bytes when enabled. Direct smoothing and air scatter retain their existing field.
- TAAU: scene/volume composition and both existing volume compute grids operate at the optional reduced integer resolution, full-resolution depth/normal/DH/material-guided reconstruction before later post effects. Native geometry/deferred grids still full size. Default 100%.
- Validation: focused V4 GLSL mode plus full compile matrix, numerical tests, Iris directives, ZIP and aislop; no in-game GPU measurement or release claim until actual checks complete.

V5: actual geometry viewport, logical UV/active extent contract and native temporal resolve are integrated; see docs/taau-v1.md. Geometric rain, independent diffuse smoothing and direct/diffuse half-life controls are exposed in the options menu. Hardware/loader validation remains separate from static GLSL.
