"""CPU numerical and work-count proxy, not GPU performance measurement."""
import math
import random
import json
import itertools


def run():
    rng=random.Random(5701)
    arc_error=0.; full_open=0
    for _ in range(100000):
        g=rng.uniform(-math.pi/2,math.pi/2); c=rng.uniform(-1,1)
        h=math.acos(c); b=min(h,max(g+math.pi/2,0)); cg=math.cos(g); sg=math.sin(g)
        old=.25*(cg-math.cos(2*b-g)+2*b*sg)
        if c<=-sg:
            new=.5*(cg+(g+math.pi/2)*sg); full_open+=1
        else:new=.25*(cg-(2*c*c-1)*cg-2*c*math.sqrt(max(1-c*c,0))*sg+2*h*sg)
        arc_error=max(arc_error,abs(old-new))
    depth_mismatch=0
    for _ in range(100000):
        w=rng.uniform(.001,5); z=-rng.uniform(.05,512)*w; center=-rng.uniform(.05,512)
        tol=max(.5,-center*.035)
        depth_mismatch+= (abs(z/w-center)>tol)!=(abs(z-center*w)>tol*abs(w))
    motion=[]
    for cap in (4,8,12):
        counts=[min(cap,max(2,math.ceil(min(p,24)*.75)+1)) for p in (.4,1,2,4,8,12,24)]
        motion.append(dict(cap=cap,pixels=[.4,1,2,4,8,12,24],counts=counts))
    misses=0; examined=0; rows=[]
    for n in (96,128):
        side=n//4; tiles=list(itertools.product(range(side),repeat=3))
        for probability in (.01,.05,.2):
            walls={t for t in tiles if rng.random()<probability}
            halo={tuple(a+b for a,b in zip(t,d)) for t in walls for d in itertools.product((-1,0,1),repeat=3)}
            halo={t for t in halo if min(t)>=0 and max(t)<side}
            for _ in range(10000):
                cell=tuple(rng.randrange(n) for _ in range(3)); tile=tuple(c//4 for c in cell)
                axis=rng.randrange(3); delta=rng.choice((-2,-1,1,2)); neighbor=list(cell); neighbor[axis]+=delta
                if min(neighbor)>=0 and max(neighbor)<n:
                    if tuple(c//4 for c in neighbor) in walls and tile not in halo: misses+=1
                    examined+=1
            rows.append(dict(grid=n,wall_tile_probability=probability,total_tiles=len(tiles),wall_free_tiles=len(tiles)-len(halo),skip_pct=100*(1-len(halo)/len(tiles))))
    rng=random.Random(5702); old=new=0
    for _ in range(20000):
        coverage=rng.random()**3
        old+=coverage<.035
        new+=coverage<.012
    return dict(arc_cases=100000,arc_max_abs_error=arc_error,open_arc_count=full_open,depth_cases=100000,depth_mismatch=depth_mismatch,motion=motion,wall_halo_cases=examined,wall_halo_misses=misses,wall_halo=rows,edge_fallback=dict(cases=20000,old=old,new=new,reduction_pct=100*(1-new/old)),hdr_removed_write_bytes={f'{w}x{h}':w*h*8 for w,h in ((1920,1080),(2560,1440),(3840,2160))})

if __name__=='__main__':print(json.dumps(run(),indent=2))
