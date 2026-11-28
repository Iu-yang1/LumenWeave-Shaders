import random
import math
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from check_shaders import compiler_source, preview_profiles
from quality_budget import MIB, resource_budget


def projected_depth(position,normal,ray):
    depth=-position[2]
    denominator=sum(left*right for left,right in zip(normal,ray))
    if denominator**2<=.0004*sum(value**2 for value in ray):
        return None
    distance=sum(left*right for left,right in zip(normal,position))/denominator
    intersection=-ray[2]*distance
    if distance<=0 or intersection<=0 or abs(intersection-depth)>=max(.25,depth*.12):
        return None
    return intersection


class ReconstructionTests(unittest.TestCase):
    def test_planes_match_raster_donors_at_odd_sizes(self):
        rng=random.Random(2701)
        for width,height in ((1920,1080),(1919,1079),(1280,720),(3,3)):
            half_width,half_height=max(1,width//2),max(1,height//2)
            for _ in range(300):
                column,row=rng.randrange(half_width),rng.randrange(half_height)
                pixel_x=min(int((column+.5)*width/half_width),width-1)
                pixel_y=min(int((row+.5)*height/half_height),height-1)
                ray=(2*(pixel_x+.5)/width-1,2*(pixel_y+.5)/height-1,-1)
                normal=(rng.uniform(-.2,.2),rng.uniform(-.2,.2),1)
                position=(ray[0]*2,ray[1]*2,-2)
                depth=projected_depth(position,normal,ray)
                self.assertIsNotNone(depth)
                self.assertAlmostEqual(depth,2)
                opposite_plane=depth+.3
                self.assertGreater(abs(opposite_plane-depth),max(.12,depth*.035))

    def test_grazing_and_behind_eye_donors_rejected(self):
        self.assertIsNone(projected_depth((0,0,-2),(1,0,0),(0,0,-1)))
        self.assertIsNone(projected_depth((0,0,-2),(0,0,1),(0,0,1)))
        self.assertIsNone(projected_depth((0,0,-2),(.9,0,1),(1,0,-1)))
        for scale in (.01,1,100):
            self.assertAlmostEqual(projected_depth((0,0,-2),(0,0,1),(0,0,-scale)),2)

    def test_near_coverage_preserves_contacts_and_disocclusions(self):
        def reusable(coverage,values):
            return len(values)>=2 and coverage>=.72 and max(values)-min(values)<=.08
        self.assertFalse(reusable(1,[.8]))
        self.assertFalse(reusable(.5,[.8,.8]))
        self.assertFalse(reusable(1,[.5,.9]))
        self.assertTrue(reusable(.75,[.8,.83]))

    def test_reference_defaults_and_geometry_contract(self):
        profiles=preview_profiles(ROOT/"shaders")
        self.assertIn("#define AO_NEAR_RECONSTRUCTION 0 ",
                      (ROOT/"shaders/lib/quality.glsl").read_text(encoding="utf-8"))
        source=compiler_source(ROOT/"shaders",ROOT/"shaders/world0/deferred1.fsh",
                               {**profiles["profile.Extreme"],"AO_NEAR_RECONSTRUCTION":"1"},())
        self.assertIn("LW_AO_NEAR_GRID",source)
        self.assertIn("coverage<0.72",source)
        self.assertIn("maximumAo-minimumAo>0.08",source)
        self.assertIn("donorPlaneDepth",source)

    def test_extended_support_is_disjoint_and_bounded(self):
        for horizontal in (0,1):
            for vertical in (0,1):
                primary={(column,row) for column in (0,1) for row in (0,1)}
                extended={(-1,vertical),(2,vertical),(horizontal,-1),(horizontal,2)}
                self.assertEqual(len(extended),4)
                self.assertTrue(primary.isdisjoint(extended))
                self.assertTrue(all(-1<=column<=2 and -1<=row<=2 for column,row in extended))

    def test_near_ao_payload_and_dynamic_ownership_do_not_overlap(self):
        extreme={**preview_profiles(ROOT/"shaders")["profile.Extreme"],
                 "GEOMETRY_TAAU_SCALE":"100","PROJECTION_JITTER":"0"}
        for width,height in ((1920,1080),(1919,1079)):
            base=resource_budget(extreme,width,height)
            near=resource_budget({**extreme,"AO_NEAR_RECONSTRUCTION":"1"},width,height)
            self.assertEqual(base["ao_shared_single_mib"],0)
            self.assertEqual(near["ao_shared_single_mib"],4*(width//2)*(height//2)/MIB)
            dynamic=resource_budget({**extreme,"AO_NEAR_RECONSTRUCTION":"1","PROJECTION_JITTER":"2"},width,height)
            self.assertEqual(dynamic["ao_shared_single_mib"],0)
            fixed=resource_budget({**extreme,"PROJECTION_JITTER":"1"},width,height)
            self.assertEqual(fixed["ao_shared_single_mib"],near["ao_shared_single_mib"])

    def test_material_occlusion_precedes_screen_ao_and_gi(self):
        source=(ROOT/"shaders/programs/shared/deferred1.fsh.glsl").read_text(encoding="utf-8")
        self.assertLess(source.index("float materialVisibility=material.occlusion;"),
                        source.index("material.occlusion*="))
        self.assertEqual(source.count("* materialVisibility;"),2)
        self.assertIn("if(any(greaterThan(diffuse,vec3(0.0))))",source)
        rng=random.Random(2702)
        for _ in range(1000):
            sky,block,direct,emission,ao=(rng.random() for _ in range(5))
            base=direct+emission
            unoccluded=base+sky+block
            occluded=base+(sky+block)*ao
            self.assertGreaterEqual(occluded,base)
            self.assertLessEqual(occluded,unoccluded)
            self.assertAlmostEqual(base+(sky+block)*1,unoccluded)

    def test_zero_weight_history_donors_preserve_bilinear_result(self):
        rng=random.Random(2703)
        for fraction in ((0,0),(0,.5),(.5,0),(1,1),(.3,.6)):
            values=[rng.random() for _ in range(4)]
            weights=[(fraction[0] if column else 1-fraction[0])*
                     (fraction[1] if row else 1-fraction[1])
                     for row in range(2) for column in range(2)]
            dense=sum(value*weight for value,weight in zip(values,weights))
            sparse=sum(value*weight for value,weight in zip(values,weights) if weight>0)
            self.assertEqual(dense,sparse)
            if fraction==(0,0):
                self.assertEqual(sum(weight>0 for weight in weights),1)
        for relative in ("shaders/lib/temporal/screen_gi_history.glsl",
                         "shaders/lib/reflection/material_history.glsl"):
            source=(ROOT/relative).read_text(encoding="utf-8")
            guard="if(weight<=0.0)" if "screen_gi" in relative else "if(w<=0.0)"
            start=source.index(guard)
            self.assertLess(start,source.index("texelFetch",start))

    def test_cloud_history_follows_shared_wind_coordinates(self):
        rng=random.Random(2704)
        for _ in range(2000):
            time=rng.uniform(0,3599)
            elapsed=rng.uniform(.001,.039)
            speed=rng.uniform(.1,2)
            gusts=rng.random()
            current=time*speed
            delta=elapsed*speed
            travel=lambda phase:phase-gusts*2*math.sin(phase*.11)
            shift=delta-4*gusts*math.cos((current-delta*.5)*.11)*math.sin(delta*.055)
            self.assertAlmostEqual(shift,travel(current)-travel(current-delta),places=10)
            direction=rng.uniform(0,2*math.pi)
            current_point=(rng.uniform(-100,100),rng.uniform(-100,100))
            axis=(math.cos(direction),math.sin(direction))
            for point,component in zip(current_point,axis):
                previous_point=point-component*shift
                self.assertAlmostEqual(previous_point-component*travel(current-delta),
                                       point-component*travel(current),places=10)


if __name__=="__main__":
    unittest.main()
