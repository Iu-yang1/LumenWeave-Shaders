package io.lumenweave.renderer.core;

import java.util.*;

/** Render-thread owned section index. GPU-facing snapshots are immutable and versioned. */
public final class SectionStore {
    public record Key(int x, int y, int z) {}
    public record Window(int x, int y, int z, int size) {
        public Window { if (size <= 0 || size > 128) throw new IllegalArgumentException("size"); }
        public boolean contains(Key k) {
            return (long)k.x*16 < (long)x+size && (long)k.x*16+16 > x
                && (long)k.y*16 < (long)y+size && (long)k.y*16+16 > y
                && (long)k.z*16 < (long)z+size && (long)k.z*16+16 > z;
        }
    }
    public record Snapshot(Key key, long revision, int[] entries) {
        public Snapshot { entries = entries.clone(); }
        @Override public int[] entries() { return entries.clone(); }
    }
    public record Delta(long generation, long epoch, Window window, List<Snapshot> upserts,
                        Set<Key> removals, Set<Key> missing, int resident) {
        public Delta { upserts=List.copyOf(upserts); removals=Set.copyOf(removals); missing=Set.copyOf(missing); }
        public boolean complete() { return missing.isEmpty(); }
    }
    @FunctionalInterface public interface Source {
        /** Null means not available, not an empty section. Entries use index | seed<<12. */
        int[] read(Key key);
    }

    private final Set<Key> loaded = new HashSet<>();
    private final Set<Key> dirty = new HashSet<>();
    private final Map<Key,Snapshot> resident = new HashMap<>();
    private final Set<Key> removed = new HashSet<>();
    private Window previous;
    private Set<Key> lastMissing=Set.of();
    private boolean indexChanged=true;
    private Delta idle;
    private long generation=1, epoch;
    public void added(Key key) { loaded.add(key); dirty.add(key); indexChanged=true; }
    public void ensureLoaded(Key key) {
        if(loaded.add(key)){dirty.add(key);indexChanged=true;}
    }
    public void changed(Key key) {
        if(loaded.contains(key)){dirty.add(key);indexChanged=true;}
    }
    public void removed(Key key) {
        indexChanged=true;
        loaded.remove(key); dirty.remove(key);
        if(resident.remove(key)!=null) removed.add(key);
    }
    public void invalidateMaterials() { dirty.addAll(loaded); indexChanged=true; }
    public void reset() {
        loaded.clear(); dirty.clear(); resident.clear(); removed.clear();
        previous=null; lastMissing=Set.of(); generation++; epoch=0; indexChanged=true; idle=null;
    }
    public Delta update(Window window, Source source) {
        if(!indexChanged&&window.equals(previous)&&lastMissing.isEmpty())return idle;
        // Iterate only the 8-9 sections per axis intersecting the active volume,
        // not every loaded section and not every voxel on stationary frames.
        if(!window.equals(previous)) {
            for(var it=resident.keySet().iterator();it.hasNext();) {
                Key k=it.next(); if(!window.contains(k)){it.remove();removed.add(k);}
            }
        }
        Set<Key> missing=new HashSet<>();
        List<Snapshot> writes=new ArrayList<>();
        int loX=Math.floorDiv(window.x,16), hiX=Math.floorDiv(window.x+window.size-1,16);
        int loY=Math.floorDiv(window.y,16), hiY=Math.floorDiv(window.y+window.size-1,16);
        int loZ=Math.floorDiv(window.z,16), hiZ=Math.floorDiv(window.z+window.size-1,16);
        for(int z=loZ;z<=hiZ;z++) for(int y=loY;y<=hiY;y++) for(int x=loX;x<=hiX;x++) {
            Key k=new Key(x,y,z);
            if(!loaded.contains(k)){missing.add(k);continue;}
            Snapshot old=resident.get(k);
            if(old!=null&&!dirty.contains(k)) continue;
            int[] seed=source.read(k);
            if(seed==null){missing.add(k);if(resident.remove(k)!=null)removed.add(k);continue;}
            dirty.remove(k);
            if(old!=null&&Arrays.equals(old.entries,seed)) continue;
            Snapshot next=new Snapshot(k,++epoch,seed);
            resident.put(k,next);writes.add(next);
        }
        previous=window;lastMissing=Set.copyOf(missing);
        // A replacement wins over a pending deletion in the same transaction.
        for(Snapshot s:writes) removed.remove(s.key);
        if(!removed.isEmpty()) ++epoch;
        Delta delta=new Delta(generation,epoch,window,writes,removed,missing,resident.size());
        removed.clear();
        idle=new Delta(generation,epoch,window,List.of(),Set.of(),missing,resident.size());
        indexChanged=false;
        return delta;
    }
    /** Rehydrate a newly created backend without depending on the last incremental delta. */
    public Delta fullSnapshot(){
        if(previous==null)throw new IllegalStateException("no active window");
        return new Delta(generation,epoch,previous,new ArrayList<>(resident.values()),Set.of(),lastMissing,resident.size());
    }
    public static int seed(int materialId,int light) {
        int strength=Math.max(0,Math.min(15,light));
        if(strength>0) {
            int kind=materialId>=10011&&materialId<=10019?materialId-10010:
                materialId>=10024&&materialId<=10029?materialId-10014:0;
            return strength<<4|kind;
        }
        return materialId>=10020&&materialId<=10023?256|materialId-10020:0;
    }
    public static int entry(int x,int y,int z,int seed) {
        if((x|y|z)<0||x>15||y>15||z>15||seed<=0||seed>259) throw new IllegalArgumentException("entry");
        return x|(y<<4)|(z<<8)|(seed<<12);
    }
}
