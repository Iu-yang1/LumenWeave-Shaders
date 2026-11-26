import csv
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from shader_benchmark import analyze,ENV

class ShaderBenchmarkTests(unittest.TestCase):
    def test_independent_matched_runs(self):
        # Synthetic fixture solely for analyzer correctness.
        with TemporaryDirectory() as tmp:
            root=Path(tmp)
            packs=[dict(id=n,version="fixture",profile="fixture",sha256="fixture") for n in ("a","b")]
            scene=dict(id="fixture",world_seed=0,camera_path="fixture",weather="clear",time=0,dimension="overworld",comparison="matched_features",runs={})
            for pack,ms in (("a",8),("b",10)):
                scene["runs"][pack]=[]
                for i in range(3):
                    prefix=f"{pack}{i}"
                    for suffix,header,rows in (("present.csv",("frame_ns",),[(ms*1000000,)]*300),("gpu.csv",("frame","gpu_ms"),[(j,ms) for j in range(300)])):
                        with (root/(prefix+suffix)).open("w",newline="") as out:
                            writer=csv.writer(out);writer.writerow(header);writer.writerows(rows)
                    (root/(prefix+".png")).write_bytes(b"fixture")
                    scene["runs"][pack].append(dict(source="measured_gpu",warmup_frames=300,frame_csv=prefix+"present.csv",gpu_csv=prefix+"gpu.csv",screenshot=prefix+".png",quality_accepted=True))
            manifest=dict(environment={k:"fixture" for k in ENV},packs=packs,scenes=[scene])
            report=analyze(manifest,root)["scenes"][0]["packs"]
            self.assertEqual(report["a"]["median_mean_fps"],125)
            self.assertEqual(report["b"]["median_gpu_ms"],10)
            scene["runs"]["b"][0]["gpu_csv"]=scene["runs"]["a"][0]["gpu_csv"]
            with self.assertRaises(ValueError): analyze(manifest,root)
