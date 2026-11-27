"""Summarize candidate-indexed frame, GPU, telemetry and readback evidence."""

import argparse
import csv
import hashlib
import json
import statistics
from datetime import datetime
from pathlib import Path

from summarize_frames import summarize


def image_comparison(directory, left, right):
    from PIL import Image, ImageChops, ImageStat

    paths = [directory / f"{label}.png" for label in (left, right)]
    if not all(path.exists() for path in paths):
        return None
    regions = {"wall": (60, 90, 500, 350), "floor": (100, 910, 650, 1030),
               "shadow": (1120, 650, 1380, 780), "foliage": (820, 80, 1240, 250)}
    result = {"left": left, "right": right, "regions": {}}
    with Image.open(paths[0]) as first, Image.open(paths[1]) as second:
        if first.size != (1920, 1080) or second.size != first.size:
            raise ValueError("The fixed-camera fixture ROIs require native 1920x1080 screenshots")
        for name, bounds in regions.items():
            difference = ImageChops.difference(first.crop(bounds).convert("RGB"),
                                              second.crop(bounds).convert("RGB"))
            result["regions"][name] = {"bounds": bounds,
                                       "rgb_mae_code8": statistics.mean(ImageStat.Stat(difference).mean)}
    return result


def telemetry(directory, timing):
    path = directory / "gpu-telemetry.csv"
    if not path.exists() or not timing:
        return {}
    start = datetime.fromisoformat(timing["frame_start"])
    end = datetime.fromisoformat(timing["frame_end"])
    selected = []
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream, skipinitialspace=True):
            timestamp = datetime.strptime(row["timestamp"].strip(), "%Y/%m/%d %H:%M:%S.%f")
            timestamp = timestamp.replace(tzinfo=start.tzinfo)
            if start <= timestamp <= end:
                selected.append(row)
    result = {"samples": len(selected)}
    for field in ("utilization.gpu [%]", "clocks.current.graphics [MHz]",
                  "power.draw [W]", "temperature.gpu"):
        values = []
        for row in selected:
            value = row.get(field, "").strip().split(" ")[0]
            try:
                values.append(float(value))
            except ValueError:
                continue
        if values:
            result[field] = statistics.median(values)
    return result


def analyze(directory,capture_pattern="capture-reuse_*.csv"):
    result = {"directory": str(directory), "cases": {}}
    pairs = (("reuse_ref_a", "reuse_exact_a"), ("reuse_ref_b", "reuse_exact_b"),
             ("reuse_ref_a", "reuse_ref_b"), ("reuse_exact_a", "reuse_exact_b"),
             ("reuse_exact_a", "reuse_half_a"), ("reuse_bridge1_a", "reuse_bridge2_a"))
    result["image_comparisons"] = [comparison for left, right in pairs
                                   if (comparison := image_comparison(directory, left, right)) is not None]
    digest = directory / "shader-pack-sha256.txt"
    if digest.exists():
        result["shader_archive"] = digest.read_text(encoding="utf-8").strip()
    log = directory / "logs/latest.log"
    if log.exists():
        result["readbacks"] = [line for line in log.read_text(encoding="utf-8").splitlines()
                               if "LumenWeave P4 readback" in line]
        result["handoffs"] = [line for line in log.read_text(encoding="utf-8").splitlines()
                              if "Persistent seed handoff:" in line]
    for capture in sorted(directory.glob(capture_pattern)):
        label = capture.stem.removeprefix("capture-")
        count, seconds, fps, median, p95, p99, low = summarize(capture)
        case = {"frames": count, "seconds": seconds, "mean_fps": fps,
                "median_ms": median, "p95_ms": p95, "p99_ms": p99, "1pct_low_fps": low}
        settings = directory / f"settings-{label}.txt"
        case["settings"] = settings.read_text(encoding="utf-8").splitlines()
        timing_path = directory / f"timing-{label}.json"
        timing = json.loads(timing_path.read_text(encoding="utf-8")) if timing_path.exists() else {}
        case["telemetry"] = telemetry(directory, timing)
        stages_path = directory / f"gpu-stages-{label}.csv"
        if stages_path.exists():
            stages = {}
            with stages_path.open(encoding="utf-8", newline="") as stream:
                for row in csv.DictReader(stream):
                    stages.setdefault(row["pass"], []).append(float(row["self_gpu_ms"]))
            case["gpu_exclusive_ms"] = {name: statistics.mean(values) for name, values in stages.items()}
        seeds = directory / f"seeds-benchmark-{label}.bin"
        if seeds.exists():
            case["seed_sha256"] = hashlib.sha256(seeds.read_bytes()).hexdigest()
        result["cases"][label] = case
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("instances", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--capture-pattern",default="capture-reuse_*.csv")
    args = parser.parse_args()
    report = {"scope": "Frame presentation and GPU timestamps are separate captures. "
                       "Clock/load drift must be assessed before attributing performance changes.",
              "instances": [analyze(path,args.capture_pattern) for path in args.instances]}
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
