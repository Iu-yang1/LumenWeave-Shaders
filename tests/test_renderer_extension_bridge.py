import itertools
import random
import unittest
from pathlib import Path
S=Path(__file__).resolve().parents[1]/"shaders"
class ExtensionBridgeTests(unittest.TestCase):
    def test_flag_disjoint(self):
        p=(S/"shaders.properties").read_text()
        for n in (32,64,96,128):
            d=n+(n+63)//64
            self.assertGreaterEqual(n*n*(d-n),(n//4)**3)
            self.assertIn(f"false false {n} {n} {d+1}",p)
        self.assertIn("lwExternalSeedFlagAddress()", (S/"programs/shared/begin.csh.glsl").read_text())
        self.assertIn("lwExternalSeedFlagAddress()", (S/"lib/voxel/inject.glsl").read_text())
    def test_unaligned_bricks(self):
        rng=random.Random(6210)
        for _ in range(5000):
            n=rng.choice((32,64,96,128))
            base=tuple(rng.randrange(-4,n+4) for _ in range(3))
            first=tuple(v//4 for v in base)
            flags=set()
            mask=0
            for local in itertools.product(range(4),repeat=3):
                c=tuple(a+b for a,b in zip(base,local))
                if min(c)<0 or max(c)>=n or rng.random()<.5:continue
                t=tuple(v//4 for v in c);flags.add(t)
                rel=tuple(a-b for a,b in zip(t,first))
                self.assertTrue(all(v in (0,1) for v in rel))
                mask|=1<<(rel[0]+2*(rel[1]+2*rel[2]))
            decoded={tuple(a+b for a,b in zip(first,(i&1,(i>>1)&1,i>>2))) for i in range(8) if mask&(1<<i)}
            self.assertEqual(decoded,flags)
