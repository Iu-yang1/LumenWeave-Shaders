# v1.0.0 engineering review

Reviewed baseline `efaa8754022bd2b505f6d2fbe565bef90a07ecca`: all three CI workflows passed (GLSL matrix, 136 tests and three compatibility packages, aislop). User-reported P49 loader exception was fixed by explicit literal dispatch dimensions and covered in all compute entry points. Runtime confirmation of the corrected build is still outstanding.

| Module | Engineering decision / evidence | Remaining runtime scope |
| --- | --- | --- |
| Materials / PBR | Linear HDR, analytic GGX, LabPBR path, view Fresnel reuse; no speculative BRDF LUT. | Material pack variants, bright emissives |
| Shadow / DH | Receiver-plane PCSS, hybrid hardware compare only when compatible, bounded taps; Iris shadowtex0HW recognized. | Thin geometry, striping, DH transition |
| AO / SSGI | Half-size depth-aware reconstruction with exact fallback; fixed-grid history and separate per-dimension policy. | Moving occluders, camera cuts |
| Voxel | Feature-gated incremental ring, dirty propagation, half rounding in fused stages; legacy path retained. | Large translations, chunk edits, driver barriers |
| SSR / water | Screen-space tracing, depth/geometry validation, fallback environment; fade both correction terms in this release. Native waves default, periodic LUT experimental. | Offscreen reflection, water/DH edges |
| Atmosphere | Original precomputed tables plus change-driven sky/aerial LUT; do not read stale night table with zero weight. | Time jumps, sunrise and cache refresh |
| Clouds / shafts | Ring density basis, live weather, bounded ray steps, optical-depth approximation; fix horizontal slab rays. | Cloud-layer traversal, teleport, fine occluders |
| Local light / bloom | Separate emission, scattering and bloom, segmented integrals, HDR threshold. | Lava hue and contrast in dark scenes |
| End / Nether | Explicit dimension markers, End octahedral asset and analytic stars; no celestial work in Nether/End. | Dimension transitions and driver-specific rendering |
| Temporal / post | HDR ownership, no reuse of stale cloud history, depth/normal rejection, fixed projection for advanced presets. | Motion ghosting and dynamic projection |
| Presets / packaging | Six performance tiers and four comparison configs; consistent flags, optional features and resource limits, all version bundles. | Performance ordering depends on hardware/scene |

No claim that every hardware path is optimal or runtime-certified. Preserve all features and A/B controls; no arbitrary new restrictions. The source corrections in this review are layer intersection, night LUT access and symmetric SSR fade. Preset labels clarified, quality parameters unchanged. Release gates run GLSL validation, unit tests, package checks and aislop on the exact source before publication. Actual FPS and visual sign-off remain separate.

References: pinned Iris 1.21.1 loader, Photon `2a3d502c`, MakeUp reference in THIRD_PARTY_NOTICES, Hillaire 2020. No external code or assets imported in the release review.
