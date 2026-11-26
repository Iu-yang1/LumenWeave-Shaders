package io.lumenweave.renderer.client;

import io.lumenweave.renderer.core.*;
import org.lwjgl.opengl.GL45C;
import org.lwjgl.system.MemoryUtil;
import java.nio.IntBuffer;
import java.nio.ShortBuffer;
import java.util.Set;
import static org.lwjgl.opengl.GL45C.*;

/** Real persistent OpenGL seed upload probe. Its texture is not yet bound into Iris shaders. */
public final class OpenGlSeedAtlas implements RendererBackend {
    public record Difference(long differing,long referenceNonzero,long candidateNonzero){}
    private final int texture;
    private final ShortBuffer section=MemoryUtil.memCallocShort(4096);
    private long generation=-1;
    public OpenGlSeedAtlas(){
        texture=glCreateTextures(GL_TEXTURE_3D);
        glTextureStorage3D(texture,1,GL_R16UI,SeedAtlasLayout.SIDE,SeedAtlasLayout.SIDE,SeedAtlasLayout.SIDE);
        glTextureParameteri(texture,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTextureParameteri(texture,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        clear();
    }
    private void clear(){glClearTexImage(texture,0,GL_RED_INTEGER,GL_UNSIGNED_SHORT,(ShortBuffer)null);}
    public static int width(int texture){return glGetTextureLevelParameteri(texture,0,GL_TEXTURE_WIDTH);}
    @Override public Capabilities capabilities(){return new Capabilities(Api.OPENGL,Set.of(Feature.SECTION_SEEDS),0);}
    @Override public Receipt uploadSeeds(SectionStore.Delta d){
        if(generation!=d.generation()){clear();generation=d.generation();}
        if(!d.upserts().isEmpty()||!d.removals().isEmpty()){
            try(var unpack=new PixelTransfer(false)){
                // Deletes precede upserts; different resident sections never alias.
                for(var k:d.removals()){zero();upload(k);}
                for(var s:d.upserts()){
                    zero();
                    for(int e:s.entries())section.put(e&4095,(short)(e>>>12));
                    upload(s.key());
                }
            }
            glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT|GL_TEXTURE_FETCH_BARRIER_BIT|GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        }
        return new Receipt(d.generation(),d.epoch(),d.window(),d.complete(),false,false);
    }
    private void zero(){for(int i=0;i<4096;i++)section.put(i,(short)0);}
    private void upload(SectionStore.Key k){
        glTextureSubImage3D(texture,0,SeedAtlasLayout.sectionAddress(k.x()),SeedAtlasLayout.sectionAddress(k.y()),SeedAtlasLayout.sectionAddress(k.z()),
            16,16,16,GL_RED_INTEGER,GL_UNSIGNED_SHORT,section);
    }
    /** Diagnostic synchronous readback, not part of the performance path. */
    public Difference compare(int reference,SectionStore.Window w){
        int n=w.size(),s=SeedAtlasLayout.SIDE;
        IntBuffer original=MemoryUtil.memAllocInt(n*n*n);
        ShortBuffer candidate=MemoryUtil.memAllocShort(s*s*s);
        try(var pack=new PixelTransfer(true)){
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT|GL_TEXTURE_UPDATE_BARRIER_BIT);
            glGetTextureSubImage(reference,0,0,0,0,n,n,n,GL_RED_INTEGER,GL_UNSIGNED_INT,original);
            glGetTextureImage(texture,0,GL_RED_INTEGER,GL_UNSIGNED_SHORT,candidate);
            long diff=0,a=0,b=0;
            for(int z=0;z<n;z++)for(int y=0;y<n;y++)for(int x=0;x<n;x++){
                int u=original.get(x+n*(y+n*z));
                int v=Short.toUnsignedInt(candidate.get(SeedAtlasLayout.index(w.x()+x,w.y()+y,w.z()+z)));
                if(u!=v)diff++;if(u!=0)a++;if(v!=0)b++;
            }
            return new Difference(diff,a,b);
        }finally{MemoryUtil.memFree(original);MemoryUtil.memFree(candidate);}
    }
    @Override public void close(){glDeleteTextures(texture);MemoryUtil.memFree(section);}
    /** Preserve GL pixel-buffer and packing state around a native transfer. */
    private static final class PixelTransfer implements AutoCloseable {
        private final int target,binding;
        private final int[] names,values;
        PixelTransfer(boolean pack){
            target=pack?GL_PIXEL_PACK_BUFFER:GL_PIXEL_UNPACK_BUFFER;
            binding=glGetInteger(pack?GL_PIXEL_PACK_BUFFER_BINDING:GL_PIXEL_UNPACK_BUFFER_BINDING);
            names=pack?new int[]{GL_PACK_ALIGNMENT,GL_PACK_ROW_LENGTH,GL_PACK_IMAGE_HEIGHT,GL_PACK_SKIP_PIXELS,GL_PACK_SKIP_ROWS,GL_PACK_SKIP_IMAGES,GL_PACK_SWAP_BYTES}
                      :new int[]{GL_UNPACK_ALIGNMENT,GL_UNPACK_ROW_LENGTH,GL_UNPACK_IMAGE_HEIGHT,GL_UNPACK_SKIP_PIXELS,GL_UNPACK_SKIP_ROWS,GL_UNPACK_SKIP_IMAGES,GL_UNPACK_SWAP_BYTES};
            values=new int[names.length];glBindBuffer(target,0);
            for(int i=0;i<names.length;i++){values[i]=glGetInteger(names[i]);glPixelStorei(names[i],i==0?1:0);}
        }
        @Override public void close(){for(int i=0;i<names.length;i++)glPixelStorei(names[i],values[i]);glBindBuffer(target,binding);}
    }
}