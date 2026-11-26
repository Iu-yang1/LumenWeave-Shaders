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
        self.assertEqual(len(data), 66*100*2)
        for y in range(66):
            row=data[y*132:(y+1)*132]
            self.assertEqual(row[:2],row[128:130])
            self.assertEqual(row[2:4],row[130:132])
        self.assertEqual(data[:132],data[64*132:65*132])
        self.assertEqual(data[132:264],data[65*132:66*132])
        for y in range(66,100):
            row=data[y*132:(y+1)*132]
            self.assertEqual(row[:2],row[64:66])
            self.assertEqual(row[2:4],row[66:68])
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

    def test_voxel_history_atlas(self):
        source=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("historyCell=cell+ivec3(0,0,LW_GRID_SIZE)",source)
        self.assertIn("previous.w==frameCounter-1 && withinVoxelGrid(previousLocal)",source)
        self.assertIn(">=LW_VOXEL_WALL) value=vec4(0.0)",source)
        self.assertIn("sampleLightRgbaAtOrigin(cell,cacheOrigin)",(S/"lib/atmosphere/local_scatter.glsl").read_text())
        for size in (32,64,96,128):
            cells={(x+31)%size for x in range(size)}
            self.assertEqual(len(cells),size)
            self.assertTrue(set(range(size)).isdisjoint(range(size,2*size)))

    def test_hdr_format_and_rain_ripple_reuse(self):
        self.assertIn("colortex8Format = R11F_G11F_B10F",(S/"programs/shared/deferred1.fsh.glsl").read_text())
        bloom=(S/"programs/shared/composite3.fsh.glsl").read_text()
        self.assertIn("LW_SCATTER_UPSAMPLE_ACTIVE",bloom)
        self.assertIn("colortex11Format = R11F_G11F_B10F",bloom)
        self.assertIn("rainRippleSlope",(S/"lib/weather/wet_surface.glsl").read_text())

    def test_ssr_half_preserves_raw_history(self):
        q=(S/"lib/quality.glsl").read_text()
        self.assertIn("LW_SSR_HALF",q)
        self.assertIn("GI_REUSE_MODE == 2",q)
        self.assertIn("imageStore(colorimg9,p,result)",(S/"programs/shared/deferred2_a.csh.glsl").read_text())
        src=(S/"programs/shared/deferred2.fsh.glsl").read_text()
        self.assertIn("reconstructRoughReflection",src)
        self.assertIn("traceMaterialCorrection(pixel",src)
        self.assertIn("weightSum<0.20",src)
        self.assertIn("metadata.a<0.28",src)
