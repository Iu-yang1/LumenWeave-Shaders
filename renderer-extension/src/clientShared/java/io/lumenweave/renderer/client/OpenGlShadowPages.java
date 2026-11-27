package io.lumenweave.renderer.client;

import io.lumenweave.renderer.core.ShadowPageBackend;
import static org.lwjgl.opengl.GL45C.*;

/** Native depth array resources. No Iris framebuffer mutation; caller owns raster state. */
public final class OpenGlShadowPages implements ShadowPageBackend {
    private final int capacity,size,staticDepth,dynamicDepth,framebuffer;
    public OpenGlShadowPages(int pageSize,int pages){
        if(pageSize<=0||pages<=0||pages>glGetInteger(GL_MAX_ARRAY_TEXTURE_LAYERS))throw new IllegalArgumentException("depth page dimensions");
        capacity=pages;size=pageSize;
        staticDepth=create();dynamicDepth=create();
        framebuffer=glCreateFramebuffers();
        glNamedFramebufferDrawBuffer(framebuffer,GL_NONE);
        glNamedFramebufferReadBuffer(framebuffer,GL_NONE);
    }
    private int create(){
        int id=glCreateTextures(GL_TEXTURE_2D_ARRAY);
        glTextureStorage3D(id,1,GL_DEPTH_COMPONENT32F,size,size,capacity);
        glTextureParameteri(id,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTextureParameteri(id,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        glTextureParameteri(id,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
        glTextureParameteri(id,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
        return id;
    }
    public int depthTexture(Layer layer){return layer==Layer.STATIC?staticDepth:dynamicDepth;}
    @Override public int capacity(){return capacity;}
    @Override public int pageSize(){return size;}
    @Override public Target target(int slot,Layer layer){
        if(slot<0||slot>=capacity)throw new IndexOutOfBoundsException(slot);
        return new Target(slot,layer,size,size,depthTexture(layer));
    }
    /** Attach a layer to the private FBO; caller sets viewport/depth state and restores Iris state. */
    public int attach(Target target){
        glNamedFramebufferTextureLayer(framebuffer,GL_DEPTH_ATTACHMENT,depthTexture(target.layer()),0,target.slot());
        if(glCheckNamedFramebufferStatus(framebuffer,GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)throw new IllegalStateException("shadow page framebuffer incomplete");
        return framebuffer;
    }
    @Override public void clear(Target target,DepthConvention convention){
        float value=convention==DepthConvention.REVERSE?0.0f:1.0f;
        // Texture clear is independent of current viewport/scissor/depth mask.
        glClearTexSubImage(depthTexture(target.layer()),0,0,0,target.slot(),size,size,1,GL_DEPTH_COMPONENT,GL_FLOAT,new float[]{value});
    }
    @Override public void close(){glDeleteFramebuffers(framebuffer);glDeleteTextures(staticDepth);glDeleteTextures(dynamicDepth);}
}
