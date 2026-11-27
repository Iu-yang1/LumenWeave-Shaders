package io.lumenweave.renderer.core;

import java.util.*;

public final class SeedPatchPlan {
    public record Brick(int x,int y,int z) {}

    public static List<Brick> build(SectionStore.Window current,SectionStore.Window previous,
                                    Collection<SectionStore.Key> dirty){
        if(current.equals(previous)&&dirty.isEmpty())return List.of();
        var result=new LinkedHashSet<Brick>();
        int[] lower={current.x(),current.y(),current.z()};
        int size=current.size();
        if(previous==null||previous.size()!=size){
            add(result,current,lower,new int[]{lower[0]+size,lower[1]+size,lower[2]+size});
        }else{
            int[] old={previous.x(),previous.y(),previous.z()};
            for(int axis=0;axis<3;axis++){
                int[] start=lower.clone(),end={lower[0]+size,lower[1]+size,lower[2]+size};
                if(lower[axis]<old[axis]){
                    end[axis]=Math.min(end[axis],old[axis]);
                    add(result,current,start,end);
                }else if(lower[axis]>old[axis]){
                    start[axis]=Math.max(start[axis],old[axis]+size);
                    add(result,current,start,end);
                }
            }
            for(var key:dirty)
                add(result,current,new int[]{key.x()*16,key.y()*16,key.z()*16},
                    new int[]{key.x()*16+16,key.y()*16+16,key.z()*16+16});
        }
        return List.copyOf(result);
    }

    private static void add(Set<Brick> result,SectionStore.Window window,int[] lower,int[] upper){
        int[] origin={window.x(),window.y(),window.z()};
        for(int axis=0;axis<3;axis++){
            lower[axis]=Math.max(lower[axis],origin[axis]);
            upper[axis]=Math.min(upper[axis],origin[axis]+window.size());
            if(lower[axis]>=upper[axis])return;
        }
        for(int z=Math.floorDiv(lower[2],4)*4;z<upper[2];z+=4)
            for(int y=Math.floorDiv(lower[1],4)*4;y<upper[1];y+=4)
                for(int x=Math.floorDiv(lower[0],4)*4;x<upper[0];x+=4)
                    result.add(new Brick(x,y,z));
    }

    private SeedPatchPlan(){}
}
