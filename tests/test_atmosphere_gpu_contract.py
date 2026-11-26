import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"

class AtmosphereGpuContract(unittest.TestCase):
    def test_four_luts_and_spectral_aerial(self):
        props = (ROOT/"shaders.properties").read_text()
        for name in ("Trans","Multi","Sky","Scatter","Through"):
            self.assertIn("image.lwAtmo"+name+"Image =",props)
        for stage in ("setup","setup1","begin1","begin2"):
            for world in ("world0","world-1","world1"):
                self.assertTrue((ROOT/world/(stage+".csh")).is_file())
        aerial = (ROOT/"lib/atmosphere/aerial.glsl").read_text()
        self.assertIn("scene*through+scatter",aerial)
        self.assertIn("ATMO_KM_PER_BLOCK",aerial)
        self.assertIn("#ifdef LW_ATMOSPHERE_LUT_ACTIVE",aerial)

    def test_no_default_profile_change(self):
        props = (ROOT/"shaders.properties").read_text()
        for line in props.splitlines():
            if line.startswith("profile."):
                self.assertNotIn(" PHYSICAL_ATMOSPHERE",line)
