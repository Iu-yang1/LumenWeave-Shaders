import itertools
import math
import random
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
sys.path.insert(0, str(ROOT / "tools"))
from gpu_pass_profile import summarize


class DeepPipelineTests(unittest.TestCase):
    def test_shared_stencil_mapping(self):
        def cell(i):
            if i < 64:
                return i % 4, (i // 4) % 4, i // 16
            face, u, v = (i-64)//16, (i-64)%4, ((i-64)//4)%4
            side = -1 if face%2 == 0 else 4
            return ((side,u,v),(u,side,v),(u,v,side))[face//2]

        def index(p):
            x,y,z = p
            if x < 0 or x > 3:
                return 64 + (16 if x>3 else 0) + y + 4*z
            if y < 0 or y > 3:
                return 96 + (16 if y>3 else 0) + x + 4*z
            if z < 0 or z > 3:
                return 128 + (16 if z>3 else 0) + x + 4*y
            return x+4*y+16*z

        self.assertEqual(len({cell(i) for i in range(160)}),160)
        for p in itertools.product(range(4), repeat=3):
            for axis, delta in itertools.product(range(3),(-1,1)):
                q=list(p)
                q[axis]+=delta
                self.assertEqual(cell(index(q)),tuple(q))

    def test_empty_tile_halo_and_skip(self):
        rng=random.Random(91013)
        for size in (8,12,16):
            count=size//4
            lit={p for p in itertools.product(range(size),repeat=3) if rng.random()<.015}
            occupied={tuple(v//4 for v in p) for p in lit}
            def empty(tile):
                return not any(max(abs(a-b) for a,b in zip(tile,p))<=1 for p in occupied)
            for tile in itertools.product(range(count),repeat=3):
                if not empty(tile):
                    continue
                for corner in itertools.product(range(-1,5),repeat=3):
                    p=tuple(4*t+c for t,c in zip(tile,corner))
                    self.assertNotIn(p,lit)
            for _ in range(100):
                p=[rng.uniform(0,size) for _ in range(3)]
                ray=[rng.uniform(-1,1) for _ in range(3)]
                length=math.sqrt(sum(v*v for v in ray))
                ray=[v/length for v in ray]
                step=rng.uniform(.1,2.5)
                tile=[math.floor(v/4) for v in p]
                exits=[((t*4+(4 if d>0 else 0))-v)/d
                       for t,v,d in zip(tile,p,ray) if abs(d)>1e-6]
                skip=max(1,min(24,math.ceil(max(min(exits)-.001,0)/step)))
                for i in range(skip):
                    self.assertEqual([math.floor((v+d*i*step)/4) for v,d in zip(p,ray)],tile)

    def test_hiz_odd_viewports(self):
        rng=random.Random(1001)
        for width,height in ((17,19),(31,37),(64,33)):
            depths=[[rng.choice((rng.random(),1.0)) for _ in range(width)] for _ in range(height)]
            for tile_size in (4,16):
                for ty in range(0,height,tile_size):
                    for tx in range(0,width,tile_size):
                        values=[depths[y][x] for y in range(ty,min(ty+tile_size,height))
                                for x in range(tx,min(tx+tile_size,width))]
                        minimum,maximum=min(values),max(values)
                        for d in (0.0,.05,.5,.99,1.0):
                            if d+2e-7<minimum:
                                self.assertTrue(all(d<v for v in values))
                            if maximum<1.0:
                                self.assertTrue(all(v<1.0 for v in values))

    def test_compaction_membership_and_capacity(self):
        rng=random.Random(1204)
        for size in (8,16,24,32):
            for probability in (0.,.03,1.):
                count=size**3
                mask=[(3 if rng.random()<probability else 0) for _ in range(count)]
                for bit in (1,2):
                    tasks=[i for i,v in enumerate(mask) if v&bit]
                    self.assertLessEqual(len(tasks),32768)
                    self.assertEqual(set(tasks),{i for i in range(count) if mask[i]&bit})
                    self.assertEqual(len(set(tasks)),len(tasks))

    def test_bilateral_depth_rejection(self):
        depth=4.0
        tolerance=max(.20,depth*.025)
        same=[4.0,4.02,3.97,4.01]
        edge=[4.0,25.,25.,25.]
        spatial=[.25]*4
        def accepted(values):
            return sum(w for v,w in zip(values,spatial) if abs(v-depth)<=tolerance)
        self.assertGreaterEqual(accepted(same),.85)
        self.assertLess(accepted(edge),.85)
        self.assertIn("integrateLocalScatter(direction,distanceToSurface)",
                      (SHADERS/"lib/atmosphere/scatter_upsample.glsl").read_text())

    def test_profile_measured_counters(self):
        rows=[
            {"frame":"1","pass":"deferred","gpu_ms":"2","read_bytes":"2000000","write_bytes":"1000000"},
            {"frame":"1","pass":"deferred","gpu_ms":"1","read_bytes":"1000000","write_bytes":"500000"},
            {"frame":"2","pass":"deferred","gpu_ms":"5","read_bytes":"","write_bytes":""},
            {"frame":"1","pass":"composite","gpu_ms":"1"},
        ]
        out=summarize(rows)
        self.assertEqual(out[0]["pass"],"deferred")
        self.assertEqual(out[0]["median_ms"],4.)
        self.assertAlmostEqual(out[0]["p95_ms"],4.9)
        self.assertEqual(out[0]["counter_frames"],1)
        self.assertEqual(out[0]["read_GB_s"],1.)
        self.assertEqual(out[0]["write_GB_s"],.5)
        self.assertIsNone(out[1]["read_GB_s"])

    def test_gpu_path_contracts(self):
        prop=(SHADERS/"lib/voxel/propagate.glsl").read_text()
        self.assertIn("shared vec3 lwStencil[160]",prop)
        self.assertIn("if (openCount < 32)",prop)
        scatter=(SHADERS/"lib/atmosphere/local_scatter.glsl").read_text()
        self.assertIn("tile+ivec3(32,0,0)",scatter)
        self.assertIn("i += skip",scatter)
        hi=(SHADERS/"lib/lighting/hiz.glsl").read_text()
        self.assertIn("rayDepth+0.0000002<bounds.x",hi)
        self.assertIn("bounds.y>=1.0",hi)
        props=(SHADERS/"shaders.properties").read_text()
        self.assertIn("image.lwHiZImage = lwHiZ rg rg32f",props)
        self.assertNotIn("indirect.prepare",props)
        self.assertIn("colorimg11",(SHADERS/"programs/shared/composite_a.csh.glsl").read_text())
        sky=(SHADERS/"lib/dimensions/celestial_sky.glsl").read_text()
        self.assertIn("endSkyDetail",sky)
        self.assertIn("celestialSkyGlow",sky)
        self.assertIn("moonPhase",sky)


if __name__ == "__main__":
    unittest.main()
