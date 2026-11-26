import math
import struct
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=ROOT/"shaders"
sys.path.insert(0,str(ROOT/"tools"))
from check_shaders import preview_profiles
from generate_atmosphere_assets import transmittance_grid,solar,multiscatter_grid


class PrebakedAssetsTests(unittest.TestCase):
    def test_all_profiles_select_optimizations_without_new_features(self):
        profiles=preview_profiles(S)
        for options in profiles.values():
            for key in ("SCENE_BUDGET","CLOUD_NOISE_MODE","CLOUD_ADAPTIVE",
                        "CLOUD_EMPTY_SKIP","SHAFT_ADAPTIVE","CLOUD_LIGHT_REUSE",
                        "VOLUME_TEMPORAL","LOCAL_SCATTER_ADAPTIVE","ATMO_PREBAKED",
                        "ATMO_UPDATE_MODE","AO_RECONSTRUCTION","HDR_REUSE"):
                self.assertEqual(options[key],"1",key)
        for name in ("Natural","Potato","Low","Medium","High","Standard"):
            self.assertEqual(profiles[f"profile.{name}"]["VOLUME_EFFECTS"],"false")
            self.assertEqual(profiles[f"profile.{name}"]["SCREEN_GI"],"false")

    def test_static_assets_and_reference_values(self):
        trans=list(struct.iter_unpack("<4e",(S/"textures/atmo_trans.rgba16f").read_bytes()))
        multi=list(struct.iter_unpack("<4e",(S/"textures/atmo_multi.rgba16f").read_bytes()))
        self.assertEqual(len(trans),128*32)
        self.assertEqual(len(multi),32*16)
        self.assertTrue(all(0<=v<=1 for row in trans for v in row))
        self.assertTrue(all(math.isfinite(v) and v>=0 for row in multi for v in row))
        self.assertTrue(all(row[3]==1 for row in trans+multi))
        grid=transmittance_grid()
        for a,b in zip(trans,grid.values):
            for x,y in zip(a[:3],b):
                self.assertLessEqual(abs(x-y),max(6e-8,abs(y)*.001))
        # Multiple-scattering reference from shader coordinates, compare all
        # texels including twilight and top/bottom altitude.
        for a,b in zip(multi,multiscatter_grid(grid).values):
            for x,y in zip(a[:3],b):
                self.assertLessEqual(abs(x-y),max(6e-8,abs(y)*.001))
        self.assertEqual(solar(grid,6361,-1),(0.,0.,0.))
        self.assertGreater(solar(grid,6380,1)[2],solar(grid,6360.2,1)[2])

    def test_atmosphere_cache_invalidation(self):
        def update(old,h,mu,time):
            if mu<=-.15:return False
            t=max(0,min(1,(mu-.02)/.33))
            threshold=.00025+.00175*t*t*(3-2*t)
            return old[3]<.5 or abs(h-old[0])>.25 or abs(mu-old[1])>threshold or time-old[2]<0 or time-old[2]>.1
        old=(64,.5,10,1)
        self.assertFalse(update(old,64.1,.5001,10.05))
        self.assertTrue(update(old,64.4,.5001,10.05))
        self.assertTrue(update(old,64,.51,10.05))
        self.assertTrue(update(old,64,.5,10.2))
        self.assertTrue(update(old,64,.5,0))
        self.assertFalse(update(old,64,-.2,10.2))
        self.assertTrue(update((0,0,0,0),64,.001,10.2))
        for name in ("begin1","begin2"):
            source=(S/f"programs/shared/{name}.csh.glsl").read_text()
            self.assertIn("if(!atmoUpdateNeeded",source)
        self.assertIn("imageStore(lwAtmoState",(S/"programs/shared/begin3.csh.glsl").read_text())

    def test_ao_only_and_volume_without_gi(self):
        q=(S/"lib/quality.glsl").read_text()
        gate=next(line for line in q.splitlines() if line.startswith("#if AO_RECONSTRUCTION"))
        self.assertNotIn("SCREEN_GI",gate)
        self.assertIn("AA_MODE < 2",gate)
        d=(S/"programs/shared/deferred.fsh.glsl").read_text()
        self.assertIn("#elif defined(LW_AO_SPATIAL)",d)
        self.assertIn("RENDERTARGETS: 3",d)
        gate=next(line for line in q.splitlines() if line.startswith("#if VOLUME_RECONSTRUCTION"))
        self.assertNotIn("defined(SCREEN_GI)",gate.split("&& !(")[0])
        self.assertIn("colortex9Format = RGBA16F",(S/"programs/shared/composite.fsh.glsl").read_text())
