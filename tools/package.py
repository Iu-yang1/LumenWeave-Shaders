#!/usr/bin/env python3
"""Build and verify the LumenWeave Iris preview or the separate voxel probe."""

import argparse
from hashlib import sha256
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "shaders"
PROBE = ROOT / "experiments" / "voxel" / "shaders"
P0_CONFIG = ROOT / "experiments" / "p0" / "shaders"
P0_SHARED = ("final.vsh", "final.fsh", "lib/soft_color.glsl")
NOTICES = ("LICENSE", "COPYING", "THIRD_PARTY_NOTICES.md")
LICENSE_DIGESTS = {
    "LICENSE": "e3a994d82e644b03a792a930f574002658412f62407f5fee083f2555c5f23118",
    "COPYING": "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986",
}
SHADER_TEXT = {".vsh", ".fsh", ".csh", ".glsl", ".lang", ".properties"}


def member_bytes(path):
    if path.suffix in SHADER_TEXT:
        return path.read_text(encoding="utf-8").encode("utf-8")
    return path.read_bytes()


def shader_members(shaders):
    return {
        f"shaders/{path.relative_to(shaders).as_posix()}": member_bytes(path)
        for path in shaders.rglob("*")
        if path.is_file() and path.name != "AGENTS.md"
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    variant = parser.add_mutually_exclusive_group()
    variant.add_argument("--voxel-probe", action="store_true")
    variant.add_argument("--p0", action="store_true")
    args = parser.parse_args()
    if args.p0:
        name = "LumenWeave-Shaders-P0"
        members = shader_members(P0_CONFIG)
        members.update({f"shaders/{path}": member_bytes(PREVIEW / path) for path in P0_SHARED})
    elif args.voxel_probe:
        name = "LumenWeave-Voxel-Probe"
        members = shader_members(PROBE)
    else:
        name = "LumenWeave-Shaders-P5-Preview"
        members = shader_members(PREVIEW)
    output = ROOT / "dist" / f"{name}.zip"
    for entry in ("final.vsh", "final.fsh", "shaders.properties"):
        if f"shaders/{entry}" not in members:
            raise SystemExit(f"Missing shaders/{entry}")
    for notice in NOTICES:
        data = (ROOT / notice).read_text(encoding="utf-8").encode("utf-8")
        if (
            notice in LICENSE_DIGESTS
            and sha256(data).hexdigest() != LICENSE_DIGESTS[notice]
        ):
            raise SystemExit(f"Unexpected GNU license content: {notice}")
        members[notice] = data
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for name, data in sorted(members.items()):
            archive.writestr(ZipInfo(name), data, compress_type=ZIP_DEFLATED)

    with ZipFile(output) as archive:
        if archive.namelist() != sorted(members) or archive.testzip() is not None:
            raise SystemExit(f"Invalid ZIP: {output}")

    digest = sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(
        f"{digest}  {output.name}\n", encoding="utf-8", newline="\n"
    )
    print(output.relative_to(ROOT))
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
