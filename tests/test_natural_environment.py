import math
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))

from check_shaders import preview_profiles
from quality_budget import resource_budget
from analyze_deferred_ablation import STAGE,summarize


class NaturalEnvironmentTests(unittest.TestCase):
    def test_ablation_preserves_negative_results_and_does_not_sum(self):
        measured=lambda value:{"gpu_exclusive_ms":{STAGE:value}}
        report={"instances":[{"directory":"synthetic","shader_archive":"fixture",
                              "cases":{"env_full_a":measured(2.0),"env_full_b":measured(2.4),
                                       "diag_shadow":measured(1.0),"diag_wet":measured(2.5)}}]}
        result=summarize(report)["stages"]
        self.assertEqual(len(result),2)
        self.assertAlmostEqual(result[0]["marginal_saving_ms"],1.2)
        self.assertAlmostEqual(result[1]["marginal_saving_ms"],-.3)
        self.assertNotIn("total_saving_ms",summarize(report))

    def test_no_new_gpu_resources_or_forced_resolution_reduction(self):
        extreme=preview_profiles(ROOT/"shaders")["profile.Extreme"]
        reference=resource_budget({**extreme,"WEATHER_COUPLING":"0"},1920,1080)
        coupled=resource_budget({**extreme,"WEATHER_COUPLING":"1"},1920,1080)
        self.assertEqual(reference,coupled)
        defaults=(ROOT/"shaders/lib/quality.glsl").read_text(encoding="utf-8")
        self.assertIn("#define LW_DEFERRED_DIAGNOSTIC 0 ",defaults)
        self.assertIn("#define GI_HISTORY_MODE 0 ",defaults)
        self.assertIn("#define GI_EDGE_RECONSTRUCTION 0 ",defaults)
        self.assertIn("#define EXTENSION_VOXELS 0 ",defaults)

    def test_wind_travel_is_continuous_and_forward(self):
        for gusts in (0.0,0.35,0.65,1.0):
            previous=None
            for step in range(36001):
                time=step*.1
                travel=time-gusts*2.0*math.sin(time*.11)
                if previous is not None:
                    self.assertGreater(travel-previous,.077)
                    self.assertLess(travel-previous,.123)
                previous=travel
        state=(ROOT/"shaders/lib/weather/state.glsl").read_text(encoding="utf-8")
        self.assertIn("return position-lwWindOffset;",state)
        vegetation=(ROOT/"shaders/lib/vegetation/wind.glsl").read_text(encoding="utf-8")
        self.assertNotIn("uniform float rainStrength;",vegetation)

    def test_plane_matching_preserves_sloped_surfaces(self):
        normal=(.4,.2,1.0)
        point=(0.0,0.0,-8.0)
        plane=sum(left*right for left,right in zip(normal,point))
        for horizontal in (-.4,-.1,.1,.4):
            ray=(horizontal,.1,-1.0)
            denominator=sum(left*right for left,right in zip(normal,ray))
            distance=plane/denominator
            expected_depth=-ray[2]*plane/denominator
            donor=tuple(value*distance for value in ray)
            self.assertAlmostEqual(sum(left*right for left,right in zip(normal,donor)),plane)
            self.assertAlmostEqual(expected_depth,-donor[2])
            self.assertGreater(expected_depth,0)


if __name__=="__main__":
    unittest.main()
