import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from render_reuse_sim import tile_cases,history_cases,gi_ssr_cases,clouds,blur

class BoundedReuseTests(unittest.TestCase):
    def test_sparse_list_coverage(self):
        rows=tile_cases()
        self.assertEqual(len(rows),10)
        for row in rows:
            self.assertLessEqual(row["new_groups"],row["old_groups"])
            if row["motion"][0]==row["grid"]:
                self.assertEqual(row["new_groups"],row["old_groups"])
        s=(ROOT/"shaders/programs/shared/prepare_e.csh.glsl").read_text()
        self.assertIn("tasks3[base3+i3]=index",s)
        self.assertIn("retainHistoryTile(tile,support)",s)
        p=(ROOT/"shaders/shaders.properties").read_text()
        self.assertIn("indirect.prepare6 = 0 32",p)
        self.assertIn("bufferObject.0 = 393264",p)

    def test_bounded_history_and_retrace_counts(self):
        result=history_cases()
        self.assertGreater(result["accepted"],0)
        self.assertLess(result["history_pair_fetches_new"],result["history_pair_fetches_old"])
        r=gi_ssr_cases()
        self.assertLess(r["gi_candidate_fallback_rays"],r["gi_reference_fallback_rays"])
        self.assertLess(r["ssr_candidate_fallback_steps"],r["ssr_reference_fallback_steps"])

    def test_cloud_proxy_and_gaussian_identity(self):
        self.assertGreater(clouds()["translation_eligible"],0)
        self.assertLess(blur()["max_abs_error"],1e-12)
        p=(ROOT/"shaders/programs/shared/composite6.fsh.glsl").read_text()
        self.assertIn("RENDERTARGETS: 10",p)
        self.assertIn("vec2(0,1),true",p)
