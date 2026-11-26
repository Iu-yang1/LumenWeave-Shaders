package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import net.minecraft.client.multiplayer.ClientLevel;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets="net.caffeinemc.mods.sodium.client.render.chunk.RenderSectionManager",remap=false)
public abstract class SodiumSectionMixin {
    @Shadow @Final private ClientLevel level;
    @Inject(method="onSectionAdded",at=@At("TAIL"))
    private void lumenweave$added(int x,int y,int z,CallbackInfo ci){RendererExtension.added(this,level,x,y,z);}
    @Inject(method="onSectionRemoved",at=@At("TAIL"))
    private void lumenweave$removed(int x,int y,int z,CallbackInfo ci){RendererExtension.removed(this,x,y,z);}
    @Inject(method="scheduleRebuild",at=@At("TAIL"))
    private void lumenweave$changed(int x,int y,int z,boolean playerChanged,CallbackInfo ci){RendererExtension.changed(this,x,y,z);}
    @Inject(method="destroy",at=@At("HEAD"))
    private void lumenweave$destroy(CallbackInfo ci){RendererExtension.destroy(this);}
}