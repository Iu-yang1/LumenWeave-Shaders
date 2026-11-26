package io.lumenweave.renderer.core;

import java.util.*;

/** Static depth pages in absolute light-space tile coordinates. Dynamic depth is per-frame. */
public final class ShadowTileCache {
    public record Tile(int level,int x,int y) {}
    public record Bounds(int level,int minX,int minY,int maxX,int maxY) {
        public boolean contains(Tile t){return t.level==level&&t.x>=minX&&t.x<=maxX&&t.y>=minY&&t.y<=maxY;}
    }
    // Exact bit representation of light orientation, scale, depth transform, clip convention.
    public record Basis(List<Integer> bits,long settingsEpoch) {
        public Basis{bits=List.copyOf(bits);}
    }
    public record Plan(long ticket,Set<Tile> keep,Set<Tile> drawStatic,Set<Tile> drawDynamic,Set<Tile> release) {
        public Plan{keep=Set.copyOf(keep);drawStatic=Set.copyOf(drawStatic);drawDynamic=Set.copyOf(drawDynamic);release=Set.copyOf(release);}
    }
    private final Set<Tile> valid=new HashSet<>();
    private Basis basis;
    private long ticket;
    private Plan pending;
    public Plan plan(Basis next,Set<Tile> required,Collection<Bounds> oldAndNewCasterBounds,Set<Tile> dynamic){
        // Invalidation is immediate even if a render fails or a frame is skipped.
        Set<Tile> release=new HashSet<>(valid);release.removeAll(required);
        if(!Objects.equals(basis,next)){valid.clear();basis=next;}
        valid.removeIf(t->oldAndNewCasterBounds.stream().anyMatch(b->b.contains(t)));
        valid.retainAll(required);
        Set<Tile> draw=new HashSet<>(required);draw.removeAll(valid);
        Set<Tile> moving=new HashSet<>(dynamic);moving.retainAll(required);
        pending=new Plan(++ticket,valid,draw,moving,release);
        return pending;
    }
    public void complete(long id,Set<Tile> rendered){
        if(pending==null||pending.ticket!=id) return;
        if(!pending.drawStatic.containsAll(rendered))throw new IllegalArgumentException("unplanned page");
        valid.addAll(rendered);pending=null;
    }
    public void invalidate(){valid.clear();basis=null;pending=null;ticket++;}
    public static Set<Tile> rectangle(int level,int x,int y,int width,int height){
        Set<Tile> out=new HashSet<>();
        for(int j=0;j<height;j++)for(int i=0;i<width;i++)out.add(new Tile(level,x+i,y+j));
        return out;
    }
    /** Conventional depth; reverse-Z backends must select max instead. */
    public static float combineDepth(float fixed,float moving,boolean reverseZ){
        return reverseZ?Math.max(fixed,moving):Math.min(fixed,moving);
    }
}
