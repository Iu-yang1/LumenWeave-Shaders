package io.lumenweave.renderer.client;

import net.caffeinemc.mods.sodium.client.render.viewport.Viewport;
import io.lumenweave.renderer.core.DrawListCache;
import java.lang.reflect.Field;
import java.util.ArrayList;

/** Only the exact culling contracts inspected in Iris 26.1 are supported. */
public final class ShadowTraversalSignature {
    private static final String ROOT="net.irisshaders.iris.shadows.frustum.";
    private static final Field VIEW_FRUSTUM=field(Viewport.class,"frustum");
    private static Field field(Class<?> type,String name){
        try{Field f=type.getDeclaredField(name);f.setAccessible(true);return f;}
        catch(ReflectiveOperationException e){return null;}
    }
    private static Object value(Object owner,Class<?> type,String name)throws ReflectiveOperationException{
        Field f=field(type,name);if(f==null)throw new NoSuchFieldException(name);return f.get(owner);
    }
    private static void box(ArrayList<Integer> out,Object box)throws ReflectiveOperationException{
        if(box==null){out.add(0);return;}
        if(!box.getClass().getName().equals(ROOT+"BoxCuller"))throw new IllegalArgumentException("unknown box");
        long bits=Double.doubleToLongBits((double)value(box,box.getClass(),"maxDistance"));
        out.add(1);out.add((int)bits);out.add((int)(bits>>>32));
    }
    public static DrawListCache.Key key(Viewport viewport,float distance,long epoch){
        if(VIEW_FRUSTUM==null)return null;
        try{
            Object frustum=VIEW_FRUSTUM.get(viewport);Class<?> type=frustum.getClass();String name=type.getName();
            ArrayList<Integer> bits=new ArrayList<>();
            if(name.equals(ROOT+"fallback.NonCullingFrustum"))bits.add(1);
            else if(name.equals(ROOT+"fallback.BoxCullingFrustum")){
                bits.add(2);box(bits,value(frustum,type,"boxCuller"));
            }else if(name.equals(ROOT+"advanced.AdvancedShadowCullingFrustum")||name.equals(ROOT+"advanced.SafeZoneCullingFrustum")){
                boolean safe=name.endsWith("SafeZoneCullingFrustum");bits.add(safe?4:3);
                Class<?> parent=safe?type.getSuperclass():type;
                int count=(int)value(frustum,parent,"planeCount");
                float[][] planes=(float[][])value(frustum,parent,"planes");
                bits.add(count);
                for(int i=0;i<count;i++)for(float v:planes[i])bits.add(Float.floatToRawIntBits(v));
                box(bits,value(frustum,parent,"boxCuller"));
                if(safe)box(bits,value(frustum,type,"distanceCuller"));
            }else return null;
            var t=viewport.getTransform();
            // Traversal uses these quantized components, not the unrounded camera.
            bits.add(t.intX);bits.add(t.intY);bits.add(t.intZ);
            bits.add(Float.floatToRawIntBits(t.fracX));bits.add(Float.floatToRawIntBits(t.fracY));bits.add(Float.floatToRawIntBits(t.fracZ));
            return new DrawListCache.Key(0,epoch,0,Float.floatToRawIntBits(distance),0,0,0,bits.stream().mapToInt(Integer::intValue).toArray(),0);
        }catch(ReflectiveOperationException|RuntimeException e){return null;}
    }
    private ShadowTraversalSignature(){}
}