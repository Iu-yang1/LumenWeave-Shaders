"""Synthetic work-count and equivalence model; not measured GPU FPS."""
import itertools, random, math, json
import numpy as np

def tiles(a):
    n=a.shape[0]; s=n//4
    return a.reshape(s,4,s,4,s,4).any(axis=(1,3,5))

def shift(a, move, fill=0):
    n=a.shape[0]; out=np.full_like(a,fill)
    src=[]; dst=[]
    for d in move:
        if abs(d)>=n:return out
        src.append(slice(max(d,0),min(n,n+d)))
        dst.append(slice(max(-d,0),min(n,n-d)))
    out[tuple(dst)]=a[tuple(src)]
    return out

def skip_mask(old_support, old_pending, dirty, move, fresh):
    side=dirty.shape[0]; skip=np.zeros_like(dirty)
    if not fresh:return skip
    for t in np.ndindex(dirty.shape):
        if dirty[t]:continue
        lo=tuple(4*x+d for x,d in zip(t,move)); hi=tuple(x+3 for x in lo)
        if min(lo)<0 or max(hi)>=side*4:continue
        first=tuple(x//4 for x in lo); last=tuple(x//4 for x in hi)
        if first==last:skip[t]=not old_pending[first]
        else:
            region=tuple(slice(x,y+1) for x,y in zip(first,last))
            skip[t]=not (old_pending[region].any() or old_support[region].any())
    return skip

def field(n, pos, lamps, walls):
    a=np.zeros((n,n,n),np.float32); b=a.copy()
    for (x,y,z),v in lamps.items():
        for dx,dy,dz in itertools.product(range(-5,6),repeat=3):
            d=abs(dx)+abs(dy)+abs(dz)
            if d>5:continue
            p=(x+dx-pos[0],y+dy-pos[1],z+dz-pos[2])
            if min(p)<0 or max(p)>=n:continue
            if d<=4:a[p]=max(a[p],v*.73**d)
            b[p]=max(b[p],v*.12*.73**d)
    for w in walls:
        p=tuple(x-y for x,y in zip(w,pos))
        if min(p)>=0 and max(p)<n:a[p]=b[p]=0
    return a,b

def run(n, diffuse, scenario):
    rng=random.Random(927+n); lamps={}
    # Explicitly synthetic sparse illumination, with repeatable source density.
    for _ in range(round(n**3/18000)):
        lamps[tuple(rng.randrange(4,n-4) for _ in range(3))]=rng.uniform(.2,1.5)
    walls=set(); pos=(0,0,0); prev=(0,0,0); old_target=np.zeros((n,n,n),np.float32); old_diff=old_target.copy(); old=old_target.copy(); old_b=old_target.copy()
    support=tiles(old>0); pending=support.copy(); rows=[]
    for frame in range(12):
        if scenario=='walk':pos=(frame,0,0)
        elif scenario=='diagonal':pos=(frame,frame,frame)
        elif scenario=='aligned':pos=(frame*4,0,0)
        elif scenario=='edits' and frame in (3,6,9):
            p=(n//2,n//2,n//2); lamps[p]=1.5 if frame==3 else 0.0
            if frame==9:walls.add(p)
        move=tuple(a-b for a,b in zip(pos,prev)); fresh=frame!=0
        target,diff=field(n,pos,lamps,walls)
        if not diffuse:diff.fill(0)
        valid=shift(np.ones_like(old,dtype=bool),move,False) if fresh else np.zeros_like(old,dtype=bool)
        prev_target=shift(old_target,move); prev_diff=shift(old_diff,move)
        prev_old=shift(old,move); prev_b=shift(old_b,move)
        # Actual target changes + entered cells; expand to model conservative dirty radius.
        dirty=tiles((~valid)|(prev_target!=target)|(prev_diff!=diff))
        raw=dirty.copy()
        for d in itertools.product(range(-1,2),repeat=3):dirty|=shift(raw,d,False)
        skip=skip_mask(support,pending,dirty,move,fresh)
        expanded=skip.repeat(4,0).repeat(4,1).repeat(4,2)
        def evolve(t,h,half):
            q=np.where(valid,t+(h-t)*2**(-1/100/half),t)
            q=np.where(abs(q-t)<=np.maximum(abs(t)*.0015,.0005),t,q)
            return q.astype(np.float16).astype(np.float32)
        ta=target.astype(np.float16).astype(np.float32); tb=diff.astype(np.float16).astype(np.float32)
        want=evolve(ta,prev_old,.18); want_b=evolve(tb,prev_b,.28)
        for w in walls:
            p=tuple(x-y for x,y in zip(w,pos))
            if min(p)>=0 and max(p)<n:want[p]=want_b[p]=0
        got=np.where(expanded,prev_old,want); got_b=np.where(expanded,prev_b,want_b)
        assert np.array_equal(got,want), (n,scenario,frame,'direct')
        assert np.array_equal(got_b,want_b), (n,scenario,frame,'diffuse')
        baseline=n**3 if any(move) or not fresh else int((dirty|pending).sum())*64
        work=int((~skip).sum())*64
        if frame:rows.append((baseline,work))
        support=tiles((ta>0)|(tb>0)|(got>0)|(got_b>0));pending=tiles((ta!=got)|(tb!=got_b))
        old,old_b=got,got_b;old_target,old_diff=target,diff;prev=pos
    a=sum(x for x,y in rows); b=sum(y for x,y in rows)
    return {'grid':n,'scene':scenario,'frames':len(rows),'baseline_cells_per_frame':round(a/len(rows)), 'candidate_cells_per_frame':round(b/len(rows)), 'reduction_pct':round(100*(1-b/a),2) if a else None,'exact_match':True}

if __name__=='__main__':
    for n in (32,96,128):
        for scene in ('walk','diagonal','aligned','edits','static'):
            print(json.dumps(run(n,n==128,scene)),flush=True)
