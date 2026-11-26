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
