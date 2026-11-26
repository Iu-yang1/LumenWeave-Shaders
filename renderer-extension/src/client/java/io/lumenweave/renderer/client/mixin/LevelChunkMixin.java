package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.LevelChunk;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LevelChunk.class)
public abstract class LevelChunkMixin {
    @Inject(method="setBlockState",at=@At("RETURN"))
    private void lumenweave$state(BlockPos pos,BlockState state,int flags,CallbackInfoReturnable<BlockState> ci){
        if(ci.getReturnValue()!=null)RendererExtension.blockChanged(((LevelChunk)(Object)this).getLevel(),pos);
    }
}