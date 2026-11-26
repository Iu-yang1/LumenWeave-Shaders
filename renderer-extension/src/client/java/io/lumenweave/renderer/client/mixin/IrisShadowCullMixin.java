package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Pseudo;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyVariable;

/** Iris 26.1 createShadowFrustum has one boolean local: hasSafeZone. */
@Pseudo
@Mixin(targets="net.irisshaders.iris.shadows.ShadowRenderer",remap=false)
public abstract class IrisShadowCullMixin {
    @ModifyVariable(method="createShadowFrustum",at=@At("STORE"),ordinal=0,require=0)
    private boolean lumenweave$normalCulling(boolean safeZone){return RendererExtension.useNormalCulling(safeZone);}
}