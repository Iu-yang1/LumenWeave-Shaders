# LumenWeave Renderer Extension 0.1 alpha.5

Independent companion mod development branch. Existing shader packs continue to run unchanged.
Version-specific artifacts share the section/page core and OpenGL implementation.

Alpha.5 reuses the immutable empty transaction for a stationary, complete voxel
window. Packet replacement, block edits, unloads, material changes, world resets
and camera movement invalidate it. Missing sections are retried even without a
new lifecycle event. The shader pack works without this mod; the experimental
bridge remains disabled by default and requires a complete per-frame handoff.

| Target | Minimum Java | Minimum Fabric Loader | Sodium contract |
| --- | --- | --- | --- |
| 1.20.1 | 17 | 0.16.5 | >=0.5.11, <0.6 |
| 1.21.1 | 21 | 0.16.5 | 0.6.13 series |
| 26.1.2 | 25 | 0.19.3 | 0.9.2 |

These are pinned anchors for the requested 1.20.x, 1.21.x and 26.x families.
Other patch versions require their own adapter/build/runtime checks; the
manifest deliberately describes the compiled target precisely. No Iris fork
is installed. Legacy adapters use vanilla packet/block changes and camera-window
bootstrap; the Sodium shadow-traversal cache remains specific to 26.1.2.

## Implemented and boundaries
- Live section packet/block events, version-specific unload adapters, camera-window bootstrap, immutable versioned deltas and explicit deletion. Sodium lifecycle/traversal integration remains specific to 26.1.2. The optional independent seed producer uses the actual Iris camera, uploads a persistent OpenGL atlas, and can hand off a complete window before shadows. Hidden blocks may differ from the original vertex producer.
- Exact-key draw-list cache generic implementation; no cancellation of Sodium traversal yet. Iris retains frame-stamped ChunkRenderList/TaskCollectingTree, so a retained list must be refreshed or proven independent of per-frame visibility and resource ownership.
- Static and dynamic shadow page planning, exact light-basis/geometry invalidation, integer tile scroll, partial completion/failed render semantics, depth composition reference. Not yet attached to Iris depth textures or real draw submission.
- Bounded virtual page allocator, priority dedup, missing pages, explicit completion; isolated GPU bitset compaction experiment. No GPU page rendering/indirect drawing yet.
- Backend-neutral API and optional hardware RT acceleration-structure/ray-dispatch contract. No native Vulkan device, interop, shader ray-tracing pipeline, or acceleration structure implementation.
- No shader preset changes and no automatic bypass. Reference backend explicitly cannot acknowledge shader visibility.

## Build
From this directory, use JDK 25 and Gradle 9.4.0:
```sh
gradle clean build coreRegression
```
Select an older target with `gradle -Ptarget=1.20.1 build coreRegression` or
`gradle -Ptarget=1.21.1 build coreRegression`. Outputs are separate under
`build/<target>/libs`, including remapped installable legacy JARs.
All three builds and regression tasks passed locally with JDK 25 and Gradle
9.8.0 on 2026-11-27. Compilation and game coverage are recorded separately below.

For dependency-free core validation, JDK 17 or newer:
```sh
mkdir -p /tmp/lw-core
javac -d /tmp/lw-core $(find src/main/java src/test/java -name '*.java')
java -cp /tmp/lw-core io.lumenweave.renderer.core.CoreRegression
```
The client adapter must be validated in the pinned game with Iris and Sodium. Compile success does not establish successful Mixin application or performance.

## Integration sequence
1. Prove complete section events, material mapping and coverage against actual shadow seed captures (hidden emitters, cutouts, modded material, full packet replacements, resource reload, dimension, DH).
2. Bind a persistent external seed resource to Iris with generation/epoch acknowledgment at prepare, exact camera grid, deletion and barriers. Only then permit normal culling.
3. Hook the Iris shadow list scope and Sodium fallback collector; preserve ownership/visibility stamps and invalidate on upload/removal/reload. Do not cache task lists blindly.
4. Allocate static/dynamic depth resources, attach selective raster submission and receiver comparison. Add old/new caster bounds and depth convention. Compare every frame to reference before enabling.
5. Connect GPU requests to page table, caster bins, draw commands and fallback sampling; add bounded budgets. Vulkan backend uses device feature negotiation, buffer ownership and explicit fences; RT consumes geometry payloads, not just voxel seeds.

## Alpha.2 live paths

- `-Dlumenweave.renderer.cacheShadowTraversal=true`: cache the ordered section coordinates returned by Sodium's RemovableMultiForest traversal, only for inspected Iris frustum classes and exact plane/box/quantized camera/distance/geometry-revision key. Every frame still visits the current FallbackVisibleChunkCollector, refreshes frame stamps and task lists, and retains original Iris draw submission. Unknown frusta use the original traversal. No stale GL handles are retained. This is an opt-in runtime test path, not a measured performance claim.
- `-Dlumenweave.renderer.seedProbe=true`: after Iris renders shadows and before prepare, update a persistent R16UI 144³ OpenGL atlas using the real camera and grid width. Dirty sections upload 16³ blocks; deletions clear their slots. Every 120 frames a synchronous diagnostic compares the original and independent textures. Run this separately from FPS capture. The probe itself does not activate a handoff.
- `-Dlumenweave.renderer.runtimeSmoke=true`: test automation only. Opens the isolated instance's `Demo_World`, dismisses screens after joining, logs the adapter and GL status, and stops after at least 200 ticks and 20 seconds. `runtimeSmokeFresh=true` creates a new timestamped test world on 26.1.2 using the game's world creation API. Keep both properties absent in normal play.
- Corrected ChunkStatus lookup to client getChunkNow; no forced chunk generation. All changes remain in the extension branch.

