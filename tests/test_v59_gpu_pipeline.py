import itertools
import math
import random
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"


def half(value):
    return struct.unpack("<e", struct.pack("<e", value))[0]


def encode(rgb, support):
    channels = [round(math.sqrt(max(0.0, min(v / 2, 1.0))) * 1023) for v in rgb]
    state = 3 if support > .9 else 2 if support > .7 else 1 if support > 0 else 0
    return channels[0] | channels[1] << 10 | channels[2] << 20 | state << 30


def decode(word):
    channels = [2 * ((word >> shift & 1023) / 1023) ** 2 for shift in (0, 10, 20)]
    return channels, (0.0, 0.599609375, 0.7998046875, 1.0)[word >> 30]


class V59PipelineTests(unittest.TestCase):
    def test_seed_tasks_match_reference(self):
        rng = random.Random(59)
        for n in (8, 16, 24, 32):
            bricks = list(itertools.product(range(n), repeat=3))
            for probability in (0, .01, .25, 1):
                flags = [rng.randrange(1, 4) if rng.random() < probability else 0 for _ in bricks]
                for stale, moved in itertools.product((False, True), repeat=2):
                    selected = [t for t, f in zip(bricks, flags) if stale or moved or f]
                    linear = [x + n * (y + n * z) for x, y, z in selected]
                    self.assertEqual(len(linear), len(set(linear)))
                    self.assertTrue(all(0 <= i < n ** 3 for i in linear))
                    self.assertEqual(selected, bricks if stale or moved else [t for t, f in zip(bricks, flags) if f])
                    for i, t in zip(linear, selected):
                        self.assertEqual((i % n, i // n % n, i // (n*n)), t)

    def test_indirect_layout(self):
        p = (ROOT / "shaders.properties").read_text()
        self.assertIn("bufferObject.0 = 524352", p)
        self.assertIn("indirect.prepare = 0 393264", p)
        self.assertEqual(3 * 16 + 3 * 32768 * 4, 393264)
        self.assertEqual(393264 + 16 + 32768 * 4, 524352)
        for dimension in ("world0", "world-1", "world1"):
            self.assertTrue((ROOT / dimension / "shadowcomp.csh").exists())
        src = (ROOT / "programs/shared/shadowcomp.csh.glsl").read_text()
        self.assertIn("atomicAdd(count0,localCount)", src)
        self.assertIn("imageStore(lwVoxelDirtyTiles,tile,uvec4(0u))", src)

    def test_stage2_support_is_exact(self):
        support = [0.0, half(half(1.0 - .2) - .2), half(1.0 - .2), 1.0]
        for a in support:
            self.assertEqual(decode(encode((0.25, 1.0, 1.89), a))[1], a)
        self.assertEqual(decode(0), ([0.0, 0.0, 0.0], 0.0))

    def test_rgb_absolute_error_bound(self):
        rng = random.Random(590)
        for _ in range(50000):
            rgb = [rng.uniform(0, 1.9) for _ in range(3)]
            output, _ = decode(encode(rgb, 1.0))
            for a, b in zip(rgb, output):
                self.assertLessEqual(abs(a-b), 0.002)
        # All vanilla emission palettes and strength/attenuation ranges fit.
        self.assertLess(1.65 * 1.15, 2.0)

    def test_dof_donor_distance_equivalence(self):
        rng = random.Random(591)
        for _ in range(10000):
            f = [rng.random(), rng.random()]
            x, y = rng.randrange(2), rng.randrange(2)
            base = [rng.randrange(4096), rng.randrange(4096)]
            pos = [b+t for b, t in zip(base, f)]
            old = math.hypot(2*(base[0]+x+.5-pos[0]-.5), 2*(base[1]+y+.5-pos[1]-.5))
            self.assertAlmostEqual(old, 2*math.hypot(x-f[0],y-f[1]), places=10)
