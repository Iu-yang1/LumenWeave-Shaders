"""Reproducible periodic, integrable water slope texture with one-texel gutters."""
import math
from pathlib import Path

MODES = [[3,5,0.17,0.2],[7,-4,0.14,1.2],[11,8,0.09,2.4],[17,-9,0.055,3.7],[23,15,0.045,4.9],[5,19,0.07,2.8],[13,-21,0.055,5.4]]
SIZE = 64

def generate():
    data = bytearray()
    for y in range(-1, SIZE + 1):
        for x in range(-1, SIZE + 1):
            u, v = (x + .5) / SIZE, (y + .5) / SIZE
            sx = sy = 0.
            for kx, ky, weight, phase in MODES:
                c = weight * math.cos(2 * math.pi * (kx*u + ky*v) + phase) / math.hypot(kx, ky)
                sx += kx*c
                sy += ky*c
            data.extend(max(0, min(255, math.floor((.5+s*.5)*255+.5))) for s in (sx, sy))
    return bytes(data)

if __name__ == "__main__":
    path = Path(__file__).resolve().parents[1] / "shaders/textures/water_normal.rg8"
    path.write_bytes(generate())
