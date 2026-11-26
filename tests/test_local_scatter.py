import itertools
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"


def integrate(distance, radius, extinction, sample, cap=24, glow=1.7, softness=0.0):
    end = min(max(distance - .08, 0.), radius - 1.)
    if end <= .001 or extinction <= 0.:
        return (0., 0., 0.), 0
    steps = max(1, min(cap, math.ceil(end / 1.5)))
    dt = end / steps
    segment = math.exp(-extinction * dt)
    weight = (1. - segment) * .75 * .90 * glow
    result = [0., 0., 0.]
    through = 1.
    for i in range(steps):
        light = sample((i + .5) * dt)
        for c in range(3):
            result[c] += light[c] * weight * through
        through *= segment
    peak=max(result)
    return tuple(v/(1+softness*.65*peak) for v in result), steps


class LocalScatterTests(unittest.TestCase):
    def test_homogeneous_source_exact_integral(self):
        for density in (.0035, .006, .010, .027):
            for distance in (.5, 2., 8., 20., 45., 100.):
                actual, steps = integrate(distance, 48., density, lambda t: (1., .3, .1))
                expected = .75 * .90 * 1.7 * (1. - math.exp(-density * min(distance - .08, 47.)))
                for a, c in zip(actual, (1., .3, .1)):
                    self.assertAlmostEqual(a, expected*c, places=12)
                self.assertLessEqual(steps, 24)

    def test_depth_occlusion_and_color(self):
        red = lambda t: (1., .23, .038) if 7. <= t <= 10. else (0., 0., 0.)
        blue = lambda t: (.14, .70, 1.) if 7. <= t <= 10. else (0., 0., 0.)
        self.assertEqual(integrate(6., 48., .027, red)[0], (0., 0., 0.))
        r, n = integrate(12., 48., .027, red)
        b, _ = integrate(12., 48., .027, blue)
        self.assertGreater(r[0], r[2])
        self.assertGreater(b[2], b[0])
        self.assertLess(n, 24)
        self.assertEqual(integrate(50., 48., .027, lambda t: (0., 0., 0.))[0], (0., 0., 0.))
        self.assertEqual(integrate(50., 48., 0., red)[1], 0)
        self.assertEqual(integrate(.05, 48., .027, red)[1], 0)

    def test_storage_neighbour_wrap_equivalence(self):
        for size in (32, 64, 96, 128):
            coords = (0, 1, size//2, size-2, size-1)
            for local, origin in itertools.product(coords, repeat=2):
                for delta in (-1, 1):
                    if not 0 <= local + delta < size:
                        continue
                    storage = (local + origin) % size
                    wrapped = storage + delta
                    if wrapped < 0:
                        wrapped += size
                    if wrapped >= size:
                        wrapped -= size
                    self.assertEqual(wrapped, (local + delta + origin) % size)

    def test_gpu_contract(self):
        source = (ROOT / "lib/atmosphere/local_scatter.glsl").read_text()
        self.assertIn("surfaceDistance - 0.08", source)
        self.assertIn("radius - 1.0", source)
        self.assertIn("clamp(int(ceil(end / 1.5)), 1, 24)", source)
        self.assertIn("transmission *= segmentTransmission", source)
        self.assertIn("sampleLightRgbaAtOrigin", source)
        self.assertIn("tile+ivec3(32,0,0)",source)
        comp = (ROOT / "programs/shared/composite.fsh.glsl").read_text()
        self.assertIn("scene.rgb += integrateLocalScatter", comp)
        self.assertIn("isEyeInWater == 0", comp)
        self.assertIn("dhDepthTex0", (ROOT / "lib/atmosphere/volume_depth.glsl").read_text())
        fog = (ROOT / "lib/lighting/fog.glsl").read_text()
        self.assertIn("#ifndef LW_LOCAL_SCATTER_ACTIVE", fog)
        self.assertIn("opticalDepth = distanceToEye * density", fog)
        ao = (ROOT / "lib/lighting/gtao.glsl").read_text()
        self.assertIn("-position.z >= 52.0 || AO_STRENGTH == 0.0", ao)
        prop = (ROOT / "lib/voxel/propagate.glsl").read_text()
        self.assertIn("stencilIndex(local+LW_VOXEL_DIRECTIONS[stepIndex])", prop)
        self.assertIn("voxelTileMask(tile)", prop)
        shadow = (ROOT / "programs/shared/shadow.vsh.glsl").read_text()
        self.assertLess(shadow.index("injectTerrainVoxel(position.xyz)"), shadow.index("gl_Position = vec4(2.0"))
        self.assertLess(shadow.index("gl_Position = vec4(2.0"), shadow.index("vegetationDisplacement("))
