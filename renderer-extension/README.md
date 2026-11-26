# LumenWeave Renderer Extension 0.1 alpha

Independent companion mod development branch. Existing shader packs continue to run unchanged.
Pinned first target: Minecraft 26.1.2, Java 25, Fabric Loader 0.19.3, Sodium 0.9.2. Iris 26.1 source contract (WorldRenderingSettings) is observed reflectively once per client tick. No Iris patch or fork is installed by this build.

## Implemented and boundaries
- Live Sodium section add/remove/rebuild event adapter, lazy scan of intersecting sections, exact material ID/light encoding, immutable versioned deltas and explicit deletion. Reference backend receives updates. Initial observation is player-centered, not a verified shader-visible camera volume; fully hidden blocks may differ from vertex producer semantics. No OpenGL injection or normal-culling switch is enabled.
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
For dependency-free core validation, JDK 21 or newer:
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
- `-Dlumenweave.renderer.seedProbe=true`: after Iris renders shadows and before prepare, use the real camera and grid width to update an external persistent R16UI 144³ OpenGL atlas. Dirty sections are uploaded as 16³ blocks; deletions clear the corresponding slot. A 144-block ring prevents aliases for nine overlapping sections in a 128-block unaligned window. Every 120 frames a synchronous diagnostic reads both textures and logs seed differences. This deliberately slows profiling; do not use it for FPS benchmarks. No shader handoff or culling switch has been enabled. Probe requires GL 4.5 DSA. No extra images are allocated in normal shader pack operation.
- Corrected ChunkStatus lookup to client getChunkNow; no forced chunk generation. All changes remain in the extension branch.

Alpha.3 adds direct client chunk packet replacement/unload and block-state change notifications, supplementing Sodium lifecycle events. The new backend gets a full resident snapshot after resource recreation rather than losing unchanged sections. The standalone Java regression remains a required Gradle check task; no JUnit framework is used.

## Native page resources and GPU-driven scheduling experiments

`ShadowFramePlanner` joins page requests, caster binning, static invalidation, per-frame dynamic draws and clearing previously occupied dynamic layers. The new `OpenGlShadowPages` allocates separate depth arrays and exposes private per-layer FBO attachments. No game framebuffer is mutated by this resource class. The backend-neutral `ShadowPageBackend` interface permits Vulkan image views and queue-specific submission in the future.

The isolated GLSL stages implement GPU reclaim, free-list allocation, revision invalidation, bounded draw page generation, completion publication, indirect indexed draw commands and diagnostic static/dynamic depth resolve. See [GPU ABI](gpu/README.md). They are compiled in CI but not yet wired to Iris's caster draw path. Current Iris opaque submission combines terrain layers; correct static/dynamic separation requires mesh/caster classification and actual layer-specific drawing, not a full-map copy that would leave moving geometry cached.

## Native OpenGL regression

CI uses a hidden GLFW context with Mesa llvmpipe (software GPU, not a game or performance benchmark) and executes `gpuSmokeTest`. It tests actual R16UI section uploads/deletion/recreation, depth-array FBO and forward/reverse clearing, real GPU compute request/reclaim/allocation/publication across page scrolling, revision and stale-ticket handling, and indirect-command ABI. Completion records are synthetic test fixtures, not proof of actual caster rasterization. This test is independent of the game desktop.
