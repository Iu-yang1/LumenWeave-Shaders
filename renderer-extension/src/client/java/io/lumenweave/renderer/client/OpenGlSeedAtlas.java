package io.lumenweave.renderer.client;

import io.lumenweave.renderer.core.*;
import org.lwjgl.opengl.GL45C;
import org.lwjgl.system.MemoryUtil;
import java.nio.IntBuffer;
import java.nio.ShortBuffer;
import java.util.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import static org.lwjgl.opengl.GL45C.*;

/** Real persistent OpenGL seed upload probe. Its texture is not yet bound into Iris shaders. */
public final class OpenGlSeedAtlas implements RendererBackend {
    public record Difference(long differing,long referenceNonzero,long candidateNonzero){}
    private final int texture;
    private final ShortBuffer section=MemoryUtil.memCallocShort(4096);
    private long generation=-1;
    private final Map<SectionStore.Key,Long> bricks=new HashMap<>();
    private int brickBuffer,brickCount,materializeProgram;
    private boolean brickListDirty=true;
    public OpenGlSeedAtlas(){
        texture=glCreateTextures(GL_TEXTURE_3D);
        glTextureStorage3D(texture,1,GL_R16UI,SeedAtlasLayout.SIDE,SeedAtlasLayout.SIDE,SeedAtlasLayout.SIDE);
        glTextureParameteri(texture,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTextureParameteri(texture,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        clear();
    }
    private void clear(){glClearTexImage(texture,0,GL_RED_INTEGER,GL_UNSIGNED_SHORT,(ShortBuffer)null);}
    public static int width(int texture){return glGetTextureLevelParameteri(texture,0,GL_TEXTURE_WIDTH);}
    public static int depth(int texture){return glGetTextureLevelParameteri(texture,0,GL_TEXTURE_DEPTH);}
    @Override public Capabilities capabilities(){return new Capabilities(Api.OPENGL,Set.of(Feature.SECTION_SEEDS),0);}
    @Override public Receipt uploadSeeds(SectionStore.Delta d){
        if(generation!=d.generation()){clear();generation=d.generation();bricks.clear();brickListDirty=true;}
        if(!d.upserts().isEmpty()||!d.removals().isEmpty()){
            try(var unpack=new PixelTransfer(false)){
                // Deletes precede upserts; different resident sections never alias.
                for(var k:d.removals()){zero();upload(k);bricks.remove(k);}
                for(var s:d.upserts()){
                    zero();long occupied=0;
                    for(int e:s.entries()){
                        int i=e&4095;section.put(i,(short)(e>>>12));
                        int x=(i&15)>>2,y=((i>>4)&15)>>2,z=((i>>8)&15)>>2;
                        occupied|=1L<<(x+4*(y+4*z));
                    }
                    if(occupied==0)bricks.remove(s.key());else bricks.put(s.key(),occupied);
                    upload(s.key());
                }
                brickListDirty=true;
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
    private void prepareBrickList(){
        if(!brickListDirty)return;
        brickCount=bricks.values().stream().mapToInt(Long::bitCount).sum();
        IntBuffer list=MemoryUtil.memAllocInt(Math.max(4,brickCount*4));
        try{
            for(var entry:bricks.entrySet()){
                var k=entry.getKey();long bits=entry.getValue();
                while(bits!=0){
                    int i=Long.numberOfTrailingZeros(bits);bits&=bits-1;
                    list.put(k.x()*16+(i&3)*4).put(k.y()*16+((i>>2)&3)*4).put(k.z()*16+(i>>4)*4).put(0);
                }
            }
            if(brickCount==0)list.put(0).put(0).put(0).put(0);
            list.flip();
            if(brickBuffer==0)brickBuffer=glCreateBuffers();
            glNamedBufferData(brickBuffer,list,GL_DYNAMIC_DRAW);
            brickListDirty=false;
        }finally{MemoryUtil.memFree(list);}
    }
    private int program(){
        if(materializeProgram!=0)return materializeProgram;
        String source;
        try(var in=OpenGlSeedAtlas.class.getResourceAsStream("/lumenweave/materialize_external_seeds.comp")){
            if(in==null)throw new IllegalStateException("external seed kernel missing");
            source=new String(in.readAllBytes(),StandardCharsets.UTF_8);
        }catch(IOException e){throw new IllegalStateException(e);}
        int shader=glCreateShader(GL_COMPUTE_SHADER);
        try{
            glShaderSource(shader,source);glCompileShader(shader);
            if(glGetShaderi(shader,GL_COMPILE_STATUS)==0)throw new IllegalStateException(glGetShaderInfoLog(shader));
            int p=glCreateProgram();glAttachShader(p,shader);glLinkProgram(p);
            if(glGetProgrami(p,GL_LINK_STATUS)==0){String error=glGetProgramInfoLog(p);glDeleteProgram(p);throw new IllegalStateException(error);}
            materializeProgram=p;return p;
        }finally{glDeleteShader(shader);}
    }
    /** Materialize only nonempty 4³ world bricks into the current Iris observation. */
    public Receipt materialize(int occupancy,SectionStore.Delta d){
        var w=d.window();int n=w.size(),flag=n+(n+63)/64;
        if(!d.complete()||depth(occupancy)!=flag+1)
            return new Receipt(d.generation(),d.epoch(),w,false,false,false);
        int p=program();prepareBrickList();
        int oldProgram=glGetInteger(GL_CURRENT_PROGRAM);
        int oldGeneric=glGetInteger(GL_SHADER_STORAGE_BUFFER_BINDING),oldBuffer=glGetIntegeri(GL_SHADER_STORAGE_BUFFER_BINDING,0);
        long oldStart=glGetInteger64i(GL_SHADER_STORAGE_BUFFER_START,0),oldSize=glGetInteger64i(GL_SHADER_STORAGE_BUFFER_SIZE,0);
        int[][] images=new int[2][6];
        int[] names={GL_IMAGE_BINDING_NAME,GL_IMAGE_BINDING_LEVEL,GL_IMAGE_BINDING_LAYERED,GL_IMAGE_BINDING_LAYER,GL_IMAGE_BINDING_ACCESS,GL_IMAGE_BINDING_FORMAT};
        for(int i=0;i<2;i++)for(int j=0;j<names.length;j++)images[i][j]=glGetIntegeri(names[j],i);
        try{
            if(brickCount!=0){
                glUseProgram(p);glBindBufferBase(GL_SHADER_STORAGE_BUFFER,0,brickBuffer);
                glBindImageTexture(0,texture,0,true,0,GL_READ_ONLY,GL_R16UI);
                glBindImageTexture(1,occupancy,0,true,0,GL_READ_WRITE,GL_R32UI);
                glUniform3i(glGetUniformLocation(p,"gridOrigin"),w.x(),w.y(),w.z());
                glUniform1i(glGetUniformLocation(p,"gridSize"),n);
                glDispatchCompute(brickCount,1,1);
            }
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT|GL_TEXTURE_UPDATE_BARRIER_BIT);
            glClearTexSubImage(occupancy,0,0,0,flag,1,1,1,GL_RED_INTEGER,GL_UNSIGNED_INT,new int[]{1});
            glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT|GL_SHADER_IMAGE_ACCESS_BARRIER_BIT|GL_TEXTURE_FETCH_BARRIER_BIT);
            return new Receipt(d.generation(),d.epoch(),w,true,true,true);
        }catch(RuntimeException e){
            // The fallback must not inherit partial external seeds.
            glClearTexSubImage(occupancy,0,0,0,0,n,n,n,GL_RED_INTEGER,GL_UNSIGNED_INT,new int[]{0});
            glClearTexSubImage(occupancy,0,0,0,flag,1,1,1,GL_RED_INTEGER,GL_UNSIGNED_INT,new int[]{0});
            glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT|GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
            throw e;
        }finally{
            for(int i=0;i<2;i++){int[] v=images[i];glBindImageTexture(i,v[0],v[1],v[2]!=0,v[3],v[4]==0?GL_READ_ONLY:v[4],v[5]==0?GL_R32UI:v[5]);}
            if(oldBuffer!=0&&oldSize>0)glBindBufferRange(GL_SHADER_STORAGE_BUFFER,0,oldBuffer,oldStart,oldSize);
            else glBindBufferBase(GL_SHADER_STORAGE_BUFFER,0,oldBuffer);
            glBindBuffer(GL_SHADER_STORAGE_BUFFER,oldGeneric);glUseProgram(oldProgram);
        }
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
    @Override public void close(){glDeleteTextures(texture);MemoryUtil.memFree(section);if(brickBuffer!=0)glDeleteBuffers(brickBuffer);if(materializeProgram!=0)glDeleteProgram(materializeProgram);}
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