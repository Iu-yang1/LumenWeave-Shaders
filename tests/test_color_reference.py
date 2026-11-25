import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from color_reference import LUMA, chart_rgb8, decode_srgb, display_color, encode_srgb


class ColorReferenceTests(unittest.TestCase):
    def test_srgb_round_trip(self):
        for code in range(256):
            self.assertEqual(round(255 * encode_srgb(decode_srgb(code / 255))), code)
        self.assertAlmostEqual(decode_srgb(0.5), 0.214041, places=6)

    def test_chart_retains_shadows_and_highlights_at_each_exposure(self):
        for exposure in range(-2, 3):
            chart = chart_rgb8(exposure)
            self.assertEqual(chart[0], (0, 0, 0))
            self.assertEqual(len(set(chart)), 10)
            for lower, upper in zip(chart[:8], chart[1:9]):
                self.assertLess(lower[0], upper[0])
            self.assertLess(chart[8][0], 255)
        self.assertLess(chart_rgb8(-1)[3][0], chart_rgb8(1)[3][0])

    def test_gamut_compression_preserves_mapped_luminance(self):
        source = (4, 0.1, 0.04)
        source_luma = sum(channel * weight for channel, weight in zip(source, LUMA))
        display = tuple(decode_srgb(channel) for channel in display_color(source))
        mapped_luma = sum(channel * weight for channel, weight in zip(display, LUMA))
        self.assertAlmostEqual(mapped_luma, source_luma / (1 + source_luma))
        self.assertAlmostEqual(max(display), 1)
        self.assertGreater(display[0], display[1])
        self.assertGreater(display[1], display[2])
