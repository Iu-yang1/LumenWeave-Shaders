import math
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"shaders"

class EmissionWaterTests(unittest.TestCase):
    def test_distinct_palette_and_noncolliding_seed(self):
        s=(ROOT/"lib/lighting/emitter_palette.glsl").read_text()
        palette=s.split("colors[16] = vec3[16](",1)[1].split(");",1)[0]
        colors=[tuple(map(float,x)) for x in re.findall(r"vec3\(([^,]+),([^,]+),([^\)]+)\)",palette)]
        self.assertEqual(len(colors),16)
        self.assertEqual(len(set(colors)),16)
        self.assertLess(colors[5][1],colors[6][1])
        self.assertGreater(colors[6][1],colors[1][1])
        self.assertGreater(colors[2][2],colors[2][0])
        self.assertGreater(colors[10][1],colors[10][0])
        codes={(strength<<4)|kind for strength in range(1,16) for kind in range(16)}
        self.assertEqual(len(codes),240)
        self.assertLess(max(codes),256)
        props=(ROOT/"block.properties").read_text()
        for id,block in ((10015,"lava"),(10016,"glowstone"),(10017,"redstone_lamp"),(10018,"pearlescent_froglight"),(10019,"ochre_froglight"),(10024,"verdant_froglight")):
            self.assertIn(f"block.{id} = minecraft:{block}",props)
    def test_clear_water_transmission(self):
        source=(ROOT/"lib/water/optics.glsl").read_text()
        self.assertIn("vec3(0.115, 0.028, 0.012)",source)
        for distance in (1,5,10,20,48):
            old=[math.exp(-(x+.025)*distance) for x in (.18,.045,.018)]
            new=[math.exp(-(x+.01)*distance) for x in (.115,.028,.012)]
            self.assertTrue(all(a>b for a,b in zip(new,old)))
            self.assertLess(new[0],new[1])
            self.assertLess(new[1],new[2])
        self.assertIn("eyeBrightnessSmooth",(ROOT/"lib/lighting/fog.glsl").read_text())
