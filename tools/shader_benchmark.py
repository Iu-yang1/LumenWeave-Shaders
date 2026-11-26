#!/usr/bin/env python3
"""Analyze matched cross-shader captures; no invented performance values."""
import argparse
import json
import statistics
from pathlib import Path

from dimension_budget import frame_samples
from gpu_pass_profile import percentile
from summarize_frames import summarize

ENV=("gpu","driver","cpu","minecraft","iris","sodium","resolution","render_distance","fov","resource_pack")
def analyze(manifest,root):
    env=manifest["environment"]
    if any(not env.get(k) for k in ENV):
        raise ValueError("Incomplete matched environment")
    packs=manifest["packs"]
    if len(packs)<2 or len({p["id"] for p in packs})!=len(packs):
        raise ValueError("At least two unique packs required")
    if any(not p.get("version") or not p.get("profile") or not p.get("sha256") for p in packs):
        raise ValueError("Pin every pack version, profile and ZIP digest")
    ids={p["id"] for p in packs}
    used=set()
    results=[]
    for scene in manifest["scenes"]:
        for key in ("id","world_seed","camera_path","weather","time","dimension","comparison"):
            if key not in scene: raise ValueError(f"Missing scene field: {key}")
        if scene["comparison"] not in ("default","matched_features"):
            raise ValueError("Comparison must be default or matched_features")
        if set(scene["runs"])!=ids:
            raise ValueError("All packs must cover the same scene")
        scores={}
        for pack,runs in scene["runs"].items():
            if len(runs)<3: raise ValueError("At least three repeats per pack")
            frames=[]; gpu=[]; quality=[]
            for run in runs:
                if run.get("source")!="measured_gpu" or run.get("warmup_frames",0)<300:
                    raise ValueError("Measured GPU source and 300 warmup frames required")
                for key in ("frame_csv","gpu_csv","screenshot"):
                    path=(root/run[key]).resolve()
                    if path in used or not path.is_file(): raise ValueError("Capture files must exist and be independent")
                    used.add(path)
                interval=summarize(root/run["frame_csv"])
                if interval[0]<300: raise ValueError("At least 300 presented frames required")
                frames.append(interval)
                values=frame_samples(root/run["gpu_csv"])
                gpu.append((statistics.median(values),percentile(values,.95),percentile(values,.99)))
                quality.append(run.get("quality_accepted") is True)
            scores[pack]={"repeats":len(runs),"median_present_ms":statistics.median(x[3] for x in frames),
                "p95_present_ms":max(x[4] for x in frames),"p99_present_ms":max(x[5] for x in frames),
                "median_mean_fps":statistics.median(x[2] for x in frames),"median_1pct_low_fps":statistics.median(x[6] for x in frames),
                "median_gpu_ms":statistics.median(x[0] for x in gpu),"worst_p95_gpu_ms":max(x[1] for x in gpu),
                "worst_p99_gpu_ms":max(x[2] for x in gpu),"quality_accepted":all(quality)}
        results.append({"scene":{k:v for k,v in scene.items() if k!="runs"},"packs":scores})
    if not results: raise ValueError("No measured scenes")
    return {"environment":env,"packs":packs,"scenes":results,"warning":"Operator-supplied measured captures; quality acceptance is not inferred from frame rate."}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("manifest",type=Path);p.add_argument("--output",type=Path)
    args=p.parse_args()
    report=json.dumps(analyze(json.loads(args.manifest.read_text(encoding="utf-8")),args.manifest.parent),indent=2,ensure_ascii=False)+"\n"
    if args.output: args.output.write_text(report,encoding="utf-8")
    else: print(report,end="")

if __name__=="__main__":
    main()
