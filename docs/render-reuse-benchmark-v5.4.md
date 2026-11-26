# V5.4 CPU proxy benchmark

Executed with Python in a local CPU container on 2026-11-26. Reproduce with `python tools/render_reuse_sim.py`. No NumPy required. These are synthetic work counts and simple numerical models, not shader execution, GPU timings, real FPS, rendered image quality metrics or a measured whole-frame comparison.

## Sparse history workgroup dispatch

Model: seeded 4% supported tiles, 25% of those pending, 1% independently dirty retained tiles plus all newly entered cells. The baseline launches every history workgroup even if it exits early. The candidate lists exactly the same update candidates in a simulated group reservation order; no duplicate or lost task. Classification overhead, seed scans, raw propagation, SSBO/command barriers and memory traffic are excluded.

| Grid | Motion in blocks | Baseline groups | Compact groups | Reduction |
|---|---|---:|---:|---:|
| 96³ | stationary | 13824 | 256 | 98.15% |
| 96³ | (1,0,0) | 13824 | 1666 | 87.95% |
| 96³ | (1,1,1) | 13824 | 4909 | 64.49% |
| 96³ | (4,0,0) | 13824 | 813 | 94.12% |
| 96³ | teleport | 13824 | 13824 | 0% |
| 128³ | stationary | 32768 | 632 | 98.07% |
| 128³ | (1,0,0) | 32768 | 3615 | 88.97% |
| 128³ | (1,1,1) | 32768 | 10941 | 66.61% |
| 128³ | (4,0,0) | 32768 | 1605 | 95.10% |
| 128³ | teleport | 32768 | 32768 | 0% |

Modern Iris uses a 393264-byte SSBO (three 16-byte headers and three 32768-entry uint arrays; +131088 bytes versus prior two-list layout). Legacy direct path still performs the same tile classifier. Zero work and complete rebuild both fit the indirect command and array limits.

## Screen-space model

- 20000 scalar history samples, explicit synthetic scene mix: 70% low motion, 80% opaque/native, 85% compatible depth/normal ownership. 6956 meet nearest donor color tolerance; color+metadata fetch count relative to an eight-fetch four-donor baseline goes from 160000 to 118264 (-26.09%). Mean relative difference from synthetic weighted donor reference 0.627%; maximum 3.193%. This excludes the old stationary shortcut, invalid donor optimizations and all current-frame samples/clipping. The shader's bound is relative to current RGB, not a guaranteed bound versus arbitrary reference history.
- 20000 synthetic donor-coverage values concentrated near low coverage (uniform cubed). GI four-ray reference retraces 25972 rays; two-ray fallback plus soft blend below 0.012 retraces 9188 (-64.62%). Analytic directional surrogate two-ray mean/max absolute difference 0.01012/0.02000 before blending, not a real indirect radiance error bound.
- Same coverage distribution, 70% rough surfaces, sharp surfaces keep 16 steps: SSR configured fallback-step count 225712 to 121328 (-46.25%). Hit refinement, early exits, Hi-Z traversal and prepass not counted. Reduced rough fallback can miss detail or long-range hits (8 steps uses the existing short-ray distance).
- 10000 synthetic 2D cloud rays with smooth analytic density: 8072 eligible for the translation interval/anchor gate before actual checkerboard, freshness and donor rounding gates. Accepted rays: max/mean one-frame transmission difference 0.003361/0.000294. No real noise, geometry occlusion raster, solar radiance or screen quantization; not an 80.72% cloud pass saving.
- 1000 scalar 9x9 patches: separable product Gaussian identity (81 vs 18 kernel taps) max absolute difference 1.11e-16. This identity is not a proof of variable-depth CoC filter equivalence. Actual reference Balanced uses up to 12 donor locations (excluding center); separable Balanced has two five-location half-resolution passes, second consumes embedded depth. Mip-assisted accepted path uses four depth probes + two HDR mip fetches; mip generation and additional pass costs must be measured.

## Runtime requirements and decisions

`APPROX_REUSE=1` on quality tiers, 0 on reference presets. `DOF_FILTER=0` remains disk default; 1 is mip-assisted, 2 separable, both experimental and only when colortex10 is transient. Current shadow, voxel grid and render scale presets unchanged. Exact depth, projection, medium, freshness and normal rejection retained for incompatible geometry; moving shafts always refreshed. Validate with actual matched Minecraft/Iris/DH GPU captures before changing camera-filter defaults or promising >100 FPS.
