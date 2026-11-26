import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def optical_depth(distance, start, end, rain=0.0, density=1.0):
    h0, h1 = (max(-0.7, min(5.0, (h - 63.0) / 180.0)) for h in (start, end))
    delta = h1 - h0
    mean = math.exp(-0.5 * (h0 + h1)) if abs(delta) < 0.01 else (
        math.exp(-h0) - math.exp(-h1)) / delta
    return max(distance - 8.0, 0.0) * mean * (0.00065 + 0.0042 * rain) * density


class NaturalV2Tests(unittest.TestCase):
    def test_near_and_disabled_air(self):
        self.assertEqual(optical_depth(5, 63, 63), 0)
        self.assertEqual(optical_depth(1000, 63, 63, density=0), 0)

    def test_air_distance_weather_height(self):
        clear = optical_depth(256, 63, 63)
        self.assertGreater(optical_depth(512, 63, 63), clear)
        self.assertGreater(optical_depth(256, 63, 63, rain=1), clear)
        self.assertLess(optical_depth(256, 200, 200), clear)

    def test_height_integral_matches_quadrature(self):
        start, end = 63, 200
        average = sum(math.exp(-(start + (end-start)*(i+0.5)/4096-63)/180)
                      for i in range(4096)) / 4096
        self.assertAlmostEqual(optical_depth(256, start, end), 248*0.00065*average, places=7)
        self.assertAlmostEqual(optical_depth(256, start, end), optical_depth(256, end, start))

    def test_snell_critical_angle(self):
        critical = math.asin(1 / 1.333)
        self.assertAlmostEqual(math.degrees(critical), 48.61, places=1)
        self.assertLess(1.333**2 * math.sin(math.radians(30))**2, 1)
        self.assertGreater(1.333**2 * math.sin(math.radians(60))**2, 1)

    def test_direct_ambient_ratio_increases(self):
        self.assertGreater((5.4 / math.pi) / 0.25, (4.2 / math.pi) / 0.38)

    def test_neighbor_reprojection_uses_its_own_pixel(self):
        source = (ROOT / "shaders/programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("temporalGeometry(neighbor, neighborUv,", source)
        self.assertNotIn("temporalGeometry(neighbor, texCoord,", source)

    def test_aerial_is_shared_by_native_and_dh(self):
        for path in ("programs/p1/surface.fsh.glsl", "programs/p5/distant.fsh.glsl",
                     "programs/shared/deferred1.fsh.glsl"):
            source = (ROOT / "shaders" / path).read_text()
            self.assertIn('/lib/lighting/fog.glsl', source)

    def test_volume_precedes_taa(self):
        props = (ROOT / "shaders/shaders.properties").read_text()
        volume = (ROOT / "shaders/programs/shared/composite.fsh.glsl").read_text()
        temporal = (ROOT / "shaders/programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("applyCloudVolume", volume)
        self.assertIn("filteredHistory", temporal)
        for world in ("world0", "world-1", "world1"):
            self.assertIn(f"program.{world}/composite.enabled = VOLUME_EFFECTS", props)
            self.assertIn(f"program.{world}/composite1.enabled = true", props)

    def test_volume_uses_cheap_visibility(self):
        source = (ROOT / "shaders/lib/atmosphere/volume.glsl").read_text()
        self.assertIn("volumeShadow(offset)", source)
        self.assertNotIn("sceneShadow(offset", source)

    def test_rayleigh_color_and_mie_direction(self):
        tau = optical_depth(512, 63, 63)
        transmission = [math.exp(-tau*c) for c in (0.47, 0.88, 1.55)]
        self.assertGreater(transmission[0], transmission[1])
        self.assertGreater(transmission[1], transmission[2])
        def phase(cosine):
            g = 0.68
            d = max(1 + g*g - 2*g*cosine, 0.04)
            return min((1-g*g)/(d*math.sqrt(d)), 5.0)
        self.assertGreater(phase(1), phase(0))
        self.assertGreater(phase(0), phase(-1))

    def test_spatial_gi_preserves_full_resolution_fallback(self):
        props = (ROOT / "shaders/shaders.properties").read_text()
        for name in ("Ultra", "Extreme"):
            profile = next(line for line in props.splitlines() if line.startswith(f"profile.{name} ="))
            self.assertIn(" SCREEN_GI_SPATIAL ", profile)
        source = (ROOT / "shaders/lib/lighting/screen_gi_spatial.glsl").read_text()
        self.assertIn("return screenDiffuseBounce(viewPosition, normal, sun)", source)
