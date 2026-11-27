package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import org.spongepowered.asm.mixin.*;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import java.util.Set;

/** Optional Iris integration; no change to framebuffer ownership or shader culling. */
@Pseudo
@Mixin(targets="net.irisshaders.iris.pipeline.IrisRenderingPipeline",remap=false)
public abstract class IrisPipelineMixin {
    @Shadow @Final private Set<?> customImages;
    @Inject(method="renderShadows",at=@At("HEAD"),require=0)
    private void lumenweave$beforeShadow(CallbackInfo ci){RendererExtension.beforeShadow(customImages);}
    @Inject(method="renderShadows",at=@At(value="INVOKE",target="Lnet/irisshaders/iris/pipeline/CompositeRenderer;renderAll()V"),require=0)
    private void lumenweave$afterShadow(CallbackInfo ci){RendererExtension.afterShadow(customImages);}
    @Inject(method="destroy",at=@At("HEAD"),require=0)
    private void lumenweave$destroy(CallbackInfo ci){RendererExtension.closeProbe();}
}
