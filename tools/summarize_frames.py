#!/usr/bin/env python3
"""Summarize the frame intervals emitted by LumenWeave Frame Capture."""

import argparse
import csv
import math
import statistics
from pathlib import Path


def summarize(path):
    with path.open(newline="", encoding="utf-8") as stream:
        intervals = sorted(
            int(row["frame_ns"]) / 1_000_000 for row in csv.DictReader(stream)
        )
    count = len(intervals)
    if not intervals or intervals[0] <= 0:
        raise ValueError(f"Expected positive frame intervals in {path}")
    slowest = math.ceil(count * 0.01)
    return (
        count,
        sum(intervals) / 1000,
        1000 / statistics.mean(intervals),
        statistics.median(intervals),
        intervals[math.ceil(count * 0.95) - 1],
        intervals[math.ceil(count * 0.99) - 1],
        1000 / statistics.mean(intervals[-slowest:]),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", type=Path, nargs="+")
    args = parser.parse_args()
    print("capture,frames,seconds,mean_fps,median_ms,p95_ms,p99_ms,1pct_low_fps")
    for path in args.captures:
        count, *metrics = summarize(path)
        print(f"{path.stem},{count}," + ",".join(f"{value:.3f}" for value in metrics))


if __name__ == "__main__":
    main()
