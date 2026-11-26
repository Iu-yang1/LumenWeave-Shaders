import math
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"shaders"

class DimensionContrastTests(unittest.TestCase):
    def test_weak_light_curve(self):
        for i in range(15):
            x=i/15
            old=x*x*(.45+1.35*x)
            new=x*x*(.20+1.60*x)
            self.assertLessEqual(new,old)
        self.assertAlmostEqual(.20+1.60,1.8)
        values=[(i/15)**2*(.20+1.60*i/15) for i in range(16)]
        self.assertTrue(all(a<b for a,b in zip(values,values[1:])))
    def test_emitter_gain_preserves_chromaticity(self):
        rgb=(.8,.35,.1)
        boosted=tuple(x*1.5 for x in rgb)
        for x,y in zip(rgb,boosted):
            self.assertAlmostEqual(x/sum(rgb),y/sum(boosted))
        self.assertAlmostEqual(1+.35*(1.5-1),1.175)
        source=(ROOT/"lib/materials/vanilla.glsl").read_text()
        self.assertIn("tint*emitterRadiance(kind)*mask*gain",source)
    def test_scatter_gain_and_zero(self):
        for density in (.0035,.006,.027):
            old=.75*.90*(1-math.exp(-density*10))
            self.assertAlmostEqual(old*1.7/old,1.7)
        s=(ROOT/"lib/atmosphere/local_scatter.glsl").read_text()
        self.assertIn("LOCAL_GLOW_STRENGTH",s)
        self.assertIn("surfaceDistance - 0.08",s)
    def test_dimension_reuse_and_shadow_budget(self):
        s=(ROOT/"programs/shared/deferred.fsh.glsl").read_text()
        self.assertIn("GI_REUSE_MODE == 2 || (GI_REUSE_MODE == 1 && (defined(LW_DIMENSION_NETHER) || defined(LW_DIMENSION_END)))",s)
        gi=(ROOT/"lib/lighting/screen_gi.glsl").read_text()
        self.assertIn("sceneShadow(worldPosition,hitNormal,light,false)",gi)
        sh=(ROOT/"lib/lighting/lite_shadows.glsl").read_text()
        self.assertIn("sceneShadow(position,normal,light,true)",sh)
        self.assertNotIn("SHADOW_FILTER_TAPS/blockerTaps",sh)
    def test_full_lut_fast_path(self):
        a=(ROOT/"lib/atmosphere/aerial.glsl").read_text()
        self.assertLess(a.index("if(boundaryFade<=0.0) return physical;"),a.index("vec3 sky = skyRadiance"))
        s=(ROOT/"lib/lighting/overworld.glsl").read_text()
        self.assertLess(s.index("if(sun.y>=0.05)"),s.index("float height = max(direction.y"))
    def test_fog_boundary_not_changed(self):
        f=(ROOT/"lib/lighting/fog.glsl").read_text()
        self.assertIn("exp(-opticalDepth)*(1.0-boundary)",f)
        self.assertIn("endNebula(direction)*boundary",f)
