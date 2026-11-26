package io.lumenweave.renderer.core;

import java.util.*;

/** Joins world-space invalidation, physical page ownership and per-frame dynamic coverage. */
public final class ShadowFramePlanner {
    public record Caster(long id,ShadowTileCache.Bounds bounds,boolean dynamic,ShadowPageBackend.DrawCommand draw){}
    public record PageWork(ShadowTileCache.Tile tile,int slot,List<ShadowPageBackend.DrawCommand> staticDraws,
                           List<ShadowPageBackend.DrawCommand> dynamicDraws,boolean redrawStatic,boolean clearDynamic){
        public PageWork{staticDraws=List.copyOf(staticDraws);dynamicDraws=List.copyOf(dynamicDraws);}
    }
    public record Frame(long ticket,VirtualPages.Plan allocation,List<PageWork> work){
        public Frame{work=List.copyOf(work);}
    }
    private final VirtualPages pages;
    private final Map<ShadowTileCache.Tile,Long> revisions=new HashMap<>();
    private final Set<ShadowTileCache.Tile> priorDynamic=new HashSet<>();
    private ShadowTileCache.Basis basis;
    private long revision;
    private Frame pending;
    public ShadowFramePlanner(int capacity){pages=new VirtualPages(capacity);}
    public Frame plan(ShadowTileCache.Basis next,Map<ShadowTileCache.Tile,Integer> required,
                      Collection<ShadowTileCache.Bounds> oldAndNew,List<Caster> casters){
        if(!Objects.equals(basis,next)){pages.invalidate();revisions.clear();priorDynamic.clear();basis=next;}
        revisions.keySet().retainAll(required.keySet());
        List<VirtualPages.Request> requests=new ArrayList<>();
        for(var tile:required.keySet()){
            if(!revisions.containsKey(tile)||oldAndNew.stream().anyMatch(b->b.contains(tile)))
                revisions.put(tile,++revision);
            requests.add(new VirtualPages.Request(tile,required.get(tile),revisions.get(tile)));
        }
        var allocation=pages.plan(requests);
        // Bin by caster extent rather than comparing every caster with every page.
        Map<ShadowTileCache.Tile,List<ShadowPageBackend.DrawCommand>> fixed=new HashMap<>(),moving=new HashMap<>();
        // The visible page set is bounded. Clamp caster traversal to the active
        // page rectangle at each level before enumerating covered coordinates.
        Map<Integer,int[]> extents=new HashMap<>();
        for(var tile:allocation.table().keySet()){
            int[] e=extents.computeIfAbsent(tile.level(),k->new int[]{tile.x(),tile.y(),tile.x(),tile.y()});
            e[0]=Math.min(e[0],tile.x());e[1]=Math.min(e[1],tile.y());e[2]=Math.max(e[2],tile.x());e[3]=Math.max(e[3],tile.y());
        }
        for(Caster caster:casters){
            var b=caster.bounds;int[] e=extents.get(b.level());if(e==null)continue;
            // Sparse/disjoint clipmaps: choose the smaller iteration domain.
            int loX=Math.max(e[0],b.minX()),loY=Math.max(e[1],b.minY()),hiX=Math.min(e[2],b.maxX()),hiY=Math.min(e[3],b.maxY());
            if(hiX<loX||hiY<loY)continue;
            long area=((long)hiX-loX+1)*((long)hiY-loY+1);
            if(area>allocation.table().size()){
                for(var tile:allocation.table().keySet())if(b.contains(tile))bin(caster,tile,allocation,fixed,moving);
            }else{
                for(long y=loY;y<=hiY;y++)for(long x=loX;x<=hiX;x++){
                    var tile=new ShadowTileCache.Tile(b.level(),(int)x,(int)y);
                    if(allocation.table().containsKey(tile))bin(caster,tile,allocation,fixed,moving);
                }
            }
        }
        List<PageWork> work=new ArrayList<>();
        for(var entry:allocation.table().entrySet()){
            var tile=entry.getKey();boolean redraw=allocation.render().contains(tile);
            var dynamic=moving.getOrDefault(tile,List.of());
            // New/reassigned static page always clears its dynamic layer too.
            boolean clearDynamic=redraw||priorDynamic.contains(tile)||!dynamic.isEmpty();
            if(redraw||clearDynamic)work.add(new PageWork(tile,entry.getValue().slot(),fixed.getOrDefault(tile,List.of()),dynamic,redraw,clearDynamic));
        }
        priorDynamic.clear();priorDynamic.addAll(moving.keySet());
        return pending=new Frame(allocation.ticket(),allocation,work);
    }
    private static void bin(Caster caster,ShadowTileCache.Tile tile,VirtualPages.Plan p,
                            Map<ShadowTileCache.Tile,List<ShadowPageBackend.DrawCommand>> fixed,
                            Map<ShadowTileCache.Tile,List<ShadowPageBackend.DrawCommand>> moving){
        if(caster.dynamic||p.render().contains(tile))
            (caster.dynamic?moving:fixed).computeIfAbsent(tile,k->new ArrayList<>()).add(caster.draw);
    }
    /** Call only after raster submission completes in the same ordered GPU timeline. */
    public void complete(long ticket,Set<ShadowTileCache.Tile> staticRendered){
        if(pending==null||pending.ticket!=ticket)return;
        pages.complete(ticket,staticRendered);pending=null;
    }
}