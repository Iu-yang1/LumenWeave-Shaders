"""Deterministic CPU proxy for V5.4; not GPU timings or shader execution."""
import itertools
import math
import random
import json
import statistics


def tile_cases():
    rng=random.Random(54)
    rows=[]
    for n in (96,128):
        s=n//4
        domain=list(itertools.product(range(s),repeat=3))
        occupied={t for t in domain if rng.random()<.04}
        pending={t for t in occupied if rng.random()<.25}
        for motion in ((0,0,0),(1,0,0),(1,1,1),(4,0,0),(n,0,0)):
            expected=[]
            for t in domain:
                lo=tuple(4*x+d for x,d in zip(t,motion)); hi=tuple(x+3 for x in lo)
                valid=min(lo)>=0 and max(hi)<n
                dirty=not valid or rng.random()<.01
                keep=False
                if not dirty:
                    first=tuple(x//4 for x in lo); last=tuple(x//4 for x in hi)
                    if first==last: keep=first not in pending
                    else: keep=not any(q in occupied or q in pending for q in itertools.product(*(range(a,b+1) for a,b in zip(first,last))))
                if not keep:expected.append(t)
            # Unordered reservations must neither lose nor duplicate entries.
            groups={}
            for t in expected: groups.setdefault(tuple(x//4 for x in t),[]).append(t)
            batches=list(groups.values());rng.shuffle(batches)
            compacted=[q for batch in batches for q in batch]
            assert sorted(compacted)==sorted(expected) and len(compacted)==len(set(compacted))
            rows.append(dict(grid=n,motion=motion,old_groups=len(domain),new_groups=len(compacted),reduction_pct=round(100*(1-len(compacted)/len(domain)),2)))
    return rows


def history_cases():
    rng=random.Random(55)
    n=20000; accepted=0; err=[]; reads_old=reads_new=0
    for i in range(n):
        c=rng.uniform(.01,3.0)
        # Explicit synthetic mix: 70% low-motion, 80% native opaque, 85% compatible geometry.
        fast=rng.random()<.70 and rng.random()<.80
        valid=rng.random()<.85
        samples=[c*(1+rng.uniform(-.025,.025)) for _ in range(4)]
        if rng.random()<.55:samples[0]=c*(1+rng.uniform(-.005,.005))
        w=[rng.random() for _ in range(4)];w=[x/sum(w) for x in w]
        ref=sum(a*b for a,b in zip(samples,w))
        reads_old+=8
        if fast and valid and abs(samples[0]-c)<=.001+abs(c)*.008:
            accepted+=1;reads_new+=2
            assert abs(samples[0]-c)<=.001+abs(c)*.008
            err.append(abs(samples[0]-ref)/max(c,.01))
        else:reads_new+=8
    return dict(pixels=n,accepted=accepted,history_pair_fetches_old=reads_old,history_pair_fetches_new=reads_new,reduction_pct=round(100*(1-reads_new/reads_old),2),max_relative_error_vs_bilinear=round(max(err),5),mean_relative_error_vs_bilinear=round(statistics.mean(err),5))


def gi_ssr_cases():
    rng=random.Random(56);n=20000
    gi_old=gi_new=ssr_old=ssr_new=0; errors=[];rough=0
    for i in range(n):
        coverage=rng.random()**3
        gi_old+=4*(coverage<.035)
        gi_new+=2*(coverage<.012)
        base=rng.uniform(.05,.35);a=rng.uniform(-.04,.04);b=rng.uniform(-.02,.02)
        rays=[base+a+b,base-a-b,base-a+b,base+a-b]
        if coverage<.012:errors.append(abs((rays[0]+rays[2])/2-sum(rays)/4))
        is_rough=rng.random()<.70;rough+=is_rough
        if not is_rough: ssr_old+=16;ssr_new+=16
        else:
            ssr_old+=16*(coverage<.20)
            ssr_new+=8*(coverage<.01)
    return dict(pixels=n,gi_reference_fallback_rays=gi_old,gi_candidate_fallback_rays=gi_new,gi_reduction_pct=round(100*(1-gi_new/gi_old),2),gi_two_ray_mean_abs_error=round(statistics.mean(errors),5),gi_two_ray_max_abs_error=round(max(errors),5),ssr_reference_fallback_steps=ssr_old,ssr_candidate_fallback_steps=ssr_new,ssr_reduction_pct=round(100*(1-ssr_new/ssr_old),2),rough_pixels=rough)


def slab(h,dy,depth):
    if abs(dy)<.05:return None
    a,b=sorted(((156-h)/dy,(174-h)/dy))
    return (a,b) if a>=32 and b<=min(depth,630)-2 else None


def clouds():
    rng=random.Random(57);accepted=0; tested=10000;max_err=0.;errors=[]
    for _ in range(tested):
        h=rng.uniform(60,140);angle=rng.uniform(.1,1.3);dx=math.cos(angle);dy=math.sin(angle);depth=rng.uniform(100,680)
        interval=slab(h,dy,depth)
        if not interval:continue
        move=rng.uniform(-.3,.3);dt=1/100;wind=1.1*dt
        a,b=interval;mid=(a+b)/2
        px=dx*mid+move+wind;py=dy*mid;length=math.hypot(px,py);ux,uy=px/length,py/length
        old=slab(h,uy,640)
        if not old or abs(move+wind)*(b-a)/(2*mid)>=.35:continue
        prior_depth=depth+move
        if prior_depth<=old[1]+2:continue
        def trans(x,rx,ry,windphase):
            total=0.
            for i in range(12):
                y=156+(i+.5)*18/12
                wx=x+rx*(y-h)/ry+windphase
                density=.5+.25*math.sin(wx*.09)+.2*math.cos(wx*.23)
                total+=density*(18/12)/ry
            return math.exp(-.15*total)
        cur=trans(move,dx,dy,wind);prev=trans(0,ux,uy,0)
        error=abs(cur-prev);errors.append(error);max_err=max(max_err,error);accepted+=1
    return dict(tested=tested,translation_eligible=accepted,eligible_pct=round(100*accepted/tested,2),max_one_frame_transmission_error=round(max_err,6),mean_one_frame_transmission_error=round(statistics.mean(errors),6),note='Before checkerboard/freshness/donor-rounding gates; no real cloud noise or occluder render')


def blur():
    # True separability of product Gaussian on synthetic 9x9 luminance data.
    rng=random.Random(58);g=[math.exp(-.5*(i/2)**2) for i in range(-4,5)];g=[x/sum(g) for x in g]
    errors=[]
    for _ in range(1000):
        p=[[rng.random() for _ in g] for _ in g]
        direct=sum(p[y][x]*g[y]*g[x] for y in range(9) for x in range(9))
        separable=sum(g[y]*sum(p[y][x]*g[x] for x in range(9)) for y in range(9))
        errors.append(abs(direct-separable))
    return dict(gaussian_direct_taps=81,gaussian_separable_taps=18,max_abs_error=max(errors),current_balanced_donor_locations=12,mip_assist_depth_probes=4,mip_assist_color_fetches=2,note='Gaussian identity only; actual bilateral CoC filter is not exactly separable, mip build overhead excluded')


if __name__=='__main__':
    print(json.dumps(dict(tiles=tile_cases(),history=history_cases(),gi_ssr=gi_ssr_cases(),clouds=clouds(),blur=blur()),indent=2))
