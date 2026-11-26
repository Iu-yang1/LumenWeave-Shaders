package io.lumenweave.renderer.core;

import java.util.*;

/** Bounded physical page pool. Missing pages are explicit, never silently aliased. */
public final class VirtualPages {
    public record Request(ShadowTileCache.Tile tile,int priority,long revision) {}
    public record Mapping(int slot,long revision,boolean valid) {}
    public record Plan(long ticket,Map<ShadowTileCache.Tile,Mapping> table,
                       Set<ShadowTileCache.Tile> render,Set<ShadowTileCache.Tile> missing) {
        public Plan{table=Map.copyOf(table);render=Set.copyOf(render);missing=Set.copyOf(missing);}
    }
    private final int capacity;
    private final Map<ShadowTileCache.Tile,Mapping> pages=new HashMap<>();
    private long ticket;
    private Plan pending;
    public VirtualPages(int capacity){if(capacity<=0)throw new IllegalArgumentException("capacity");this.capacity=capacity;}
    public Plan plan(Collection<Request> requests){
        Map<ShadowTileCache.Tile,Request> unique=new HashMap<>();
        for(Request r:requests)unique.merge(r.tile,r,(a,b)->new Request(a.tile,Math.max(a.priority,b.priority),Math.max(a.revision,b.revision)));
        List<Request> sorted=new ArrayList<>(unique.values());
        sorted.sort(Comparator.comparingInt(Request::priority).reversed()
            .thenComparingInt(r->r.tile.level()).thenComparingInt(r->r.tile.x()).thenComparingInt(r->r.tile.y()));
        Set<ShadowTileCache.Tile> selected=new HashSet<>();
        for(int i=0;i<Math.min(capacity,sorted.size());i++)selected.add(sorted.get(i).tile);
        pages.keySet().retainAll(selected);
        BitSet used=new BitSet(capacity);pages.values().forEach(p->used.set(p.slot));
        Set<ShadowTileCache.Tile> render=new HashSet<>(),missing=new HashSet<>(unique.keySet());missing.removeAll(selected);
        for(Request r:sorted){
            if(!selected.contains(r.tile))continue;
            Mapping old=pages.get(r.tile);
            if(old==null){int slot=used.nextClearBit(0);used.set(slot);old=new Mapping(slot,r.revision,false);}
            if(old.revision!=r.revision)old=new Mapping(old.slot,r.revision,false);
            pages.put(r.tile,old);if(!old.valid)render.add(r.tile);
        }
        return pending=new Plan(++ticket,pages,render,missing);
    }
    public void complete(long id,Set<ShadowTileCache.Tile> rendered){
        if(pending==null||pending.ticket!=id)return;
        if(!pending.render.containsAll(rendered))throw new IllegalArgumentException("unplanned page");
        for(var tile:rendered){var p=pages.get(tile);pages.put(tile,new Mapping(p.slot,p.revision,true));}
        pending=null;
    }
    public void invalidate(){pages.clear();pending=null;ticket++;}
}
