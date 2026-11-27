import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from check_shaders import preview_profiles


class OptionalExtensionTests(unittest.TestCase):
    def test_all_profiles_preserve_standalone_default(self):
        quality = (ROOT / "shaders/lib/quality.glsl").read_text(encoding="utf-8")
        self.assertIn("#define EXTENSION_VOXELS 0 // [0 1]", quality)
        for name, options in preview_profiles(ROOT / "shaders").items():
            with self.subTest(profile=name):
                self.assertEqual(options.get("EXTENSION_VOXELS", "0"), "0")

    def test_bridge_flag_does_not_alias_voxels_or_tile_metadata(self):
        properties = (ROOT / "shaders/shaders.properties").read_text(encoding="utf-8")
        for size in (32, 64, 96, 128):
            metadata_texels = (size // 4) ** 3
            flag_slice = size + (size + 63) // 64
            self.assertGreaterEqual(size * size * (flag_slice - size), metadata_texels)
            self.assertIn(f"false false {size} {size} {flag_slice + 1}", properties)

    def test_each_frame_requires_explicit_handoff_before_skipping_injection(self):
        begin = (ROOT / "shaders/programs/shared/begin.csh.glsl").read_text(encoding="utf-8")
        injection = (ROOT / "shaders/lib/voxel/inject.glsl").read_text(encoding="utf-8")
        self.assertIn("imageStore(lwVoxelOccupancy,lwExternalSeedFlagAddress(),uvec4(0u))", begin)
        self.assertIn("if(imageLoad(lwVoxelOccupancy,lwExternalSeedFlagAddress()).r==1u) return;", injection)
        self.assertIn("imageAtomicMax(lwVoxelOccupancy, cell, seed)", injection)
