package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import net.minecraft.client.multiplayer.ClientChunkCache;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.ChunkPos;
import net.minecraft.world.level.chunk.LevelChunk;
import org.spongepowered.asm.mixin.*;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(ClientChunkCache.class)
public abstract class ClientChunkCacheMixin {
    @Shadow @Final private ClientLevel level;
    @Inject(method="replaceWithPacketData",at=@At("RETURN"))
    private void lumenweave$packet(CallbackInfoReturnable<LevelChunk> ci){RendererExtension.chunkLoaded(ci.getReturnValue());}
    @Inject(method="drop",at=@At("HEAD"))
    private void lumenweave$drop(ChunkPos pos,CallbackInfo ci){RendererExtension.chunkUnloaded(level,pos);}
}