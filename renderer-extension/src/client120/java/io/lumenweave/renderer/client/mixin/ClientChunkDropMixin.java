package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import net.minecraft.client.multiplayer.ClientChunkCache;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.ChunkPos;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ClientChunkCache.class)
public abstract class ClientChunkDropMixin {
    @Shadow @Final private ClientLevel level;

    @Inject(method = "drop", at = @At("HEAD"))
    private void lumenweave$drop(int chunkX, int chunkZ, CallbackInfo callback) {
        RendererExtension.chunkUnloaded(level, new ChunkPos(chunkX, chunkZ));
    }
}
