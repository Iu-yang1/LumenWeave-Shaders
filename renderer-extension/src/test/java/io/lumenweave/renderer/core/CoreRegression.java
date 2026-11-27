package io.lumenweave.renderer.core;

import java.util.*;

public final class CoreRegression {
    static void check(boolean ok,String message){if(!ok)throw new AssertionError(message);}
    static SectionStore.Key key(int x,int y,int z){return new SectionStore.Key(x,y,z);}
    public static void main(String[] args){
        sections(); stationarySections(); drawLists(); shadows(); pages(); backend(); randomized(); atlas(); framePlanner(); seedPatches();
        seedPalette();
        System.out.println("Renderer core: 11 regression groups passed");
    }
    static void seedPalette(){
        int[] reads={0};
        var seeds=new SeedPalette<String>(state->{reads[0]++;return state.isEmpty()?0:259;});
        String first=new String("solid"),equal=new String("solid"),empty=new String("");
        for(int index=0;index<4096;index++) {
            check(seeds.seed(first)==259,"palette seed preserved");
            check(seeds.seed(empty)==0,"palette zero cached");
        }
        check(reads[0]==2&&seeds.size()==2,"decode per unique identity");
        check(seeds.seed(equal)==259&&reads[0]==3,"distinct state identities");
        seeds.clear();
        check(seeds.size()==0&&seeds.seed(first)==259&&reads[0]==4,"material generation reset");
    }
    static void seedPatches(){
        var rng=new Random(6206);
        int size=32;
        for(int trial=0;trial<120;trial++){
            var old=new SectionStore.Window(rng.nextInt(70)-35,rng.nextInt(70)-35,rng.nextInt(70)-35,size);
            var current=new SectionStore.Window(old.x()+rng.nextInt(11)-5,old.y()+rng.nextInt(11)-5,old.z()+rng.nextInt(11)-5,size);
            var dirty=Set.of(key(Math.floorDiv(current.x()+8,16),Math.floorDiv(current.y()+8,16),Math.floorDiv(current.z()+8,16)));
            var patches=SeedPatchPlan.build(current,old,dirty);
            var cells=new HashSet<String>();
            for(var brick:patches){
                check(Math.floorMod(brick.x(),4)==0&&Math.floorMod(brick.y(),4)==0&&Math.floorMod(brick.z(),4)==0,"aligned patch");
                for(int z=brick.z();z<brick.z()+4;z++)for(int y=brick.y();y<brick.y()+4;y++)for(int x=brick.x();x<brick.x()+4;x++)
                    if(x>=current.x()&&x<current.x()+size&&y>=current.y()&&y<current.y()+size&&z>=current.z()&&z<current.z()+size)
                        check(cells.add(x+","+y+","+z),"patches do not overlap");
            }
            for(int z=current.z();z<current.z()+size;z++)for(int y=current.y();y<current.y()+size;y++)for(int x=current.x();x<current.x()+size;x++){
                boolean entered=x<old.x()||x>=old.x()+size||y<old.y()||y>=old.y()+size||z<old.z()||z>=old.z()+size;
                boolean changed=dirty.contains(key(Math.floorDiv(x,16),Math.floorDiv(y,16),Math.floorDiv(z,16)));
                check(!(entered||changed)||cells.contains(x+","+y+","+z),"all exposed and dirty cells patched");
            }
            check(SeedPatchPlan.build(current,current,Set.of()).isEmpty(),"stationary has no writes");
        }
        for(int grid:new int[]{32,64,96,128}){
            var layout=new IncrementalSeedLayout(grid);
            check(layout.flag()<layout.persistentBase()&&layout.persistentBase()+grid==layout.supportBase(),"disjoint seed planes");
            check(layout.depth()>layout.supportBase(),"support allocation");
        }
    }
    static void stationarySections(){
        var store=new SectionStore();var active=key(0,0,0);var outside=key(1,0,0);
        var window=new SectionStore.Window(0,0,0,16);
        store.ensureLoaded(active);
        var first=store.update(window,k->new int[]{SectionStore.entry(0,0,0,17)});
        SectionStore.Source unused=k->{throw new AssertionError("stationary source read");};
        var idle=store.update(window,unused);
        check(idle.upserts().isEmpty()&&idle.removals().isEmpty()&&idle.epoch()==first.epoch(),"do not replay writes");
        check(store.update(window,unused)==idle,"reuse idle transaction");
        store.ensureLoaded(active);
        check(store.update(window,unused)==idle,"existing membership preserves idle");
        store.added(outside);
        store.update(window,unused);
        var moved=store.update(new SectionStore.Window(16,0,0,16),k->new int[0]);
        check(moved.complete()&&moved.upserts().size()==1&&moved.removals().contains(active),"window invalidation");
        store.removed(outside);
        var missing=store.update(moved.window(),unused);
        check(!missing.complete(),"unload invalidation");
        store.ensureLoaded(outside);
        check(store.update(moved.window(),k->null).missing().contains(outside),"temporarily unavailable source");
        check(store.update(moved.window(),k->new int[0]).complete(),"retry missing without lifecycle event");
        store.changed(outside);
        check(store.update(moved.window(),k->new int[]{SectionStore.entry(1,0,0,18)}).upserts().size()==1,"block invalidation");
        store.invalidateMaterials();
        check(store.update(moved.window(),k->new int[]{SectionStore.entry(1,0,0,19)}).upserts().size()==1,"material invalidation");
        store.reset();
        check(!store.update(window,unused).complete(),"reset invalidation");
    }
    static void sections(){
        var store=new SectionStore();var a=key(-1,0,0);var b=key(0,0,0);
        var window=new SectionStore.Window(-16,0,0,16);
        store.added(a);int[] reads={0};int[] seed={SectionStore.entry(15,0,0,259)};
        SectionStore.Source source=k->{reads[0]++;return seed;};
        var first=store.update(window,source);
        check(first.complete()&&first.upserts().size()==1&&reads[0]==1,"first");
        seed[0]=0;check(first.upserts().get(0).entries()[0]!=0,"immutable");
        check(store.update(window,source).upserts().isEmpty()&&reads[0]==1,"stationary");
        check(store.fullSnapshot().upserts().size()==1&&store.fullSnapshot().epoch()==first.epoch(),"backend rehydration");
        store.changed(a);seed[0]=SectionStore.entry(1,1,1,17);
        check(store.update(window,source).upserts().size()==1,"change");
        store.removed(a);var removed=store.update(window,source);
        check(!removed.complete()&&removed.removals().contains(a),"remove");
        store.added(b);var move=store.update(new SectionStore.Window(0,0,0,16),source);
        check(move.complete()&&move.resident()==1,"enter");
        store.invalidateMaterials();check(store.update(move.window(),k->null).missing().contains(b),"missing read");
        store.reset();check(store.update(move.window(),source).generation()>move.generation(),"reset");
        check(SectionStore.seed(10025,15)==251&&SectionStore.seed(10023,0)==259&&SectionStore.seed(0,0)==0,"seed ABI");
    }
    static void drawLists(){
        var cache=new DrawListCache<String>();int[] m={1,2,3};
        var k=new DrawListCache.Key(1,2,3,16,0,0,0,m,0);
        m[0]=8;check(cache.get(k,()->"a").equals("a"),"build");
        check(cache.get(new DrawListCache.Key(1,2,3,16,0,0,0,new int[]{1,2,3},0),()->"b").equals("a"),"exact hit");
        check(cache.get(new DrawListCache.Key(1,3,3,16,0,0,0,new int[]{1,2,3},0),()->"c").equals("c"),"geometry invalidation");
        cache.invalidate();check(cache.get(k,()->"d").equals("d")&&cache.hits()==1,"ownership reset");
    }
    static void shadows(){
        var cache=new ShadowTileCache();var basis=new ShadowTileCache.Basis(List.of(1,2),1);
        var all=ShadowTileCache.rectangle(0,0,0,8,8);
        var first=cache.plan(basis,all,List.of(),Set.of());check(first.drawStatic().size()==64,"initial");
        cache.complete(first.ticket(),first.drawStatic());
        var moved=ShadowTileCache.rectangle(0,1,0,8,8);
        var dirty=new ShadowTileCache.Bounds(0,2,2,2,2);
        var dynamic=Set.of(new ShadowTileCache.Tile(0,3,3));
        var plan=cache.plan(basis,moved,List.of(dirty),dynamic);
        check(plan.keep().size()==55&&plan.drawStatic().size()==9&&plan.drawDynamic().equals(dynamic),"scroll+dirty");
        cache.complete(first.ticket(),first.drawStatic()); // stale completion ignored
        var failed=cache.plan(basis,moved,List.of(),dynamic);
        check(failed.drawStatic().size()==9,"failed draw remains invalid");
        cache.complete(failed.ticket(),failed.drawStatic());
        check(cache.plan(new ShadowTileCache.Basis(List.of(2,2),1),moved,List.of(),dynamic).drawStatic().size()==64,"light basis");
        check(ShadowTileCache.combineDepth(.2f,.3f,false)==.2f&&ShadowTileCache.combineDepth(.2f,.3f,true)==.3f,"depth convention");
    }
    static void pages(){
        var pool=new VirtualPages(2);
        var a=new ShadowTileCache.Tile(0,0,0);var b=new ShadowTileCache.Tile(0,1,0);var c=new ShadowTileCache.Tile(0,2,0);
        var p=pool.plan(List.of(new VirtualPages.Request(a,3,1),new VirtualPages.Request(a,4,1),
            new VirtualPages.Request(b,2,1),new VirtualPages.Request(c,1,1)));
        check(p.table().size()==2&&p.missing().equals(Set.of(c))&&p.render().size()==2,"capacity and dedup");
        pool.complete(p.ticket(),p.render());
        var next=pool.plan(List.of(new VirtualPages.Request(a,3,1),new VirtualPages.Request(c,2,1)));
        check(next.render().equals(Set.of(c))&&next.table().get(a).valid(),"page retention");
        pool.complete(next.ticket(),next.render());
        check(pool.plan(List.of(new VirtualPages.Request(a,1,2))).render().equals(Set.of(a)),"revision");
    }
    static void backend(){
        var store=new SectionStore();store.added(key(0,0,0));
        var d=store.update(new SectionStore.Window(0,0,0,16),k->new int[0]);
        var backend=new ReferenceBackend();var receipt=backend.uploadSeeds(d);
        check(!RendererBackend.mayUseNormalCulling(d,receipt,backend.capabilities()),"reference never owns GL");
        var gpu=new RendererBackend.Capabilities(RendererBackend.Api.OPENGL,Set.of(RendererBackend.Feature.SECTION_SEEDS),0);
        check(RendererBackend.mayUseNormalCulling(d,new RendererBackend.Receipt(d.generation(),d.epoch(),d.window(),true,true,true),gpu),"exact ack");
        check(!RendererBackend.mayUseNormalCulling(d,new RendererBackend.Receipt(d.generation(),d.epoch()-1,d.window(),true,true,true),gpu),"stale ack");
    }
    static void atlas(){
        // Full section uploads are disjoint even for an unaligned 128-block window.
        for(int start=-300;start<300;start++){
            var slots=new HashSet<Integer>();
            int lo=Math.floorDiv(start,16),hi=Math.floorDiv(start+127,16);
            for(int section=lo;section<=hi;section++)
                check(slots.add(SeedAtlasLayout.sectionAddress(section)),"no section alias");
            for(int x=start;x<start+128;x++)
                check(SeedAtlasLayout.address(x)==SeedAtlasLayout.sectionAddress(Math.floorDiv(x,16))+Math.floorMod(x,16),"negative ring address");
        }
    }
    static void framePlanner(){
        var planner=new ShadowFramePlanner(4);
        var basis=new ShadowTileCache.Basis(List.of(5),1);
        var a=new ShadowTileCache.Tile(0,0,0);var b=new ShadowTileCache.Tile(0,1,0);
        var required=Map.of(a,2,b,1);
        var command=new ShadowPageBackend.DrawCommand(6,1,0,0,0);
        var bounds=new ShadowTileCache.Bounds(0,0,0,0,0);
        var fixed=new ShadowFramePlanner.Caster(1,bounds,false,command);
        var moving=new ShadowFramePlanner.Caster(2,bounds,true,command);
        var first=planner.plan(basis,required,List.of(),List.of(fixed,moving));
        check(first.work().size()==2&&first.allocation().render().size()==2,"initial pages");
        planner.complete(first.ticket(),first.allocation().render(),required.keySet());
        var second=planner.plan(basis,required,List.of(),List.of(fixed));
        check(second.work().size()==1&&second.work().get(0).tile().equals(a),"old dynamic cleared");
        check(!second.work().get(0).redrawStatic()&&second.work().get(0).clearDynamic(),"static reused");
        planner.complete(second.ticket(),Set.of(),Set.of());
        var retry=planner.plan(basis,required,List.of(),List.of(fixed));
        check(retry.work().size()==1&&retry.work().get(0).clearDynamic(),"failed dynamic clear retries");
        planner.complete(retry.ticket(),Set.of(),Set.of(a));
        var third=planner.plan(basis,required,List.of(bounds),List.of(fixed));
        check(third.allocation().render().equals(Set.of(a))&&third.work().get(0).staticDraws().size()==1,"dirty caster");
        planner.complete(third.ticket(),Set.of(),Set.of(a));
        check(planner.plan(basis,required,List.of(),List.of(fixed)).allocation().render().equals(Set.of(a)),"failed raster not valid");
    }
    static void randomized(){
        var rng=new Random(6201);var cache=new ShadowTileCache();
        var basis=new ShadowTileCache.Basis(List.of(1),1);
        Set<ShadowTileCache.Tile> previous=Set.of();
        for(int i=0;i<1000;i++){
            var required=ShadowTileCache.rectangle(0,rng.nextInt(10)-5,rng.nextInt(10)-5,8,8);
            var bounds=new ShadowTileCache.Bounds(0,-1,-1,1,1);
            var p=cache.plan(basis,required,List.of(bounds),Set.of());
            var expected=new HashSet<>(previous);expected.retainAll(required);expected.removeIf(bounds::contains);
            check(expected.equals(p.keep()),"random scroll exact");
            cache.complete(p.ticket(),p.drawStatic());previous=required;
        }
    }
}
