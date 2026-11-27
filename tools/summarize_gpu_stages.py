"""Summarize nested asynchronous GPU timestamp captures without double counting."""

import argparse
import csv
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize(path):
    stages = defaultdict(list)
    totals = {}
    exclusive = defaultdict(float)
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            frame = int(row["frame"])
            duration = float(row["gpu_ms"])
            own = float(row["self_gpu_ms"])
            if (
                not math.isfinite(duration)
                or not math.isfinite(own)
                or duration < 0
                or own < -0.00001
            ):
                raise ValueError("Invalid GPU timestamp interval")
            name = row["pass"]
            if not name.startswith("__frame__"):
                raise ValueError("Missing GPU frame scope")
            if name == "__frame__":
                if frame in totals or duration <= 0:
                    raise ValueError("Duplicate or empty GPU frame")
                totals[frame] = duration
            stages[name].append((duration, own))
            exclusive[frame] += own
    if not totals or set(totals) != set(exclusive):
        raise ValueError("Missing measured GPU totals")
    for frame, duration in totals.items():
        if abs(exclusive[frame] - duration) > max(0.0001, duration * 0.0001):
            raise ValueError("GPU scope accounting does not match the frame total")
    values = list(totals.values())
    ranked = [
        dict(
            stage=name,
            samples=len(samples),
            mean_ms=statistics.mean(value[0] for value in samples),
            mean_self_ms=statistics.mean(value[1] for value in samples),
            p95_ms=percentile([value[0] for value in samples], 0.95),
        )
        for name, samples in stages.items()
    ]
    return dict(
        capture=str(path),
        frames=len(values),
        mean_gpu_ms=statistics.mean(values),
        median_gpu_ms=statistics.median(values),
        p95_gpu_ms=percentile(values, 0.95),
        p99_gpu_ms=percentile(values, 0.99),
        gpu_p95_within_240fps_budget=percentile(values, 0.95) <= 1000 / 240,
        stages=sorted(ranked, key=lambda row: row["mean_self_ms"], reverse=True),
        scope="Iris level render, excluding presentation; frame intervals require a separate capture",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    arguments = parser.parse_args()
    print(json.dumps(summarize(arguments.capture), indent=2))


if __name__ == "__main__":
    main()
