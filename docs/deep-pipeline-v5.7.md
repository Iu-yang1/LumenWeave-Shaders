# V5.7 bottom-up pipeline audit

User observations: Extreme ~150 FPS previously, ~125 with motion blur + DoF, Ultra ~170 in the same scene. Hardware, resolution, actual per-pass costs and scene composition not supplied. The observed gap is not a measured attribution. V5.6 full GLSL, compatibility and aislop passed.

## Confirmed structural work

- Motion blur previously disabled HDR_REUSE's direct resolve output. TAA wrote RGB twice (scene and history) even though motion blur overwrote scene next. LW_TAA_HISTORY_ONLY now selects two outputs 4,5, including display RGB for non-history pixels. Composite2 reads colortex4, writes colortex0, forces scene alpha to one rather than interpreting depth as opacity. Other post stages retain LW_TAA_DIRECT only when motion blur is off. Motion pass still exists. Vertex-stage exact transform equality bypasses fragment reprojection when stationary, including DH projection. Split camera coordinate subtraction preserves small motion far from the world origin.
- Motion samples now follow projected streak length, retaining the user-selected ceiling. Homogeneous depth inequality avoids per-tap division, DH donor ownership is explicit. Sample count change is approximate.
- GTAO uses double-angle identities and skips acos for fully open arcs. Stable surface ray normalization cancels algebraically in plane intersection and z anchoring; rare near-zero z retains normalized fallback.
- Soft shadow blocker/PCF receiver-plane coordinate math is hoisted from per-tap evaluation. Same configured tap count and receiver-plane comparisons, except possible FP rounding near depth equality.
- Extreme diffuse gather checks a new conservative radius-one tile wall support bit. Two-cell axial wall reach cannot leave this halo. Wall-free targets are exactly zero, explicitly written to clear old targets. Existing direct dirty/support bits retained; no new atlas. Separate two-stage OR reduction replaces up to 256 shared atomics per 64-lane history workgroup (direct/diffuse support and pending flags). One additional group barrier; speed may depend on hardware and contention.
- AO and volume spatial fallback use lower compatible coverage threshold under APPROX_REUSE; no cross-geometry donor acceptance added. Fresh distant cloud fallback uses 0.5 integration rate with existing minimum; weak shafts use reduced current shadow sampling, strong/near retain the prior ceiling. Possible low-confidence edge artifacts. DH shadow jitter applied only once. Water reuses original background reconstruction when refraction stays in one pixel.
- Balanced disk DoF introduces diagonal samples continuously from 0.6 to 2.0 px at 1080p under APPROX_REUSE; retains cardinal foreground taps and full quality ceiling. Native linear-depth reconstruction only evaluates z/w. Extreme Overworld has half-resolution DoF with GI_REUSE_MODE=1, Nether/End raw block GI can still own colortex10 and force native fallback; do not overwrite persistent GI.

## CPU proxy results (executed locally)

Run `python tools/deep_pipeline_sim.py`. Standard library, seed 5701/5702. Not shader execution or GPU benchmarking.

| check | result |
|---|---|
| 100000 GTAO arc cases | maximum abs error 1.851e-15; 49874 open arcs skip acos |
| 100000 homogeneous depth tests | zero classification differences |
| 59169 random valid wall reach cases | zero halo misses |
| synthetic 20000 coverage cases (uniform cubed) | fallback candidates 6570 -> 4607 (-29.88%) |
| motion 8-tap ceiling at .4,1,2,4,8,12,24 px | 2,2,3,4,7,8,8 taps |

Wall-free tile fraction for independent random wall tile probability 1%, 5%, 20%: N=96: 78.49%, 27.32%, 0.95%; N=128: 77.68%, 27.89%, 0.38%. These fractions are not the fraction of active diffuse tasks, nor actual terrain distribution. The benefit can be negligible in dense terrain.

One avoided RGBA16F output is 16.5888 MB at 1080p, 29.4912 MB at 1440p, 66.3552 MB at 4K per frame (logical write bytes only; actual GPU traffic depends on compression, cache and driver). No new full-screen pass.

## Remaining audit targets

Full dense seed scan is still N^3, irrespective of sparse propagation, because shadow vertex injection rebuilds occupancy each frame. Safe persistent dirty events need loader/mesh integration or a redesigned change stream. Shadow raster workload scales with 4096 map and larger range; shadow vertex injection also runs per vertex. Do not conflate map pixel count with GPU time. Full resolution temporal resolve, tone map, sharpening and motion blur remain proportional to output resolution. Real capture not requested this round; paired user tests with lens effects off/on, static and moving, and matched render settings are the next practical acceptance. All existing profile values unchanged. No actual 240 FPS claim.
