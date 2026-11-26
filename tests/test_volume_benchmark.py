import csv
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from volume_benchmark import analyze,REQUIRED


class VolumeBenchmarkTests(unittest.TestCase):
    def test_matched_repeats_and_unmet_target(self):
        # Synthetic unit fixture, not a real GPU result.
        with TemporaryDirectory() as directory:
            root=Path(directory)
            def captures(label,times):
                result=[]
                for i,ms in enumerate(times):
                    a=root/f"{label}-{i}-frames.csv"
                    b=root/f"{label}-{i}-passes.csv"
                    with a.open("w",newline="") as f:
                        w=csv.writer(f)
                        w.writerow(("frame","gpu_ms"))
                        w.writerows((j,ms) for j in range(300))
                    with b.open("w",newline="") as f:
                        w=csv.writer(f)
                        w.writerow(("frame","pass","gpu_ms"))
                        w.writerows((j,"composite_b",ms/10) for j in range(3))
                    result.append(dict(source="measured_gpu",scene="fixture",motion="stationary",
                        quality_accepted=True,frame_csv=a.name,pass_csv=b.name))
                return result
            env={k:"fixture" for k in REQUIRED}
            env.update(baseline_commit="old",candidate_commit="new")
            entry=dict(scene="fixture",motion="stationary",
                       baseline=captures("baseline",[8,8.1,8.2]),
                       candidate=captures("candidate",[4.8,4.9,5.1]))
            manifest=dict(environment=env,scenes=[entry])
            report=analyze(manifest,root)["scenes"][0]
            self.assertAlmostEqual(report["delta_median_gpu_ms"],-3.2)
            self.assertFalse(report["target_met_in_all_runs"])
            self.assertTrue(analyze(manifest,root,5.2)["scenes"][0]["target_met_in_all_runs"])
            self.assertLess(report["pass_deltas"][0]["delta_ms"],0)
            entry["candidate"][0]["quality_accepted"]=False
            with self.assertRaises(ValueError):
                analyze(manifest,root)
            entry["candidate"][0]["quality_accepted"]=True
            entry["candidate"][1]=entry["candidate"][0]
            with self.assertRaises(ValueError):
                analyze(manifest,root)
