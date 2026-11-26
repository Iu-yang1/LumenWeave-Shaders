import math
import unittest
from pathlib import Path

S=Path(__file__).resolve().parents[1]/"shaders"

def fresnel(c,submerged):
    n1,n2=(1.333,1.) if submerged else (1.,1.333)
    st2=(n1/n2)**2*(1-c*c)
    if st2>=1: return 1.
    ct=math.sqrt(1-st2)
    return .5*((n1*c-n2*ct)**2/(n1*c+n2*ct)**2+(n2*c-n1*ct)**2/(n2*c+n1*ct)**2)

def adapt(old,target,dt,half):
    return target+(old-target)*2**(-dt/half)

class NaturalEnvironmentTests(unittest.TestCase):
    def test_water_critical_angle_and_normal(self):
        critical=math.asin(1/1.333)
        self.assertAlmostEqual(fresnel(1,True),fresnel(1,False))
        self.assertAlmostEqual(fresnel(1,False),.02037,places=4)
        self.assertEqual(fresnel(math.cos(critical+.001),True),1)
        self.assertLess(fresnel(math.cos(critical-.001),True),1)
        self.assertIn("waterExtinction() * hitTravel",(S/"lib/water/screen_space.glsl").read_text())

    def test_exposure_half_life_and_framerate(self):
        for hz in (30,60,144):
            old=0.
            for _ in range(hz): old=adapt(old,1.,1/hz,1.25)
            self.assertAlmostEqual(old,adapt(0.,1.,1.,1.25),places=10)
        self.assertLess(adapt(1.,0.,.5,.42),adapt(1.,0.,.5,1.25))
        src=(S/"programs/shared/composite4.csh.glsl").read_text()
        self.assertIn("ivec3(1, 1, 1)",src)
        self.assertIn("imageLoad(lwExposureState",src)

    def test_weather_and_buffer_ownership(self):
        props=(S/"shaders.properties").read_text()
        self.assertIn("smooth(rainStrength, 20.0, 40.0)",props)
        self.assertIn("uniform float wetness",(S/"lib/weather/wet_surface.glsl").read_text())
        for d in ("world0","world-1","world1"):
            for name in ("setup5.csh","composite4.csh","composite5.fsh","composite5.vsh"):
                self.assertTrue((S/d/name).exists())
        self.assertIn("LW_DOF_HALF",(S/"lib/quality.glsl").read_text())

    def test_continuous_weather_solar_term(self):
        prior=1.0
        for i in range(1,101):
            rain=i/100.0
            direct=(1-rain)**2
            self.assertLessEqual(direct,prior)
            self.assertLessEqual(prior-direct,.02001)
            prior=direct
        self.assertEqual(prior,0.0)
        self.assertIn("if(directWeight>0.0)",(S/"lib/atmosphere/volume.glsl").read_text())
