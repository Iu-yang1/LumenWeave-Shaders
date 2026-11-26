#!/usr/bin/env python3
"""Summarize measured GPU pass timings and optional measured memory counters.

Input normalized CSV: frame,pass,gpu_ms[,read_bytes,write_bytes].
Each row is one captured pass occurrence. Multiple occurrences of a pass in
a frame are added. Byte columns must be actual GPU counter values, not
logical shader access estimates; leave them blank when unavailable.
"""
import argparse
import csv
import math
import statistics
import sys
from collections import defaultdict


def percentile(values, fraction):
    ordered = sorted(values)
    rank = (len(ordered)-1)*fraction
    low = int(rank)
    high = min(low+1, len(ordered)-1)
    return ordered[low]+(ordered[high]-ordered[low])*(rank-low)


def optional_bytes(row, key):
    raw = (row.get(key) or "").strip()
    if not raw:
        return None
    value = float(raw)
    if not math.isfinite(value) or value < 0:
        raise ValueError(f"Invalid {key}: {raw}")
    return value


def summarize(rows):
    frames = defaultdict(dict)
    for row in rows:
        frame = row["frame"].strip()
        name = row["pass"].strip()
        ms = float(row["gpu_ms"])
        if not frame or not name or not math.isfinite(ms) or ms < 0:
            raise ValueError(f"Invalid timing row: {row}")
        read, write = optional_bytes(row, "read_bytes"), optional_bytes(row, "write_bytes")
        value = frames[name].setdefault(frame, [0., 0., 0., True])
        value[0] += ms
        if read is None or write is None:
            value[3] = False
        else:
            value[1] += read
            value[2] += write
    result = []
    for name, per_frame in frames.items():
        samples = list(per_frame.values())
        times = [sample[0] for sample in samples]
        measured = [sample for sample in samples if sample[3] and sample[0] > 0]
        duration = sum(sample[0] for sample in measured)
        result.append({
            "pass": name, "frames": len(times), "median_ms": statistics.median(times),
            "p95_ms": percentile(times, .95), "mean_ms": statistics.fmean(times),
            "counter_frames": len(measured),
            "read_GB_s": sum(sample[1] for sample in measured)/(duration*1e6) if duration else None,
            "write_GB_s": sum(sample[2] for sample in measured)/(duration*1e6) if duration else None,
        })
    return sorted(result, key=lambda row: (-row["median_ms"],row["pass"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_csv")
    args = parser.parse_args()
    try:
        with open(args.capture_csv, newline="", encoding="utf-8-sig") as source:
            reader = csv.DictReader(source)
            if not {"frame","pass","gpu_ms"}.issubset(reader.fieldnames or []):
                raise ValueError("Required CSV columns: frame,pass,gpu_ms")
            result = summarize(reader)
        fields = ["pass","frames","median_ms","p95_ms","mean_ms","counter_frames","read_GB_s","write_GB_s"]
        writer = csv.DictWriter(sys.stdout, fieldnames=fields)
        writer.writeheader()
        writer.writerows(result)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
