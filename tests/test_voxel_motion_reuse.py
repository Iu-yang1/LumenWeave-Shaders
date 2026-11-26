"""Conservative rolling metadata-bank reuse and dual-field sample contracts."""
import itertools
import random
import unittest
from pathlib import Path

S=Path(__file__).resolve().parents[1]/"shaders"

def reusable(tile,delta,n,support,pending,dirty,fresh=True):
    lo=tuple(4*t+d for t,d in zip(tile,delta))
    hi=tuple(x+3 for x in lo)
    if not fresh or dirty or min(lo)<0 or max(hi)>=n:return False
    first=tuple(x//4 for x in lo)
    last=tuple(x//4 for x in hi)
    if first==last:return first not in pending
    return not any(t in support or t in pending for t in itertools.product(*(range(a,b+1) for a,b in zip(first,last))))

class MotionReuseTests(unittest.TestCase):
    def test_overlap_is_conservative_for_every_lane(self):
        rng=random.Random(927)
        n=16
        tiles=list(itertools.product(range(n//4),repeat=3))
        for _ in range(120):
            support={t for t in tiles if rng.random()<.15}
            pending={t for t in tiles if rng.random()<.1}
            delta=tuple(rng.randrange(-5,6) for _ in range(3))
            for tile in tiles:
                dirty=rng.random()<.08
                if not reusable(tile,delta,n,support,pending,dirty):continue
                self.assertFalse(dirty)
                for lane in itertools.product(range(4),repeat=3):
                    old=tuple(4*t+l+d for t,l,d in zip(tile,lane,delta))
                    self.assertTrue(all(0<=x<n for x in old))
                    old_tile=tuple(x//4 for x in old)
                    self.assertNotIn(old_tile,pending)
                    if any(x%4 for x in delta):self.assertNotIn(old_tile,support)
        self.assertFalse(reusable((0,0,0),(0,0,0),n,set(),set(),False,False))

    def test_aligned_lit_and_unaligned_empty(self):
        t=(1,1,1)
        self.assertTrue(reusable(t,(4,0,0),16,{(2,1,1)},set(),False))
        self.assertFalse(reusable(t,(4,0,0),16,{(2,1,1)},{(2,1,1)},False))
        self.assertTrue(reusable(t,(1,1,1),16,set(),set(),False))
        self.assertFalse(reusable(t,(1,1,1),16,{(2,2,2)},set(),False))
        self.assertFalse(reusable(t,(1,1,1),16,set(),{(2,2,2)},False))

    def test_dual_field_seam_interpolation(self):
        rng=random.Random(141)
        for _ in range(500):
            fraction=[rng.random() for _ in range(3)]
            weights=[(fraction[0] if x else 1-fraction[0])*(fraction[1] if y else 1-fraction[1])*(fraction[2] if z else 1-fraction[2]) for x,y,z in itertools.product((0,1),repeat=3)]
            raw=[rng.random() for _ in weights];history=[rng.random() for _ in weights]
            for read_raw,read_hist in itertools.product((False,True),repeat=2):
                expected=(sum(a*b for a,b in zip(raw,weights)) if read_raw else 0.,sum(a*b for a,b in zip(history,weights)) if read_hist else 0.)
                result=[0.,0.]
                for a,b,w in zip(raw,history,weights):
                    if read_raw:result[0]+=a*w
                    if read_hist:result[1]+=b*w
                for value,reference in zip(result,expected):
                    self.assertAlmostEqual(value,reference,places=14)
        src=(S/"lib/voxel/irradiance.glsl").read_text()
        self.assertIn("void voxelDirectPair",src)
        self.assertIn("readHistory",src)
        self.assertIn("readTarget",src)
        stage=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("historyTileMeta(tile,parity)",stage)
        self.assertIn("priorTileState(first,1-parity)",stage)
        self.assertIn("hasHistorySupport(target)",stage)

    def test_ssr_rejects_before_material_work(self):
        source=(S/"lib/reflection/material_trace.glsl").read_text().split("vec4 traceMaterialCorrection",1)[1]
        self.assertLess(source.index("smoothness<=0.001"),source.index("vanillaMaterial"))
