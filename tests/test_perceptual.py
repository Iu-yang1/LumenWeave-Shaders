import itertools
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from gpu_budget_plan import capture,allocate,choose
from perceptual_sim import simulate
from check_shaders import preview_profiles


def synthetic(gpu,present,a,b):
    return capture([{'frame':str(f),'pass':k,'gpu_ms':v} for f in range(100)
        for k,v in [('__frame__',gpu),('__present__',present),('deferred',a),('composite',b)]])


class PerceptualTests(unittest.TestCase):
    def test_capture_budget_is_not_a_fps_prediction(self):
        base=synthetic(6,6.5,2,2)
        good=synthetic(3.6,3.9,1,1)
        cpu=synthetic(3.5,5,1,1)
        self.assertEqual(allocate(base,protected=('composite',))['budget_status'],'fixed_work_exceeds_target')
        self.assertEqual(choose(base,[('cpu_limited',cpu),('ok',good)])['selected_verified'],'ok')
        self.assertEqual(allocate(synthetic(3,4,2,2))['budget_status'],'overlapping_or_inconsistent_passes')
        with self.assertRaises(ValueError):capture([{'frame':'0','pass':'deferred','gpu_ms':2}])
    def test_proxy_work_reduction(self):
        r=simulate(2000)
        self.assertGreater(r['gi_1']['reduction_pct'],0)
        self.assertGreater(r['spatial']['reduction_pct'],0)
        self.assertGreater(r['volume_2']['reduction_pct'],r['volume_1']['reduction_pct'])
        for mode in (1,2):
            self.assertLessEqual(r[f'ssr_{mode}']['candidate_steps'],r[f'ssr_{mode}']['reference_adaptive_steps'])
        self.assertLess(r['sh']['max_abs'],1e-12)
    def test_profiles_and_ordering(self):
        profiles=preview_profiles(ROOT/'shaders')
        for name,options in profiles.items():
            fast=name in ('profile.Natural','profile.Potato','profile.Low','profile.Standard')
            for key in ('PERCEPTUAL_GI','MULTIRATE_VOLUME','SSR_FOOTPRINT'):
                self.assertEqual(options[key],'2' if fast else '1')
            for key in ('LOW_FREQ_CACHE','DIFFUSE_SH'):
                self.assertEqual(options[key],'1')
            self.assertEqual(options['EDGE_TAAU'],'1' if name in ('profile.Ultra','profile.Extreme') else '0')
        for n in itertools.product((0,1),repeat=2):
            for axis in ((1,0),(0,1)):
                candidates=[n,tuple(a^b for a,b in zip(n,axis)),tuple(a^(1-b) for a,b in zip(n,axis)),tuple(1-a for a in n)]
                self.assertEqual(len(set(candidates)),4)
        s=(ROOT/'shaders/lib/lighting/screen_gi_spatial.glsl').read_text()
        self.assertIn('coverage>=0.72',s)
        self.assertIn('cacheCoherent',s)

    def test_refresh_schedule_and_ssr_range(self):
        for period in (2,4):
            for x in range(4):
                for y in range(4):
                    for start in range(12):
                        self.assertEqual(sum((x+y+frame)%period==0 for frame in range(start,start+period)),1)
        trace=(ROOT/'shaders/lib/reflection/trace.glsl').read_text()
        material=(ROOT/'shaders/lib/reflection/material_trace.glsl').read_text()
        self.assertIn('int steps,float maxTravel,int refineBudget',trace)
        self.assertIn('refine<refineBudget',trace)
        self.assertLess(material.index('traceRange=steps<=8?12.0:48.0;',material.index('#if SSR_FOOTPRINT > 0')),material.index('steps=min(steps,reduced)'))
