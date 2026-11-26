"""CPU proxy for V5.6 optics and edge upscaler; not GPU execution."""
import json
import math
import random
import statistics

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)

def coc(d,focus,strength=.25,height=1080):
    return min(max(abs(1/focus-1/d)-.008,0)*32*strength,8)*height/1080

def idle(old,elapsed,active,dt,delay=8):
    elapsed=0 if active else min(elapsed+min(dt,.25),delay+3)
    target=smooth(delay,delay+2,elapsed)
    return target+(old-target)*2**(-min(dt,.25)/(.12 if active else .65)),elapsed

def upscale(colors,fx,fy,valid=(True,True,True,True)):
    # Scalar luminance proxy: matches shader kernel for gray RGB.
    w=[(fx if i&1 else 1-fx)*(fy if i&2 else 1-fy) for i in range(4)]
    total=sum(a for a,v in zip(w,valid) if v)
    if total<=.001:return colors[0],colors[0]
    c=[x if v else colors[0] for x,v in zip(colors,valid)]
    mean=sum(x*a for x,a,v in zip(c,w,valid) if v)/total
    gx=.5*(c[1]+c[3]-c[0]-c[2]);gy=.5*(c[2]+c[3]-c[0]-c[1])
    mag=math.hypot(gx,gy)
    if mag>1e-5:gx/=mag;gy/=mag
    else:gx=gy=0
    contrast=smooth(.04,.32,(max(c)-min(c))/max(max(c),.015))
    ew=[w[i]/(1+contrast*3*((float(i&1)-fx)*gx+(float(i>>1)-fy)*gy)**2) if valid[i] else 0 for i in range(4)]
    value=sum(x*a for x,a in zip(c,ew))/sum(ew)
    if all(valid):value=max(min(c),min(max(c),value+(value-mean)*.30*contrast))
    return value,mean

def run():
    idle_rows=[]
    for hz in (30,60,144,240):
        b=e=0;states={}
        for i in range(hz*14):
            active=i>=hz*12
            b,e=idle(b,e,active,1/hz)
            if (i+1)%hz==0:states[(i+1)//hz]=b
        idle_rows.append(dict(hz=hz,at_8s=states[8],at_10s=states[10],at_12s=states[12],at_13s=states[13]))
    rng=random.Random(5601);flat_err=[];edge_err=[];bilinear_err=[];plane_err=[]
    for _ in range(20000):
        x,y=rng.random(),rng.random()
        constant=rng.uniform(0,4)
        v,m=upscale([constant]*4,x,y);flat_err.append(abs(v-constant))
        # Vertical binary edge passing through the center of a 2x2 footprint.
        low=rng.uniform(0,.3);high=rng.uniform(.5,3)
        v,m=upscale([low,high,low,high],x,y)
        target=low if x<.5 else high
        assert low-1e-12<=v<=high+1e-12
        edge_err.append(abs(v-target));bilinear_err.append(abs(m-target))
        # Affine low-contrast ramp, no edge enhancement expected.
        base=rng.uniform(.3,3);a,b=rng.uniform(-.002,.002),rng.uniform(-.002,.002)
        v,m=upscale([base,base+a,base+b,base+a+b],x,y)
        plane_err.append(abs(v-(base+a*x+b*y)))
    return dict(idle=idle_rows,flat_max_error=max(flat_err),edge_mae=statistics.mean(edge_err),bilinear_edge_mae=statistics.mean(bilinear_err),plane_max_error=max(plane_err),coc=[dict(depth=d,focus=2,old=min(max(abs(.5-1/d)-.003,0)*48*.5,14),new=coc(d,2)) for d in (.65,1,2,4,10,512)])
if __name__=='__main__':print(json.dumps(run(),indent=2))
