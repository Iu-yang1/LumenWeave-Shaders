"""CPU reference for spherical atmosphere LUT research.

Distances are km, coefficients km^-1, radiance per unit solar irradiance.
The multiple-scattering closure is an isotropic approximation, not a
bit-equivalent implementation of any published renderer. No GPU dependency.
"""
import argparse
import json
import math
from pathlib import Path

GROUND = 6360.0
TOP = 6460.0
RAYLEIGH = (0.005802, 0.013558, 0.033100)
MIE_S = 0.003996
MIE_T = 0.004440
OZONE = (0.000650, 0.001881, 0.000085)
WHITE = (1.0, 1.0, 1.0)
BLACK = (0.0, 0.0, 0.0)
GROUND_ALBEDO = 0.12


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def norm(a):
    return math.sqrt(dot(a, a))


def unit(mu, phi=0.0):
    horizontal = math.sqrt(max(0.0, 1-mu*mu))
    return (horizontal*math.cos(phi), mu, horizontal*math.sin(phi))


def add_scaled(a, b, t):
    return tuple(x+t*y for x, y in zip(a, b))


def medium(radius):
    height = max(radius-GROUND, 0.0)
    r = math.exp(-height/8.0)
    m = math.exp(-height/1.2)
    ozone = max(0.0, 1.0-abs(height-25.0)/15.0)
    rs = tuple(c*r for c in RAYLEIGH)
    ms = MIE_S*m
    extinction = tuple(c+MIE_T*m+o*ozone for c,o in zip(rs,OZONE))
    return rs, ms, extinction


def ray_boundary(radius, mu):
    # Stable expression: positive outer sphere root, nearest positive ground root.
    b = radius*mu
    ground_disc = b*b - (radius*radius-GROUND*GROUND)
    if mu < 0 and ground_disc >= 0:
        return max(0.0, -b-math.sqrt(ground_disc)), True
    top_disc = b*b + TOP*TOP-radius*radius
    return max(0.0, -b+math.sqrt(max(top_disc, 0.0))), False


def optical_transmission(radius, mu, steps=64):
    length, blocked = ray_boundary(radius, mu)
    if blocked:
        return BLACK
    depth = [0.0]*3
    origin = (0.0, radius, 0.0)
    direction = unit(mu)
    dt = length/steps
    for i in range(steps):
        _, _, ext = medium(norm(add_scaled(origin,direction,(i+0.5)*dt)))
        for channel in range(3):
            depth[channel] += ext[channel]*dt
    return tuple(math.exp(-value) for value in depth)


def phase_rayleigh(cosine):
    return 3.0/(16.0*math.pi)*(1.0+cosine*cosine)


def phase_mie(cosine, g=0.8):
    return (1-g*g)/(4*math.pi*max(1+g*g-2*g*cosine, 1e-8)**1.5)


class Grid2D:
    def __init__(self, width, height, values):
        self.width, self.height, self.values = width, height, values

    def sample(self, u, v):
        x = min(1.0,max(0.0,u))*(self.width-1)
        y = min(1.0,max(0.0,v))*(self.height-1)
        bx, by = int(x), int(y)
        fx, fy = x-bx, y-by
        result = [0.0]*3
        for dy in (0,1):
            for dx in (0,1):
                value = self.values[min(by+dy,self.height-1)*self.width+min(bx+dx,self.width-1)]
                weight = (fx if dx else 1-fx)*(fy if dy else 1-fy)
                for c in range(3):
                    result[c] += value[c]*weight
        return tuple(result)

    def as_dict(self):
        return {"width": self.width, "height": self.height, "rgb": self.values}


def make_transmittance(width=48, height=24, steps=64):
    # Map above-horizon directions only; ground blockage is handled separately.
    values = []
    for y in range(height):
        radius = GROUND+(TOP-GROUND)*y/(height-1)
        horizon = -math.sqrt(max(0.0,1-(GROUND/radius)**2))
        for x in range(width):
            mu = horizon+(1-horizon)*x/(width-1)
            # Offset the tangent endpoint slightly to avoid numerical ground classification.
            values.append(optical_transmission(radius,min(1.0,mu+1e-7),steps))
    return Grid2D(width,height,values)


def sun_transmittance(table, radius, mu):
    horizon = -math.sqrt(max(0.0,1-(GROUND/max(radius,GROUND))**2))
    if mu < horizon:
        return BLACK
    return table.sample((mu-horizon)/max(1-horizon,1e-9),(radius-GROUND)/(TOP-GROUND))


