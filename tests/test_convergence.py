import csv
import math
import random
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from summarize_gpu_stages import summarize


class ConvergenceTests(unittest.TestCase):
    def test_post_stages_produce_hdr_owner_varying(self):
        root = Path(__file__).resolve().parents[1] / "shaders/programs/shared"
        for stage in ("composite3", "composite5"):
            self.assertIn('/programs/shared/final.vsh.glsl', (root / f"{stage}.vsh.glsl").read_text(encoding="utf-8"))
        source = (root / "final.vsh.glsl").read_text(encoding="utf-8")
        self.assertIn("flat out int lwPostHistory", source)
        self.assertIn("lwPostHistory=lwMotionIsIdentity()?1:0", source)

    def test_sun_phase_distinguishes_equal_altitude(self):
        for angle in (-2.8, -1.2, -0.3, 0.3, 1.2, 2.8):
            altitude = math.sin(angle)
            horizontal = math.cos(angle)
            phase = math.atan2(altitude, horizontal)
            self.assertAlmostEqual(math.sin(phase), altitude)
            self.assertAlmostEqual(math.cos(phase), horizontal)
        self.assertGreater(abs(math.atan2(.5, .866) - math.atan2(.5, -.866)), .004)
        difference = abs((math.pi - .001) - (-math.pi + .001))
        self.assertAlmostEqual(min(difference, 2 * math.pi - difference), .002)

    def test_roughness_variance_preserves_flat_and_bounds_glints(self):
        rng = random.Random(20261127)
        for _ in range(10000):
            roughness = rng.uniform(.04, 1)
            variance = rng.uniform(0, 2)
            filtered = min(roughness ** 4 + variance, 1) ** .25
            self.assertGreaterEqual(filtered, roughness - 1e-12)
            self.assertLessEqual(filtered, 1)
            self.assertAlmostEqual((roughness ** 4) ** .25, roughness)

    def test_zero_energy_ray_tail_is_pruned(self):
        travel = .16
        taps = []
        for _ in range(8):
            taps.append(travel)
            travel = travel * 1.32 + .16
        self.assertEqual(sum(distance < 3.9 for distance in taps), 7)
        for distance in taps:
            fade = max(0, min(1, (distance - 1.3) / (3.9 - 1.3)))
            contribution = 1 - fade * fade * (3 - 2 * fade)
            if distance >= 3.9:
                self.assertEqual(contribution, 0)

    def test_hemisphere_basis_has_constant_length(self):
        rng = random.Random(2701)
        for _ in range(1000):
            normal = [rng.uniform(-1, 1) for _ in range(3)]
            length = math.sqrt(sum(value * value for value in normal))
            normal = [value / length for value in normal]
            reference = [0, 1, 0] if abs(normal[1]) < .85 else [1, 0, 0]
            tangent = [reference[1] * normal[2] - reference[2] * normal[1],
                       reference[2] * normal[0] - reference[0] * normal[2],
                       reference[0] * normal[1] - reference[1] * normal[0]]
            length = math.sqrt(sum(value * value for value in tangent))
            tangent = [value / length for value in tangent]
            bitangent = [normal[1] * tangent[2] - normal[2] * tangent[1],
                         normal[2] * tangent[0] - normal[0] * tangent[2],
                         normal[0] * tangent[1] - normal[1] * tangent[0]]
            for first, second in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
                ray = [(normal[index] + (first * tangent[index] + second * bitangent[index])
                        / math.sqrt(2)) / math.sqrt(2) for index in range(3)]
                self.assertAlmostEqual(sum(value * value for value in ray), 1)

    def test_nested_gpu_scope_accounting(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "capture.csv"
            with path.open("w", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow(("frame", "pass", "gpu_ms", "self_gpu_ms"))
                writer.writerows(((0, "__frame__", 5, 1),
                                  (0, "__frame__/deferred", 4, 1),
                                  (0, "__frame__/deferred/lighting", 3, 3)))
            report = summarize(path)
            self.assertEqual(report["mean_gpu_ms"], 5)
            self.assertFalse(report["gpu_p95_within_240fps_budget"])
            with path.open("a") as stream:
                stream.write("0,__frame__/overlap,1,1\n")
            with self.assertRaisesRegex(ValueError, "accounting"):
                summarize(path)


if __name__ == "__main__":
    unittest.main()
