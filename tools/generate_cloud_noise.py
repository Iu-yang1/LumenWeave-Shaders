#!/usr/bin/env python3
"""Original LumenWeave periodic R8 smooth value noise, not imported assets."""
from pathlib import Path

SIZE=1024
PERIOD=255
MASK=0xffffffff

def lattice_hash(x,y):
    z=((x*0x1f123bb5)^(y*0x5f356495)^0x6d2b79f5)&MASK
    z=((z^(z>>16))*0x7feb352d)&MASK
    z=((z^(z>>15))*0x846ca68b)&MASK
    return (z^(z>>16))/MASK

def generate():
    values=[[lattice_hash(x,y) for x in range(PERIOD)] for y in range(PERIOD)]
    def coord(i):
        p=(i-2)/4
        n=int(p//1)
        t=p-n
        return n%PERIOD,(n+1)%PERIOD,t*t*(3-2*t)
    coords=[coord(i) for i in range(SIZE)]
    out=bytearray(SIZE*SIZE)
    for y,(j,k,t) in enumerate(coords):
        for x,(i,l,s) in enumerate(coords):
            a,b,c,d=values[j][i],values[j][l],values[k][i],values[k][l]
            lo=a+(b-a)*s
            hi=c+(d-c)*s
            out[y*SIZE+x]=int((lo+(hi-lo)*t)*255+0.5)
    return bytes(out)

if __name__=="__main__":
    target=Path(__file__).resolve().parents[1]/"shaders/textures/cloud_noise.r8"
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(generate())
