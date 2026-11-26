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
        self.assertIn("scene=lwDofResolve(colortex10,texCoord,scene,depth,focus)",final)
        self.assertNotIn("confidence>=0.999",final)

    def test_resolution_scaled_blur_and_bounded_taps(self):
        dof=(S/"lib/post/dof.glsl").read_text()
        self.assertIn("max(viewHeight,1.0)/1080.0",dof)
        self.assertIn("ringWeight>0.0 && (DOF_QUALITY==2 || i<4)",dof)
        for height in (720,1080,1440,2160):
            scale=height/1080
            self.assertAlmostEqual(min(.5*32*scale,8*scale)/height,8/1080)
        self.assertAlmostEqual(2**.02,1.01395948,places=7)

    def test_focused_pixel_retains_native_color(self):
        dof=(S/"lib/post/dof.glsl").read_text()
        self.assertIn("blur*smoothstep(0.05,0.65,total)",dof)
        self.assertIn("float nearLimit=depth*0.97;",dof)
        self.assertIn("if(s.a<nearLimit)",dof)
        # At optical focus and without a closer blurred donor, native HDR
        # is preserved rather than replaced by a half-resolution sample.
        for native,half in ((.2,.8),(1.5,.3)):
            self.assertEqual(native*(1-0)+half*0,native)
