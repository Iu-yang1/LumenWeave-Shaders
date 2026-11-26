#!/usr/bin/env python3
"""Select dimension budgets from measured, matched A/B GPU captures.

Input JSON manifest: device/loader metadata and per-dimension runs.
Frame CSV columns: frame,gpu_ms (actual whole GPU frame duration, not sums
of replay events). Pass CSV is the normalized RenderDoc timestamp export.
Each run must have identical scene ID and >=300 frame samples, >=3 distinct
capture frames. Quality acceptance is supplied by the operator.
No live shader option changes, no synthetic timings, no implied FPS.
"""
import argparse
import csv
import json
import math
import statistics
from pathlib import Path

from gpu_pass_profile import load_rows,percentile,summarize

DIMENSIONS={"overworld":"OVERWORLD_BUDGET","nether":"NETHER_BUDGET","end":"END_BUDGET"}


def frame_samples(path):
    with path.open(newline="",encoding="utf-8-sig") as source:
        reader=csv.DictReader(source)
        if not {"frame","gpu_ms"}.issubset(reader.fieldnames or []):
            raise ValueError("frame CSV requires frame,gpu_ms")
        frames={}
        for row in reader:
            frame=row["frame"].strip()
            value=float(row["gpu_ms"])
            if not frame or frame in frames or not math.isfinite(value) or value<=0:
                raise ValueError("Invalid or repeated frame timing")
            frames[frame]=value
    if len(frames)<300:
        raise ValueError("At least 300 measured GPU frames per run")
    return list(frames.values())


def measure(run,root):
    if run.get("source")!="measured_gpu" or run.get("quality_accepted") is not True:
        raise ValueError("Requires real GPU timing and operator-approved image quality")
    if type(run.get("mode")) is not int or run["mode"] not in (0,1,2):
        raise ValueError("Mode must be 0, 1, or 2")
    times=frame_samples(root/run["frame_csv"])
    passes=summarize(load_rows(root/run["pass_csv"]))
    if not passes or min(row["frames"] for row in passes)<3:
        raise ValueError("At least three captured frames per mapped pass")
    return {"mode":run["mode"],"median_ms":statistics.median(times),
            "p95_ms":percentile(times,.95),"frames":len(times),
            "passes":passes}


def select(runs,target_ms):
    # Retain the highest quality tier meeting the p95 target. If none meets
    # target, choose the fastest verified mode, never claim target achieved.
    qualifying=[r for r in runs if r["p95_ms"]<=target_ms]
    if qualifying:
        return min(qualifying,key=lambda r:(r["mode"],r["p95_ms"]))
    return min(runs,key=lambda r:(r["p95_ms"],r["median_ms"],r["mode"]))


def analyze(manifest,root,target_ms=5.0):
    if not math.isfinite(target_ms) or target_ms<=0:
        raise ValueError("Positive finite target required")
    for key in ("gpu","driver","minecraft","iris","sodium","resolution","shader_commit","profile"):
        if not manifest.get(key):
            raise ValueError(f"Missing matched environment field: {key}")
    output={"target_gpu_ms":target_ms,"environment":{k:v for k,v in manifest.items() if k!="dimensions"},
            "dimensions":{},"shader_options":{}}
    for dimension,option in DIMENSIONS.items():
        entry=manifest.get("dimensions",{}).get(dimension)
        if not entry:
            output["dimensions"][dimension]={"status":"unmeasured"}
            continue
        runs=entry["runs"]
        scene=entry.get("scene")
        if not scene or any(run.get("scene")!=scene for run in runs):
            raise ValueError(f"Unmatched scenes: {dimension}")
        measured=[measure(run,root) for run in runs]
        modes=[run["mode"] for run in measured]
        if len(set(modes))!=len(modes) or 1 not in modes or len(modes)<2:
            raise ValueError("Compare balanced mode against at least one distinct mode")
        winner=select(measured,target_ms)
        output["shader_options"][option]=winner["mode"]
        output["dimensions"][dimension]={"status":"measured","scene":scene,
            "selected":winner["mode"],"target_met":winner["p95_ms"]<=target_ms,"runs":measured}
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest",type=Path)
    parser.add_argument("--target-gpu-ms",type=float,default=5.0)
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    manifest=json.loads(args.manifest.read_text(encoding="utf-8"))
    result=analyze(manifest,args.manifest.parent,args.target_gpu_ms)
    text=json.dumps(result,indent=2,ensure_ascii=False)+"\n"
    if args.output:
        args.output.write_text(text,encoding="utf-8")
    else:
        print(text,end="")

if __name__=="__main__":
    main()