def integrate(radius, direction, sun, transmittance, multi=None, max_distance=math.inf, steps=24):
    distance, ground = ray_boundary(radius,direction[1])
    length = min(distance,max_distance)
    dt = length/steps
    origin = (0.0,radius,0.0)
    cosine = max(-1.0,min(1.0,dot(direction,sun)))
    pr, pm = phase_rayleigh(cosine), phase_mie(cosine)
    throughput = [1.0]*3
    radiance = [0.0]*3
    isotropic_response = [0.0]*3
    for i in range(steps):
        point = add_scaled(origin,direction,(i+0.5)*dt)
        r = norm(point)
        mu = dot(point,sun)/r
        rs, ms, ext = medium(r)
        solar = sun_transmittance(transmittance,r,mu)
        multiple = multi.sample((mu+1)*0.5,(r-GROUND)/(TOP-GROUND)) if multi else BLACK
        for c in range(3):
            sigma_s = rs[c]+ms
            segment = math.exp(-ext[c]*dt)
            integral = -math.expm1(-ext[c]*dt)/ext[c] if ext[c] > 1e-12 else dt
            source = solar[c]*(rs[c]*pr+ms*pm)+multiple[c]*sigma_s
            radiance[c] += throughput[c]*source*integral
            isotropic_response[c] += throughput[c]*sigma_s*integral
            throughput[c] *= segment
    if ground and distance <= max_distance:
        point = add_scaled(origin,direction,distance)
        mu = max(0.0,dot(point,sun)/GROUND)
        solar = sun_transmittance(transmittance,GROUND,mu)
        for c in range(3):
            radiance[c] += throughput[c]*GROUND_ALBEDO*mu*solar[c]/math.pi
            isotropic_response[c] += throughput[c]*GROUND_ALBEDO
    return tuple(radiance),tuple(throughput),tuple(isotropic_response)


def make_multiscattering(transmittance,width=12,height=8,directions=24,steps=24):
    values = []
    golden = math.pi*(3-math.sqrt(5))
    for y in range(height):
        radius = GROUND+(TOP-GROUND)*y/(height-1)
        for x in range(width):
            sun = unit(-1+2*x/(width-1))
            source, response = [0.0]*3,[0.0]*3
            for i in range(directions):
                direction = unit(1-2*(i+0.5)/directions,golden*i)
                light,_,feedback = integrate(radius,direction,sun,transmittance,steps=steps)
                for c in range(3):
                    source[c] += light[c]/directions
                    response[c] += feedback[c]/directions
            values.append(tuple(source[c]/max(1-response[c],0.02) for c in range(3)))
    return Grid2D(width,height,values)


def make_sky_view(radius,sun_mu,transmittance,multi,width=32,height=16,steps=32):
    values = []
    sun = unit(sun_mu)
    for y in range(height):
        mu = -1+2*y/(height-1)
        for x in range(width):
            direction = unit(mu,2*math.pi*x/(width-1))
            light,_,_ = integrate(radius,direction,sun,transmittance,multi,steps=steps)
            values.append(light)
    return Grid2D(width,height,values)


def make_aerial(radius,sun_mu,transmittance,multi,width=16,height=8,depth=12,max_distance=40.0,steps=24):
    """Direction-space volume: azimuth, elevation, logarithmic path length."""
    sun = unit(sun_mu)
    radiance, transmission, distances = [], [], []
    for z in range(depth):
        length = math.expm1(math.log1p(max_distance)*z/(depth-1))
        distances.append(length)
        for y in range(height):
            mu = -1+2*y/(height-1)
            for x in range(width):
                direction = unit(mu,2*math.pi*x/(width-1))
                # Aerial perspective stops at the surface; ground radiance is
                # handled by terrain shading, not baked into the volume.
                boundary, _ = ray_boundary(radius,mu)
                limit = min(length,max(0.0,boundary-1e-6))
                light,through,_ = integrate(radius,direction,sun,transmittance,multi,limit,steps)
                radiance.append(light)
                transmission.append(through)
    return {"size":[width,height,depth],"distance_km":distances,"inscatter_rgb":radiance,"transmittance_rgb":transmission}


def build_luts(radius=GROUND+0.2,sun_mu=0.55):
    transmittance = make_transmittance()
    multi = make_multiscattering(transmittance)
    sky = make_sky_view(radius,sun_mu,transmittance,multi)
    aerial = make_aerial(radius,sun_mu,transmittance,multi)
    return {"radius_km":radius,"sun_mu":sun_mu,"transmittance":transmittance.as_dict(),
            "multiple_scattering":multi.as_dict(),"sky_view":sky.as_dict(),"aerial":aerial}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    parser.add_argument("--height-km",type=float,default=0.2)
    parser.add_argument("--sun-mu",type=float,default=0.55)
    args = parser.parse_args()
    if not 0 < args.height_km < TOP-GROUND or not -1 <= args.sun_mu <= 1:
        parser.error("camera height must be inside the atmosphere; sun cosine in [-1,1]")
    args.output.write_text(json.dumps(build_luts(GROUND+args.height_km,args.sun_mu)),encoding="utf-8")


if __name__ == "__main__":
    main()