Alpha.3 adds direct client chunk packet replacement/unload and block-state change notifications, supplementing Sodium lifecycle events. The new backend gets a full resident snapshot after resource recreation rather than losing unchanged sections. The standalone Java regression remains a required Gradle check task; no JUnit framework is used.

## Native page resources and GPU-driven scheduling experiments

`ShadowFramePlanner` joins page requests, caster binning, static invalidation, per-frame dynamic draws and clearing previously occupied dynamic layers. The new `OpenGlShadowPages` allocates separate depth arrays and exposes private per-layer FBO attachments. No game framebuffer is mutated by this resource class. The backend-neutral `ShadowPageBackend` interface permits Vulkan image views and queue-specific submission in the future.

The isolated GLSL stages implement GPU reclaim, free-list allocation, revision invalidation, bounded draw page generation, completion publication, indirect indexed draw commands and diagnostic static/dynamic depth resolve. See [GPU ABI](gpu/README.md). They are compiled in CI but not yet wired to Iris's caster draw path. Current Iris opaque submission combines terrain layers; correct static/dynamic separation requires mesh/caster classification and actual layer-specific drawing, not a full-map copy that would leave moving geometry cached.

## Native OpenGL regression

CI uses a hidden GLFW context with Mesa llvmpipe (software GPU, not a game or performance benchmark) and executes `gpuSmokeTest`. It tests actual R16UI section uploads/deletion/recreation, depth-array FBO and forward/reverse clearing, real GPU compute request/reclaim/allocation/publication across page scrolling, revision and stale-ticket handling, and indirect-command ABI. Completion records are synthetic test fixtures, not proof of actual caster rasterization. This test is independent of the game desktop.

`gpuCompatSmokeTest` repeats this in a requested OpenGL 3.2 context. Feature
selection accepts core 4.5 or the required DSA, clear-texture, compute, SSBO
and image-load/store extensions. The RTX 4070 Laptop game context reports 3.2
while exposing these extensions; checking only `OpenGL45` incorrectly disabled
the bridge. Both hidden context variants passed on that adapter.

## Experimental independent seed handoff / normal culling

Use the shader pack from this branch, enable `EXTENSION_VOXELS=1` together with incremental voxel lighting, and launch the companion mod with `-Dlumenweave.renderer.independentSeeds=true`. No additional Iris custom image slot is required: one extra occupancy tail plane carries the per-frame handoff flag. The persistent external atlas produces a compact SSBO of nonempty world-aligned 4³ bricks; the compute shader writes current local occupancy and tile bits after begin but before shadow. Empty sections produce no workgroups. A complete, exact-window receipt publishes the flag, suppresses duplicate shadow vertex injection, and changes Iris SAFE_ZONE culling to ordinary advanced culling through the version-specific mixin. Missing sections, unsupported GL, absent mod or disabled option keep the original producer and culling. CPU material classification includes hidden blocks (unlike vertex-derived observations); the native smoke tests prove the transfer/flag ABI, not identical in-game lighting or successful Mixin application. Compare the two producers with seedProbe separately before accepting performance or visual quality. The depth page renderer still requires real caster/mesh attachment; no VSM path is enabled in the pack.

## Local game evidence, 2026-11-27

- 1.21.1 / Fabric 0.16.5 / Iris 1.8.8 / Sodium 0.6.13:
  isolated, muted world tests, 1920×1080 Extreme captures, three dimensions,
  underwater and rain readbacks, and motion-blur/DOF pipeline reloads.
  Independent handoff and ordinary shadow culling were observed in the log;
  a complete stationary window contained 648 sections with no missing entries.
  Distant Horizons 2.3.2-b with Fabric API 0.104.0 passed eight river-distance,
  time and weather views, including real LOD water depth samples.
- 1.20.1 uses Iris 1.7.6 with its declared Sodium dependency
  **0.5.12-beta.2**, not the incompatible 0.5.11 pairing. It joined a generated
  world and completed a 20-second runtime smoke with GL error zero.
- 26.1.2 / Fabric 0.19.3 / Iris 1.11.4 / Sodium 0.9.2 / Java 25:
  a world created through the game's API completed the same runtime smoke
  with GL error zero. This checks loading and ordinary rendering, not
  three-dimension quality, traversal-cache performance or all 26.x patches.
- Other patch versions within the three requested families remain unverified.
  A family name is not an assertion that every patch shares the same renderer API.

The final candidate measured about 178–179 FPS in the short Extreme 1080p
fixture with the active bridge (default geometry scale 85%). Native 100%
measured about 158 FPS. Disabling SSGI in the earlier baseline reached about
249 FPS as a bottleneck diagnostic;
this does not satisfy full Extreme quality. Independent seeds have not shown
a reliable FPS gain in this fixture. No 240 FPS acceptance is claimed.
