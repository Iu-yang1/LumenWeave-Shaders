import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = ROOT / "shaders"
sys.path.insert(0, str(ROOT / "tools"))
from generate_water_normal import generate

class RenderingEfficiencyTests(unittest.TestCase):
    def test_water_asset_reproducible_and_periodic(self):
        data = generate()
        self.assertEqual(data, (S/"textures/water_normal.rg8").read_bytes())
        self.assertEqual(len(data), 66*66*2)
        for y in range(66):
            row=data[y*132:(y+1)*132]
            self.assertEqual(row[:2],row[128:130])
            self.assertEqual(row[2:4],row[130:132])
        self.assertEqual(data[:132],data[64*132:65*132])
        self.assertEqual(data[132:264],data[65*132:])
        self.assertNotIn("noisetex",(S/"lib/water/waves.glsl").read_text())

    def test_wet_gi_and_transmission_contract(self):
        self.assertIn("wetSurface(albedo,source",(S/"lib/lighting/screen_gi.glsl").read_text())
        self.assertIn("wetSurface(bounceAlbedo",(S/"programs/shared/deferred1.fsh.glsl").read_text())
        self.assertIn("smoothstep(0.02,0.30,above)",(S/"lib/water/screen_space.glsl").read_text())

    def test_exposure_state_coherence(self):
        source=(S/"programs/shared/composite4.csh.glsl").read_text()
        self.assertIn("vec4(next,old,glare,target)",source)
        self.assertIn("terrainWeight",source)
        self.assertIn("return state.g",(S/"lib/post/exposure.glsl").read_text())
        self.assertIn("LW_EXPOSURE_FINAL",(S/"programs/shared/final.fsh.glsl").read_text())
        self.assertIn("colortex9,sampleUv,0.0).a",(S/"lib/post/solar_visibility.glsl").read_text())

    def test_dof_near_coverage_and_hand_depth(self):
        src=(S/"lib/post/dof.glsl").read_text()
        self.assertIn("depthtex2",src)
        self.assertIn("nearTotal",src)
        self.assertIn("-lwCoC(d,focus)",src)
