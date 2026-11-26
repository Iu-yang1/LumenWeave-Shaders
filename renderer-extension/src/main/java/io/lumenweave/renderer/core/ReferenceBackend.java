package io.lumenweave.renderer.core;

import java.util.*;

/** CPU reference backend for regression and development telemetry, never a shader binding. */
public final class ReferenceBackend implements RendererBackend {
    private final Map<SectionStore.Key,SectionStore.Snapshot> data=new HashMap<>();
    private long generation=-1;
    @Override public Capabilities capabilities(){return new Capabilities(Api.REFERENCE,Set.of(Feature.SECTION_SEEDS),0);}
    @Override public Receipt uploadSeeds(SectionStore.Delta delta){
        if(generation!=delta.generation()){data.clear();generation=delta.generation();}
        delta.removals().forEach(data::remove);
        for(var s:delta.upserts())data.put(s.key(),s);
        return new Receipt(delta.generation(),delta.epoch(),delta.window(),delta.complete(),false,false);
    }
    public int residentSections(){return data.size();}
    @Override public void close(){data.clear();generation=-1;}
}
