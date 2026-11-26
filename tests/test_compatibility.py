import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from compatibility import TARGETS, adapt_members
from package import PREVIEW, shader_members

class CompatibilityTests(unittest.TestCase):
    def test_all_targets_and_dimension_entry_points(self):
        source=shader_members(PREVIEW)
        self.assertEqual(set(TARGETS),{"1.20.x","1.21.x","26.x"})
        for target in TARGETS:
            pack=adapt_members(source,target)
            self.assertIn("COMPATIBILITY.txt",pack)
            self.assertEqual("shaders/dimension.properties" in pack,target!="1.20.x")
            for dimension,marker in (("world1",b"LW_DIMENSION_END"),("world-1",b"LW_DIMENSION_NETHER")):
                for name,data in pack.items():
                    if name.startswith(f"shaders/{dimension}/") and name.endswith((".fsh",".vsh",".csh")):
                        self.assertTrue(data.startswith(b"#version "),name)
                        self.assertIn(b"#define "+marker,data,name)
            self.assertEqual(pack["shaders/lib/lighting/hiz.glsl"],source["shaders/lib/lighting/hiz.glsl"])

    def test_registry_rename_and_modern_indirect_gate(self):
        props=(PREVIEW/"block.properties").read_text()
        self.assertIn("#if MC_VERSION < 12003",props)
        self.assertIn("minecraft:grass ",props)
        self.assertIn("minecraft:short_grass ",props)
        self.assertIn("minecraft:red_poplar_leaves",props)
        quality=(PREVIEW/"lib/quality.glsl").read_text()
        self.assertIn("IRIS_VERSION >= 11107 && MC_VERSION >= 260100",quality)
