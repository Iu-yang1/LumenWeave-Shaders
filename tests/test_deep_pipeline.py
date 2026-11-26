import functools
import itertools
import random
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from deep_pipeline_sim import run

class DeepPipelineTests(unittest.TestCase):
    def test_numeric_models(self):
        r=run()
        self.assertLess(r['arc_max_abs_error'],1e-12)
        self.assertEqual(r['depth_mismatch'],0)
        self.assertEqual(r['wall_halo_misses'],0)
        self.assertLess(r['edge_fallback']['new'],r['edge_fallback']['old'])
    def test_separable_wall_expansion(self):
        rng=random.Random(5703)
        cells=list(itertools.product(range(8),repeat=3))
        for _ in range(20):
            original={t for t in cells if rng.random()<.08}
            expanded=original
            for axis in range(3):
                expanded={t for t in cells if any(tuple(x+(d if i==axis else 0) for i,x in enumerate(t)) in expanded for d in (-1,0,1))}
            brute={t for t in cells if any(all(abs(a-b)<=1 for a,b in zip(t,w)) for w in original)}
            self.assertEqual(expanded,brute)
    def test_history_flag_reduction(self):
        rng=random.Random(5704)
        for _ in range(1000):
            flags=[rng.randrange(16) for _ in range(64)]
            groups=[functools.reduce(int.__or__,flags[i:i+8],0) for i in range(0,64,8)]
            self.assertEqual(functools.reduce(int.__or__,groups,0),functools.reduce(int.__or__,flags,0))
    def test_shader_dataflow(self):
        q=(ROOT/'shaders/lib/quality.glsl').read_text()
        resolve=(ROOT/'shaders/programs/shared/composite1.fsh.glsl').read_text()
        motion=(ROOT/'shaders/programs/shared/composite2.fsh.glsl').read_text()
        self.assertIn('#define LW_TAA_HISTORY_ONLY',q)
        self.assertIn('#ifdef LW_TAA_HISTORY_ONLY',resolve)
        self.assertIn('RENDERTARGETS: 4,5',resolve)
        self.assertIn('#define LW_MOTION_SOURCE colortex4',motion)
        self.assertIn('lwMotionActive!=0',motion)
        shared_motion=(ROOT/'shaders/lib/post/motion_blur.glsl').read_text()
        self.assertIn('if(!moving) return center',shared_motion)
        self.assertIn('outputColor.a=1.0',motion)
        v=(ROOT/'shaders/programs/shared/prepare5.csh.glsl').read_text()
        self.assertIn('(tileMask&16u)==0u',v)
        h=(ROOT/'shaders/programs/shared/prepare6.csh.glsl').read_text()
        self.assertIn('historyFlags[lane]=flags',h)
        self.assertNotIn('atomicOr(',h)
