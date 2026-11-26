# V5.3 synthetic voxel movement benchmark

Run: `python tools/voxel_motion_sim.py` (NumPy required; optional benchmark, not a runtime or unit-test dependency).

Executed in a local CPU container. 12 simulated frames per case, initial frame excluded from averages. Seed 927+N; approximately one synthetic emitter per 18,000 voxels; direct field uses a four-step Manhattan kernel, diffuse a five-step surrogate at N=128; edits add/remove one central emitter and add a wall. Scalar FP16 history model with 100 Hz time step and fixed decay. Dirty tiles are inferred from actual synthetic target changes and entry, then dilated one tile. This is not a port of all shader propagation, occupancy, RGB/alpha quantization or the actual Iris pipeline. The equality assertions compare skipped history with a full update **within this model**. Shader tests separately check overlapping old tiles and independent support flags. Work counts exclude metadata lookups, barriers, all other passes and GPU caches. No real FPS or GPU bandwidth claims.

| N | motion | baseline cells/frame | candidate cells/frame | reduction | model equality |
|---|---|---:|---:|---:|---|
| 32 | walk | 32768 | 9292 | 71.64% | exact |
| 32 | diagonal | 32768 | 20684 | 36.88% | exact |
| 32 | aligned | 32768 | 8192 | 75% | exact |
| 32 | edits | 1507 | 1507 | 0% | exact |
| 32 | static | 0 | 0 | n/a | exact |
| 96 | walk | 884736 | 127139 | 85.63% | exact |
| 96 | diagonal | 884736 | 308369 | 65.15% | exact |
| 96 | aligned | 884736 | 73728 | 91.67% | exact |
| 96 | edits | 1507 | 1507 | 0% | exact |
| 96 | static | 0 | 0 | n/a | exact |
| 128 | walk | 2097152 | 308433 | 85.29% | exact |
| 128 | diagonal | 2097152 | 694639 | 66.88% | exact |
| 128 | aligned | 2097152 | 131072 | 93.75% | exact |
| 128 | edits | 2397 | 2397 | 0% | exact |
| 128 | static | 0 | 0 | n/a | exact |

Stationary and edit-only results are controls: the prior stationary cache already skipped settled tiles, so no artificial gain is claimed. Moving history reuse needs 2N² extra RGBA16F texels (144 KiB at 96, 256 KiB at 128) and an unchanged dispatch grid. More complex densely lit worlds, active light changes, teleportation and initial frame can reduce or eliminate the gain. Real comparison needs matched GPU capture CSV via tools/gpu_pass_profile.py and actual game visual acceptance.
