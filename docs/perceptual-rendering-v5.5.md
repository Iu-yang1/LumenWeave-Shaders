# Perceptual rendering V5.5 — 240 FPS target

All ten player profiles expose balanced perceptual controls; inactive effects do not incur new passes. No changes to existing render scale, voxel size, shadow resolution, or Fixed sampling. Presets maintain their feature differences. The default target is 4.1667 ms **whole-frame** interval, with a provisional 0.3 ms GPU headroom (3.8667 ms GPU p95). This is a test target, not a hardware-independent claim.

## Real capture calibration

Iris frameTime is whole-frame, not per-pass GPU measurement. Obtain matched captures with host OpenGL asynchronous timer queries (GL_TIME_ELAPSED / GL_TIMESTAMP) or external GPU profiling. No new Iris mod or in-game timer-query integration is included. Save normalized CSV columns `frame,pass,gpu_ms`. Every frame must have `__frame__` measured GPU total; optional `__present__` is measured frame/present interval in ms, not GPU time. Use disjoint pass groups for allocation, no nested/overlapping intervals. Same hardware, driver, loader, scene, resolution, render distance, warm-up, VSync/FPS cap disabled; include CPU-limited captures and real game frame intervals. Capture every preset separately and repeat. No real captures were supplied in this turn.

```
python tools/gpu_budget_plan.py baseline.csv --candidate balanced=balanced.csv --candidate fast=fast.csv --fps 240 --reserve-ms 0.3 --protect shadow
```

Planner allocates mean GPU budget proportionally to measured complete pass costs after protected/unattributed work. This is a requested reduction, not predicted speed. Rejects summed costs inconsistent with measured total; partial passes are not silently set to zero. Candidate selection uses actual recorded GPU p95 and optional whole-frame p95; only returns selected_verified if both pass. Supply candidates in quality preference order; the planner never extrapolates combinations.

## Algorithms and trade-offs

- PERCEPTUAL_GI=1: full update scheduled every other frame; 2 schedules every fourth. Otherwise geometry-validated prior GI is compared with a fresh opposed pair; discrepancy triggers complementary pair. Colored block contribution triggers refresh. This reduces second-pair frequency, never blindly freezes GI; the pair-average may differ from full-ray clipping, and unseen lighting changes may wait until the scheduled refresh. Existing mode-2 raw history reuse remains separate.
- LOW_FREQ_CACHE=1: ordered two-donor reconstruction when their combined bilinear coverage >=0.72 and depth, normal and sampled radiance agree. No new spatial texture or pass. The omitted donors are not inspected: rare high-contrast edge errors are possible.
- MULTIRATE_VOLUME=1/2: distant clouds use up to 25/50% fewer quadrature taps; weak shafts and far local scattering get a lower rate. Near clouds retain the original budget, and shafts still update current shadows. Changed quadrature positions can cause detail changes.
- SSR_FOOTPRINT=1/2: roughness, approximate projected block footprint and contribution set budget; near-mirror ceiling retained. The existing roughness/distance ceiling is retained, and the new footprint policy cannot increase steps versus V5.4. Sharp mirrors retain their previous budget. Reduced rough fallback from V5.4 remains.
- DIFFUSE_SH=1: real first-order axisymmetric SH is evaluated as folded constant and vertical coefficients. Exactly represents the existing affine sky/Nether/End diffuse environment; not a new dynamic directional SH probe volume, and no GPU speedup is claimed for this algebraic rewrite.

## Executed CPU proxy

`python tools/perceptual_sim.py` (Python standard library). 20,000 synthetic samples per mode, seeded 5501. These are not shader executions or actual GPU timings. Prior GI model includes random anisotropy, 80% geometry-compatible samples and 12% prior light changes. Spatial proxy assumes exact 2:1 footprint, 70% smooth samples. Cloud uses smooth analytic density, fixed 12-tap reference; SSR compares to the previous rough/distant adaptive ceiling, assuming projected footprints below 14 correspond to depth >36.

| metric | balanced | fast |
|---|---:|---:|
| GI rays vs four-ray reference | 65,758 / 80,000 (-17.80%) | 57,336 / 80,000 (-28.33%) |
| GI mean abs scalar error | .00173848 | .00283973 |
| GI max abs scalar error | .01466908 | .01493664 |
| cloud taps vs 12-tap reference | 198,227 / 240,000 (-17.41%) | 154,132 / 240,000 (-35.78%) |
| cloud mean transmission error | .00009506 | .00039028 |
| cloud max transmission error | .00086675 | .00341751 |
| SSR adaptive ceiling | see reproducible simulator | see reproducible simulator |

Spatial donor count 57,034 / 80,000 (-28.71%), mean absolute scalar error .00057267, max .05997907; not an arbitrary-scene error bound. SH affine equivalence 40,000 cases, max 2.22e-16 in CPU double precision. Synthetic planner tests verify overlap rejection, protected cost exceeding budget, and CPU-limited candidate rejection. Real GPU speedup, visual quality, and all-tier 240 FPS remain unverified.
