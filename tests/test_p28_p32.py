import csv
import itertools
import math
import random
import struct
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT=Path(__file__).resolve().parents[1]
SHADERS=ROOT/"shaders"
sys.path.insert(0,str(ROOT/"tools"))
from dimension_budget import analyze,select


def half(value):
    return struct.unpack("e",struct.pack("e",value))[0]


DIRS=((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1))
ZERO=(0.,0.,0.,0.)


def neighbor(p,d):
    return tuple(a+b for a,b in zip(p,d))


def step(p,field,seeds,walls):
    if p in walls:
        return ZERO
    source=seeds.get(p,ZERO)
    incoming=[max(field.get(neighbor(p,d),ZERO)[c] for d in DIRS) for c in range(4)]
    return tuple(half(max(source[c],incoming[c]*.73)) for c in range(3))+(half(max(source[3],incoming[3]-.20)),)


def distance(p):
    return sum(max(-c,c-3,0) for c in p)


class PipelineTests(unittest.TestCase):
    def test_lava_reflection_and_glow(self):
        lava=(SHADERS/"programs/p1/surface.fsh.glsl").read_text()
        self.assertIn("reflectedRadiance*lavaTint*min(fresnel,0.18)",lava)
        self.assertIn("0.12+0.22*emissionPeak",lava)
        self.assertIn("lit=material.emission+nonEmissive*lavaTint*0.65+reflection",lava)
        scene=(SHADERS/"lib/color/scene.glsl").read_text()
        self.assertIn("color/peak,hueWeight",scene)
        # Synthetic saturated HDR highlight: preserve a higher red/green
        # ratio than neutral gamut compression, without exceeding display gamut.
        for peak in (1.00001,1.2,2.,4.):
            color=(peak,.24*peak,.06*peak)
            mapped=sum(v*w for v,w in zip(color,(.2126,.7152,.0722)))
            if mapped>=1:
                continue
            neutral=tuple(mapped+(c-mapped)*(1-mapped)/(peak-mapped) for c in color)
            hue=tuple(c/peak for c in color)
            self.assertGreaterEqual(hue[0]/hue[1],neutral[0]/neutral[1])
            self.assertTrue(all(0<=v<=1 for v in hue))
        values=[x/(1+.65*x) for x in (0.,.01,.1,1.,2.,10.)]
        self.assertTrue(all(a<b for a,b in zip(values,values[1:])))
        self.assertEqual(values[0],0.)
        self.assertLess(values[-1],1/.65)
        self.assertIn("GLOW_SOFTNESS*0.65*peak",(SHADERS/"lib/atmosphere/local_scatter.glsl").read_text())

    def test_hybrid_shadow_plane_threshold(self):
        source=(SHADERS/"lib/lighting/lite_shadows.glsl").read_text()
        self.assertIn("uniform sampler2DShadow shadowtex0HW",source)
        self.assertIn("slope.x+slope.y<=0.00002",source)
        self.assertIn("texelFetch(shadowtex0,p,0)",source)
        self.assertIn("compareShadowTexel(receiver,gradient",source)
        for a,b in itertools.product((0.,1e-6,1e-5),repeat=2):
            for x,y in itertools.product((-1.,1.),repeat=2):
                self.assertLessEqual(abs(a*x+b*y),2e-5)

    def test_pair_matches_two_half_float_steps(self):
        rng=random.Random(2932)
        domain=set(itertools.product(range(8),repeat=3))
        self.assertEqual(sum(distance(p)<=2 for p in itertools.product(range(-2,6),repeat=3)),304)
        self.assertEqual(sum(distance(p)<=1 for p in itertools.product(range(-1,5),repeat=3)),160)
        for _ in range(8):
            walls={p for p in sorted(domain) if rng.random()<.24}
            seeds={p:(half(rng.random()*2),half(rng.random()),half(rng.random()),1.)
                   for p in sorted(domain-walls) if rng.random()<.1}
            field={p:seeds.get(p,ZERO) for p in domain}
            for _ in range(2):
                middle={p:step(p,field,seeds,walls) for p in domain}
                expected={p:step(p,middle,seeds,walls) for p in domain}
                actual={}
                for base in itertools.product((0,4),repeat=3):
                    input_halo={neighbor(base,p):field.get(neighbor(base,p),ZERO)
                                for p in itertools.product(range(-2,6),repeat=3) if distance(p)<=2}
                    mid_halo={neighbor(base,p):step(neighbor(base,p),input_halo,seeds,walls)
                              if neighbor(base,p) in domain else ZERO
                              for p in itertools.product(range(-1,5),repeat=3) if distance(p)<=1}
                    for p in itertools.product(range(4),repeat=3):
                        cell=neighbor(base,p)
                        actual[cell]=step(cell,mid_halo,seeds,walls)
                self.assertEqual(actual,expected)
                field=actual
        shader=(SHADERS/"lib/voxel/propagate_pair.glsl").read_text()
        self.assertIn("unpackHalf2x16(packHalf2x16(v.xy))",shader)
        self.assertIn("pairHaloDistance(p)>2",shader)
        self.assertIn("pairHaloDistance(p-1)>1",shader)

    def test_volume_affine_and_hdr_ownership(self):
        rng=random.Random(3031)
        for _ in range(1000):
            scene,scatter,shaft,t,f=[rng.random()*5 for _ in range(3)]+[rng.random(),rng.random()]
            old=scene*(1-f)+(scene*t+scatter)*f+shaft
            new=scene*((1-f)+t*f)+scatter*f+shaft
            self.assertAlmostEqual(old,new,places=12)
        q=(SHADERS/"lib/quality.glsl").read_text()
        self.assertIn("GI_REUSE_MODE == 2",q)
        self.assertIn("!defined(MOTION_BLUR)",q)
        comp=(SHADERS/"programs/shared/composite_b.csh.glsl").read_text()
        self.assertIn("imageStore(colorimg9,p,result)",comp)
        self.assertIn("imageStore(colorimg3,p",comp)
        taa=(SHADERS/"programs/shared/composite1.fsh.glsl").read_text()
        self.assertIn("RENDERTARGETS: 4,5",taa)
        self.assertIn("colorHistory=vec4(sceneColor.rgb,0.0)",taa)
        for name in ("final","composite3"):
            src=(SHADERS/f"programs/shared/{name}.fsh.glsl").read_text()
            self.assertIn("#define LW_POST_SOURCE colortex4",src)

    def test_budget_selection_with_synthetic_fixture(self):
        # Unit fixture only; not GPU evidence. The tool consumes data from
        # operator-supplied capture files and cannot independently attest it.
        with TemporaryDirectory() as directory:
            root=Path(directory)
            runs=[]
            for mode,ms in ((0,6.),(1,5.4),(2,4.9)):
                fp=root/f"{mode}-frame.csv"
                pp=root/f"{mode}-pass.csv"
                with fp.open("w",newline="") as f:
                    writer=csv.writer(f)
                    writer.writerow(("frame","gpu_ms"))
                    writer.writerows((i,ms) for i in range(300))
                with pp.open("w",newline="") as f:
                    writer=csv.writer(f)
                    writer.writerow(("frame","pass","gpu_ms"))
                    writer.writerows((i,"deferred",ms/3) for i in range(3))
                runs.append(dict(mode=mode,scene="fixture",source="measured_gpu",
                                 quality_accepted=True,frame_csv=fp.name,pass_csv=pp.name))
            manifest={k:"fixture" for k in ("gpu","driver","minecraft","iris","sodium","resolution","shader_commit","profile")}
            manifest["dimensions"]={"overworld":{"scene":"fixture","runs":runs}}
            result=analyze(manifest,root)
            self.assertEqual(result["shader_options"],{"OVERWORLD_BUDGET":2})
            self.assertTrue(result["dimensions"]["overworld"]["target_met"])
            self.assertEqual(result["dimensions"]["end"]["status"],"unmeasured")
            self.assertFalse(analyze(manifest,root,4.)["dimensions"]["overworld"]["target_met"])
            self.assertEqual(analyze(manifest,root,7.)["shader_options"],{"OVERWORLD_BUDGET":0})
            runs[0]["quality_accepted"]=False
            with self.assertRaises(ValueError):
                analyze(manifest,root)
        self.assertEqual(select([dict(mode=1,p95_ms=6.,median_ms=5.),dict(mode=2,p95_ms=7.,median_ms=6.)],5.)["mode"],1)
