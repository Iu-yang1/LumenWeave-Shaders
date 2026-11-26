# Natural Environment & Cinematic Rendering V1

Baseline: acf0596cde795733451fe0e59ae4efeed187f3c1. Player main remains unchanged until validation. macOS GL 4.1 remediation explicitly deferred.

## Design and acceptance
- Water: exact Fresnel, TIR remains physically correct, hit distance in Beer–Lambert, directional refraction with sky fallback; SSR cannot see off-screen geometry. Hybrid waves and rain rings with derivative fade.
- Weather: rain half-lives 20/40 ticks; wetness uses Iris built-in persistence; dielectric film and procedural flat puddle mask. Wet material SSR uses existing SSR when enabled (Ultra/Extreme by default). Skylight approximates rain exposure.
- Exposure: HDR weighted 7x7 log-luminance samples once per frame, asymmetric 0.42/1.25 s half-lives and bounded correction. Legacy image-budget configurations fall back to smoothed eye light. Fixed-exposure comparison presets retained. Reprojected terrain luminance adaptation uses TAA depth, normal, motion and hue rejection; does not time-ramp voxel propagation or emissive texels.
- Depth of field: optional automatic/manual/cinematic modes; signed CoC, depth rejection, half-resolution transient colortex10 except persistent GI configurations; smoothed center-depth and approximate hand exclusion. Solar glare: projected depth test once per fullscreen vertex, scene luminance proxy for clouds, optional ghosts/star.
- Performance: compare identical shader flags, resolution, scene, weather, FOV and GPU. P50/P53/P55/P56 candidates; P54/P57/P58/P59 require GPU A/B. Record 300 warm-up frames + 300 measured frames x3, median/p95/p99; wet forests, open water, underwater sky, torch placement/removal, dark-to-bright transitions, rain start/stop, sunrise, Nether/End, resize, teleport and reload. Full GLSL, Iris directives/parser regression, tests, ZIP and aislop required. No physical GPU signoff implied by CI.

References: pinned MakeUp 9.6a water.glsl and final_vertex.glsl; Iris custom uniforms, custom images, setup, centerDepthSmooth documentation (https://shaders.properties/); SEUS visual inspiration (https://www.sonicether.com/seus/).
