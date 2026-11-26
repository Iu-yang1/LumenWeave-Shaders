package io.lumenweave.renderer.core;

import java.util.Arrays;
import java.util.Objects;
import java.util.function.Supplier;

/** Exact culling inputs only. A list is reusable only while the renderer owns its handles. */
public final class DrawListCache<T> {
    public record Key(long generation,long geometryEpoch,long ownershipEpoch,int distance,
                      long cameraX,long cameraY,long cameraZ,int[] projectionAndFrustumBits,
                      int flags) {
        public Key { projectionAndFrustumBits=projectionAndFrustumBits.clone(); }
        @Override public int[] projectionAndFrustumBits(){return projectionAndFrustumBits.clone();}
        @Override public boolean equals(Object object) {
            return object instanceof Key other&&generation==other.generation&&geometryEpoch==other.geometryEpoch
                &&ownershipEpoch==other.ownershipEpoch&&distance==other.distance&&cameraX==other.cameraX
                &&cameraY==other.cameraY&&cameraZ==other.cameraZ&&flags==other.flags
                &&Arrays.equals(projectionAndFrustumBits,other.projectionAndFrustumBits);
        }
        @Override public int hashCode(){return 31*Objects.hash(generation,geometryEpoch,ownershipEpoch,distance,cameraX,cameraY,cameraZ,flags)+Arrays.hashCode(projectionAndFrustumBits);}
    }
    private Key key;
    private T value;
    private long hits,misses;
    public T get(Key next,Supplier<T> build){
        if(next.equals(key)&&value!=null){hits++;return value;}
        misses++;T result=Objects.requireNonNull(build.get());key=next;value=result;return result;
    }
    public void invalidate(){key=null;value=null;}
    public long hits(){return hits;}
    public long misses(){return misses;}
}
