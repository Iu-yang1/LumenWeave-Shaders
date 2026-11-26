import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from check_shaders import DIMENSIONS, check_iris_directives, compile_shard, expand, menu_options, preview_profiles
from package import P0_CONFIG, PREVIEW


class ShaderToolsTests(unittest.TestCase):
    def test_iris_clear_color_rejects_scalar_constructor(self):
        with self.assertRaisesRegex(ValueError, "four explicit"):
            check_iris_directives("const vec4 colortex4ClearColor = vec4(0.0);", "composite")

    def test_iris_compute_directive_rejects_scalar_splat_and_expressions(self):
        for source in (
            "const ivec3 workGroups=ivec3(1);",
            "const ivec3 workGroups=ivec3(1, 1);",
            "const ivec3 workGroups=ivec3(1+1, 1, 1);",
            "const ivec3 workGroups=ivec3(1, 0, 1);",
        ):
            with self.subTest(source=source), self.assertRaisesRegex(ValueError, "three explicit"):
                check_iris_directives(source, "setup4.csh")
        with self.assertRaisesRegex(ValueError, "two explicit"):
            check_iris_directives("const vec2 workGroupsRender=vec2(0.5);", "composite_b.csh")
        check_iris_directives("const ivec3 workGroups=ivec3(1, 1, 1);", "setup4.csh")
        check_iris_directives("const vec2 workGroupsRender=vec2(0.5, 0.5);", "composite_b.csh")

    def test_all_compute_entries_are_iris_parseable(self):
        # Run in fast packaging CI as well as the full GLSL matrix.
        for entry in sorted(PREVIEW.rglob("*.csh")):
            with self.subTest(entry=entry.relative_to(PREVIEW)):
                check_iris_directives(expand(PREVIEW, entry), entry)

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
                "AA_MODE": "0", "VOLUME_EFFECTS": "false", "VOXEL_LIGHTING": "false",
                "SCREEN_GI": "false", "SCREEN_GI_HISTORY": "false", "SCREEN_GI_SPATIAL": "false",
                "VOXEL_GI": "false", "VOXEL_GRID_SIZE": "32",
                "SHADOW_MAP": "0", "SHADOW_RANGE": "48.0",
                "WATER_WAVE_DETAIL": "4", "SHADOW_FILTER_TAPS": "4", "AO_SLICES": "2",
                "WATER_REFLECTION_STEPS": "0",
                "PHYSICAL_ATMOSPHERE": "false", "MATERIAL_SSR": "false",
                "DH_SHADOWS": "false", "INCREMENTAL_VOXELS": "false",
                "MATERIAL_REFLECTION_STEPS": "8", "CLOUD_STEPS": "12",
                "SHAFT_STEPS": "6", "DH_SHADOW_STEPS": "14", "PROJECTION_JITTER": "0",
                "ADAPTIVE_SHADING": "true", "ADAPTIVE_SHADOWS": "true", "TEMPORAL_REUSE": "true",
                "GI_REUSE_MODE": "1", "HIZ_MODE": "1", "EMISSION_STRENGTH": "1.5",
                "LOCAL_GLOW_STRENGTH": "1.7", "DARK_AMBIENT": "0.65",
                "BLOOM": "false", "BLOOM_STRENGTH": "0.04", "BLOOM_THRESHOLD": "1.5", "BLOOM_FILTER": "0", "AO_RECONSTRUCTION": "1", "SHADOW_HYBRID": "1", "GLOW_SOFTNESS": "1.0", "VOXEL_FUSION": "1", "VOLUME_RECONSTRUCTION": "1", "HDR_REUSE": "1", "OVERWORLD_BUDGET": "1", "NETHER_BUDGET": "1", "END_BUDGET": "1", "SCENE_BUDGET": "1", "CLOUD_NOISE_MODE": "1", "CLOUD_ADAPTIVE": "1", "CLOUD_EMPTY_SKIP": "1", "SHAFT_ADAPTIVE": "1", "CLOUD_LIGHT_REUSE": "1", "VOLUME_TEMPORAL": "1", "LOCAL_SCATTER_ADAPTIVE": "1", "ATMO_PREBAKED": "1", "ATMO_UPDATE_MODE": "1", "END_NEBULA_ASSET": "1", "CLOUD_DENSITY_CACHE": "1", "CLOUD_OPTICAL_CACHE": "1", "SKY_ENV_REUSE": "1", "WATER_PHASE_LUT": "0", "BRDF_REUSE": "1",
                "WATER_HYBRID_WAVES": "1", "RAIN_RIPPLES": "0", "WET_SURFACES": "false",
                "PUDDLE_STRENGTH": "0.65", "AUTO_EXPOSURE": "false", "EXPOSURE_ADAPTATION": "0.65",
                "SMOOTH_LIGHTING": "false", "SOLAR_GLARE": "false", "GLARE_STRENGTH": "0.25",
                "GEOMETRY_TAAU_SCALE":"100","SCENE_TAAU_SCALE":"100","SSR_HALF_RES":"1",
                "RAIN_GEOMETRY":"1","VOXEL_DIFFUSE_SMOOTHING":"1","DIRECT_RISE_HALF":"0.10","DIRECT_FALL_HALF":"0.18",
                "DIFFUSE_RISE_HALF":"0.16","DIFFUSE_FALL_HALF":"0.28","RAIN_RISE_TIME":"20.0","RAIN_FALL_TIME":"40.0","APPROX_REUSE":"0","PERCEPTUAL_GI":"1","MULTIRATE_VOLUME":"1","SSR_FOOTPRINT":"1","LOW_FREQ_CACHE":"1","DIFFUSE_SH":"1",
            },
        )
        self.assertEqual(profiles["profile.LowExposure"]["EXPOSURE"], "-1")
        self.assertEqual(profiles["profile.HighExposure"]["EXPOSURE"], "1")
        self.assertEqual(profiles["profile.Potato"]["SCENE_SHADOWS"], "false")
        self.assertEqual(profiles["profile.Low"]["SCENE_SHADOWS"], "true")
        self.assertEqual(profiles["profile.Potato"]["AA_MODE"], "1")
        self.assertEqual(profiles["profile.Low"]["AA_MODE"], "1")
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

    def test_nested_menus_reject_missing_screens_and_cycles(self):
        self.assertEqual(
            menu_options({"screen": "<profile> [WATER] [POST]", "screen.WATER": "WAVES",
                          "screen.POST": "[AA]", "screen.AA": "AA_MODE"})[0],
            {"WAVES", "AA_MODE"},
        )
        with self.assertRaisesRegex(ValueError, "Missing settings menu"):
            menu_options({"screen": "[MISSING]"})
        with self.assertRaisesRegex(ValueError, "cycle"):
            menu_options({"screen": "[POST]", "screen.POST": "[AA]", "screen.AA": "[POST]"})

    def test_dimension_entry_points_are_complete(self):
        expected = {path.name for path in (PREVIEW / "world0").iterdir()}
        for dimension in DIMENSIONS:
            extra = {"gbuffers_clouds.fsh", "gbuffers_clouds.vsh"} if dimension == "world1" else set()
            self.assertEqual({path.name for path in (PREVIEW / dimension).iterdir()}, expected | extra)
            for entry in (PREVIEW / dimension).iterdir():
                self.assertTrue(expand(PREVIEW, entry).startswith("#version "))

    def test_personal_effects_are_independent_of_quality_profiles(self):
        for profile in preview_profiles(PREVIEW).values():
            self.assertFalse({"MOTION_BLUR", "WAVING_LEAVES", "WAVING_GRASS", "DOF_MODE", "DOF_FOCUS", "DOF_STRENGTH", "DOF_AF_SPEED", "DOF_AF_AREA", "DOF_QUALITY", "DOF_FILTER", "LENS_GHOSTS", "LENS_STAR"} & profile.keys())

    def test_compile_matrix_shards_cover_each_link_once(self):
        programs = [PREVIEW / dim / name for dim in DIMENSIONS
                    for name in ("deferred1", "composite1", "gbuffers_water", "prepare7")]
        assignments = [compile_shard(PREVIEW, profile, program, env, 6)
                       for profile in ("native", "geometry", "scene")
                       for program in programs for env in ((), ("DISTANT_HORIZONS",))]
        self.assertEqual(set(assignments), set(range(6)))
        self.assertEqual(sum(assignments.count(i) for i in range(6)), len(assignments))
        for program in programs:
            self.assertEqual(compile_shard(PREVIEW, "native", program, ("B","A"), 6),
                             compile_shard(PREVIEW, "native", program, ("A","B"), 6))
            self.assertEqual(compile_shard(PREVIEW, "native", program, (), 1), 0)

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
