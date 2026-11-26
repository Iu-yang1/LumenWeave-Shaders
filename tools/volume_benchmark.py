#!/usr/bin/env python3
"""Compare actual P32/P40 GPU capture repetitions without estimating FPS.

Manifest fields: environment metadata and scenes, each with baseline and
candidate run lists (three or more repetitions, same scene/motion).
Each run supplies whole-GPU-frame and RenderDoc pass CSV paths. The operator
must affirm quality acceptance; neither this program nor CI can attest the
physical provenance of the supplied files.
"""
import argparse
import json
import math
import statistics
from pathlib import Path

from dimension_budget import frame_samples
from gpu_pass_profile import load_rows,percentile,compare,summarize

REQUIRED=("gpu","driver","minecraft","iris","sodium","resolution","render_distance",
          "fov","profile","baseline_commit","candidate_commit")


def summarize_runs(runs,root,scene,motion):
    if len(runs)<3:
        raise ValueError("At least three independent repetitions required")
    medians,p95s,rows=[],[],[]
    used=set()
    for n,run in enumerate(runs):
        if (run.get("source")!="measured_gpu" or run.get("scene")!=scene or
                run.get("motion")!=motion or run.get("quality_accepted") is not True):
            raise ValueError("Unmatched GPU scene, motion, or unaccepted image quality")
        files=(root/run["frame_csv"],root/run["pass_csv"])
        for file in files:
            if file.resolve() in used:
                raise ValueError("Each repetition needs distinct capture files")
            used.add(file.resolve())
        values=frame_samples(files[0])
        medians.append(statistics.median(values))
        p95s.append(percentile(values,.95))
        passes=load_rows(files[1])
        stats=summarize(passes)
        if not stats or min(row["frames"] for row in stats)<3:
            raise ValueError("At least three frames per mapped pass")
        rows.extend({**row,"frame":f"{n}:{row['frame']}"} for row in passes)
    return {"runs":len(runs),"median_gpu_ms":statistics.median(medians),
            "median_p95_gpu_ms":statistics.median(p95s),
            "worst_p95_gpu_ms":max(p95s)},rows,used


def analyze(manifest,root,target=5.0):
    if not math.isfinite(target) or target<=0:
        raise ValueError("Target must be positive and finite")
    env=manifest["environment"]
    if any(not env.get(key) for key in REQUIRED):
        raise ValueError("Missing matched environment metadata")
    if env["baseline_commit"]==env["candidate_commit"]:
        raise ValueError("Select different baseline and candidate commits")
    if not manifest.get("scenes"):
        raise ValueError("No measured scenes")
    results=[]
    seen=set()
    for entry in manifest["scenes"]:
        scene,motion=entry["scene"],entry["motion"]
        if motion not in ("stationary","moving") or (scene,motion) in seen:
            raise ValueError("Invalid or duplicate scene/motion pair")
        seen.add((scene,motion))
        a,ar,af=summarize_runs(entry["baseline"],root,scene,motion)
        b,br,bf=summarize_runs(entry["candidate"],root,scene,motion)
        if af&bf:
            raise ValueError("Baseline and candidate must be independent captures")
        results.append({"scene":scene,"motion":motion,"baseline":a,"candidate":b,
                        "delta_median_gpu_ms":b["median_gpu_ms"]-a["median_gpu_ms"],
                        "target_met_in_all_runs":b["worst_p95_gpu_ms"]<=target,
                        "pass_deltas":compare(ar,br)})
    return {"environment":env,"target_gpu_ms":target,"scenes":results}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("manifest",type=Path)
    p.add_argument("--target-gpu-ms",type=float,default=5.0)
    p.add_argument("--output",type=Path)
    args=p.parse_args()
    report=analyze(json.loads(args.manifest.read_text(encoding="utf-8")),
                   args.manifest.parent,args.target_gpu_ms)
    output=json.dumps(report,indent=2,ensure_ascii=False)+"\n"
    if args.output:
        args.output.write_text(output,encoding="utf-8")
    else:
        print(output,end="")

if __name__=="__main__":
    main()
