package io.lumenweave.renderer.core;

import java.nio.ByteBuffer;
import java.util.*;

/** Backend-neutral resource/transaction boundary; no GL object names escape into the core. */
public interface RendererBackend extends AutoCloseable {
    enum Api { REFERENCE, OPENGL, VULKAN }
    enum Feature { SECTION_SEEDS, SHADOW_DRAW_LIST, STATIC_SHADOW_PAGES, DYNAMIC_SHADOW_PAGES,
        INDIRECT_DRAW, VIRTUAL_SHADOW_MAPS, ACCELERATION_STRUCTURE, RAY_QUERY, RAY_PIPELINE }
    record Capabilities(Api api,Set<Feature> features,int maxPhysicalPages) {
        public Capabilities { features=Set.copyOf(features); }
        public boolean supports(Feature f){return features.contains(f);}
    }
    record Receipt(long generation,long epoch,SectionStore.Window window,boolean complete,
                   boolean visibleToShaders,boolean ownsGeometryContract) {}
    record GeometryUpdate(SectionStore.Key section,long revision,ByteBuffer vertices,ByteBuffer indices,
                          int vertexStride,int indexCount,boolean remove) {
        public GeometryUpdate {
            // Caller retains native buffer ownership until the backend fence completes.
            vertices=vertices.asReadOnlyBuffer();indices=indices.asReadOnlyBuffer();
        }
        @Override public ByteBuffer vertices(){return vertices.asReadOnlyBuffer();}
        @Override public ByteBuffer indices(){return indices.asReadOnlyBuffer();}
    }
    record Fence(long value) {}
    interface HardwareRayTracing {
        Fence updateAccelerationStructures(long generation,List<GeometryUpdate> updates);
        Fence trace(RayDispatch dispatch,Fence geometryReady);
    }
    record RayDispatch(int width,int height,int depth,long pipelineId,long descriptorSetId) {}
    Capabilities capabilities();
    Receipt uploadSeeds(SectionStore.Delta delta);
    default Optional<HardwareRayTracing> rayTracing(){return Optional.empty();}
    default Optional<ShadowPageBackend> shadowPages(){return Optional.empty();}
    // Normal culling is permitted only after the actual shader-visible independent producer
    // acknowledges complete coverage of this exact frame's grid. Reference models cannot ack it.
    static boolean mayUseNormalCulling(SectionStore.Delta delta,Receipt receipt,Capabilities caps){
        return caps.supports(Feature.SECTION_SEEDS)&&delta.complete()&&receipt.complete
            &&receipt.visibleToShaders&&receipt.ownsGeometryContract
            &&delta.generation()==receipt.generation&&delta.epoch()==receipt.epoch
            &&delta.window().equals(receipt.window);
    }
    void close();
}
