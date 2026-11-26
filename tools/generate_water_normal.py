"""Two explicitly filtered periodic water slope levels with bilinear gutters."""
import math
from pathlib import Path

MODES = [[3,5,0.17,0.2],[7,-4,0.14,1.2],[11,8,0.09,2.4],[17,-9,0.055,3.7],[23,15,0.045,4.9],[5,19,0.07,2.8],[13,-21,0.055,5.4]]
SIZE = 64
WIDTH = 66
HEIGHT = 100

def generate():
    def slope(x,y):
        u,v=(x+.5)/SIZE,(y+.5)/SIZE
        sx=sy=0.
        for kx,ky,weight,phase in MODES:
            c=weight*math.cos(2*math.pi*(kx*u+ky*v)+phase)/math.hypot(kx,ky)
            sx+=kx*c
            sy+=ky*c
        return tuple(max(0,min(255,math.floor((.5+s*.5)*255+.5))) for s in (sx,sy))
    base=[[slope(x,y) for x in range(SIZE)] for y in range(SIZE)]
    def fine(x,y):
        return base[y%SIZE][x%SIZE]
    def coarse(x,y):
        donors=[fine(2*x+dx,2*y+dy) for dy in range(2) for dx in range(2)]
        return tuple((sum(p[k] for p in donors)+2)//4 for k in range(2))
    data=bytearray()
    for y in range(-1,65):
        for x in range(-1,65):
            data.extend(fine(x,y))
    for y in range(-1,33):
        for x in range(-1,65):
            data.extend(coarse(x,y) if x<=32 else (128,128))
    return bytes(data)

if __name__=="__main__":
    (Path(__file__).resolve().parents[1]/"shaders/textures/water_normal.rg8").write_bytes(generate())
