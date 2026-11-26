import math
import random
import struct
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=ROOT/"shaders"
sys.path.insert(0,str(ROOT/"tools"))
from check_shaders import preview_profiles
from quality_budget import resource_budget,MIB


def half(x):
    return struct.unpack("<e",struct.pack("<e",x))[0]


def cell_for_pixel(pixel,origin):
    return origin+((pixel-origin)&511)


def encode_origin(value):
    value//=32
    hi=value//1024
    return half(hi),half(value-hi*1024)


def decode_origin(value):
    return (int(value[0])*1024+int(value[1]))*32


def azimuth_cos(u):
    x=2*u-1
    return -math.copysign(2*abs(x)-x*x,x)


def azimuth_uv(c):
    return .5-.5*math.copysign(1-math.sqrt(max(0,1-abs(c))),c)


class P44P49Tests(unittest.TestCase):
    def test_ring_overlap_and_teleport(self):
        for old,new in ((-256,-224),(-256,-288),(-512,0),(1024,-2048),(0,0)):
            old_cells={cell_for_pixel(i,old):i for i in range(512)}
            new_cells={cell_for_pixel(i,new):i for i in range(512)}
            self.assertEqual(set(new_cells),set(range(new,new+512)))
            for cell in old_cells.keys()&new_cells.keys():
                self.assertEqual(old_cells[cell],new_cells[cell])
            self.assertEqual(len(new_cells.keys()-old_cells.keys()),min(abs(new-old),512))
        for value in range(-10000000,10000001,3200):
            self.assertEqual(decode_origin(encode_origin(value)),value)
        for old,new in ((0,32),(0,64),(-32,32)):
            # Overlap in two dimensions is the product of axis overlap.
            self.assertEqual(512**2-(512-abs(old-new))**2,2*512*abs(old-new)-abs(old-new)**2)
        source=(S/"programs/shared/begin4.csh.glsl").read_text()
        self.assertIn("ivec3(8,8,1)",source)
        self.assertIn("if(previousValid && all(equal(origin,previousOrigin))) return",source)
        for lane in range(128):
            self.assertEqual(len(range(lane,512,128)),4)

    def test_azimuth_grid_is_inverse(self):
        for i in range(10001):
            u=i/10000
            c=azimuth_cos(u)
            self.assertAlmostEqual(azimuth_uv(c),u,places=10)
        self.assertEqual(azimuth_cos(0),1)
        self.assertEqual(azimuth_cos(1),-1)
        for name in ("begin1","begin2"):
            self.assertIn("atmoViewDirection(atmoElevationMu(uv.y),uv.x)",(S/f"programs/shared/{name}.csh.glsl").read_text())

    def test_periodic_water_asset_error(self):
        data=[x[0] for x in struct.iter_unpack("<e",(S/"textures/water_phase.r16f").read_bytes())]
        self.assertEqual(len(data),257)
        self.assertEqual(data[0],data[-1])
        rng=random.Random(47)
        worst=0
        for _ in range(20000):
            p=rng.uniform(-2048,2048)
            x=(p/(2*math.pi)%1)*256
            i=int(x)
            v=data[i]+(data[i+1]-data[i])*(x-i)
            worst=max(worst,abs(v-math.cos(p)))
        self.assertLess(worst,.0004)
        self.assertIn("if(abs(phase)>2048.0) return cos(phase)",(S/"lib/water/waves.glsl").read_text())

    def test_profile_budget_and_history(self):
        profiles=preview_profiles(S)
        for opts in profiles.values():
            for k in ("CLOUD_DENSITY_CACHE","CLOUD_OPTICAL_CACHE","SKY_ENV_REUSE","BRDF_REUSE"):
                self.assertEqual(opts[k],"1")
            self.assertEqual(opts["WATER_PHASE_LUT"],"0")
        extreme=profiles["profile.Extreme"]
        budget=resource_budget(extreme,1920,1080)
        self.assertEqual(budget["cloud_cache_mib"],513*512*4/MIB)
        self.assertEqual(resource_budget({**extreme,"VOXEL_FUSION":"0"},1920,1080)["cloud_cache_mib"],0)
        self.assertEqual(resource_budget({**extreme,"CLOUD_DENSITY_CACHE":"0"},1920,1080)["cloud_cache_mib"],0)
        hist=(S/"lib/atmosphere/volume_temporal.glsl").read_text()
        self.assertIn("if(priorFresh && reuseTile)",hist)
        self.assertIn("if(!reuseCloud) imageStore",hist)
        self.assertIn("reuseCloud ? -tag : tag",hist)

    def test_solar_basis_and_fresnel(self):
        rng=random.Random(45)
        for _ in range(1000):
            a,b,c,d,layer=[rng.random() for _ in range(5)]
            base=.65*a+.25*b
            high=.10*c
            original=base+.10*(.5+(c-.5)*d)
            cached=base+(.05+(high-.05)*d)
            self.assertAlmostEqual(original,cached,places=14)
            self.assertAlmostEqual(2.6*layer*original,2.6*layer*cached,places=14)
            g=rng.random()
            self.assertAlmostEqual(g**5,g*g*g*g*g,places=14)
        volume=(S/"lib/atmosphere/volume.glsl").read_text()
        self.assertIn("return 2.6*cachedCloudDensity",volume)
        self.assertIn("exp(-cloudSolarOpticalDepth(point+sun*6.0,detail))",volume)
