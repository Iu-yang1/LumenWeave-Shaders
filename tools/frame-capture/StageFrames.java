package lumenweave.bench;

import lumenweave.capture.runtime.GpuStageProfiler;
import java.io.IOException;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "net.irisshaders.iris.pipeline.IrisRenderingPipeline", remap = false)
public abstract class StageFrames {
    @Inject(method = "beginLevelRendering", at = @At("HEAD"), remap = false)
    private void lumenweave$begin(CallbackInfo callback) throws IOException {
        GpuStageProfiler.beginFrame();
    }

    @Inject(method = "finalizeLevelRendering", at = @At("RETURN"), remap = false)
    private void lumenweave$end(CallbackInfo callback) throws IOException {
        GpuStageProfiler.endFrame();
    }
}
