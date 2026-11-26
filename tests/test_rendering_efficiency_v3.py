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
        self.assertIn("colortex9,cloudUv,0.0).a",(S/"lib/post/solar_visibility.glsl").read_text())

    def test_dof_near_coverage_and_hand_depth(self):
        src=(S/"lib/post/dof.glsl").read_text()
        self.assertIn("depthtex2",(S/"lib/post/camera_depth.glsl").read_text())
        self.assertIn("nearTotal",src)
        self.assertIn("-lwCoC(d,focus)",src)

    def test_voxel_history_atlas(self):
        source=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("historyCell=cell+ivec3(0,0,LW_GRID_SIZE)",source)
        self.assertIn("previous.w==frameCounter-1 && withinVoxelGrid(previousLocal)",source)
        self.assertIn("if(wall) value=vec4(0.0)",source)
        self.assertIn(">=LW_VOXEL_WALL",source)
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
            banks=[{(i%n,(i//n)%n,2*n+2*parity+i//(n*n)) for i in range(side**3)} for parity in (0,1)]
            self.assertEqual(len(banks[0]),side**3)
            self.assertEqual(len(banks[1]),side**3)
            self.assertTrue(banks[0].isdisjoint(banks[1]))
            self.assertTrue(all(2*n<=p[2]<2*n+4 for bank in banks for p in bank))
        source=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("if(skipTile)",source)
        self.assertIn("bool fresh=previous.w==frameCounter-1",(S/"lib/voxel/history_tiles.glsl").read_text())
        self.assertIn("!withinVoxelGrid(lo) || !withinVoxelGrid(hi)",(S/"lib/voxel/history_tiles.glsl").read_text())
        self.assertIn("(mask&3u)!=0u",(S/"lib/voxel/history_tiles.glsl").read_text())
        self.assertIn("return prior.g==0.0",(S/"lib/voxel/history_tiles.glsl").read_text())
        self.assertIn("retainHistoryTile(tile,previousSupport)",source)

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
        self.assertIn("flags|=2u",src)
        self.assertIn("sampleVoxelIrradianceSlab(lwVoxelDiffuse,relativePosition,normal,1.05,1)",(S/"lib/voxel/irradiance.glsl").read_text())
        for hz in (30,60,144):
            value=1.
            for _ in range(hz):
                value*=2**(-1/hz/.28)
            self.assertAlmostEqual(value,2**(-1/.28),places=10)

    def test_rain_columns_and_local_relief(self):
        stage=(S/"programs/shared/prepare7.csh.glsl").read_text()
        self.assertIn("LW_RAIN_COLUMN_SLICE",stage)
        self.assertIn("LW_VOXEL_WALL",stage)
        src=(S/"lib/weather/column_height.glsl").read_text()
        self.assertIn("c.x-cell.y",src)
        self.assertIn("known<4.0",src)
        for n in (32,64,96,128):
            self.assertLess(2*n+4,2*n+5)
            self.assertNotIn(2*n+4,range(2*n,2*n+4))
        def retention(center,neighbors):
            if len(neighbors)!=4: return None
            lower=sum(n<center for n in neighbors)
            higher=sum(n>center for n in neighbors)
            return (1-min(1,lower))*(.35+.65*higher/4)
        self.assertEqual(retention(10,[11]*4),1)
        self.assertEqual(retention(10,[9,10,11,11]),0)
        self.assertAlmostEqual(retention(10,[10]*4),.35)
        self.assertIsNone(retention(10,[10,11,10]))

    def test_production_scene_taau_grid(self):
        phases=[(-.375,-.125),(.125,.375),(.375,-.375),(-.125,.125),(.375,.125),(-.125,-.375),(-.375,.375),(.125,-.125)]
        self.assertEqual(tuple(sum(p[i] for p in phases) for i in (0,1)),(0.,0.))
        for display in (1,1919,1920,2161,3840):
            for scale in (50,67,75,85,100):
                low=max(display*scale//100,1)
                for phase in [p[0] for p in phases]:
                    for index in (0,low//2,low-1):
                        uv=(index+.5+phase)/low
                        self.assertAlmostEqual(uv*low-phase-.5,index)
                        self.assertLessEqual(0,int(uv*display))
                        self.assertLess(int(uv*display),display)
        composite=(S/"programs/shared/composite.fsh.glsl").read_text()
        self.assertIn("lwSceneDonorPixel",composite)
        self.assertIn("volumeRay(uv",composite)
        resolve=(S/"programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("lwSceneLowCoord(stableUv",resolve)
        self.assertIn("donorWater!=water",resolve)
        self.assertIn("lwSceneRenderSize(size)",resolve)

    def test_scene_taau_scales_volume_grid_and_readers(self):
        for name,reader in (("composite_a","scatter_upsample"),("composite_b","volume_spatial")):
            self.assertIn("size=lwSceneRenderSize(size)",(S/f"programs/shared/{name}.csh.glsl").read_text())
            self.assertIn("size=lwSceneRenderSize(size)",(S/f"lib/atmosphere/{reader}.glsl").read_text())
        self.assertIn("cloudUv=clamp",(S/"lib/post/solar_visibility.glsl").read_text())

    def test_geometry_taau_presets_and_raster_contract(self):
        from check_shaders import preview_profiles
        profiles=preview_profiles(S)
        expected={"Natural":100,"LowExposure":100,"HighExposure":100,"Potato":100,"Low":100,"Medium":67,"High":75,"Ultra":75,"Extreme":85,"Standard":100}
        self.assertEqual({k.split(".")[1]:int(v["GEOMETRY_TAAU_SCALE"]) for k,v in profiles.items()},expected)
        for width,height in ((1,1),(1919,1079),(1920,1080),(3840,2160)):
            for scale in (50,67,75,85,100):
                for divisor in (1,2,4):
                    for dimension in (width,height):
                        storage=max(dimension//divisor,1)
                        active=max(storage*scale//100,1)
                        for p in (0,active-1):
                            uv=(p+.5)/active
                            self.assertAlmostEqual(uv*active/storage*storage-.5,p)
                            clip=2*uv-1
                            ratio=active/storage
                            self.assertAlmostEqual((clip*ratio+ratio-1)*.5+.5,uv*ratio)
        for stage in ("p1/surface","p5/distant","shared/gbuffers_skybasic"):
            self.assertIn("lwRasterClip",(S/f"programs/{stage}.vsh.glsl").read_text())
            self.assertIn("lwRasterDiscardOutside",(S/f"programs/{stage}.fsh.glsl").read_text())
        for name in ("deferred","deferred1","deferred2","composite"):
            self.assertIn("lwRasterClip",(S/f"programs/shared/{name}.vsh.glsl").read_text())
        resolve=(S/"programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("stableUv+jitterOffset(frameCounter)",resolve)
        self.assertIn("donorWater!=water",resolve)
        self.assertIn("lwRasterSize(colortex0)",resolve)

    def test_every_public_advanced_option_reachable_and_localized(self):
        import re
        from check_shaders import menu_options,properties
        props=S/"shaders.properties"
        cfg=properties(props,"\n".join(l for l in props.read_text().splitlines() if l.startswith(("profile.","screen"))))
        menus,_=menu_options(cfg)
        declarations=(S/"lib/quality.glsl").read_text()+"\n"+(S/"lib/voxel/settings.glsl").read_text()
        public={m.group(1) for m in re.finditer(r"(?m)^(?://)?#define[ \t]+([A-Z0-9_]+)(?:[ \t]+\S+[ \t]+// \[[^\]]+\])?[ \t]*$",declarations) if not m.group(1).startswith("LW_")}
        self.assertFalse(public-menus)
        for lang in ("en_us","zh_cn"):
            localized=properties(S/f"lang/{lang}.lang")
            self.assertFalse({f"option.{n}" for n in public}-localized.keys())

    def test_geometry_temporal_volume_reprojection(self):
        self.assertIn("uv+=jitterOffset(frameCounter-1)",(S/"lib/atmosphere/volume_temporal.glsl").read_text())
        for name in ("composite_a","composite_b"):
            source=(S/f"programs/shared/{name}.csh.glsl").read_text()
            self.assertEqual(source.count("const vec2 workGroupsRender"),5)

    def test_fixed_geometry_jitter_and_settled_tiles(self):
        source=(S/"lib/coordinates/raster_grid.glsl").read_text()
        self.assertIn("PROJECTION_JITTER == 1",source)
        self.assertIn("return vec2(0.0);",source)
        stage=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("float(transitioning)",stage)
        self.assertIn("if(diffusePending) flags|=8u",stage)
        self.assertIn("packHalf2x16",stage)
        self.assertIn("retainHistoryTile(tile,previousSupport)",stage)
        for changed in (0,1,2,3):
            for pending in (0,1,2,3):
                for stationary in (False,True):
                    skip=stationary and not changed and not pending
                    self.assertEqual(skip,stationary and changed==pending==0)
        resolve=(S/"programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("ivec2 outputPixel=ivec2(gl_FragCoord.xy)",resolve)
        self.assertIn("all(equal(donor,pixel))",resolve)

    def test_settled_lighting_fast_paths(self):
        source=(S/"programs/shared/prepare6.csh.glsl").read_text()
        self.assertIn("if(all(equal(old,target)))",source)
        self.assertIn("directDecay=exp2(-dt/vec2",source)
        self.assertIn("diffuseDecay=exp2(-dt/vec2",source)
        self.assertIn("uint occupied = imageLoad(lwVoxelDirtyTiles,tile).r",(S/"programs/shared/prepare8.csh.glsl").read_text())
        self.assertIn("min(now,old)*1.01395948",(S/"programs/shared/composite1.fsh.glsl").read_text())
