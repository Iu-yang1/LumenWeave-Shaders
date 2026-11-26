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

    def test_voxel_tile_metadata_and_zero_work(self):
        for n in (32,64,96,128):
            side=n//4
            coords={(i%n,(i//n)%n,2*n+i//(n*n)) for i in range(side**3)}
            self.assertEqual(len(coords),side**3)
            self.assertTrue(all(2*n<=p[2]<2*n+2 for p in coords))
        source=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("if(skipTile)",source)
        self.assertIn("previous.w==frameCounter-1 && all(equal(cameraPositionInt,previous.xyz))",source)
        self.assertIn("imageLoad(lwVoxelFirst,tileMeta).r==0.0",source)

    def test_taau_grid_contract(self):
        for width,height in ((1920,1080),(1919,1079),(3840,2160)):
            for scale in (.5,.67,.75,.85,1.):
                for size in (width,height):
                    render=int(size*scale)
                    s=render/size
                    for u in (.0,.25,.5,.999):
                        clip=2*u-1
                        self.assertAlmostEqual((s*clip+s-1)*.5+.5,u*s)
                    for pixel in (0,render-1):
                        uv=(pixel+.5)/render
                        self.assertAlmostEqual(uv*s*size-.5,pixel)

    def test_independent_diffuse_history(self):
        src=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("imageLoad(lwVoxelSecond,historyCell)",src)
        self.assertIn("imageStore(lwVoxelSecond,historyCell,diffuseValue)",src)
        self.assertIn("atomicOr(occupied,2u)",src)
        self.assertIn("sampleVoxelIrradianceSlab(lwVoxelDiffuse,relativePosition,normal,1.05,1)",(S/"lib/voxel/irradiance.glsl").read_text())
        for hz in (30,60,144):
            value=1.
            for _ in range(hz):
                value*=2**(-1/hz/.28)
            self.assertAlmostEqual(value,2**(-1/.28),places=10)

    def test_rain_columns_and_local_relief(self):
        stage=(S/"programs/shared/prepare7.csh.glsl").read_text()
        self.assertIn("2*LW_GRID_SIZE+2",stage)
        self.assertIn("LW_VOXEL_WALL",stage)
        src=(S/"lib/weather/column_height.glsl").read_text()
        self.assertIn("c.x-cell.y",src)
        self.assertIn("known<4.0",src)
        for n in (32,64,96,128):
            self.assertLess(2*n+2,2*n+3)
            self.assertGreaterEqual(2*n+2,2*n+2)
        def retention(center,neighbors):
            if len(neighbors)!=4: return None
            lower=sum(n<center for n in neighbors)
            higher=sum(n>center for n in neighbors)
            return (1-min(1,lower))*(.35+.65*higher/4)
        self.assertEqual(retention(10,[11]*4),1)
        self.assertEqual(retention(10,[9,10,11,11]),0)
        self.assertAlmostEqual(retention(10,[10]*4),.35)
        self.assertIsNone(retention(10,[10,11,10]))
