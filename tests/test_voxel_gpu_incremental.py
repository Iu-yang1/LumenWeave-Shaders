import itertools
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"

class VoxelGpuIncrementalTests(unittest.TestCase):
    def test_tile_radius_covers_dependencies(self):
        # All possible positions in one tile, all Manhattan offsets up to the
        # four propagation steps or six propagation+diffuse dependencies.
        for steps, radius in ((4,1),(6,2)):
            for pos in itertools.product(range(4), repeat=3):
                for offset in itertools.product(range(-steps,steps+1),repeat=3):
                    if sum(map(abs,offset)) > steps:
                        continue
                    target = tuple((x+y)//4 for x,y in zip(pos,offset))
                    self.assertLessEqual(max(map(abs,target)),radius)

    def test_stage_cache_and_seed_deletion(self):
        start = (ROOT/"programs/shared/prepare.csh.glsl").read_text()
        self.assertIn("imageLoad(lwVoxelPrevSeed,cacheCell).r != seed",start)
        self.assertIn("imageStore(lwVoxelPrevSeed,cacheCell,uvec4(seed))",start)
        self.assertIn("previous.w != frameCounter - 1",start)
        for i in range(1,5):
            stage = (ROOT/f"programs/shared/prepare{i}.csh.glsl").read_text()
            self.assertIn(f"#define LW_VOXEL_READ lwVoxelStage{i-1}",stage)
            self.assertIn("#define LW_VOXEL_WRITE "+("lwVoxelFirst" if i==4 else f"lwVoxelStage{i}"),stage)
        self.assertIn("voxelTileMask(tile)",(ROOT/"lib/voxel/propagate.glsl").read_text())
        self.assertIn("voxelTileMask(tile)",(ROOT/"programs/shared/prepare5.csh.glsl").read_text())

    def test_image_budget(self):
        props = (ROOT/"shaders.properties").read_text()
        self.assertEqual(len({line.split("=",1)[0].strip() for line in props.splitlines()
                              if line.startswith("image.")}),16)

    def test_ring_cache_exact_scroll(self):
        import random
        import sys
        sys.path.insert(0,str(ROOT.parent/"tools"))
        from voxel_incremental_reference import grid,source,evaluate,full_rebuild
        rng=random.Random(6214)
        size=8
        origin=(-4,-4,-4)
        emitters={(0,0,0):(1.,.2,.1)}
        walls={(1,0,0)}
        stages=full_rebuild(origin,size,emitters,walls,4)
        def wrap(cell):
            return tuple(x%size for x in cell)
        ring=[{wrap(c):v for c,v in stage.items()} for stage in stages]
        prevseeds={wrap(c):(source(c,emitters,walls),c in walls) for c in stages[0]}
        oldorigin=origin
        for step in range(18):
            origin=tuple(x+rng.choice((-1,0,1)) for x in origin)
            if step==8:
                origin=(19,-6,-20)
            cell=tuple(o+rng.randrange(size) for o in origin)
            if step%3==0:
                emitters[cell]=(1.,.6,.3)
            elif step%3==1:
                if emitters:
                    emitters.pop(next(iter(emitters)))
                walls.add(cell)
            else:
                walls.discard(cell)
            domain=grid(origin,size)
            olddomain=grid(oldorigin,size)
            dirty=set()
            for c in domain:
                local=tuple(x-o for x,o in zip(c,origin))
                oldlocal=tuple(x-o for x,o in zip(c,oldorigin))
                seed=(source(c,emitters,walls),c in walls)
                changed=c not in olddomain or prevseeds.get(wrap(c))!=seed
                lost=any((v==0 and p>0) or (v==size-1 and p<size-1)
                         for v,p in zip(local,oldlocal))
                if changed:
                    ring[0][wrap(c)]=seed[0]
                    prevseeds[wrap(c)]=seed
                if changed or lost:
                    dirty.add(tuple(x//4 for x in local))
            for i in range(1,5):
                previous={c:ring[i-1][wrap(c)] for c in domain}
                for c in domain:
                    tile=tuple((x-o)//4 for x,o in zip(c,origin))
                    if any(max(abs(x-y) for x,y in zip(tile,d))<=1 for d in dirty):
                        ring[i][wrap(c)]=evaluate(c,previous,emitters,walls)
            actual=[{c:stage[wrap(c)] for c in domain} for stage in ring]
            self.assertEqual(actual,full_rebuild(origin,size,emitters,walls,4))
            oldorigin=origin

    def test_separable_dirty_expansion_is_exact(self):
        import random
        rng=random.Random(45744560427)
        for size in (4,8):
            domain=set(itertools.product(range(size),repeat=3))
            for probability in (0.0,0.03,0.4,1.0):
                dirty={c for c in domain if rng.random()<probability}
                mask={c:3 if c in dirty else 0 for c in domain}
                for axis in range(3):
                    new={}
                    for c in domain:
                        bits=0
                        for d in range(-2,3):
                            other=list(c)
                            other[axis]+=d
                            bits |= mask.get(tuple(other),0)&(3 if abs(d)<=1 else 2)
                        new[c]=bits
                    mask=new
                for c in domain:
                    for radius,bit in ((1,1),(2,2)):
                        expected=any(max(abs(a-b) for a,b in zip(c,p))<=radius for p in dirty)
                        self.assertEqual(bool(mask[c]&bit),expected)
        source=(ROOT/"lib/voxel/expand_dirty.glsl").read_text()
        self.assertIn("32*(LW_DIRTY_AXIS+1)",source)
        for suffix in ("a","b","c"):
            self.assertTrue((ROOT/"world0"/f"prepare_{suffix}.csh").is_file())
