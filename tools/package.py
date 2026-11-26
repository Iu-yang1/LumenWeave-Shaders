#!/usr/bin/env python3
"""Build and verify the LumenWeave Iris preview or the separate voxel probe."""

import argparse
import json
from compatibility import TARGETS, adapt_members
from hashlib import sha256
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "shaders"
PROBE = ROOT / "experiments" / "voxel" / "shaders"
TAAU_PROBE = ROOT / "experiments" / "taau" / "shaders"
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


def build_pack(name, members):
    output = ROOT / "dist" / f"{name}.zip"
    for entry in ("final.vsh", "final.fsh", "shaders.properties"):
        if f"shaders/{entry}" not in members:
            raise SystemExit(f"Missing shaders/{entry}")
    members = dict(members)
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
            entry = ZipInfo(name)
            entry.create_system = 0
            archive.writestr(entry, data, compress_type=ZIP_DEFLATED)

    with ZipFile(output) as archive:
        if archive.namelist() != sorted(members) or archive.testzip() is not None:
            raise SystemExit(f"Invalid ZIP: {output}")

    digest = sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(
        f"{digest}  {output.name}\n", encoding="utf-8", newline="\n"
    )
    print(output.relative_to(ROOT))
    print(f"SHA256: {digest}")
    return output


def build_bundle():
    source = shader_members(PREVIEW)
    packs = []
    manifest = {"status": "compatibility-targets; runtime certification pending", "packs": []}
    for target, info in TARGETS.items():
        path = build_pack(f"LumenWeave-Shaders-MC-{target}", adapt_members(source, target))
        packs.append(path)
        manifest["packs"].append({"file": path.name, "sha256": sha256(path.read_bytes()).hexdigest(), **info})
    output = ROOT / "dist" / "LumenWeave-Shaders-All-Versions.zip"
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        files = {p.name: p.read_bytes() for p in packs}
        files.update({p.name+".sha256": p.with_suffix(".zip.sha256").read_bytes() for p in packs})
        files["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2)+"\n").encode("utf-8")
        files["README.txt"] = ("Extract this bundle first. Choose only the ZIP for your Minecraft version.\n"
                               "Fabric/NeoForge Iris as appropriate; 26.x requires OpenGL.\n").encode("utf-8")
        for name, data in sorted(files.items()):
            entry = ZipInfo(name)
            entry.create_system = 0
            archive.writestr(entry, data, compress_type=ZIP_DEFLATED)
    with ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise SystemExit(f"Invalid bundle: {output}")
    digest = sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n", encoding="utf-8")
    print(output.relative_to(ROOT))
    print(f"SHA256: {digest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    variant = parser.add_mutually_exclusive_group()
    variant.add_argument("--voxel-probe", action="store_true")
    variant.add_argument("--taau-probe", action="store_true")
    variant.add_argument("--p0", action="store_true")
    variant.add_argument("--compatibility", choices=tuple(TARGETS))
    variant.add_argument("--all-versions", action="store_true")
    args = parser.parse_args()
    if args.all_versions:
        build_bundle()
        return
    if args.p0:
        name = "LumenWeave-Shaders-P0"
        members = shader_members(P0_CONFIG)
        members.update({f"shaders/{path}": member_bytes(PREVIEW / path) for path in P0_SHARED})
    elif args.taau_probe:
        name = "LumenWeave-TAAU-Experimental-Probe"
        members = shader_members(TAAU_PROBE)
    elif args.voxel_probe:
        name = "LumenWeave-Voxel-Probe"
        members = shader_members(PROBE)
    else:
        name = f"LumenWeave-Shaders-MC-{args.compatibility}" if args.compatibility else "LumenWeave-Shaders-P5-Preview"
        members = adapt_members(shader_members(PREVIEW), args.compatibility)
    build_pack(name, members)


if __name__ == "__main__":
    main()
