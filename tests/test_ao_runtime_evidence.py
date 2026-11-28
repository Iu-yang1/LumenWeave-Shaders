import sys
import hashlib
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from verify_ao_gi_runtime import validate_instance
PAYLOAD=b"fixture-shader"
DIGEST=hashlib.sha256(PAYLOAD).hexdigest()


class RuntimeEvidenceTests(unittest.TestCase):
    def fixture(self,directory):
        (directory/"logs").mkdir()
        (directory/"shaderpacks").mkdir()
        (directory/"shaderpacks/LumenWeave-Shaders-P5-Preview.zip").write_bytes(PAYLOAD)
        (directory/"shader-pack-sha256.txt").write_text(
            DIGEST.upper()+"  LumenWeave-Shaders-P5-Preview.zip\n",encoding="utf-8")
        (directory/"options.txt").write_text("soundCategory_master:0.0\n",encoding="utf-8")
        (directory/"logs/latest.log").write_text(
            "LumenWeave P4 readback static framebuffer=1920x1080 giTargets=2 externalFlag=0 "
            "giLit=15 dimension=minecraft:overworld camera=(0.0 1.0 2.0) GPU=fixture GL error=0\n",
            encoding="utf-8")

    def test_reject_wrong_candidate_and_failed_shader_pipeline(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)
            self.fixture(directory)
            self.assertEqual(validate_instance(directory,DIGEST,("static",),0)["readbacks"]["static"]["camera_position"],[0,1,2])
            with self.assertRaisesRegex(ValueError,"Candidate mismatch"):
                validate_instance(directory,"cd"*32,("static",),0)
            installed=directory/"shaderpacks/LumenWeave-Shaders-P5-Preview.zip"
            installed.write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError,"Candidate mismatch"):
                validate_instance(directory,DIGEST,("static",),0)
            installed.write_bytes(PAYLOAD)
            with (directory/"logs/latest.log").open("a",encoding="utf-8") as stream:
                stream.write("ShaderCompileException: reserved identifier\n")
            with self.assertRaisesRegex(ValueError,"Shader or OpenGL failure"):
                validate_instance(directory,DIGEST,("static",),0)

    def test_missing_stage_and_nonzero_audio_are_not_acceptance(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)
            self.fixture(directory)
            with self.assertRaisesRegex(ValueError,"Missing valid"):
                validate_instance(directory,DIGEST,("arrived",),0)
            (directory/"options.txt").write_text("soundCategory_master:1.0\n",encoding="utf-8")
            with self.assertRaisesRegex(ValueError,"Master audio"):
                validate_instance(directory,DIGEST,("static",),0)

    def test_mod_presence_is_not_a_verified_handoff(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)
            self.fixture(directory)
            with self.assertRaisesRegex(ValueError,"Missing valid"):
                validate_instance(directory,DIGEST,("static",),2)
