import itertools
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shaders"

class VoxelGpuIncrementalTests(unittest.TestCase):
    def test_tile_radius_covers_dependencies(self):
        # All possible positions in one tile, all Manhattan offsets up to the
        # four propagation steps or six propagation+diffuse dependencies.
        for steps, radius in ((4,1),(6,2)):
            for pos in itertools.product(range(4), repeat=3):
                for offset in itertools.product(range(-steps,steps+1),repeat=3):
                    if sum(map(abs,offset)) > steps:
                        continue
                    target = tuple((x+y)//4 for x,y in zip(pos,offset))
                    self.assertLessEqual(max(map(abs,target)),radius)

    def test_stage_cache_and_seed_deletion(self):
        start = (ROOT/"programs/shared/prepare.csh.glsl").read_text()
        self.assertIn("imageLoad(lwVoxelPrevSeed, cell).r != seed",start)
        self.assertIn("imageStore(lwVoxelPrevSeed, cell, uvec4(seed))",start)
        self.assertIn("previous.w != frameCounter - 1",start)
        for i in range(1,5):
            stage = (ROOT/f"programs/shared/prepare{i}.csh.glsl").read_text()
            self.assertIn(f"#define LW_VOXEL_READ lwVoxelStage{i-1}",stage)
            self.assertIn("#define LW_VOXEL_WRITE "+("lwVoxelFirst" if i==4 else f"lwVoxelStage{i}"),stage)
        self.assertIn("voxelTileNeedsUpdate(1)",(ROOT/"lib/voxel/propagate.glsl").read_text())
        self.assertIn("voxelTileNeedsUpdate(2)",(ROOT/"programs/shared/prepare5.csh.glsl").read_text())

    def test_image_budget(self):
        props = (ROOT/"shaders.properties").read_text()
        self.assertEqual(len({line.split("=",1)[0].strip() for line in props.splitlines()
                              if line.startswith("image.")}),15)
