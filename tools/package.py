#!/usr/bin/env python3
"""Build the LumenWeave Iris preview ZIP."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist" / "LumenWeave-Shaders-P0.zip"


def main():
    shaders = ROOT / "shaders"
    for name in ("final.vsh", "final.fsh", "shaders.properties"):
        if not (shaders / name).is_file():
            raise SystemExit(f"Missing shaders/{name}")

    OUTPUT.parent.mkdir(exist_ok=True)
    with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED) as archive:
        for path in sorted(shaders.rglob("*")):
            if path.is_file():
                entry = ZipInfo(path.relative_to(ROOT).as_posix())
                archive.writestr(entry, path.read_bytes(), compress_type=ZIP_DEFLATED)

    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
