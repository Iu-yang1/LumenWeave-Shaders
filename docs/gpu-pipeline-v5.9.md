# V5.9 GPU pipeline

The modern Iris capability gate now compacts seed-comparison bricks in
shadowcomp, after the existing shadow vertex producer. begin resets the
appended indirect header; prepare consumes its list. All bricks remain
scheduled on camera motion or invalid metadata. Empty stationary bricks
explicitly clear their dirty mask. Existing propagation/history indirect
headers remain at offsets 0, 16 and 32; seed header at 393264. Older
loaders keep the stationary empty-brick fast path.

Fused propagation uses R16UI source seeds (decode with original half
quantization) and R32UI stage 2: three 10-bit square-root companded RGB
channels in [0,2], plus exact four-state support. Final and historical
RGBA16F fields, trilinear filtering, physical grid size, propagation
radius, and non-fused mode are unchanged. RGB quantization has an
absolute error bound of approximately 0.002 before subsequent attenuation.
At 128^3 the two intermediates occupy 12 MiB rather than 32 MiB.

Post effects retain dependency order (motion blur, bloom, camera meter,
half-res depth of field, final resolve); donor distance and reciprocal,
ring and motion tap invariants are reused, not a fused full-resolution
pass. Hi-Z reuses ray invariants; water reuses phase/elapsed scaling.
No dynamic shadow cache, independent chunk geometry feed, or full HDR
tile fusion is implemented: these need loader geometry invalidation or a
verified attachment/flip and neighborhood exchange contract. GPU timing,
visual quality, and the driver/loader dispatch barrier need live testing.

## Stationary HDR ownership and subgroup injection

When HDR reuse and motion blur are enabled and the existing transform
predicate is exactly stationary, the fullscreen motion vertex pass clips
its quad. Bloom, exposure/solar meter, DOF, final color and solar visibility
read current colortex4 directly. Moving frames still write/read colortex0.
Mip-assisted DOF retains its original statically selected mip source.
The ARB shader ballot path suppresses only duplicate cell+seed keys
matching the first active vertex invocation; unsupported hardware uses
original atomics. No geometric assumption about quad indices is required.
Neither change alters the scene shadow draw or implements a cross-tile
motion/DOF fusion. Real loader flip behavior and GPU speed require testing.

## Tiled separable DOF

DOF_FILTER=2 on compute/custom-image-capable loaders now replaces the
horizontal and vertical raster passes with composite7. Each 8x16 output
tile caches the horizontal results plus the vertical donor halo, explicitly
round-tripped through half-float to match the old store/load boundary.
Far-out or edge donors retain the same horizontal function. The vertical
filter writes the existing colortex10 directly, with no extra image slots
or new full-resolution attachment. Legacy loaders retain composite5/6;
GI history ownership still excludes DOF half-buffer writes. This removes
one half-resolution global store/load boundary, but does not fuse moving
motion blur with DOF or guarantee a measured speed-up (halo recomputation
and texture-cache behavior need GPU tests). Disk and mip DOF are unchanged.

## Moving motion + disk DOF (experimental)
HDR_TILE_FUSION=1 uses composite1 compute for depth-only autofocus before the TAA raster pass, then composite2 compute for full-resolution motion and half-resolution disk DOF. The existing motion kernel is shared. Motion RGB is quantized to half before shared tile sampling, with bilinear reconstruction and exact immutable-source recomputation for cross-tile donors. Motion writes the current colortex0 for later Bloom, exposure and final optics; DOF writes current colortex10. composite2 raster is clipped and its flip disabled; composite5 is disabled. Stationary frames still bypass the HDR copy. History ownership, unsupported compute, other DOF modes and HDR_REUSE=0 retain the reference route. This is opt-in until live GPU timings justify enabling by default: extra cross-tile computation can outweigh saved traffic. The full-resolution motion result is still necessary for downstream effects.
The ARB ballot path is now language-version gated (450+); existing GLSL 330 wrappers use original atomics. This fixes the glslang 330 compile failure without raising the minimum GLSL version.
