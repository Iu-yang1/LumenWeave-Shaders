package io.lumenweave.renderer.client;

import io.lumenweave.renderer.core.*;
import net.fabricmc.api.ClientModInitializer;
import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.ChunkPos;
import org.joml.Vector3d;
import org.lwjgl.opengl.GL;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Map;

/** Initial live producer: observes Sodium section lifecycle, no mutation of Iris draws. */
public final class RendererExtension implements ClientModInitializer {
    private static final Logger LOG=LoggerFactory.getLogger("LumenWeaveRenderer");
    private static final SectionStore STORE=new SectionStore();
    private static final ReferenceBackend REFERENCE=new ReferenceBackend();
    private static Object owner;
    private static ClientLevel world;
    private static Map<?,?> materialIds;
    private static Field settingsField;
    private static Method materialMethod;
    private static long ticks;
    private static final boolean GPU_PROBE=Boolean.getBoolean("lumenweave.renderer.seedProbe");
    private static OpenGlSeedAtlas atlas;
    private static long probeFrames;
    private static Method cameraMethod;
    private static SectionStore.Delta latest;
    @Override public void onInitializeClient(){
        try{
            Class<?> settings=Class.forName("net.irisshaders.iris.shaderpack.materialmap.WorldRenderingSettings");
            settingsField=settings.getField("INSTANCE");
            materialMethod=settings.getMethod("getBlockStateIds");
            cameraMethod=Class.forName("net.irisshaders.iris.uniforms.CameraUniforms").getMethod("getUnshiftedCameraPosition");
        }catch(ReflectiveOperationException e){
            LOG.info("Iris material map unavailable; independent seed observation inactive");
        }
        LOG.info("LumenWeave Renderer Extension 0.1: observational section producer; Iris owns rendering");
    }
    public static void attach(Object manager,ClientLevel level){
        if(owner==manager)return;
        STORE.reset();REFERENCE.close();owner=manager;world=level;materialIds=null;latest=null;
    }
    // Packet replacement may replace data without creating a new Sodium section.
    public static void chunkLoaded(LevelChunk chunk){
        if(chunk==null||world==null||chunk.getLevel()!=world)return;
        var pos=chunk.getPos();
        for(int i=0;i<chunk.getSections().length;i++)
            STORE.added(new SectionStore.Key(pos.x,world.getSectionYFromSectionIndex(i),pos.z));
    }
    public static void chunkUnloaded(ClientLevel level,ChunkPos pos){
        if(world!=level)return;
        for(int y=level.getMinSectionY();y<=level.getMaxSectionY();y++)
            STORE.removed(new SectionStore.Key(pos.x,y,pos.z));
    }
    public static void blockChanged(Level level,BlockPos pos){
        if(world==level)STORE.changed(new SectionStore.Key(Math.floorDiv(pos.getX(),16),Math.floorDiv(pos.getY(),16),Math.floorDiv(pos.getZ(),16)));
    }
    public static void added(Object manager,ClientLevel level,int x,int y,int z){
        attach(manager,level);STORE.added(new SectionStore.Key(x,y,z));
    }
    public static void removed(Object manager,int x,int y,int z){
        if(owner==manager)STORE.removed(new SectionStore.Key(x,y,z));
    }
    public static void changed(Object manager,int x,int y,int z){
        if(owner==manager)STORE.changed(new SectionStore.Key(x,y,z));
    }
    public static void destroy(Object manager){
        if(owner==manager){STORE.reset();REFERENCE.close();owner=null;world=null;materialIds=null;latest=null;}
    }
    public static SectionStore.Delta latest(){return latest;}
    public static void tick(){
        Minecraft mc=Minecraft.getInstance();
        if(world==null||mc.level!=world||mc.player==null||materialMethod==null||GPU_PROBE)return;
        Map<?,?> ids;
        try{ids=(Map<?,?>)materialMethod.invoke(settingsField.get(null));}
        catch(ReflectiveOperationException e){LOG.warn("Iris material map read failed; producer disabled",e);materialMethod=null;return;}
        if(ids!=materialIds){materialIds=ids;STORE.invalidateMaterials();}
        if(ids==null)return;
        // Observation uses player-centered grid; a final shader handshake must
        // use Iris's actual camera position and active VOXEL_GRID_SIZE.
        var window=new SectionStore.Window(mc.player.getBlockX()-64,mc.player.getBlockY()-64,mc.player.getBlockZ()-64,128);
        latest=STORE.update(window,RendererExtension::snapshot);
        REFERENCE.uploadSeeds(latest);
        if(++ticks%200==0)LOG.info("Seed observation: resident={}, missing={}, upserts={}, epoch={}",
            latest.resident(),latest.missing().size(),latest.upserts().size(),latest.epoch());
    }
    // Called after Iris shadow production and before prepare. The optional
    // probe uses Iris camera coordinates and the real occupancy texture size.
    public static void afterShadow(Set<?> images){
        if(!GPU_PROBE||world==null||Minecraft.getInstance().level!=world||cameraMethod==null||materialMethod==null)return;
        if(!GL.getCapabilities().OpenGL45)return;
        try{
            int occupancy=0;
            for(Object image:images){
                if("lwVoxelOccupancy".equals(image.getClass().getMethod("getName").invoke(image))){
                    occupancy=(int)image.getClass().getMethod("getId").invoke(image);break;
                }
            }
            if(occupancy==0)return;
            int n=OpenGlSeedAtlas.width(occupancy);
            if(n!=32&&n!=64&&n!=96&&n!=128)return;
            Map<?,?> ids=(Map<?,?>)materialMethod.invoke(settingsField.get(null));
            if(ids==null)return;
            if(ids!=materialIds){materialIds=ids;STORE.invalidateMaterials();}
            Vector3d pos=(Vector3d)cameraMethod.invoke(null);
            var window=new SectionStore.Window((int)Math.floor(pos.x)-n/2,(int)Math.floor(pos.y)-n/2,(int)Math.floor(pos.z)-n/2,n);
            boolean newAtlas=atlas==null;
            if(newAtlas)atlas=new OpenGlSeedAtlas();
            latest=STORE.update(window,RendererExtension::snapshot);
            REFERENCE.uploadSeeds(latest);
            atlas.uploadSeeds(newAtlas?STORE.fullSnapshot():latest);
            if(++probeFrames%120==0){
                var diff=atlas.compare(occupancy,window);
                LOG.info("GPU seed probe: grid={}, complete={}, missing={}, differing={}, referenceNonzero={}, candidateNonzero={}",
                    n,latest.complete(),latest.missing().size(),diff.differing(),diff.referenceNonzero(),diff.candidateNonzero());
            }
        }catch(ReflectiveOperationException e){LOG.warn("Iris seed probe contract changed",e);cameraMethod=null;}
    }
    public static void closeProbe(){if(atlas!=null){atlas.close();atlas=null;}}
    private static int[] snapshot(SectionStore.Key key){
        var chunk=world.getChunkSource().getChunkNow(key.x(),key.z());
        if(chunk==null)return null;
        int index=world.getSectionIndexFromSectionY(key.y());
        var sections=chunk.getSections();
        if(index<0||index>=sections.length)return null;
        var section=sections[index];
        if(section.hasOnlyAir())return new int[0];
        int[] entries=new int[4096];int count=0;
        for(int z=0;z<16;z++)for(int y=0;y<16;y++)for(int x=0;x<16;x++){
            BlockState state=section.getBlockState(x,y,z);
            if(state.isAir())continue;
            Object id=materialIds.get(state);
            int seed=SectionStore.seed(id instanceof Number n?n.intValue():-1,state.getLightEmission());
            if(seed!=0)entries[count++]=SectionStore.entry(x,y,z,seed);
        }
        return Arrays.copyOf(entries,count);
    }
}