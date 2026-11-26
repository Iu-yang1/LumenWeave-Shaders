"""Numerical contracts for the unjittered output and jittered GI histories."""
import math
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"


def offsets():
    source = (SHADERS / "lib/temporal/jitter.glsl").read_text()
    sequence = source.split("vec2[8](", 1)[1].split(");", 1)[0]
    values = [tuple(map(float, x)) for x in re.findall(r"vec2\(([-0-9.]+), ([-0-9.]+)\)", sequence)]
    mean = tuple(map(float, re.search(r"mean = vec2\(([-0-9.]+), ([-0-9.]+)\)", source).groups()))
    return [(x-mean[0], y-mean[1]) for x, y in values]


class StableGridTests(unittest.TestCase):
    def test_jitter_zero_mean_and_subpixel(self):
        values = offsets()
        self.assertEqual(len(values), 8)
        for axis in (0, 1):
            self.assertAlmostEqual(sum(v[axis] for v in values), 0.0, places=5)
            self.assertTrue(all(abs(v[axis]) < 0.5 for v in values))

    def test_stationary_ramp_resolves_to_same_pixel(self):
        # Raw raster sample at i - jitter; sample grid at i + jitter.
        for width, height in ((1280,720), (1920,1080), (2560,1440), (3840,2160), (1919,1079)):
            for jx, jy in offsets():
                for x,y in ((width//3,height//3),(width//2,height//2)):
                    px = ((x+0.5)/width + jx/width)*width - 0.5
                    py = ((y+0.5)/height + jy/height)*height - 0.5
                    bx, by = math.floor(px), math.floor(py)
                    fx, fy = px-bx, py-by
                    color = sum((0.002*(bx+i-jx)+0.004*(by+k-jy))
                                *(fx if i else 1-fx)*(fy if k else 1-fy)
                                for i in (0,1) for k in (0,1))
                    self.assertAlmostEqual(color, 0.002*x+0.004*y, places=10)

    def test_independent_history_coordinates(self):
        source = (SHADERS / "lib/temporal/reproject.glsl").read_text()
        self.assertIn("previousProjection, false", source)
        self.assertIn("previousProjection, true", source)
        self.assertIn("if (sampleJitteredHistory)", source)
        taa = (SHADERS / "programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("reprojectStableTerrain(viewPosition", taa)
        self.assertIn("stableUv + jitterOffset(frameCounter)", taa)
        self.assertIn("vec4(normal, vec2(size))", taa)
        self.assertIn("metadata.zw - vec2(size)", taa)

    def test_gi_continuous_fallback(self):
        source = (SHADERS / "lib/lighting/screen_gi_spatial.glsl").read_text()
        self.assertIn("smoothstep(0.15, 0.55, coverage)", source)
        self.assertIn("mix(full.sky, filtered.sky", source)

    def test_projection_mode_is_separate_from_aa(self):
        quality = (SHADERS / "lib/quality.glsl").read_text()
        jitter = (SHADERS / "lib/temporal/jitter.glsl").read_text()
        self.assertIn("#define PROJECTION_JITTER 0 // [0 1 2]", quality)
        self.assertIn("#define LW_TAA_ACTIVE", quality)
        self.assertIn("PROJECTION_JITTER == 2", quality)
        self.assertIn("!defined(VOLUME_EFFECTS) && !defined(SCREEN_GI) && !defined(VOXEL_LIGHTING)", quality)
        self.assertIn("#ifndef LW_DYNAMIC_JITTER\n    return vec2(0.0);", jitter)

    def test_advanced_profiles_keep_all_lighting_and_taa(self):
        props = (SHADERS / "shaders.properties").read_text()
        for name in ("Ultra", "Extreme"):
            line = next(line for line in props.splitlines() if line.startswith(f"profile.{name} ="))
            tokens = line.split()
            self.assertTrue({"AA_MODE:2", "VOLUME_EFFECTS", "VOXEL_LIGHTING", "SCREEN_GI",
                             "SCREEN_GI_HISTORY", "SCREEN_GI_SPATIAL", "SOFT_SHADOWS"} <= set(tokens))
            self.assertIn("VOXEL_GRID_SIZE:" + ("96" if name == "Ultra" else "128"), tokens)
            self.assertIn("VOXEL_GI" if name == "Extreme" else "!VOXEL_GI", tokens)
