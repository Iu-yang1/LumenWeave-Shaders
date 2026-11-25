import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from check_shaders import check_iris_directives, expand, preview_profiles
from package import P0_CONFIG, PREVIEW


class ShaderToolsTests(unittest.TestCase):
    def test_iris_clear_color_rejects_scalar_constructor(self):
        with self.assertRaisesRegex(ValueError, "four explicit"):
            check_iris_directives("const vec4 colortex4ClearColor = vec4(0.0);", "composite")

    def test_water_uses_a_geometry_stage_sampler(self):
        with self.assertRaisesRegex(ValueError, "cannot bind colortex3"):
            check_iris_directives("uniform sampler2D colortex3;", "gbuffers_water.fsh")
        water = PREVIEW / "world0/gbuffers_water.fsh"
        check_iris_directives(expand(PREVIEW, water), water)
        deferred = PREVIEW / "world0/deferred1.fsh"
        self.assertIn("RENDERTARGETS: 0,6,7,8", expand(PREVIEW, deferred))
        self.assertIn("RENDERTARGETS: 0,8", expand(PREVIEW, deferred))

    def test_checked_profiles_and_absolute_include(self):
        self.assertEqual(
            preview_profiles(PREVIEW, P0_CONFIG),
            {
                "profile.Neutral": {"SOFT_COLOR": "false"},
                "profile.Soft": {"SOFT_COLOR": "true"},
            },
        )
        expanded = expand(PREVIEW, PREVIEW / "final.fsh")
        self.assertIn("vec3 applySoftColor(vec3 color)", expanded)
        self.assertNotIn("#include", expanded)

    def test_p1_profiles_and_dimension_entry(self):
        profiles = preview_profiles(PREVIEW)
        self.assertEqual(
            profiles["profile.Natural"],
            {
                "EXPOSURE": "0", "SHOW_COLOR_CHART": "false", "SOFT_COLOR": "true",
                "LITE_LIGHTING": "false", "SCENE_SHADOWS": "false",
                "DEFERRED_LIGHTING": "false", "SCREEN_AO": "false", "SOFT_SHADOWS": "false",
                "ADVANCED_WATER": "false",
                "TEMPORAL_AA": "false", "VOLUME_EFFECTS": "false", "VOXEL_LIGHTING": "false",
                "SCREEN_GI": "false", "SCREEN_GI_HISTORY": "false", "SCREEN_GI_SPATIAL": "false",
                "VOXEL_GI": "false", "VOXEL_GRID_SIZE": "32",
                "SHADOW_MAP": "0", "SHADOW_RANGE": "48.0",
                "SPATIAL_AA": "false",
            },
        )
        self.assertEqual(profiles["profile.LowExposure"]["EXPOSURE"], "-1")
        self.assertEqual(profiles["profile.HighExposure"]["EXPOSURE"], "1")
        self.assertEqual(profiles["profile.Potato"]["SCENE_SHADOWS"], "false")
        self.assertEqual(profiles["profile.Low"]["SCENE_SHADOWS"], "true")
        self.assertEqual(profiles["profile.Potato"]["SPATIAL_AA"], "true")
        self.assertEqual(profiles["profile.Low"]["SPATIAL_AA"], "true")
        self.assertEqual(profiles["profile.Standard"]["DEFERRED_LIGHTING"], "true")
        self.assertEqual(
            [name for name, options in profiles.items() if options["SCREEN_GI_HISTORY"] == "true"],
            ["profile.Ultra", "profile.Extreme"],
        )
        self.assertEqual(
            [(profiles[f"profile.{name}"]["SHADOW_MAP"], profiles[f"profile.{name}"]["SHADOW_RANGE"],
              profiles[f"profile.{name}"]["VOXEL_GRID_SIZE"])
             for name in ("Potato", "Low", "Medium", "High", "Ultra", "Extreme")],
            [("512", "48.0", "32"), ("1024", "64.0", "32"), ("1024", "96.0", "32"),
             ("2048", "128.0", "64"), ("2048", "160.0", "96"), ("4096", "192.0", "128")],
        )
        expanded = expand(PREVIEW, PREVIEW / "world0/final.vsh")
        self.assertTrue(expanded.startswith("#version 330 compatibility\n"))
        self.assertNotIn("#include", expanded)

    def test_relative_includes_and_cycles(self):
        with TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            entry = root / "test.fsh"
            helper = root / "helper.glsl"
            entry.write_text('#include "helper.glsl"\n', encoding="utf-8")
            helper.write_text("float helper;\n", encoding="utf-8")
            self.assertEqual(expand(root, entry).strip(), "float helper;")
            helper.write_text('#include "test.fsh"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Include cycle"):
                expand(root, entry)
            entry.write_text('#include "../outside.glsl"\n', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "outside pack"):
                expand(root, entry)
