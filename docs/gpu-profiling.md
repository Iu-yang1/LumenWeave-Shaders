# P24 — GPU profiling protocol

Use actual Minecraft + Iris + Sodium on the target GPU. Offline compilation,
software GL and shader invocation estimates are not frame-time measurements.
Use an isolated game instance/background desktop; mute master volume.
Record Minecraft/Iris/Sodium/DH versions, GPU/driver, resolution, render distance,
profile, shader commit, world seed, camera transform and weather/time. Disable
VSync and frame cap for throughput tests. Keep all parameters identical.

## A/B captures

1. Compare P18 (`2b73e0a`) and candidate in the same scenes: Overworld dense
   forest and reflective water, Nether lava/cave, End islands/sky. Capture
   both stationary (after warm-up) and moving camera. Warm up at least 300
   frames; record at least 300 frame times per run, repeat three runs.
2. For pass analysis, use RenderDoc (OpenGL) with Iris' documented debugger
   integration. Capture several representative frames; replay on the same GPU.
   Identify draw/dispatch event ranges by shader/program in the Event Browser.
   Export a per-capture mapping JSON (event IDs can differ between captures).
   Use disjoint ranges; keep unclassified events visible rather than assigning
   an invented pass. The exporter reads EventGPUDuration, actual GPU timestamps.
3. In a Python environment containing the matching RenderDoc replay module:
   `python tools/renderdoc_gpu_capture.py frame.rdc --map pass-map.json --frame 001 --output frame-001.csv`.
   Merge normalized CSV rows (one header). Then run
   `python tools/gpu_pass_profile.py candidate.csv --baseline baseline.csv`.
   Negative delta_ms is improvement. Missing passes remain unknown, not zero.
4. Timing counters measure replay event duration, not whole-frame latency;
   do not sum overlapping GPU work into a claimed FPS. Record actual frame
   times separately (PresentMon or equivalent). Only include actual measured
   memory read/write counters if available; otherwise leave columns blank.
5. Compare screenshot crops at near occluders, foliage, water and fog edges.
   Test block place/break, light toggles, camera rotation, resize, dimension
   switch and teleport. Compare defaults and each new option separately.

References:
- Iris graphics debugger integration: https://shaders.properties/current/reference/miscellaneous/debugging_shaders/
- RenderDoc v1.38 API counter definitions: https://github.com/baldurk/renderdoc/blob/v1.38/renderdoc/api/replay/replay_enums.h
- MakeUp developer notes: https://github.com/javiergcim/MakeUpUltraFast/blob/master/ForDevelopers.EN.md

No real Minecraft GPU capture has been obtained in the chat/CI environment.
The exporter is an integration tool, not evidence of measured performance.

For TEMPORAL_REUSE, include Iris final copy-back events in the A/B mapping (e.g. `history_copy`). The persistent half-resolution GI target adds a copy in Ultra and two in Extreme. This is a loader cost, not a zero-cost history reuse. For the disabled option the buffers revert to normal clear behavior.

## P32 per-dimension calibration

Each dimension exposes budget 0 (full), 1 (balanced default), 2 (performance, earlier far-only reductions). Keep the rest of Extreme unchanged. Collect comparable images and actual GPU whole-frame times (not sums of RenderDoc pass durations), plus at least three matched pass-counter frames per mode. Record three separate runs for manual repeatability; for the selector provide a representative comparable run of each tested mode. Mark quality accepted only after screenshot/motion comparison. Create a JSON manifest with GPU, driver, Minecraft, Iris, Sodium, resolution, shader_commit, profile and dimensions. Example shape (paths are placeholders, not actual captures):

```json
{"gpu":"actual GPU","driver":"actual driver","minecraft":"actual version","iris":"actual version","sodium":"actual version","resolution":"1920x1080","shader_commit":"actual SHA","profile":"Extreme","dimensions":{"overworld":{"scene":"fixed scene ID","runs":[{"mode":1,"scene":"fixed scene ID","source":"measured_gpu","quality_accepted":true,"frame_csv":"balanced-frames.csv","pass_csv":"balanced-passes.csv"},{"mode":2,"scene":"fixed scene ID","source":"measured_gpu","quality_accepted":true,"frame_csv":"performance-frames.csv","pass_csv":"performance-passes.csv"}]}}}
```

Run `python tools/dimension_budget.py manifest.json --target-gpu-ms 5 --output dimension-budget.json`. It chooses the highest quality accepted mode reaching the GPU p95 target; if none meets it, reports fastest measured approved mode and target_met=false. Unmeasured worlds are explicitly unknown. Apply recommended options in Performance > Dimension-specific budgets. Actual presentation FPS depends on CPU and frame pacing too; 5 ms GPU time does not itself establish 200 FPS. GLSL has no real per-pass timer query interface, so this is measured offline calibration, not a live automatic controller. No GPU captures available in CI.
