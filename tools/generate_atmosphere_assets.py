#!/usr/bin/env python3
"""Bake the shader's static atmosphere LUTs, not the older research grid.

Mirrors physical_common.glsl, physical_lookup.glsl, setup/setup1 and
single-scattering physical_integrate.glsl. Uses double precision for
integration, quantizes transmittance to RGBA16F before multiple scattering.
No external asset or dependency. Little-endian half-float payloads.
"""
import argparse
import math
import struct
from pathlib import Path

from atmosphere_lut_reference import (
    GROUND, TOP, GROUND_ALBEDO, Grid2D, dot, norm, unit, medium,
)

ROOT=Path(__file__).resolve().parents[1]/"shaders/textures"
BLACK=(0.,0.,0.)


def clamp(x,a=0.,b=1.):
    return max(a,min(b,x))


def horizon(radius):
    return -math.sqrt(max(0.,(radius-GROUND)*(radius+GROUND)))/radius


def radius_at(v):
    return GROUND+.02+(TOP-GROUND-.02)*v*v


def altitude_uv(radius):
    return math.sqrt(clamp((radius-GROUND-.02)/(TOP-GROUND-.02)))


def elevation_mu(v):
    x=2*v-1
    return math.copysign(x*x,x)


def coordinate(t):
    return t*t*(3-2*t)


def boundary(radius,mu):
    b=radius*mu
    disc=b*b-(radius-GROUND)*(radius+GROUND)
    if mu<horizon(radius) and disc>=0:
        return max(0.,-b-math.sqrt(disc)),True
    return max(0.,-b+math.sqrt(max(0.,b*b+(TOP-radius)*(TOP+radius)))),False


def half(value):
    return struct.unpack("<e",struct.pack("<e",value))[0]


def transmission(radius,mu):
    distance,blocked=boundary(radius,mu)
    if blocked:
        return BLACK
    tau=[0.]*3
    for i in range(64):
        a=distance*coordinate(i/64)
        b=distance*coordinate((i+1)/64)
        t=(a+b)*.5
        r=math.sqrt(max(0.,radius*radius+2*radius*mu*t+t*t))
        ext=medium(r)[2]
        for c in range(3):
            tau[c]+=ext[c]*(b-a)
    return tuple(half(math.exp(-v)) for v in tau)


def transmittance_grid():
    values=[]
    for y in range(32):
        r=radius_at(y/31)
        h=horizon(r)
        for x in range(128):
            mu=h+(1-h)*(x/127)**2
            values.append(transmission(r,min(mu+1e-6,1.)))
    return Grid2D(128,32,values)


def solar(table,radius,mu):
    h=horizon(radius)
    if mu<h:
        return BLACK
    return table.sample(math.sqrt(clamp((mu-h)/max(1-h,.0001))),altitude_uv(radius))


def integrate_single(radius,direction,sun,table):
    distance,ground=boundary(radius,direction[1])
    cosine=clamp(dot(direction,sun),-1.,1.)
    pr=3/(16*math.pi)*(1+cosine*cosine)
    denom=max(1.64-1.6*cosine,.0001)
    pm=.36/(4*math.pi*denom*math.sqrt(denom))
    light,through,feedback=[0.]*3,[1.]*3,[0.]*3
    for i in range(24):
        a=distance*coordinate(i/24)
        b=distance*coordinate((i+1)/24)
        dt=b-a
        t=(a+b)*.5
        p=(direction[0]*t,radius+direction[1]*t,direction[2]*t)
        r=norm(p)
        mu=dot(p,sun)/r
        rs,ms,ext=medium(r)
        s=solar(table,r,mu)
        for c in range(3):
            tau=ext[c]*dt
            segment=math.exp(-tau)
            integral=dt if tau<.0001 else (1-segment)/max(ext[c],1e-8)
            light[c]+=through[c]*s[c]*(rs[c]*pr+ms*pm)*integral
            feedback[c]+=through[c]*(rs[c]+ms)*integral
            through[c]*=segment
    if ground:
        p=(direction[0]*distance,radius+direction[1]*distance,direction[2]*distance)
        mu=max(0.,dot(p,sun)/norm(p))
        s=solar(table,GROUND,mu)
        for c in range(3):
            light[c]+=through[c]*GROUND_ALBEDO*mu*s[c]/math.pi
            feedback[c]+=through[c]*GROUND_ALBEDO
    return light,feedback


def multiscatter_grid(table):
    directions=[unit(1-2*(i+.5)/24,i*2.39996323) for i in range(24)]
    values=[]
    for y in range(16):
        radius=radius_at(y/15)
        for x in range(32):
            sun=unit(elevation_mu(x/31))
            source,feedback=[0.]*3,[0.]*3
            for direction in directions:
                a,b=integrate_single(radius,direction,sun,table)
                for c in range(3):
                    source[c]+=a[c]/24
                    feedback[c]+=b[c]/24
            values.append(tuple(half(source[c]/max(1-feedback[c],.02)) for c in range(3)))
    return Grid2D(32,16,values)


def payload(grid):
    return b"".join(struct.pack("<4e",*rgb,1.) for rgb in grid.values)


def build():
    trans=transmittance_grid()
    return {"atmo_trans.rgba16f":payload(trans),
            "atmo_multi.rgba16f":payload(multiscatter_grid(trans))}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check",action="store_true")
    args=p.parse_args()
    for name,data in build().items():
        path=ROOT/name
        if args.check:
            expected=list(struct.iter_unpack("<4e",data))
            actual=list(struct.iter_unpack("<4e",path.read_bytes()))
            # Cross-language rounding at binary16 boundaries may differ by
            # one ULP; use a tight absolute+relative tolerance.
            if len(actual)!=len(expected) or any(
                abs(a-b)>max(6e-8,abs(b)*.001) for x,y in zip(actual,expected) for a,b in zip(x,y)):
                raise SystemExit(f"Asset mismatch: {path}")
        else:
            path.write_bytes(data)
        print(f"{name}: {len(data)} bytes")


if __name__=="__main__":
    main()
