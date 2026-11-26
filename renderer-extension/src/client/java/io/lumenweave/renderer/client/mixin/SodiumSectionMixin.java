package io.lumenweave.renderer.client.mixin;

import io.lumenweave.renderer.client.RendererExtension;
import net.minecraft.client.multiplayer.ClientLevel;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.Redirect;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
import net.caffeinemc.mods.sodium.client.render.chunk.tree.RemovableMultiForest;
import net.caffeinemc.mods.sodium.client.render.chunk.lists.CoordinateSectionVisitor;
import net.caffeinemc.mods.sodium.client.render.viewport.Viewport;
import it.unimi.dsi.fastutil.ints.IntArrayList;
import io.lumenweave.renderer.core.DrawListCache;
import io.lumenweave.renderer.client.ShadowTraversalSignature;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(targets="net.caffeinemc.mods.sodium.client.render.chunk.RenderSectionManager",remap=false)
public abstract class SodiumSectionMixin {
    @Shadow @Final private ClientLevel level;
    @Unique private final DrawListCache<int[]> lumenweave$traversal=new DrawListCache<>();
    @Unique private long lumenweave$geometryEpoch;
    @Unique private RemovableMultiForest lumenweave$forest;
    @Inject(method="onSectionAdded",at=@At("TAIL"))
    private void lumenweave$added(int x,int y,int z,CallbackInfo ci){lumenweave$geometryEpoch++;RendererExtension.added(this,level,x,y,z);}
    @Inject(method="onSectionRemoved",at=@At("TAIL"))
    private void lumenweave$removed(int x,int y,int z,CallbackInfo ci){lumenweave$geometryEpoch++;RendererExtension.removed(this,x,y,z);}
    @Inject(method="scheduleRebuild",at=@At("TAIL"))
    private void lumenweave$changed(int x,int y,int z,boolean playerChanged,CallbackInfo ci){RendererExtension.changed(this,x,y,z);}
    // Every uploaded section-info replacement may mutate the renderable forest.
    @Inject(method="updateSectionInfo",at=@At("RETURN"))
    private void lumenweave$updated(CallbackInfoReturnable<Integer> ci){lumenweave$geometryEpoch++;}
    @Redirect(method="renderOutOfGraph",at=@At(value="INVOKE",target="Lnet/caffeinemc/mods/sodium/client/render/chunk/tree/RemovableMultiForest;traverse(Lnet/caffeinemc/mods/sodium/client/render/chunk/lists/CoordinateSectionVisitor;Lnet/caffeinemc/mods/sodium/client/render/viewport/Viewport;F)V"))
    private void lumenweave$reuseTraversal(RemovableMultiForest forest,CoordinateSectionVisitor visitor,Viewport viewport,float distance){
        if(!Boolean.getBoolean("lumenweave.renderer.cacheShadowTraversal")){
            forest.traverse(visitor,viewport,distance);return;
        }
        var key=ShadowTraversalSignature.key(viewport,distance,lumenweave$geometryEpoch);
        if(key==null){forest.traverse(visitor,viewport,distance);return;}
        if(lumenweave$forest!=forest){lumenweave$traversal.invalidate();lumenweave$forest=forest;}
        boolean[] built={false};
        int[] coordinates=lumenweave$traversal.get(key,()->{
            built[0]=true;IntArrayList result=new IntArrayList();
            forest.traverse((x,y,z)->{result.add(x);result.add(y);result.add(z);visitor.visit(x,y,z);},viewport,distance);
            return result.toIntArray();
        });
        if(!built[0])for(int i=0;i<coordinates.length;i+=3)visitor.visit(coordinates[i],coordinates[i+1],coordinates[i+2]);
    }
    @Inject(method="destroy",at=@At("HEAD"))
    private void lumenweave$destroy(CallbackInfo ci){lumenweave$traversal.invalidate();lumenweave$forest=null;RendererExtension.destroy(this);}
}