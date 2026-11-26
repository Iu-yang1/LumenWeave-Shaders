import itertools
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from gpu_pass_profile import compare
from renderdoc_gpu_capture import counter_rows,event_owner

class AdaptivePerformanceTests(unittest.TestCase):
    def test_temporal_refresh_guarantee(self):
        for x,y,frame in itertools.product(range(8),range(8),range(32)):
            self.assertNotEqual((x+y+frame)&1,(x+y+frame+1)&1)
        source=(ROOT/"shaders/programs/shared/deferred.fsh.glsl").read_text()
        self.assertIn("matchesHistoryDepth(previous.a,expectedDepth)",source)
        self.assertIn("dot(normal,decodeNormal(metadata.xy))>0.92",source)
        self.assertIn("colortex9Clear = false",source)

    def test_metadata_exact_range(self):
        for seed in range(260):
            self.assertEqual(seed & 65535,seed)
        for flags in range(16):
            self.assertEqual(flags & 255,flags)
        props=(ROOT/"shaders/shaders.properties").read_text()
        self.assertIn("lwVoxelPrevSeedSampler red_integer r16ui unsigned_short",props)
        self.assertIn("lwVoxelDirtySampler red_integer r8ui unsigned_byte",props)
        self.assertIn("lwVoxelSeeds red_integer r32ui unsigned_int",props)
        begin=(ROOT/"shaders/programs/shared/begin.csh.glsl").read_text()
        self.assertNotIn("lwVoxelDirtyTiles",begin)

    def test_adaptive_shadow_near_preserved(self):
        for taps in (4,8):
            for distance in (0,12,28,30,48,100):
                count=min(4,taps) if distance>28 else taps
                selected=[i*taps//count for i in range(count)]
                self.assertEqual(len(set(selected)),count)
                if distance<=28:
                    self.assertEqual(selected,list(range(taps)))

    def test_measured_duration_export(self):
        spans=event_owner({"shadow":[[1,3]],"deferred":[[4,8]]})
        results=[SimpleNamespace(eventId=i,value=SimpleNamespace(d=t))
                 for i,t in [(1,.001),(5,.002),(10,.003)]]
        rows=counter_rows("001",results,spans)
        self.assertEqual([r["pass"] for r in rows],["shadow","deferred","unclassified"])
        self.assertEqual([r["gpu_ms"] for r in rows],[1.,2.,3.])
        self.assertTrue(all(r["read_bytes"]=="" for r in rows))
        with self.assertRaises(ValueError):
            event_owner({"a":[[1,5]],"b":[[5,7]]})

    def test_compare_missing_is_not_zero(self):
        baseline=[{"frame":"1","pass":"a","gpu_ms":"2"},{"frame":"1","pass":"b","gpu_ms":"1"}]
        candidate=[{"frame":"2","pass":"a","gpu_ms":"1"}]
        rows={row["pass"]:row for row in compare(baseline,candidate)}
        self.assertEqual(rows["a"]["delta_percent"],-50)
        self.assertIsNone(rows["b"]["candidate_ms"])
        self.assertIsNone(rows["b"]["delta_ms"])
