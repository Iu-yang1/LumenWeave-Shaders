import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))

from check_shaders import preview_profiles
from quality_budget import MIB, resource_budget


class ResourceReuseTests(unittest.TestCase):
    def test_half_history_payload_and_dynamic_fallback(self):
        extreme=preview_profiles(ROOT/"shaders")["profile.Extreme"]
        for width,height in ((1920,1080),(1919,1079),(961,541)):
            baseline=resource_budget(extreme,width,height)
            reduced=resource_budget({**extreme,"GI_HISTORY_MODE":"1"},width,height)
            self.assertEqual(reduced["gi_history_double_mib"],32*(width//2)*(height//2)/MIB)
            self.assertEqual(baseline["gi_history_double_mib"],32*width*height/MIB)
            dynamic=resource_budget({**extreme,"GI_HISTORY_MODE":"1","PROJECTION_JITTER":"2"},width,height)
            self.assertEqual(dynamic["gi_history_double_mib"],baseline["gi_history_double_mib"])
        self.assertEqual(resource_budget({**extreme,"SCREEN_GI":"false","GI_HISTORY_MODE":"1"},1920,1080)["gi_history_double_mib"],0)

    def test_persistent_layout_regions_are_disjoint(self):
        for size in (32,64,96,128):
            planes=(size+63)//64
            flag=size+planes
            base=flag+1
            support=base+size
            depth=support+planes
            current=set()
            cached=set()
            for tile in range((size//4)**3):
                current.add((tile%size,(tile//size)%size,size+tile//(size*size)))
                cached.add((tile%size,(tile//size)%size,support+tile//(size*size)))
            self.assertTrue(current.isdisjoint(cached))
            self.assertNotIn((0,0,flag),current|cached)
            self.assertTrue(all(base<=z<support for z in (base,support-1)))
            self.assertTrue(all(support<=point[2]<depth for point in cached))
            options=preview_profiles(ROOT/"shaders")["profile.Extreme"]
            budget=resource_budget({**options,"VOXEL_GRID_SIZE":str(size),"EXTENSION_VOXELS":"2"},1920,1080)
            self.assertEqual(budget["extension_extra_mib"],4*size*size*(size+planes+1)/MIB)
            self.assertLess(budget["extension_extra_mib"],64)

    def test_history_tag_rejects_cached_dimension_gaps(self):
        tag=lambda frame:((frame&1023)+1,((frame>>10)&1023)+1)
        for current in range(1,3000):
            for gap in (2,3,17,500,1024,1025,65537,720720):
                self.assertNotEqual(tag(current-gap),tag(current-1))
        time_distance=lambda left,right:min(abs(left-right),3600-abs(left-right))
        self.assertLess(time_distance(3599.99,.01),.1)
        self.assertGreater(time_distance(64,.01),.1)
        self.assertGreater(time_distance(10,20),.1)

    def test_every_seed_consumer_uses_current_frame_source_selection(self):
        for path in ("lib/voxel/propagate.glsl","lib/voxel/propagate_pair.glsl",
                     "programs/shared/prepare.csh.glsl","programs/shared/prepare5.csh.glsl",
                     "programs/shared/prepare6.csh.glsl","programs/shared/prepare7.csh.glsl"):
            source=(ROOT/"shaders"/path).read_text(encoding="utf-8")
            self.assertIn('"/lib/voxel/seed_source.glsl"',source)
            self.assertIn("initializeVoxelSeedSource();",source)
            self.assertIn("voxelSeedAt(",source)


if __name__=="__main__":
    unittest.main()
