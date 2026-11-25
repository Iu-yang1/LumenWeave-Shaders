import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from voxel_reference import BLACK, propagate


class VoxelReferenceTests(unittest.TestCase):
    def test_mix_decay_and_source_preservation(self):
        emitters = {(2, 4, 4): (1, 0, 0), (6, 4, 4): (0, 0, 1)}
        field = propagate(9, emitters, set(), 2)
        self.assertEqual(field[(4, 4, 4)], (0.5625, 0, 0.5625))
        self.assertEqual(field[(2, 4, 4)], (1, 0, 0))
        self.assertNotIn((2, 4, 7), field)

    def test_wall_blocks_and_boundaries_do_not_wrap(self):
        wall = {(3, row, depth) for row in range(7) for depth in range(7)}
        field = propagate(7, {(2, 3, 3): (1, 0, 0)}, wall, 20)
        self.assertNotIn((3, 3, 3), field)
        self.assertEqual(field.get((4, 3, 3), BLACK), BLACK)
        corner = propagate(7, {(0, 0, 0): (1, 1, 1)}, set(), 1)
        self.assertEqual(set(corner), {(0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)})

    def test_reseeding_removes_light_and_energy_stays_bounded(self):
        field = propagate(9, {(4, 4, 4): (0.2, 0.8, 1)}, set(), 10)
        self.assertTrue(
            all(0 <= channel <= 1 for light in field.values() for channel in light)
        )
        self.assertEqual(propagate(9, {}, set(), 10), {})
