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
