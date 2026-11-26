import itertools
import math
import random
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"shaders"


class ShadowAoTests(unittest.TestCase):
    def test_receiver_plane_matches_actual_texel_centres(self):
        # Orthographic clip scales, all combinations of signed slopes and
        # resolutions. Rasterized depth of a single continuous plane should
        # never become a blocker merely because a neighbour is sampled.
        rng=random.Random(271)
        false_old=0
        for resolution in (512,1024,2048,4096):
            for _ in range(300):
                nx,ny=rng.uniform(-.6,.6),rng.uniform(-.6,.6)
                nz=math.sqrt(1-nx*nx-ny*ny)
                sx,sy,sz=.005,.005,-.004
                gradient=(-nx/nz*sz/sx,-ny/nz*sz/sy)
                u,v=rng.uniform(.1,.9),rng.uniform(.1,.9)
                depth=.5
                bias=.00004
                for dx,dy in itertools.product((-8,-3,-1,0,1,3,8),repeat=2):
                    px,py=int(u*resolution)+dx,int(v*resolution)+dy
                    du,dv=(px+.5)/resolution-u,(py+.5)/resolution-v
                    stored=depth+gradient[0]*du+gradient[1]*dv
                    corrected=depth-bias+gradient[0]*du+gradient[1]*dv
                    self.assertLess(corrected,stored)
                    # A real blocker remains in front of the receiver plane.
                    self.assertGreater(corrected,stored-.002)
                    false_old+=int(depth-bias>stored)
        self.assertGreater(false_old,0)

    def test_symmetric_four_probe_subset(self):
        taps=((-0.62,-0.62),(-.16,-.38),(.62,-.62),(.38,-.16),
              (.62,.62),(.16,.38),(-.62,.62),(-.38,.16))
        for count in (4,8):
            selected=taps[::8//count]
            self.assertEqual(len(selected),count)
            for axis in (0,1):
                self.assertAlmostEqual(sum(p[axis] for p in selected),0.)
        source=(ROOT/"lib/lighting/lite_shadows.glsl").read_text()
        self.assertIn("receiverDepthAt(receiver,gradient,p,resolution)",source)
        self.assertIn("sum+=plane-depth",source)
        self.assertIn("compareShadowTexel(receiver,gradient",source)
        self.assertIn("blockerTaps==8 ? 1 : 2",source)

    def test_shared_ao_geometry_and_full_resolution_fallback(self):
        q=(ROOT/"lib/quality.glsl").read_text()
        self.assertIn("AO_RECONSTRUCTION == 1 && PROJECTION_JITTER == 1",q)
        self.assertIn("!defined(LW_DIMENSION_END) && !defined(LW_DIMENSION_NETHER)",q)
        props=(ROOT/"shaders.properties").read_text()
        self.assertIn("size.buffer.colortex3 = 0.5 0.5",props)
        p=(ROOT/"programs/shared/deferred.fsh.glsl").read_text()
        self.assertIn("RENDERTARGETS: 9,10,3",p)
        self.assertIn("RENDERTARGETS: 9,3",p)
        self.assertLess(p.index("aoTrace=vec2(groundTruthOcclusion"),p.index("ScreenBounce bounce ="))
        spatial=(ROOT/"lib/lighting/gtao_spatial.glsl").read_text()
        self.assertIn("if(depth<4.0) return groundTruthOcclusion",spatial)
        self.assertIn("if(coverage<=0.003) return groundTruthOcclusion",spatial)
        self.assertIn("smoothstep(4.0,6.0,depth)",spatial)
        for width,height in ((1920,1080),(1919,1079),(2560,1440),(1,1)):
            sw,sh=max(1,width//2),max(1,height//2)
            for x,y in ((0,0),(sw-1,sh-1)):
                donor=(int((x+.5)*width/sw),int((y+.5)*height/sh))
                self.assertTrue(0<=donor[0]<width and 0<=donor[1]<height)

    def test_voxel_reduction_and_support(self):
        rng=random.Random(1727)
        for _ in range(200):
            flags=[rng.randrange(16) for _ in range(64)]
            groups=[]
            for i in range(8):
                mask=0
                for flag in flags[i*8:i*8+8]:
                    mask|=flag
                groups.append(mask)
            expected=0
            for flag in flags:
                expected|=flag
            actual=0
            for group in groups:
                actual|=group
            self.assertEqual(actual,expected)
        for local in range(4):
            # Four propagation steps + one diffuse neighbour + one filter halo.
            for delta in range(-6,7):
                self.assertLessEqual(abs((local+delta)//4),2)
        seed=(ROOT/"programs/shared/prepare.csh.glsl").read_text()
        self.assertNotIn("atomicOr(lwGroupFlags",seed)
        self.assertIn("lwGroupFlags[lane]=flags",seed)
        irrad=(ROOT/"lib/voxel/irradiance.glsl").read_text()
        self.assertIn("tile+ivec3(96,0,0)",irrad)
        self.assertIn("return sampleWrappedVoxel(field,sampleCell)",irrad)
