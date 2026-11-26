import math
import random
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))

from atmosphere_lut_reference import (GROUND,TOP,make_transmittance,make_multiscattering,
    make_sky_view,make_aerial,optical_transmission,ray_boundary,phase_rayleigh,phase_mie)
from voxel_incremental_reference import IncrementalVoxelCache,full_rebuild


class AtmosphereReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.trans = make_transmittance(12,8,32)
        cls.multi = make_multiscattering(cls.trans,6,5,12,12)

    def test_spherical_ground_and_top(self):
        self.assertAlmostEqual(ray_boundary(GROUND+1,1)[0],TOP-GROUND-1)
        self.assertTrue(ray_boundary(GROUND+1,-1)[1])
        self.assertEqual(optical_transmission(GROUND+1,-1),(0,0,0))

    def test_spectral_transmission(self):
        rgb = optical_transmission(GROUND+0.2,1)
        self.assertTrue(0 < rgb[2] < rgb[1] < rgb[0] < 1)
        self.assertGreater(optical_transmission(GROUND+30,1)[2],rgb[2])
        self.assertGreater(phase_mie(1),phase_mie(0))
        self.assertAlmostEqual(phase_rayleigh(1),phase_rayleigh(-1))

    def test_lut_values_and_zero_distance(self):
        sky = make_sky_view(GROUND+0.2,0.6,self.trans,self.multi,8,5,12)
        self.assertTrue(all(math.isfinite(c) and c>=0 for value in sky.values for c in value))
        self.assertTrue(any(c>0 for value in self.multi.values for c in value))
        aerial = make_aerial(GROUND+0.2,0.6,self.trans,self.multi,6,5,5,8,12)
        self.assertEqual(aerial["inscatter_rgb"][:30],[(0,0,0)]*30)
        self.assertEqual(aerial["transmittance_rgb"][:30],[(1,1,1)]*30)
        for column in range(30):
            previous = (1,1,1)
            for z in range(1,5):
                value = aerial["transmittance_rgb"][z*30+column]
                self.assertTrue(all(0<=x<=y+1e-5 for x,y in zip(value,previous)))
                previous = value


class IncrementalVoxelTests(unittest.TestCase):
    def test_stationary_delete_wall_and_scroll(self):
        emitters = {(3,3,3):(1,0.3,0),(5,3,3):(0,0.4,1)}
        walls = {(4,3,3)}
        cache = IncrementalVoxelCache((0,0,0),9,emitters,walls,4)
        stats = cache.update((0,0,0),emitters,walls)
        self.assertEqual(sum(stats["evaluations_by_stage"]),0)
        del emitters[(3,3,3)]
        stats = cache.update((0,0,0),emitters,walls)
        self.assertLess(sum(stats["evaluations_by_stage"]),stats["full_evaluations"])
        self.assertEqual(cache.stages,full_rebuild((0,0,0),9,emitters,walls,4))
        walls.clear()
        cache.update((1,0,0),emitters,walls)
        self.assertEqual(cache.stages,full_rebuild((1,0,0),9,emitters,walls,4))
        emitters.clear()
        cache.update((1,0,0),emitters,walls)
        self.assertTrue(all(value==(0,0,0) for value in cache.stages[-1].values()))

    def test_randomized_edits_and_grid_translation(self):
        rng = random.Random(20261126)
        origin = (0,0,0)
        emitters,walls = {},set()
        cache = IncrementalVoxelCache(origin,7,emitters,walls,4)
        for i in range(20):
            cell = tuple(rng.randrange(-2,9) for _ in range(3))
            if i%3==0:
                emitters[cell]=(1,0.3,0.2)
            elif i%3==1:
                emitters.pop(cell,None)
                walls.add(cell)
            else:
                walls.discard(cell)
                origin=(rng.randrange(-2,3),0,0)
            cache.update(origin,emitters,walls)
            self.assertEqual(cache.stages,full_rebuild(origin,7,emitters,walls,4))


class AdvancedShaderContracts(unittest.TestCase):
    def test_ssr_replaces_environment(self):
        source = (ROOT/"shaders/programs/shared/deferred2.fsh.glsl").read_text()
        self.assertIn("filtered*metadata.rgb-fallback",source)
        self.assertIn("temporalReflectionCorrection",source)
        self.assertIn("LW_REFLECTION_DH_DEPTH dhDepthTex0",source)
        self.assertIn("LW_REFLECTION_DEPTH depthtex0",source)

    def test_advanced_budget(self):
        props = (ROOT/"shaders/shaders.properties").read_text()
        self.assertIn("dhShadow.enabled = true",props)
        for line in props.splitlines():
            if line.startswith("profile."):
                enabled=line.startswith(("profile.Ultra =","profile.Extreme ="))
                tokens=set(line.split())
                for feature in ("DH_SHADOWS","MATERIAL_SSR","PHYSICAL_ATMOSPHERE","INCREMENTAL_VOXELS"):
                    self.assertIn(feature if enabled else "!"+feature,tokens)
                self.assertIn("PROJECTION_JITTER:"+("1" if line.startswith(("profile.Medium =","profile.High =","profile.Ultra =","profile.Extreme =")) else "0"),tokens)

    def test_dh_deferred_direct_only_shadow(self):
        lighting=(ROOT/"shaders/lib/lighting/dh_terrain_shadows.glsl").read_text()
        self.assertIn("celestialIrradiance(sun)*direct*shadow/LW_PI",lighting)
        self.assertIn("shadow*=mix(farShadow,1.0,coverage)",lighting)
        self.assertIn("dhProjection*vec4(ray,1.0)",lighting)
        self.assertIn("depthPixelAtUv(dhDepthTex0,uv)",lighting)
        deferred=(ROOT/"shaders/programs/shared/deferred1.fsh.glsl").read_text()
        self.assertIn("opaqueScene=vec4(distantLit,scene.a)",deferred)
