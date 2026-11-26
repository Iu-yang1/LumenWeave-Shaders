#!/usr/bin/env python3
"""Export actual RenderDoc replay GPU timestamp counters, not shader estimates.

Run with a Python environment matching the RenderDoc Python module.
Map event ID ranges to pass names using an explicit JSON mapping:
{"shadow": [[10, 82]], "prepare": [[90, 100]]}
Unmapped timed events remain visible as "unclassified"; no inference.
"""
import argparse
import csv
import json
import math
from pathlib import Path


def event_owner(mapping):
    spans=[]
    for name,ranges in mapping.items():
        if not name or name=="unclassified":
            raise ValueError("Invalid pass name")
        for first,last in ranges:
            if not isinstance(first,int) or not isinstance(last,int) or first<1 or last<first:
                raise ValueError(f"Invalid event range for {name}")
            spans.append((first,last,name))
    spans.sort()
    if any(a[1]>=b[0] for a,b in zip(spans,spans[1:])):
        raise ValueError("Pass event ranges overlap")
    return spans


def counter_rows(frame,results,spans):
    rows=[]
    seen=set()
    for result in results:
        event=int(result.eventId)
        seconds=float(result.value.d)
        if event in seen:
            raise ValueError(f"Duplicate GPU timing event {event}")
        seen.add(event)
        if not math.isfinite(seconds) or seconds<0:
            continue
        name=next((name for first,last,name in spans if first<=event<=last),"unclassified")
        rows.append({"frame":frame,"pass":name,"gpu_ms":seconds*1000,
                     "event_id":event,"read_bytes":"","write_bytes":""})
    if not rows:
        raise ValueError("Capture has no valid GPU duration counters")
    return rows


def export_capture(rd,path,frame,spans):
    capture=rd.OpenCaptureFile()
    try:
        status=capture.OpenFile(str(path),"",None)
        if status!=rd.ResultCode.Succeeded:
            raise RuntimeError(f"Cannot open {path}: {status}")
        status,controller=capture.OpenCapture(rd.ReplayOptions(),None)
        if status!=rd.ResultCode.Succeeded:
            raise RuntimeError(f"Cannot replay {path}: {status}")
        try:
            counter=rd.GPUCounter.EventGPUDuration
            if counter not in controller.EnumerateCounters():
                raise RuntimeError("GPU duration counter unavailable on this replay device")
            return counter_rows(frame,controller.FetchCounters([counter]),spans)
        finally:
            controller.Shutdown()
    finally:
        capture.Shutdown()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture",type=Path)
    parser.add_argument("--map",type=Path,required=True)
    parser.add_argument("--frame",required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    import renderdoc as rd
    spans=event_owner(json.loads(args.map.read_text(encoding="utf-8")))
    rd.InitialiseReplay(rd.GlobalEnvironment(),[])
    try:
        rows=export_capture(rd,args.capture,args.frame,spans)
    finally:
        rd.ShutdownReplay()
    with args.output.open("w",newline="",encoding="utf-8") as output:
        writer=csv.DictWriter(output,fieldnames=["frame","pass","gpu_ms","event_id","read_bytes","write_bytes"])
        writer.writeheader()
        writer.writerows(rows)

if __name__=="__main__":
    main()
