"""Numerical contracts for reticle autofocus and bounded DoF resolve."""
import math
import unittest
from pathlib import Path
S=Path(__file__).resolve().parents[1]/"shaders"

def update(old,target,dt,half=.22):
    band=max(.0025,old*.035)
    delta=target-old
    requested=old+math.copysign(max(abs(delta)-band,0),delta)
    return requested+(old-requested)*2**(-dt/(half*(.8 if requested>old else 1.35)))

class AutofocusTests(unittest.TestCase):
    def test_focus_pull_is_continuous_and_monotonic(self):
        for start,target in ((1/4,1/64),(1/64,1/4)):
            results=[]
            for hz in (30,60,144):
                value=start
                for _ in range(hz*3):
                    new=update(value,target,1/hz)
                    self.assertTrue(min(value,target)<=new<=max(value,target))
                    value=new
                results.append(value)
            self.assertLess(max(results)-min(results),.001)
            self.assertLess(abs(results[0]-target),.009)
    def test_isolated_foreground_rejected(self):
        samples=[1/20]*8+[1/1.2]
        self.assertEqual(sorted(samples)[4],1/20)
    def test_deadband_stops_focus_hunting(self):
        self.assertAlmostEqual(update(.1,.102,1/60),.1)
    def test_separate_state_and_bounded_reconstruction(self):
        meter=(S/"programs/shared/composite4.csh.glsl").read_text()
        self.assertIn("ivec2(1,0)",meter)
        self.assertIn("lwAdvanceFocus",meter)
        depth=(S/"lib/post/camera_depth.glsl").read_text()
        self.assertIn("lwPostDepth(depthtex2,uv)",depth)
        final=(S/"programs/shared/final.fsh.glsl").read_text()
        self.assertIn("scene=lwDofResolve(colortex10,texCoord,scene,depth)",final)
        self.assertNotIn("confidence>=0.999",final)
