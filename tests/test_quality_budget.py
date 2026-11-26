import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from check_shaders import preview_profiles
from package import PREVIEW
from quality_budget import ATMO_BYTES, MIB, TIERS, resource_budget


class QualityBudgetTests(unittest.TestCase):
    def test_budget_by_tier(self):
        profiles = preview_profiles(PREVIEW)
        for tier in TIERS:
            options = profiles[f"profile.{tier}"]
            result = resource_budget(options, 1920, 1080)
            if tier in ("Ultra", "Extreme"):
                size = int(options["VOXEL_GRID_SIZE"])
                self.assertAlmostEqual(result["voxel_mib"], ((46 + 8*(tier=="Extreme")) * size ** 3 + 24*size**2 + 128 * 32 * 32 + 16) / MIB)
                self.assertEqual(result["atmosphere_mib"], (ATMO_BYTES + 16) / MIB)
                self.assertEqual(result["hiz_mib"], 67 * 37 * 8 / MIB)
                self.assertEqual(result["extra_color_single_mib"], 28 * 1920 * 1080 / MIB)
            else:
                self.assertTrue(all(value == 0 for key,value in result.items() if key not in ("hiz_mib","end_nebula_mib","water_normal_mib","opaque_hdr_single_mib")))
                self.assertEqual(result["hiz_mib"], 0)
                self.assertEqual(result["voxel_diffuse_smooth_mib"],0)
            self.assertEqual(result["opaque_hdr_single_mib"],1920*1080*4/MIB if options.get("DEFERRED_LIGHTING")==options.get("ADVANCED_WATER")=="true" else 0)

    def test_fixed_mode_removes_dynamic_owner_payload(self):
        options = preview_profiles(PREVIEW)["profile.Ultra"]
        dynamic = resource_budget({**options, "PROJECTION_JITTER": "2"}, 1920, 1080)
        fixed = resource_budget({**options, "PROJECTION_JITTER": "1"}, 1920, 1080)
        self.assertAlmostEqual(dynamic["extra_color_single_mib"] - fixed["extra_color_single_mib"], 8 * 1920 * 1080 / MIB)
        self.assertEqual(dynamic["voxel_mib"], fixed["voxel_mib"])

    def test_invalid_resolution(self):
        options = preview_profiles(PREVIEW)["profile.Ultra"]
        with self.assertRaises(ValueError):
            resource_budget(options, 0, 1080)
