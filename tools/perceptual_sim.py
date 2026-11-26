"""Deterministic CPU proxy for perceptual sampling; not measured GPU time."""
import math
import random
import statistics
import json


def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)


def simulate(n=20000):
    rng=random.Random(5501)
    out={}
    for mode in (1,2):
        rays=0; errors=[]; full=0
        for i in range(n):
            base=rng.uniform(.03,.3)
            # Opposite ray pairs share a low-frequency term; anisotropy is independent.
            a=rng.uniform(-.015,.015); b=rng.uniform(-.015,.015)
            pair=[base+a,base+b]; ref=sum(pair)/2
            previous=ref*(1+rng.uniform(-.04,.04))
            stable=rng.random()<.8
            if rng.random()<.12: previous*=rng.uniform(.3,1.7)
            period=4 if mode==2 else 2
            candidate=pair[(i+i//2)&1]
            mismatch=abs(candidate-previous)/max(candidate,previous,.015)
            refresh=i%period==0 or not stable or mismatch>(.30 if mode==2 else .18)
            rays+=4 if refresh else 2; full+=refresh
            errors.append(abs((ref if refresh else candidate)-ref))
        out[f'gi_{mode}']={'reference_rays':4*n,'candidate_rays':rays,'full_refreshes':full,'reduction_pct':100*(1-rays/(4*n)),'mae':statistics.mean(errors),'max_abs':max(errors)}
    donors=0; errors=[]; accepted=0
    for i in range(n):
        # Exact 2:1 footprint; 80% of samples are geometry compatible.
        values=[rng.uniform(.01,.3) for _ in range(4)]
        if rng.random()<.7:
            values=[values[0]*(1+rng.uniform(-.025,.025)) for _ in range(4)]
        valid=rng.random()<.8
        ref=sum(x*w for x,w in zip(values,(.5625,.1875,.1875,.0625)))
        reuse=valid and abs(values[0]-values[1])<=.002+max(values[:2])*.04
        donors+=2 if reuse else 4; accepted+=reuse
        errors.append(abs((.75*values[0]+.25*values[1] if reuse else ref)-ref))
    out['spatial']={'reference_donors':4*n,'candidate_donors':donors,'accepted':accepted,'reduction_pct':100*(1-donors/(4*n)),'mae':statistics.mean(errors),'max_abs':max(errors)}
    for mode in (1,2):
        base_taps=0; taps=0; errors=[]; ssr=0
        for _ in range(n):
            start=rng.uniform(16,450); span=rng.uniform(18,90); phase=rng.uniform(0,2*math.pi)
            old=12; new=min(old,max(4,math.ceil(old*(1-(.50 if mode==2 else .25)*smooth(64,192,start)))))
            def trans(k):
                density=sum(.35+.2*math.sin((i+.5)/k*span*.09+phase)+.09*math.cos((i+.5)/k*span*.23+phase) for i in range(k))
                return math.exp(-.15*span*density/k)
            errors.append(abs(trans(new)-trans(old)));base_taps+=old;taps+=new
            rough=rng.uniform(0,.65);foot=rng.uniform(2,90);reflectance=rng.uniform(0,.08)
            reduction=smooth(.20,.55,rough)*max(1-smooth(8,40,foot),1-smooth(.008,.05,reflectance))*(.60 if mode==2 else .42)
            steps=min(16,max(9,math.ceil(16*(1-reduction))))
            if rough<=.20: assert steps==16
            ssr+=steps
        out[f'volume_{mode}']={'reference_taps':base_taps,'candidate_taps':taps,'reduction_pct':100*(1-taps/base_taps),'transmission_mae':statistics.mean(errors),'max_abs':max(errors)}
        out[f'ssr_{mode}']={'reference_ceiling_steps':16*n,'candidate_ceiling_steps':ssr,'reduction_pct':100*(1-ssr/(16*n))}
    sh=[]
    for _ in range(n):
        u=rng.uniform(-1,1);amp=rng.uniform(0,2)
        for lo,c,s in ((.24,.62,.38),(.55,.775,.225)):
            sh.append(abs(amp*(lo+(1-lo)*(u*.5+.5))-amp*(c+s*u)))
    out['sh']={'cases':len(sh),'max_abs':max(sh)}
    return out


if __name__=='__main__':
    print(json.dumps(simulate(),indent=2))
