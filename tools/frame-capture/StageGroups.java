package lumenweave.bench;

import lumenweave.capture.runtime.GpuStageProfiler;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets = "net.irisshaders.iris.gl.GLDebug", remap = false)
public abstract class StageGroups {
    @Inject(method = "pushGroup(ILjava/lang/String;)V", at = @At("HEAD"), remap = false)
    private static void lumenweave$begin(int id, String name, CallbackInfo callback) {
        GpuStageProfiler.begin(name);
    }

    @Inject(method = "popGroup()V", at = @At("HEAD"), remap = false)
    private static void lumenweave$end(CallbackInfo callback) {
        GpuStageProfiler.end();
    }
}
