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
    private static final SeedPalette<BlockState> SEED_PALETTE=new SeedPalette<>(state->{
        if(state.isAir())return 0;
        Object id=materialIds.get(state);
        return SectionStore.seed(id instanceof Number number?number.intValue():-1,state.getLightEmission());
    });
    private static Field settingsField;
    private static Method materialMethod;
    private static long ticks;
    private static final boolean GPU_PROBE=Boolean.getBoolean("lumenweave.renderer.seedProbe");
    private static final boolean INDEPENDENT=Boolean.getBoolean("lumenweave.renderer.independentSeeds");
    private static final boolean OBSERVE=Boolean.getBoolean("lumenweave.renderer.observeSeeds");
    private static boolean externalActive;
    private static SectionStore.Window sectionWindow;
    private static boolean reportedNormalCull;
    private static OpenGlSeedAtlas atlas;
    private static long probeFrames;
    private static long handoffFrames;
    private static Method cameraMethod;
    private static SectionStore.Delta latest;
    private static Set<?> imageOwner;
    private static int occupancyTexture,occupancySize,occupancyDepth;
    @Override public void onInitializeClient(){
        try{
            Class<?> settings=Class.forName("net.irisshaders.iris.shaderpack.materialmap.WorldRenderingSettings");
            settingsField=settings.getField("INSTANCE");
            materialMethod=settings.getMethod("getBlockStateIds");
            cameraMethod=Class.forName("net.irisshaders.iris.uniforms.CameraUniforms").getMethod("getUnshiftedCameraPosition");
        }catch(ReflectiveOperationException e){
            LOG.info("Iris material map unavailable; independent seed observation inactive");
        }
        LOG.info("LumenWeave Renderer Extension 0.1: independentSeeds={}, seedProbe={}; Iris owns rendering",INDEPENDENT,GPU_PROBE);
    }
    public static void attach(Object manager,ClientLevel level){
        if(owner==manager&&world==level)return;
        if(world!=level)closeProbe();
        STORE.reset();REFERENCE.close();SEED_PALETTE.clear();owner=manager;world=level;materialIds=null;latest=null;sectionWindow=null;externalActive=false;
    }
    // Packet replacement may replace data without creating a new Sodium section.
    public static void chunkLoaded(LevelChunk chunk){
        if(chunk==null||world==null||chunk.getLevel()!=world)return;
        var pos=chunk.getPos();
        for(int i=0;i<chunk.getSections().length;i++)
            STORE.added(new SectionStore.Key(ClientPlatform.chunkX(pos),world.getSectionYFromSectionIndex(i),ClientPlatform.chunkZ(pos)));
    }
    public static void chunkUnloaded(ClientLevel level,ChunkPos pos){
        if(world!=level)return;
        for(int y=ClientPlatform.minSection(level);y<=ClientPlatform.maxSection(level);y++)
            STORE.removed(new SectionStore.Key(ClientPlatform.chunkX(pos),y,ClientPlatform.chunkZ(pos)));
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
        if(owner==manager){STORE.reset();REFERENCE.close();SEED_PALETTE.clear();owner=null;world=null;materialIds=null;latest=null;sectionWindow=null;externalActive=false;}
    }
    public static SectionStore.Delta latest(){return latest;}
    public static void tick(){
        Minecraft mc=Minecraft.getInstance();
        RuntimeSmoke.tick(mc);
        if(world!=mc.level){
            closeProbe();
            if(mc.level==null){
                STORE.reset();REFERENCE.close();SEED_PALETTE.clear();owner=null;world=null;materialIds=null;latest=null;sectionWindow=null;externalActive=false;
            }else attach(mc,mc.level);
        }
        if(!OBSERVE||world==null||mc.level!=world||mc.player==null||materialMethod==null||GPU_PROBE||INDEPENDENT)return;
        Map<?,?> ids;
        try{ids=(Map<?,?>)materialMethod.invoke(settingsField.get(null));}
        catch(ReflectiveOperationException e){LOG.warn("Iris material map read failed; producer disabled",e);materialMethod=null;return;}
        if(ids!=materialIds){materialIds=ids;SEED_PALETTE.clear();STORE.invalidateMaterials();}
        if(ids==null)return;
        // Observation uses player-centered grid; a final shader handshake must
        // use Iris's actual camera position and active VOXEL_GRID_SIZE.
        var window=new SectionStore.Window(mc.player.getBlockX()-64,mc.player.getBlockY()-64,mc.player.getBlockZ()-64,128);
        ensureWindowLoaded(window);
        latest=STORE.update(window,RendererExtension::snapshot);
        REFERENCE.uploadSeeds(latest);
        if(++ticks%200==0)LOG.info("Seed observation: resident={}, missing={}, upserts={}, epoch={}",
            latest.resident(),latest.missing().size(),latest.upserts().size(),latest.epoch());
    }
    public static boolean externalActive(){return externalActive;}
    public static boolean useNormalCulling(boolean safeZone){
        if(safeZone&&externalActive&&!reportedNormalCull){
            reportedNormalCull=true;LOG.info("Independent voxel handoff active; ordinary shadow frustum enabled");
        }
        return safeZone&&!externalActive;
    }
    private static int occupancy(Set<?> images)throws ReflectiveOperationException{
        if(imageOwner!=images){
            occupancyTexture=0;occupancySize=0;occupancyDepth=0;
            for(Object image:images)if("lwVoxelOccupancy".equals(image.getClass().getMethod("getName").invoke(image))){
                occupancyTexture=(int)image.getClass().getMethod("getId").invoke(image);
                occupancySize=OpenGlSeedAtlas.width(occupancyTexture);
                occupancyDepth=OpenGlSeedAtlas.depth(occupancyTexture);
                break;
            }
            imageOwner=images;
        }
        return occupancyTexture;
    }
    private static boolean ready(){
        return world!=null&&Minecraft.getInstance().level==world&&cameraMethod!=null&&materialMethod!=null&&OpenGlFeatures.seedBridge(GL.getCapabilities());
    }
    private static SectionStore.Window prepareAtlas(int n)throws ReflectiveOperationException{
        Map<?,?> ids=(Map<?,?>)materialMethod.invoke(settingsField.get(null));
        if(ids==null)return null;
        if(ids!=materialIds){materialIds=ids;SEED_PALETTE.clear();STORE.invalidateMaterials();}
        Vector3d pos=(Vector3d)cameraMethod.invoke(null);
        var w=new SectionStore.Window((int)Math.floor(pos.x)-n/2,(int)Math.floor(pos.y)-n/2,(int)Math.floor(pos.z)-n/2,n);
        ensureWindowLoaded(w);
        boolean newAtlas=atlas==null;
        if(newAtlas)atlas=new OpenGlSeedAtlas();
        latest=STORE.update(w,RendererExtension::snapshot);
        if(GPU_PROBE||OBSERVE)REFERENCE.uploadSeeds(latest);
        atlas.uploadSeeds(newAtlas?STORE.fullSnapshot():latest);
        return w;
    }
    private static void ensureWindowLoaded(SectionStore.Window w){
        int n=w.size();
        var aligned=new SectionStore.Window(Math.floorDiv(w.x(),16)*16,Math.floorDiv(w.y(),16)*16,Math.floorDiv(w.z(),16)*16,n);
        if(!aligned.equals(sectionWindow)){
            int x0=Math.floorDiv(w.x(),16),x1=Math.floorDiv(w.x()+n-1,16);
            int y0=Math.floorDiv(w.y(),16),y1=Math.floorDiv(w.y()+n-1,16);
            int z0=Math.floorDiv(w.z(),16),z1=Math.floorDiv(w.z()+n-1,16);
            // Include the next section at each boundary even for an aligned window.
            for(int z=z0;z<=Math.max(z1,z0+n/16);z++)for(int x=x0;x<=Math.max(x1,x0+n/16);x++){
                boolean loaded=world.getChunkSource().getChunkNow(x,z)!=null;
                for(int y=y0;y<=Math.max(y1,y0+n/16);y++)
                    if(loaded||y<ClientPlatform.minSection(world)||y>ClientPlatform.maxSection(world))STORE.ensureLoaded(new SectionStore.Key(x,y,z));
            }
            sectionWindow=aligned;
        }
    }
    // begin already cleared the previous observation and external flag.
    public static void beforeShadow(Set<?> images){
        externalActive=false;
        if(!INDEPENDENT)return;
        boolean report=++handoffFrames%240==0;
        if(!ready()){
            if(report)LOG.info("Independent seed readiness: world={}, current={}, camera={}, materials={}, gl45={}, dsa={}, version={}",
                world!=null,Minecraft.getInstance().level==world,cameraMethod!=null,materialMethod!=null,
                GL.getCapabilities().OpenGL45,GL.getCapabilities().GL_ARB_direct_state_access,
                org.lwjgl.opengl.GL11C.glGetString(org.lwjgl.opengl.GL11C.GL_VERSION));
            return;
        }
        try{
            int texture=occupancy(images);
            if(texture==0){
                if(report)LOG.info("Independent seed producer waiting for occupancy image");
                return;
            }
            int n=occupancySize;
            int depth=occupancyDepth;
            if((n!=32&&n!=64&&n!=96&&n!=128)||
                (depth!=n+(n+63)/64+1&&depth!=new IncrementalSeedLayout(n).depth())){
                if(report)LOG.info("Independent seed producer waiting for extension layout: width={}, depth={}",n,depth);
                return;
            }
            var window=prepareAtlas(n);
            if(report && window!=null)
                LOG.info("Independent seed window: resident={}, missing={}, epoch={}",
                    latest.resident(),latest.missing().size(),latest.epoch());
            if(window==null||!latest.complete())return;
            var receipt=depth==new IncrementalSeedLayout(n).depth()
                ?atlas.materializeIncremental(texture,latest):atlas.materialize(texture,latest);
            externalActive=RendererBackend.mayUseNormalCulling(latest,receipt,atlas.capabilities());
            if(report&&depth==new IncrementalSeedLayout(n).depth())
                LOG.info("Persistent seed handoff: active={}, patchedBricks={}, epoch={}",externalActive,atlas.lastPatchedBricks(),latest.epoch());
        }catch(ReflectiveOperationException|RuntimeException e){
            LOG.warn("External voxel handoff failed; original shadow producer retained",e);
        }
    }
    // The diagnostic compares independent seeds against original vertex output.
    public static void afterShadow(Set<?> images){
        if(!GPU_PROBE||externalActive||!ready())return;
        try{
            int texture=occupancy(images);
            if(texture==0)return;
            int n=occupancySize;
            if(n!=32&&n!=64&&n!=96&&n!=128)return;
            var window=prepareAtlas(n);
            if(window!=null&&++probeFrames%120==0){
                var diff=atlas.compare(texture,window);
                LOG.info("GPU seed probe: grid={}, complete={}, missing={}, differing={}, referenceNonzero={}, candidateNonzero={}",
                    n,latest.complete(),latest.missing().size(),diff.differing(),diff.referenceNonzero(),diff.candidateNonzero());
            }
        }catch(ReflectiveOperationException|RuntimeException e){LOG.warn("Iris seed probe failed",e);}
    }
    public static void closeProbe(){
        if(atlas!=null){atlas.close();atlas=null;}
        externalActive=false;sectionWindow=null;imageOwner=null;occupancyTexture=0;occupancySize=0;occupancyDepth=0;
    }
    private static int[] snapshot(SectionStore.Key key){
        if(key.y()<ClientPlatform.minSection(world)||key.y()>ClientPlatform.maxSection(world))return new int[0];
        var chunk=world.getChunkSource().getChunkNow(key.x(),key.z());
        if(chunk==null)return null;
        int index=world.getSectionIndexFromSectionY(key.y());
        var sections=chunk.getSections();
        if(index<0||index>=sections.length)return null;
        var section=sections[index];
        if(section.hasOnlyAir()||!section.maybeHas(state->SEED_PALETTE.seed(state)!=0))return new int[0];
        int[] entries=new int[4096];int count=0;
        for(int z=0;z<16;z++)for(int y=0;y<16;y++)for(int x=0;x<16;x++){
            BlockState state=section.getBlockState(x,y,z);
            if(state.isAir())continue;
            int seed=SEED_PALETTE.seed(state);
            if(seed!=0)entries[count++]=SectionStore.entry(x,y,z,seed);
        }
        return Arrays.copyOf(entries,count);
    }
}
