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

    def test_high_tier_default_lut(self):
        props = (ROOT/"shaders.properties").read_text()
        for line in props.splitlines():
            if line.startswith("profile."):
                enabled=line.startswith(("profile.Ultra =","profile.Extreme ="))
                self.assertIn("PHYSICAL_ATMOSPHERE" if enabled else "!PHYSICAL_ATMOSPHERE",line.split())

    def test_prefix_integration_and_horizon_warp(self):
        import math
        common=(ROOT/"lib/atmosphere/physical_common.glsl").read_text()
        self.assertIn("atmoElevationUv",common)
        self.assertIn("atmoAltitudeUv",common)
        for mu in (-1.,-.5,-.01,0.,.01,.5,1.):
            u=.5+.5*math.copysign(math.sqrt(abs(mu)),mu)
            x=2*u-1
            self.assertAlmostEqual(math.copysign(x*x,x),mu)
        # Closed-form constant medium: prefix integral equals direct integral.
        extinction=.028
        source=.0021
        radiance=0.
        throughput=1.
        previous=0.
        for z in range(16):
            d=math.expm1(math.log1p(120.)*z/15)
            segment=math.exp(-extinction*(d-previous))
            radiance+=throughput*source*(1-segment)/extinction
            throughput*=segment
            self.assertAlmostEqual(throughput,math.exp(-extinction*d),places=12)
            self.assertAlmostEqual(radiance,source*(1-math.exp(-extinction*d))/extinction,places=12)
            previous=d
        stage=(ROOT/"programs/shared/begin2.csh.glsl").read_text()
        self.assertIn("atmoIntegrateSegment(radius,direction,sun,previous,distanceKm,4,l,t,f)",stage)
        self.assertIn("for(int z=0;z<16;++z)",stage)
