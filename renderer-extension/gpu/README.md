# GPU virtual shadow page ABI (OpenGL reference, Vulkan-compatible layout)

All buffers use std430; uint = 32 bit. The host owns allocation, initialization and barriers.
- Selected bitset is the *budgeted* unique page set; compact requests via compact_shadow_requests.comp. Initialize page table slots and physical owners to 0xffffffff on reset. A page table record is uvec4(slot, revision, valid, reserved).
- Reset freeCount/cursor/drawCount/overflow each frame. Reclaim physical slots not in selected; storage barrier. Allocate only compacted unique selected requests, reuse revision-matched pages; invalid pages emit (id, slot, revision, ticket). If capacity is exceeded, leave pages invalid and use the reference visibility fallback.
- Rasterize pages with the required static geometry and fresh dynamic layer. Publish only successful static raster results using the matching frame ticket and ownership; never mark allocated pages valid before drawing. Reuse physical slots only after the previous submission's fence or on one ordered GPU queue.
- For indirect indexed drawing, command stride is 20 bytes (count, instanceCount, firstIndex, signed baseVertex, baseInstance). Header precedes commands at offset 16. baseInstance refers to a page-specific transform/metadata entry; host shader must consume it. Clamp draw count to capacity. GL_COMMAND_BARRIER_BIT | GL_SHADER_STORAGE_BARRIER_BIT before draw, and appropriate framebuffer/texture visibility barrier before sampling.
- Static/dynamic page depth is min for forward Z, max for reverse Z. Clear vanished dynamic casters every frame before sampling.

Vulkan implementation must negotiate storage/indirect features, allocate VkImages and image views, use vkCmdPipelineBarrier2 with matching stage/access masks, and timeline semaphore/fence ownership. Hardware RT is a distinct capability (VK_KHR_acceleration_structure, VK_KHR_ray_query or VK_KHR_ray_tracing_pipeline); mesh geometry, not voxel seeds alone, feeds BLAS/TLAS. These experiments do not implement or advertise a Vulkan device or hardware RT pipeline.

## Independent seed ABI 2

For a grid of width `N`, let `P=(N+63)/64`. The existing current seed prefix
occupies Z `[0,N)`; current tile support begins at `N`, and the frame flag
is at `(0,0,N+P)`. The persistent world-aligned seed ring occupies
`[N+P+1,2*N+P+1)`. Persistent tile support follows for `P` planes, giving total
depth `2*N+2*P+1`. No new custom image slot is used.

`patch_external_seeds.comp` writes deduplicated world-aligned 4³ bricks,
including zero values for removals. The CPU supplies the nonnegative residue
of the active window origin; bounded local coordinates avoid signed negative
remainder in GPU ring addressing. Persistent tile bits are `1=occupied`,
`2=needs support rebuild`. A window shift rebuilds all local tile support.
`publish_external_tiles.comp` publishes support into the current observation.
The host inserts image barriers and only then writes flag `2` with texture
update/image access visibility. The shader clears that flag at the beginning
of every frame and selects persistent seeds only after the matching receipt.

An incomplete frame never consumes pending dirty sections. Resource replacement,
material/world generation changes and incomplete updates retain rehydration or
fallback semantics. ABI 1 continues to publish flag `1` and current local seeds.
