#!/usr/bin/env python3
"""Original End wisp density on an octahedral sphere, native R16F."""
import argparse
import functools
import math
import struct
from pathlib import Path

SIZE=256
ROOT=Path(__file__).resolve().parents[1]/"shaders/textures/end_wisps.r16f"


def f32(value):
    return struct.unpack("<f",struct.pack("<f",value))[0]


def fract(value):
    return value-math.floor(value)


@functools.lru_cache(maxsize=None)
def sky_hash(x,y,z):
    p=[fract(f32(f32(v)*f32(.1031))) for v in (x,y,z)]
    q=[f32(p[(i+1)%3]+f32(33.33)) for i in range(3)]
    d=f32(f32(f32(p[0]*q[0])+f32(p[1]*q[1]))+f32(p[2]*q[2]))
    p=[f32(v+d) for v in p]
    return fract(f32(f32(p[0]+p[1])*p[2]))


def mix(a,b,t):
    return a+(b-a)*t


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)


def noise(p):
    i=[math.floor(v) for v in p]
    f=[smooth(0,1,fract(v)) for v in p]
    x,y,z=i
    a=mix(sky_hash(x,y,z),sky_hash(x+1,y,z),f[0])
    b=mix(sky_hash(x,y+1,z),sky_hash(x+1,y+1,z),f[0])
    c=mix(sky_hash(x,y,z+1),sky_hash(x+1,y,z+1),f[0])
    d=mix(sky_hash(x,y+1,z+1),sky_hash(x+1,y+1,z+1),f[0])
    return mix(mix(a,b,f[1]),mix(c,d,f[1]),f[2])


def normalize(v):
    n=math.sqrt(sum(x*x for x in v))
    return tuple(x/n for x in v)


def sign(x):
    return 1. if x>=0 else -1.


def decode_octahedral(x,y):
    z=1-abs(x)-abs(y)
    if z<0:
        x,y=(1-abs(y))*sign(x),(1-abs(x))*sign(y)
    return normalize((x,y,z))


def encode_octahedral(direction):
    scale=sum(abs(v) for v in direction)
    x,y,z=[v/scale for v in direction]
    if z<0:
        x,y=(1-abs(y))*sign(x),(1-abs(x))*sign(y)
    return x,y


AXIS=normalize((.34,.71,.61))


def wisps(direction):
    p=[v*5 for v in direction]
    n=.62*noise(p)+.26*noise(tuple(v*2.31+b for v,b in zip(p,(9,3,5))))+.12*noise(tuple(v*5.13+b for v,b in zip(p,(3,12,7))))
    latitude=abs(sum(a*b for a,b in zip(direction,AXIS))+.23*(n-.5))
    return smooth(.32,.8,n)*(1-smooth(.08,.55,latitude))


def build():
    return b"".join(struct.pack("<e",wisps(decode_octahedral(2*x/(SIZE-1)-1,2*y/(SIZE-1)-1)))
                   for y in range(SIZE) for x in range(SIZE))


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check",action="store_true")
    args=p.parse_args()
    data=build()
    if args.check:
        expected=list(struct.iter_unpack("<e",data))
        actual=list(struct.iter_unpack("<e",ROOT.read_bytes()))
        if len(expected)!=len(actual) or any(abs(a[0]-b[0])>max(6e-8,abs(a[0])*.001)
                                              for a,b in zip(expected,actual)):
            raise SystemExit("End wisp asset mismatch")
    else:
        ROOT.write_bytes(data)
    print(f"{ROOT.name}: {len(data)} bytes")
