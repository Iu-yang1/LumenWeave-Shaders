# P12 GPU active-tile compaction probe

Not part of the shipped shader pack. This prototype uses two compact active-tile lists from the existing radius-one and radius-two dirty masks (x offset 96). Each local group reserves one contiguous range per nonempty list, rather than issuing a global atomic for every active tile.

Host contract: allocate a 262176-byte std430 SSBO at binding 0. Dispatch reset (1,1,1), issue GL_SHADER_STORAGE_BARRIER_BIT, dispatch compact (ceil(tileCount/4), ceil(tileCount/4), ceil(tileCount/4)); the dirty image must already be visible via GL_SHADER_IMAGE_ACCESS_BARRIER_BIT. Then issue GL_SHADER_STORAGE_BARRIER_BIT | GL_COMMAND_BARRIER_BIT before binding the SSBO as GL_DISPATCH_INDIRECT_BUFFER and dispatching consume with byte offset 0 (radius 1) or 16 (radius 2). The output image must be cleared before each consume. Read back the visited mask after an image-access barrier and compare it to the original mask. A direct dispatch of tileCount^3 groups is a correctness fallback, not a dispatch-count reduction.

The inspected Iris 1.21.1 source branch's ComputeProgram dispatch barrier includes shader storage, image access and texture fetch but not GL_COMMAND_BARRIER_BIT; IrisRenderSystem.dispatchComputeIndirect directly calls OpenGL. The exact Iris 1.8.8 build has not been verified here. Shader memoryBarrierBuffer() is not a substitute for a host command-fetch barrier. Do not enable indirect dispatch in the production pack until the pinned loader and the zero/full/sparse queue GPU readbacks are verified. The production incremental path retains fixed dispatch and workgroup-coherent dirty-mask rejection.

No runtime GPU measurement or loader patch is claimed by this experiment.
