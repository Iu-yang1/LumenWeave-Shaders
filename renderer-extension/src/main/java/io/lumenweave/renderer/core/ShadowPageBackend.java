package io.lumenweave.renderer.core;

import java.util.List;

/** Device-owned static/dynamic depth targets. Vulkan implementations may use image views. */
public interface ShadowPageBackend extends AutoCloseable {
    enum Layer { STATIC, DYNAMIC }
    enum DepthConvention { FORWARD, REVERSE }
    record Target(int slot,Layer layer,int width,int height,long nativeHandle) {}
    record DrawCommand(int indexCount,int instanceCount,int firstIndex,int baseVertex,int baseInstance) {}
    record PageDraw(Target target,List<DrawCommand> commands,long geometryEpoch) {
        public PageDraw{commands=List.copyOf(commands);}
    }
    int capacity();
    int pageSize();
    Target target(int slot,Layer layer);
    /** Clear uses the backend's depth convention. Render state belongs to the caller. */
    void clear(Target target,DepthConvention convention);
    @Override void close();
}