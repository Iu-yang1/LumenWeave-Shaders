import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from check_shaders import preview_profiles
from package import PREVIEW

class ReleaseReviewTests(unittest.TestCase):
    def test_cloud_slab_horizontal_and_near_horizontal(self):
        def intersect(y,dy,limit):
            end=min(limit,640.)
            if dy==0:
                return (0.,end) if 156.<y<174. and end>0 else None
            a,b=sorted(((156.-y)/dy,(174.-y)/dy))
            start,end=max(a,0.),min(b,end)
            return (start,end) if end>start and start<630 else None
        self.assertEqual(intersect(165.,0.,640.),(0.,640.))
        self.assertIsNone(intersect(155.,0.,640.))
        self.assertEqual(intersect(155.,.002,640.),(500.,640.))
        self.assertEqual(intersect(175.,-.002,640.),(500.,640.))
        self.assertIsNone(intersect(100.,0.,640.))
        self.assertIn("if(direction.y==0.0)",(PREVIEW/"lib/atmosphere/volume.glsl").read_text())

    def test_ssr_fade_is_symmetric(self):
        a=(.7,.4,.2)
        b=(.2,.1,.06)
        for f in (0.,.2,.5,1.):
            for x,y in zip(a,b):
                self.assertAlmostEqual(x*f-y*f,(x-y)*f)
        s=(PREVIEW/"programs/shared/deferred1.fsh.glsl").read_text()
        self.assertIn("specularMetadata.rgb*=reflectionFade",s)
        self.assertIn("specularEnvironment.rgb*=reflectionFade",s)

    def test_night_lut_skip_and_tier_order(self):
        s=(PREVIEW/"lib/lighting/overworld.glsl").read_text()
        self.assertIn("if(physicalWeight>0.0)",s)
        profiles=preview_profiles(PREVIEW)
        tiers=[profiles["profile."+n] for n in ("Potato","Low","Medium","High","Ultra","Extreme")]
        for key in ("SHADOW_MAP","SHADOW_RANGE","VOXEL_GRID_SIZE","WATER_WAVE_DETAIL","SHADOW_FILTER_TAPS","AO_SLICES","WATER_REFLECTION_STEPS"):
            values=[float(p[key]) for p in tiers]
            self.assertEqual(values,sorted(values),key)
        for key in ("DEFERRED_LIGHTING","SCREEN_AO","SOFT_SHADOWS","ADVANCED_WATER","VOLUME_EFFECTS","VOXEL_LIGHTING","SCREEN_GI","PHYSICAL_ATMOSPHERE","MATERIAL_SSR","VOXEL_GI"):
            values=[p[key]=="true" for p in tiers]
            self.assertEqual(values,sorted(values),key)
        self.assertEqual(profiles["profile.Standard"]["AA_MODE"],"0")
        self.assertEqual(len(profiles),10)
