import math
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"shaders"

class DynamicSamplingContract(unittest.TestCase):
    def test_oblique_surface_lighting_anchor(self):
        # Plane z = -8 + .35*x - .20*y. Projected samples at different
        # subpixel offsets intersect the same stable output ray after reanchoring.
        n=(-.35,.20,1.)
        def dot(a,b):
            return sum(x*y for x,y in zip(a,b))
        stable=(.2,-.1,-1.)
        expected=tuple(v*(-8/dot(n,stable)) for v in stable)
        for w,h in ((1280,720),(1920,1080),(1919,1079),(3840,2160)):
            for jx,jy in ((-.4,.3),(.4,-.3),(0.,0.)):
                ray=(stable[0]+2*jx/w,stable[1]+2*jy/h,-1.)
                p=tuple(v*(-8/dot(n,ray)) for v in ray)
                result=tuple(v*(dot(n,p)/dot(n,stable)) for v in stable)
                for a,b in zip(result,expected):
                    self.assertAlmostEqual(a,b,places=10)

    def test_ownership_and_projection_classes(self):
        owner=(ROOT/"lib/coordinates/sample_owner.glsl").read_text()
        self.assertIn("abs(metadata.x - depth)",owner)
        self.assertIn("distant ? !dh : !native",owner)
        taa=(ROOT/"programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("(metadata.z<0.0)!=distant",taa)
        self.assertIn("(metadata.w<0.0)!=sky",taa)
        self.assertIn("temporalSky",taa)

    def test_flat_temporal_variance_retains_history(self):
        current=1.0
        previous=.95
        old=min(current,max(current,previous))
        extent=max(.12*current,.002)
        new=min(current+extent,max(current-extent,previous))
        self.assertEqual(old,current)
        self.assertEqual(new,previous)
        self.assertLess(.08*current+.92*new,current)

    def test_gi_actual_half_viewport_and_history(self):
        deferred=(ROOT/"programs/shared/deferred.fsh.glsl").read_text()
        self.assertIn("texCoord * vec2(fullSize)",deferred)
        self.assertNotIn("fullSize / 2",deferred)
        gi=(ROOT/"lib/temporal/screen_gi_history.glsl").read_text()
        self.assertIn("reprojectStableTerrain",gi)
        self.assertIn("metadata.zw - vec2(size)",gi)
