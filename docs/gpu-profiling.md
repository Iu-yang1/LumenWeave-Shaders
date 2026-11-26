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
