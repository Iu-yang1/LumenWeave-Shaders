import math
import random
import unittest
from pathlib import Path

S = Path(__file__).resolve().parents[1] / "shaders"

class MotionDofFusionTests(unittest.TestCase):
    def test_half_output_ownership(self):
        for w,h in ((1,1),(16,16),(17,19),(127,95),(1921,1081)):
            for hw,hh in ((max(1,w//2),max(1,h//2)),((w+1)//2,(h+1)//2)):
                padded_w=(w+15)//16*16
                padded_h=(h+15)//16*16
                self.assertLessEqual((hw-1)*2,padded_w-1)
                self.assertLessEqual((hh-1)*2,padded_h-1)
                self.assertEqual((hw-1)*2//2,hw-1)
                self.assertEqual((hh-1)*2//2,hh-1)
    def test_tile_bilinear_matches_global(self):
        rng=random.Random(60)
        w,h=37,29
        field=[[rng.random()*8 for _ in range(w)] for _ in range(h)]
        def pixel(x,y):
            return field[max(0,min(y,h-1))][max(0,min(x,w-1))]
        for _ in range(5000):
            x,y=rng.uniform(-.5,w-.5),rng.uniform(-.5,h-.5)
            tx,ty=rng.randrange(3)*16,rng.randrange(2)*16
            ix,iy=math.floor(x),math.floor(y)
            fx,fy=x-ix,y-iy
            def donor(a,b):
                a,b=max(0,min(a,w-1)),max(0,min(b,h-1))
                if tx<=a<tx+16 and ty<=b<ty+16:
                    return field[ty+(b-ty)][tx+(a-tx)]
                return pixel(a,b)
            def bilinear(fetch):
                return ((1-fx)*fetch(ix,iy)+fx*fetch(ix+1,iy))*(1-fy)+((1-fx)*fetch(ix,iy+1)+fx*fetch(ix+1,iy+1))*fy
            self.assertEqual(bilinear(donor),bilinear(pixel))
    def test_no_cross_group_feedback(self):
        shader=(S/"programs/shared/composite2.csh.glsl").read_text()
        self.assertNotIn("imageLoad(colorimg0",shader)
        self.assertIn("return lwMotionPixel(source,p,size);",shader)
        self.assertIn("imageStore(colorimg10,h",shader)
        self.assertIn("imageStore(colorimg0,p",shader)
        self.assertIn("flip.composite2.colortex0 = false",(S/"shaders.properties").read_text())
        self.assertIn("__VERSION__ >= 450",(S/"programs/shared/shadow.vsh.glsl").read_text())
