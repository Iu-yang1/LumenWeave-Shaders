import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"


class DimensionLightingTests(unittest.TestCase):
    def test_blocklight_contrast(self):
        source = (ROOT / "lib/lighting/overworld.glsl").read_text()
        self.assertIn("x*x*(0.20 + 1.60*x)", source)
        values = [x*x*(0.20 + 1.60*x) for x in (i/15 for i in range(16))]
        self.assertEqual(values[0], 0.0)
        self.assertTrue(all(a < b for a, b in zip(values, values[1:])))
        self.assertLess(values[5], (5/15)**2)
        self.assertAlmostEqual(values[-1], 1.8)
        self.assertIn("blockLightIrradiance(lightLevels.x)", (ROOT / "lib/lighting/surface.glsl").read_text())

    def test_emitter_headroom_and_lava_path(self):
        palette = (ROOT / "lib/lighting/emitter_palette.glsl").read_text()
        self.assertIn("if (kind==5u) return 3.8;", palette)
        self.assertIn("kind==6u", palette)
        surface = (ROOT / "programs/p1/surface.fsh.glsl").read_text()
        lava = surface.split("if (blockId == 10015)", 1)[1].split("radiance = surfaceRadiance", 1)[0]
        self.assertIn("min(WATER_REFLECTION_STEPS,8)", lava)
        self.assertIn("lit - fallback.rgb", lava)
        self.assertIn("applySceneFog(lit,lavaPosition)", lava)
        self.assertNotIn("physicalWater(", lava)
        self.assertIn("specularEnvironment = vec4(environmentContribution,1.0)", (ROOT / "lib/lighting/surface.glsl").read_text())
        reflectance = [min(.045 + .955 * (1 - x/100)**5, .42) for x in range(101)]
        self.assertTrue(all(.045 <= v <= .42 for v in reflectance))
        self.assertTrue(all(a >= b for a, b in zip(reflectance, reflectance[1:])))

    def test_dimension_fog_optical_depth(self):
        source = (ROOT / "lib/lighting/fog.glsl").read_text()
        density_source = (ROOT / "lib/lighting/overworld.glsl").read_text()
        self.assertIn("mix(0.012, 0.027, horizon)", density_source)
        self.assertIn("mix(0.0035, 0.010, horizon)", density_source)
        self.assertIn("dimensionFogDensity(direction)", source)
        self.assertIn("opticalDepth = distanceToEye * density;", source)
        self.assertIn("skyRadiance(direction, sunDirection())", source)
        self.assertIn("isEyeInWater == 0 && !hasSkylight", source)
        for density in (.012, .027, .0035, .010):
            trans = [math.exp(-max(d - 5, 0)*density) for d in (0, 5, 16, 32, 64, 128)]
            self.assertEqual(trans[:2], [1, 1])
            self.assertTrue(all(a >= b > 0 for a, b in zip(trans, trans[1:])))
        self.assertLess(math.exp(-59*.027), math.exp(-59*.010))

    def test_gi_nonnegative_ambient(self):
        source = (ROOT / "lib/lighting/screen_gi.glsl").read_text()
        self.assertIn("vec3(ambientFloor())", source)
        self.assertIn("vec3(0.0));", source)
