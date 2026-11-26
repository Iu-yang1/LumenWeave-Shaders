import math
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from optics_upscale_sim import run,coc,upscale
from check_shaders import preview_profiles

class OpticsUpscaleTests(unittest.TestCase):
    def test_numerical_proxy(self):
        r=run()
        self.assertLess(r['flat_max_error'],1e-12)
        self.assertLess(r['plane_max_error'],1e-12)
        self.assertLess(r['edge_mae'],r['bilinear_edge_mae'])
        for row in r['idle']:
            self.assertLess(row['at_8s'],1e-10)
            self.assertGreater(row['at_12s'],row['at_10s'])
            self.assertLess(row['at_13s'],.005)
        self.assertEqual(coc(2,2),0)
        self.assertLess(coc(.65,2),8)
        self.assertEqual(upscale([.1,2,.1,2],.4,.4,(True,False,True,False))[0],.1)

    def test_preset_scope(self):
        profiles=preview_profiles(ROOT/'shaders')
        for name,profile in profiles.items():
            self.assertEqual(profile['EDGE_TAAU'],'1' if name in ('profile.Ultra','profile.Extreme') else '0')
            if name in ('profile.Natural','profile.Potato','profile.Low','profile.Standard'):
                for key in ('PERCEPTUAL_GI','MULTIRATE_VOLUME','SSR_FOOTPRINT'):
                    self.assertEqual(profile[key],'2')
                self.assertEqual(profile['APPROX_REUSE'],'1')
            self.assertFalse({'DOF_IDLE','DOF_IDLE_DELAY','DOF_IDLE_STRENGTH','PERIPHERAL_OPTICS','PERIPHERAL_STRENGTH'} & profile.keys())
        for name in ('Ultra','Extreme'):
            self.assertEqual(profiles['profile.'+name]['PROJECTION_JITTER'],'1')

    def test_idle_camera_state(self):
        meter=(ROOT/'shaders/programs/shared/composite4.csh.glsl').read_text()
        self.assertIn('ivec2(2,0),lwAdvanceIdle',meter)
        idle=(ROOT/'shaders/lib/post/idle_focus.glsl').read_text()
        self.assertIn('gbufferPreviousModelView',idle)
        self.assertIn('heldItemId2',idle)
        final=(ROOT/'shaders/programs/shared/final.fsh.glsl').read_text()
        self.assertIn('scene=lwLensOptics',final)
