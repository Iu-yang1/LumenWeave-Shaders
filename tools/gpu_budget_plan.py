#!/usr/bin/env python3
"""Calibrate 240-FPS budgets from matched, measured GPU captures; no FPS prediction."""
import argparse
import csv
import json
import math
import statistics
from collections import defaultdict


def p95(xs):
    xs=sorted(xs)
    rank=(len(xs)-1)*.95
    lo=int(rank)
    return xs[lo]+(xs[min(lo+1,len(xs)-1)]-xs[lo])*(rank-lo)


def load_capture(path):
    with open(path,encoding='utf-8-sig',newline='') as f:
        rows=list(csv.DictReader(f))
    return capture(rows)


def capture(rows):
    frames=defaultdict(dict)
    for row in rows:
        frame=row['frame'].strip(); name=row['pass'].strip(); ms=float(row['gpu_ms'])
        if not frame or not name or not math.isfinite(ms) or ms<0:
            raise ValueError('Invalid capture row')
        if name in ('__frame__','__present__') and name in frames[frame]:
            raise ValueError('Duplicate total for frame '+frame)
        frames[frame][name]=frames[frame].get(name,0)+ms
    if not frames or any('__frame__' not in f or f['__frame__']<=0 for f in frames.values()):
        raise ValueError('Each frame must contain measured __frame__ GPU duration; cannot sum overlapping passes')
    present=all('__present__' in f and f['__present__']>0 for f in frames.values())
    # __present__ is optional measured whole-frame interval in ms, not GPU query time.
    if any('__present__' in f for f in frames.values()) and not present:
        raise ValueError('Incomplete __present__ interval series')
    totals=[f['__frame__'] for f in frames.values()]
    names=sorted(set().union(*(f.keys() for f in frames.values()))-{'__frame__','__present__'})
    stats={k:{'mean_ms':statistics.fmean(f[k] for f in frames.values() if k in f),'frames':sum(k in f for f in frames.values())} for k in names}
    return {'frames':len(frames),'gpu_mean_ms':statistics.fmean(totals),'gpu_p95_ms':p95(totals),'present_p95_ms':p95([f['__present__'] for f in frames.values()]) if present else None,'passes':stats}


def allocate(baseline,target_fps=240,reserve_ms=.3,protected=()):
    if not math.isfinite(target_fps) or not math.isfinite(reserve_ms) or target_fps<=0 or reserve_ms<0 or reserve_ms>=1000/target_fps:
        raise ValueError('Invalid FPS or headroom')
    budget=1000/target_fps-reserve_ms
    # Work only with passes sampled on every frame. Do not treat missing as zero.
    stats=baseline['passes']; n=baseline['frames']
    complete={k:v['mean_ms'] for k,v in stats.items() if v['frames']==n}
    missing=sorted(set(stats)-set(complete))
    total=sum(complete.values()); measured=baseline['gpu_mean_ms']
    if total>measured+max(.02,measured*.02):
        return {'target_gpu_ms':budget,'budget_status':'overlapping_or_inconsistent_passes','incomplete_passes':missing,'passes':[]}
    fixed=max(0,measured-total)+sum(v for k,v in complete.items() if k in protected)
    adjustable=sum(v for k,v in complete.items() if k not in protected)
    factor=min(1,max(0,budget-fixed)/adjustable) if adjustable else 0
    return {'target_gpu_ms':budget,'budget_status':'allocated' if fixed<=budget else 'fixed_work_exceeds_target','unattributed_or_protected_ms':fixed,'incomplete_passes':missing,'passes':[{'pass':k,'measured_mean_ms':v,'budget_ms':v if k in protected else v*factor,'requested_reduction_ms':0 if k in protected else v*(1-factor)} for k,v in sorted(complete.items(),key=lambda p:-p[1])]}


def choose(baseline,candidates,target_fps=240,reserve_ms=.3):
    target=1000/target_fps-reserve_ms
    rows=[]
    for name,cap in [('baseline',baseline),*candidates]:
        gpu=cap['gpu_p95_ms']<=target
        interval=cap['present_p95_ms']
        rows.append({'name':name,'gpu_p95_ms':cap['gpu_p95_ms'],'present_p95_ms':interval,'gpu_target_met':gpu,'whole_frame_target_met':None if interval is None else interval<1000/target_fps})
    # Candidate order is operator-supplied quality preference. Never combine unmeasured settings.
    selected=next((r['name'] for r in rows if r['gpu_target_met'] and r['whole_frame_target_met'] is True),None)
    gpu_only=next((r['name'] for r in rows if r['gpu_target_met'] and r['whole_frame_target_met'] is not False),None)
    return {'measured_candidates':rows,'selected_verified':selected,'gpu_budget_candidate':gpu_only}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline');p.add_argument('--candidate',action='append',default=[],metavar='NAME=CSV')
    p.add_argument('--fps',type=float,default=240);p.add_argument('--reserve-ms',type=float,default=.3)
    p.add_argument('--protect',action='append',default=[])
    a=p.parse_args()
    try:
        base=load_capture(a.baseline)
        candidates=[(item.split('=',1)[0],load_capture(item.split('=',1)[1])) for item in a.candidate]
        print(json.dumps({**allocate(base,a.fps,a.reserve_ms,a.protect),**choose(base,candidates,a.fps,a.reserve_ms)},indent=2))
    except (ValueError,KeyError,OSError,IndexError) as e:p.exit(1,str(e)+'\n')


if __name__=='__main__':main()
