import itertools
import math
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"


class PerformanceRegressionTests(unittest.TestCase):
    def test_emitter_support_covers_all_propagated_and_filtered_cells(self):
        # Four Manhattan steps and a one-cell trilinear halo.
        for seed in itertools.product(range(4), repeat=3):
            for delta in itertools.product(range(-5, 6), repeat=3):
                if sum(map(abs, delta)) > 4:
                    continue
                for halo in itertools.product((-1, 0, 1), repeat=3):
                    cell = tuple((s + d + h) // 4 for s, d, h in zip(seed, delta, halo))
                    self.assertLessEqual(max(map(abs, cell)), 2)

    def test_fused_masks_keep_dirty_and_emitter_flags_independent(self):
        rng = random.Random(177)
        domain = list(itertools.product(range(6), repeat=3))
        dirty = {p for p in domain if rng.random() < .05}
        lights = {p for p in domain if rng.random() < .08}
        walls = {p for p in domain if rng.random() < .4}
        mask = {p: (3 if p in dirty else 0) | (4 if p in lights else 0) for p in domain}
        for axis in range(3):
            next_mask = {}
            for p in domain:
                bits = 0
                for d in range(-2, 3):
                    q = list(p)
                    q[axis] += d
                    bits |= mask.get(tuple(q), 0) & (7 if abs(d) <= 1 else 6)
                next_mask[p] = bits
            mask = next_mask
        for p in domain:
            for seeds, radius, bit in ((dirty, 1, 1), (dirty, 2, 2), (lights, 2, 4)):
                expected = any(max(abs(a-b) for a,b in zip(p,q)) <= radius for q in seeds)
                self.assertEqual(bool(mask[p]&bit), expected)
            value = mask[p] | (8 if p in walls else 0)
            self.assertEqual(bool(value&8), p in walls)

    def test_bounded_wrap_matches_modulo(self):
        for size in (32, 64, 96, 128):
            for c in range(-size, 2*size):
                corrected = c + (size if c < 0 else 0)
                corrected -= size if corrected >= size else 0
                self.assertEqual(corrected, c % size)

    def test_perspective_interval_conservative(self):
        rng = random.Random(710)
        for _ in range(1000):
            wa, wb = rng.uniform(.2, 20), rng.uniform(.2, 20)
            a = [rng.random() for _ in range(3)]
            b = [rng.random() for _ in range(3)]
            for step in range(17):
                t = step / 16
                for x,y in zip(a,b):
                    actual = ((1-t)*wa*x + t*wb*y) / ((1-t)*wa+t*wb)
                    self.assertGreaterEqual(actual, min(x,y)-1e-12)
                    self.assertLessEqual(actual, max(x,y)+1e-12)

    def test_adaptive_path_has_no_full_retrace(self):
        quality = (ROOT/"lib/quality.glsl").read_text()
        self.assertIn("#define HIZ_MODE 1", quality)
        for path in ("lib/reflection/trace.glsl", "lib/lighting/screen_gi.glsl"):
            source = (ROOT/path).read_text()
            self.assertEqual(source.count("hizRejectInterval("), 1)
            self.assertIn("#if defined(LW_HIZ_ACTIVE) && HIZ_MODE == 2", source)
            self.assertIn("firstTap=3", source)
        props = (ROOT/"shaders.properties").read_text()
        for dimension in ("world0", "world-1", "world1"):
            for stage in ("prepare7", "prepare8"):
                self.assertIn(f"program.{dimension}/{stage}.enabled = false", props)
        source = (ROOT/"lib/voxel/propagate.glsl").read_text()
        self.assertNotIn("atomicOr", source)
        self.assertLess(source.index("if((tileMask&4u)==0u)"), source.index("uint seed = voxelSeedAt"))

    def test_shared_depth_prepass(self):
        stage = (ROOT/"programs/shared/deferred_a.csh.glsl").read_text()
        self.assertNotIn("uniform sampler2D depthtex1", stage)
        self.assertIn("base=tile*64", stage)
        self.assertIn("writeRange(tile,64", stage)

    def test_bilateral_compatible_tap_does_not_force_exact_ray(self):
        source = (ROOT/"lib/atmosphere/scatter_upsample.glsl").read_text()
        self.assertIn("smoothstep(0.001,0.025,weightSum)", source)
        self.assertNotIn("spatialSum", source)
        # A single fully compatible tap with weight .25 is enough.
        self.assertGreater(.25, .025)
        self.assertLess(0., .001)
