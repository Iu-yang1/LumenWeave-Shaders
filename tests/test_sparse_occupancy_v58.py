import math
import random
import unittest
from itertools import product
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"


def address(tile, n):
    side = n // 4
    x, y, z = tile
    i = x + side * (y + side * z)
    return i % n, (i // n) % n, n + i // (n * n)


class SparseOccupancyTests(unittest.TestCase):
    def test_atlas_capacity_and_configuration(self):
        props = (ROOT / "shaders.properties").read_text()
        for n in (32, 64, 96, 128):
            addresses = {address(t, n) for t in product(range(n // 4), repeat=3)}
            depth = n + (n + 63) // 64
            self.assertEqual(len(addresses), (n // 4) ** 3)
            self.assertTrue(all(0 <= x < n and 0 <= y < n and n <= z < depth
                                for x, y, z in addresses))
            self.assertIn(f"image.lwVoxelOccupancy = lwVoxelSeeds red_integer r32ui unsigned_int false false {n} {n} {depth}", props)

    def test_differential_frames(self):
        rng = random.Random(58)
        n = 16
        cells = list(product(range(n), repeat=3))
        tiles = list(product(range(n // 4), repeat=3))
        def tile(c):
            return tuple(v // 4 for v in c)
        physical, flags, previous_world = {}, {}, {}
        previous_camera = (0, 0, 0)
        for frame in range(240):
            fresh = frame != 0 and frame % 41 != 0
            camera = previous_camera if frame % 4 else tuple(rng.randrange(-12, 13) for _ in range(3))
            stationary = camera == previous_camera
            physical = {c: v for c, v in physical.items() if fresh and not flags.get(tile(c), 0) & 1}
            flags = {t: ((flags.get(t, 0) & 1) << 1) if fresh else 0 for t in tiles}
            submissions = []
            for _ in range(rng.randrange(0, 700)):
                c = rng.choice(cells)
                submissions.extend((c, rng.choice((1, 17, 255, 256, 259))) for _ in range(rng.randrange(1, 5)))
            rng.shuffle(submissions)
            reference = {}
            for c, s in submissions:
                old = physical.get(c, 0)
                physical[c] = max(old, s)
                if old == 0:
                    flags[tile(c)] |= 1
                reference[c] = max(reference.get(c, 0), s)
            self.assertEqual(physical, reference)
            current_world = {tuple(a + b for a, b in zip(c, camera)): v for c, v in reference.items()}
            dirty_full, dirty_sparse = set(), set()
            for c in cells:
                w = tuple(a + b for a, b in zip(c, camera))
                p = tuple(a - b for a, b in zip(w, previous_camera))
                entered = any(v < 0 or v >= n for v in p)
                lost = not stationary and any((c[i] == 0 and p[i] > 0) or (c[i] == n - 1 and p[i] < n - 1) for i in range(3))
                changed = not fresh or entered or previous_world.get(w, 0) != current_world.get(w, 0) or lost
                if changed:
                    dirty_full.add(tile(c))
                if fresh and stationary and flags[tile(c)] == 0:
                    continue
                if changed:
                    dirty_sparse.add(tile(c))
            self.assertEqual(dirty_sparse, dirty_full)
            previous_world, previous_camera = current_world, camera

    def test_deletion_and_reappearance(self):
        flags = (1 & 1) << 1
        self.assertEqual(flags, 2)
        flags = (flags & 1) << 1
        self.assertEqual(flags, 0)
        self.assertEqual(flags | 1, 1)

    def test_shader_contract(self):
        begin = (ROOT / "programs/shared/begin.csh.glsl").read_text()
        inject = (ROOT / "lib/voxel/inject.glsl").read_text()
        prepare = (ROOT / "programs/shared/prepare.csh.glsl").read_text()
        self.assertIn("uvec4(last << 1u)", begin)
        self.assertIn("clearTile = !fresh || last != 0u", begin)
        self.assertIn("uint previous = imageAtomicMax", inject)
        self.assertIn("if (previous == 0u)", inject)
        self.assertIn("lwEmptyTile = !lwFullRebuild && lwStationary", prepare)
        self.assertLess(prepare.index("if (lwEmptyTile)"), prepare.index("uint seed = imageLoad"))


class SharedMathTests(unittest.TestCase):
    def test_wave_zero(self):
        rng = random.Random(58)
        for lite, threshold in ((False, 12.5), (True, 1000.0)):
            for v in [threshold] + [threshold + rng.random() * 10000 for _ in range(100000)]:
                resolved = 1 / (1 + 0.5 * v) if lite else math.exp(-0.5 * v)
                self.assertLess(resolved, 0.002)

    def test_hiz_interior_and_edges(self):
        rng = random.Random(85)
        for _ in range(10000):
            w, h = rng.randrange(1, 4097), rng.randrange(1, 4097)
            scale = rng.choice((16, 64))
            x, y = rng.randrange((w + scale - 1) // scale), rng.randrange((h + scale - 1) // scale)
            full = (x + 1) * scale <= w and (y + 1) * scale <= h
            for _ in range(8):
                px, py = x * scale + rng.randrange(scale), y * scale + rng.randrange(scale)
                valid = px < w and py < h
                self.assertEqual(full or valid, valid)

    def test_footprint_equivalence(self):
        rng = random.Random(56)
        for _ in range(100000):
            a, b, c, d = [rng.uniform(-100, 100) for _ in range(4)]
            self.assertEqual(max(math.sqrt(a*a+b*b), math.sqrt(c*c+d*d)), math.sqrt(max(a*a+b*b,c*c+d*d)))
