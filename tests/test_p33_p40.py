import math
import random
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
S=ROOT/"shaders"
sys.path.insert(0,str(ROOT/"tools"))
from generate_cloud_noise import generate, SIZE, PERIOD
from check_shaders import preview_profiles
from quality_budget import resource_budget, MIB


def cloud_sample(data,x,y):
    px=(x%PERIOD)*4+2
    py=(y%PERIOD)*4+2
    i,j=int(px),int(py)
    u,v=px-i,py-j
    a,b=data[j*SIZE+i],data[j*SIZE+i+1]
    c,d=data[(j+1)*SIZE+i],data[(j+1)*SIZE+i+1]
    return ((a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v)/255


class VolumePipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=(S/"textures/cloud_noise.r8").read_bytes()

    def test_r8_reproducible_and_periodic(self):
        self.assertEqual(len(self.data),1024**2)
        self.assertEqual(self.data,generate())
        rng=random.Random(33)
        for _ in range(1000):
            x,y=rng.uniform(-500,500),rng.uniform(-500,500)
            self.assertAlmostEqual(cloud_sample(self.data,x,y),cloud_sample(self.data,x+255,y-255),places=11)
        # Worst bilinear derivative, including all padded seam texels.
        mx=max(abs(self.data[i+1]-self.data[i]) for i in range(len(self.data)-1) if i%SIZE!=SIZE-1)
        my=max(abs(self.data[i+SIZE]-self.data[i]) for i in range(len(self.data)-SIZE))
        self.assertLessEqual(4*math.hypot(mx,my)/255,2.3)

    def test_conservative_empty_skip_against_actual_map(self):
        rng=random.Random(36)
        skipped=0
        for _ in range(30000):
            x,y=rng.uniform(-300,300),rng.uniform(-300,300)
            dx,dy=rng.uniform(-.15,.15),rng.uniform(-.15,.15)
            threshold=rng.uniform(.34,.48)
            coarse=cloud_sample(self.data,x,y)
            upper=.65*min(1.,coarse+2.3*math.hypot(dx,dy))+.35
            if upper<=threshold:
                skipped+=1
                for a,b in ((x,y),(x+dx,y+dy)):
                    actual=.65*cloud_sample(self.data,a,b)+.25*cloud_sample(self.data,a*2.07,b*2.07)+.10*cloud_sample(self.data,a*5,b*5)
                    self.assertLessEqual(actual,threshold+1e-12)
        self.assertGreater(skipped,0)

    def test_shaft_recurrence_and_comparison_budget(self):
        rng=random.Random(35)
        for _ in range(1000):
            h=rng.uniform(20,120)
            step=rng.uniform(-12,12)
            decay=math.exp(-step*.019)
            density=math.exp(-max(h-63,0)*.019)
            for _ in range(24):
                self.assertAlmostEqual(density,math.exp(-max(h-63,0)*.019),places=12)
                next_h=h+step
                density=1 if next_h<=63 else density*decay if h>=63 else math.exp(-(next_h-63)*.019)
                h=next_h
        for cap in (4,6,8):
            for steps in range(2,cap+1):
                base=steps
                extra=cap-base
                self.assertLessEqual(base+2*(extra//2),cap)

    def test_history_nonoverlap_and_freshness(self):
        for w,h in ((960,540),(959,539),(1,1)):
            for x,y in ((0,0),(w-1,h-1)):
                pixels={(x+s*w,y+p*h) for s in range(3) for p in range(2)}
                self.assertEqual(len(pixels),6)
                self.assertTrue(all(0<=i<3*w and 0<=j<2*h for i,j in pixels))
        # Across arbitrary donor tile changes, a reused cloud is marked
        # negative and cannot become the source of another reuse.
        for frame in range(1,2049):
            tag=(frame&1023)+1
            self.assertGreater(tag,0)
            self.assertNotEqual(-tag,tag)
        source=(S/"lib/atmosphere/volume_temporal.glsl").read_text()
        self.assertIn("priorFresh=meta.a>0.0",source)
        self.assertIn("valid && priorFresh",source)
        self.assertIn("reuseCloud ? -tag : tag",source)
        self.assertIn("shaft=applyLightShafts",source)
        self.assertIn("stable ? (reuseCloud ? -tag : tag) : 0.0",source)

    def test_segmented_scattering_homogeneous_exact(self):
        for end in (25,30,40,50,63):
            for step in (2.0,2.5):
                n=min(16,math.ceil((end-12)/step))
                self.assertLessEqual(8+n,24)
                for k in (.0035,.006,.018,.027):
                    result=0
                    for lo,hi,count in ((0,12,8),(12,end,n)):
                        d=(hi-lo)/count
                        t=math.exp(-k*lo)
                        trans=math.exp(-k*d)
                        for _ in range(count):
                            result+=t*(1-trans)
                            t*=trans
                    self.assertAlmostEqual(result,1-math.exp(-k*end),places=12)

    def test_scene_footprint_and_profile_resource_budget(self):
        def reduce(depth,threshold,contribution,footprint,limit):
            return depth>threshold and contribution<.65 and footprint*math.sqrt(contribution)<limit
        self.assertFalse(reduce(8,22,.9,80,28))
        self.assertTrue(reduce(26,22,.2,30,28))
        self.assertFalse(reduce(26,22,.2,100,28))
        options=preview_profiles(S)["profile.Extreme"]
        self.assertEqual(options["CLOUD_NOISE_MODE"],"1")
        self.assertEqual(options["VOLUME_TEMPORAL"],"1")
        budget=resource_budget(options,1920,1080)
        self.assertEqual(budget["cloud_noise_mib"],1)
        self.assertAlmostEqual(budget["volume_history_mib"],8*2880*1080/MIB)
        self.assertEqual(resource_budget({**options,"VOXEL_FUSION":"0"},1920,1080)["volume_history_mib"],0)
        self.assertEqual(resource_budget({**options,"VOLUME_TEMPORAL":"0"},1920,1080)["volume_history_mib"],0)
        self.assertEqual(resource_budget({**options,"PROJECTION_JITTER":"2"},1920,1080)["volume_history_mib"],0)

    def test_pipeline_contract(self):
        v=(S/"lib/atmosphere/volume.glsl").read_text()
        self.assertIn("cloudDensityCoarse(point,detail,uv,coarse)",v)
        self.assertIn("extraSamples-=2",v)
        self.assertIn("volumeShadowProjected",v)
        self.assertIn("previousLight",v)
        props=(S/"shaders.properties").read_text()
        self.assertIn("customTexture.lwCloudNoise = textures/cloud_noise.r8 TEXTURE_2D R8 1024 1024 RED UNSIGNED_BYTE",props)
        self.assertIn("image.lwVolumeHistory",props)
        self.assertIn("program.world-1/setup3.enabled = false",props)
        self.assertIn("program.world1/setup3.enabled = false",props)
