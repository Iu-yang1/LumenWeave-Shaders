import math
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"shaders"

def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)

def border(displacement,far,fog_end,dh=0,ceiling=True):
    distance=max(math.hypot(displacement[0],displacement[2]),abs(displacement[1]))
    if not ceiling and dh>far+16:
        return smooth(dh*.78,dh,distance)
    limit=min(far,fog_end) if fog_end>1 else far
    end=max(limit-8,limit*.78)
    return smooth(end*.68,end,distance)

class BorderFogTests(unittest.TestCase):
    def test_boundary_is_opaque_before_chunk_limit(self):
        for far in (32,48,64,96,128,192,256,512):
            for fog_end in (0,far*.6,far,far*4):
                limit=min(far,fog_end) if fog_end>1 else far
                end=max(limit-8,limit*.78)
                self.assertEqual(border((end,0,0),far,fog_end),1.)
                self.assertEqual(border((0,end,0),far,fog_end),1.)
                values=[border((d,0,0),far,fog_end) for d in range(int(limit)+1)]
                self.assertEqual(values[0],0.)
                self.assertTrue(all(a<=b for a,b in zip(values,values[1:])))
                self.assertEqual(values[-1],1.)

    def test_world_space_cylinder_invariant_to_heading(self):
        for angle in range(0,360,15):
            x,z=100*math.cos(math.radians(angle)),100*math.sin(math.radians(angle))
            self.assertAlmostEqual(border((x,12,z),128,128),border((100,12,0),128,128))

    def test_dh_end_uses_distant_range(self):
        self.assertEqual(border((128,0,0),128,128,512,False),0.)
        self.assertEqual(border((512,0,0),128,128,512,False),1.)
        self.assertEqual(border((128,0,0),128,128,512,True),1.)

    def test_boundary_color_independent_of_geometry(self):
        for density in (.0035,.010,.012,.027):
            for far in (32,64,128,256):
                distance=max(far-8,far*.78)
                transmission=math.exp(-distance*density)*(1-border((distance,0,0),far,far))
                self.assertEqual(transmission,0.)
                haze=(.03,.012,.045)
                for lit in ((0.,0.,0.),(1.,0.,0.),(8.,2.,1.)):
                    actual=tuple(a*transmission+b*(1-transmission) for a,b in zip(lit,haze))
                    self.assertEqual(actual,haze)

    def test_background_depth_ownership_and_forward_enabled(self):
        source=(ROOT/"programs/shared/deferred1.fsh.glsl").read_text()
        self.assertIn("if(depth<1.0) return false",source)
        self.assertIn("if(depthAtUv(dhDepthTex0,uv)<1.0) return false",source)
        self.assertIn("if(dimensionBackgroundPixel(texCoord,depthAtUv(depthtex0,texCoord)))",source)
        self.assertLess(source.index("if(boundary>=1.0)"),source.index("groundTruthOcclusion("))
        props=(ROOT/"shaders.properties").read_text()
        for world in ("world-1","world1"):
            self.assertIn(f"program.{world}/deferred1.enabled = true",props)
        fog=(ROOT/"lib/lighting/fog.glsl").read_text()
        self.assertIn("dimensionBorder(displacement)",fog)
        self.assertIn("endNebula(direction)*boundary",fog)
        self.assertIn("(1.0-boundary)",fog)

    def test_near_quality_and_far_work_budget(self):
        gi=(ROOT/"lib/lighting/screen_gi.glsl").read_text()
        self.assertIn("rayCount=-viewPosition.z>22.0 ? 2 : 4",gi)
        self.assertIn("0.5/float(rayCount)",gi)
        for count in (2,4):
            self.assertAlmostEqual(sum(.5/count for _ in range(count)),.5)
        ao=(ROOT/"lib/lighting/gtao.glsl").read_text()
        self.assertIn("taps=-position.z>32.0 ? 2 : 4",ao)
        vol=(ROOT/"lib/atmosphere/volume.glsl").read_text()
        self.assertIn("start<128.0 ? CLOUD_STEPS",vol)
