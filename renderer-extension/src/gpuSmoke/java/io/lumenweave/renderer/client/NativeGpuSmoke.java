package io.lumenweave.renderer.client;

import io.lumenweave.renderer.core.*;
import java.nio.IntBuffer;
import java.nio.FloatBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import org.lwjgl.opengl.GL;
import org.lwjgl.system.MemoryUtil;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL45C.*;

/** Real GPU API tests in a hidden GL context. Never starts or modifies Minecraft. */
public final class NativeGpuSmoke {
    private static final int INVALID=-1;
    static void check(boolean ok,String message){if(!ok)throw new AssertionError(message);}
    public static void main(String[] args)throws Exception{
        check(glfwInit(),"GLFW init");
        long window=0;
        try{
            glfwWindowHint(GLFW_VISIBLE,GLFW_FALSE);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR,4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR,5);
            glfwWindowHint(GLFW_OPENGL_PROFILE,GLFW_OPENGL_CORE_PROFILE);
            window=glfwCreateWindow(32,32,"LumenWeave GL smoke",0,0);
            check(window!=0,"GL context");
            glfwMakeContextCurrent(window);GL.createCapabilities();
            System.out.println("GL renderer: "+glGetString(GL_RENDERER)+"; version: "+glGetString(GL_VERSION));
            seedAtlas();depthPages();pagePipeline();indirect();
            check(glGetError()==GL_NO_ERROR,"GL error");
            System.out.println("Native GPU: seed atlas, depth pages, virtual page lifecycle and indirect draws passed");
        }finally{
            if(window!=0)glfwDestroyWindow(window);
            glfwTerminate();
        }
    }
    static void seedAtlas(){
        var store=new SectionStore();var w=new SectionStore.Window(-1,0,0,32);
        var key=new SectionStore.Key(-1,0,0);var k2=new SectionStore.Key(1,0,0);
        store.added(key);store.added(k2);
        var initial=store.update(w,k->k.equals(key)?new int[]{SectionStore.entry(15,0,0,255)}:new int[]{SectionStore.entry(0,0,0,259)});
        int ref=glCreateTextures(GL_TEXTURE_3D);glTextureStorage3D(ref,1,GL_R32UI,32,32,32);
        IntBuffer expected=MemoryUtil.memCallocInt(32*32*32);
        try(var atlas=new OpenGlSeedAtlas()){
            expected.put(0,255);expected.put(17,259);
            glTextureSubImage3D(ref,0,0,0,0,32,32,32,GL_RED_INTEGER,GL_UNSIGNED_INT,expected);
            atlas.uploadSeeds(initial);
            check(atlas.compare(ref,w).differing()==0,"initial seed atlas");
            store.removed(key);
            atlas.uploadSeeds(store.update(w,k->new int[0]));
            check(atlas.compare(ref,w).differing()==1,"explicit deletion");
            expected.put(0,0);glTextureSubImage3D(ref,0,0,0,0,32,32,32,GL_RED_INTEGER,GL_UNSIGNED_INT,expected);
            check(atlas.compare(ref,w).differing()==0,"deletion agrees");
            try(var rebuilt=new OpenGlSeedAtlas()){
                rebuilt.uploadSeeds(store.fullSnapshot());
                check(rebuilt.compare(ref,w).differing()==0,"resource rehydration");
            }
        }finally{MemoryUtil.memFree(expected);glDeleteTextures(ref);}
    }
    static void depthPages(){
        try(var pool=new OpenGlShadowPages(16,3)){
            var fixed=pool.target(1,ShadowPageBackend.Layer.STATIC);
            var moving=pool.target(1,ShadowPageBackend.Layer.DYNAMIC);
            pool.attach(fixed);pool.clear(fixed,ShadowPageBackend.DepthConvention.FORWARD);
            pool.attach(moving);pool.clear(moving,ShadowPageBackend.DepthConvention.REVERSE);
            FloatBuffer data=MemoryUtil.memAllocFloat(256);
            try{
                glGetTextureSubImage(pool.depthTexture(fixed.layer()),0,0,0,1,16,16,1,GL_DEPTH_COMPONENT,GL_FLOAT,data);
                for(int i=0;i<256;i++)check(data.get(i)==1.0f,"static depth clear");
                glGetTextureSubImage(pool.depthTexture(moving.layer()),0,0,0,1,16,16,1,GL_DEPTH_COMPONENT,GL_FLOAT,data);
                for(int i=0;i<256;i++)check(data.get(i)==0.0f,"dynamic reverse depth clear");
            }finally{MemoryUtil.memFree(data);}
        }
    }
    static int program(String file)throws Exception{
        int shader=glCreateShader(GL_COMPUTE_SHADER);
        glShaderSource(shader,Files.readString(Path.of("gpu",file)));
        glCompileShader(shader);check(glGetShaderi(shader,GL_COMPILE_STATUS)!=0,file+": "+glGetShaderInfoLog(shader));
        int program=glCreateProgram();glAttachShader(program,shader);glLinkProgram(program);
        check(glGetProgrami(program,GL_LINK_STATUS)!=0,file+": "+glGetProgramInfoLog(program));
        glDeleteShader(shader);return program;
    }
    static int buffer(int[] data){int b=glCreateBuffers();glNamedBufferData(b,data,GL_DYNAMIC_COPY);return b;}
    static int[] read(int buffer,int length){int[] data=new int[length];glGetNamedBufferSubData(buffer,0,data);return data;}
    static void bind(int... buffers){for(int i=0;i<buffers.length;i++)glBindBufferBase(GL_SHADER_STORAGE_BUFFER,i,buffers[i]);}
    static void uniform(int p,String name,int value){int location=glGetUniformLocation(p,name);check(location>=0,name);glProgramUniform1ui(p,location,value);}
    static void dispatch(int program,int groups){glUseProgram(program);glDispatchCompute(groups,1,1);glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT|GL_BUFFER_UPDATE_BARRIER_BIT|GL_COMMAND_BARRIER_BIT);}
    static void pagePipeline()throws Exception{
        int compact=program("compact_shadow_requests.comp"),reclaim=program("reclaim_shadow_pages.comp"),
            alloc=program("allocate_shadow_pages.comp"),publish=program("publish_shadow_pages.comp");
        int selected=buffer(new int[]{(1<<0)|(1<<2)|(1<<5)});
        int requests=buffer(new int[]{0,0,8,0,0,0,0,0,0,0,0,0});
        int owners=buffer(new int[]{INVALID,INVALID,INVALID});
        int[] tableInitial=new int[32];for(int i=0;i<8;i++)tableInitial[i*4]=INVALID;
        int table=buffer(tableInitial),free=buffer(new int[]{0,0,0,0,0});
        int[] rev=new int[8];Arrays.fill(rev,1);int revisions=buffer(rev);
        int draws=buffer(new int[]{0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0});
        int completed=buffer(new int[12]);
        try{
            bind(selected,requests);uniform(compact,"virtualPageCount",8);dispatch(compact,1);
            int[] req=read(requests,12);check(req[0]==3&&req[1]==0,"unique GPU request count");
            Set<Integer> ids=new HashSet<>();for(int i=0;i<req[0];i++)ids.add(req[4+i]);
            check(ids.equals(Set.of(0,2,5)),"GPU compact ids");
            bind(selected,owners,table,free);uniform(reclaim,"physicalCount",3);uniform(reclaim,"virtualCount",8);dispatch(reclaim,1);
            check(read(free,5)[0]==3,"GPU free list");
            bind(requests,owners,table,free,revisions,draws);uniform(alloc,"virtualCount",8);uniform(alloc,"frameTicket",1);dispatch(alloc,1);
            int[] d=read(draws,16),t=read(table,32);check(d[0]==3&&d[1]==0,"GPU allocations");
            Set<Integer> slots=new HashSet<>();
            for(int id:ids){check(t[id*4]>=0&&t[id*4]<3&&t[id*4+2]==0,"invalid until raster");slots.add(t[id*4]);}
            check(slots.size()==3,"physical slot uniqueness");
            // Simulated successful raster completion records. No actual caster
            // rasterization is claimed by this compute pipeline test.
            glNamedBufferSubData(completed,0,Arrays.copyOfRange(d,4,16));
            bind(completed,owners,table);uniform(publish,"completedCount",3);uniform(publish,"virtualCount",8);uniform(publish,"physicalCount",3);uniform(publish,"frameTicket",1);dispatch(publish,1);
            t=read(table,32);for(int id:ids)check(t[id*4+2]==1,"published");
            int keepSlot=t[2*4];
            glNamedBufferSubData(selected,0,new int[]{(1<<2)|(1<<5)|(1<<7)});
            glNamedBufferSubData(requests,0,new int[]{0,0,8,0});
            glNamedBufferSubData(free,0,new int[]{0,0});
            glNamedBufferSubData(draws,0,new int[]{0,0,3,0});
            rev[5]=2;glNamedBufferSubData(revisions,0,rev);
            bind(selected,requests);dispatch(compact,1);
            bind(selected,owners,table,free);dispatch(reclaim,1);
            bind(requests,owners,table,free,revisions,draws);uniform(alloc,"frameTicket",2);dispatch(alloc,1);
            t=read(table,32);d=read(draws,16);
            check(t[0]==INVALID&&t[2*4]==keepSlot&&t[2*4+2]==1,"scroll retention");
            check(t[5*4+1]==2&&t[5*4+2]==0&&t[7*4+2]==0&&d[0]==2,"revision and entering page");
            // Stale completion must not mark newly allocated pages valid.
            bind(completed,owners,table);uniform(publish,"frameTicket",2);dispatch(publish,1);
            t=read(table,32);check(t[5*4+2]==0&&t[7*4+2]==0,"stale GPU ticket");
        }finally{
            glUseProgram(0);for(int p:new int[]{compact,reclaim,alloc,publish})glDeleteProgram(p);
            for(int b:new int[]{selected,requests,owners,table,free,revisions,draws,completed})glDeleteBuffers(b);
        }
    }
    static void indirect()throws Exception{
        int p=program("shadow_indirect_draws.comp");
        int pairs=buffer(new int[]{0,0,7,1,1,0,8,0,2,1,9,1});
        int casters=buffer(new int[]{6,12,-3,0,9,24,5,0});
        int commands=buffer(new int[]{0,0,2,0,0,0,0,0,0,0,0,0,0,0});
        try{
            bind(pairs,casters,commands);uniform(p,"pairCount",3);uniform(p,"casterCount",2);dispatch(p,1);
            int[] c=read(commands,14);check(c[0]==2&&c[1]==0,"indirect count");
            Map<Integer,List<Integer>> actual=new HashMap<>();
            for(int i=0;i<2;i++){int o=4+i*5;actual.put(c[o+4],List.of(c[o],c[o+1],c[o+2],c[o+3]));}
            check(actual.equals(Map.of(7,List.of(6,1,12,-3),9,List.of(9,1,24,5))),"20-byte indirect ABI");
        }finally{glUseProgram(0);glDeleteProgram(p);glDeleteBuffers(pairs);glDeleteBuffers(casters);glDeleteBuffers(commands);}
    }
}