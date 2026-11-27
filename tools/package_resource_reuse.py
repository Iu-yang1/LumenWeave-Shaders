"""Package the tested shader candidate and exact-target optional extension JARs."""

import argparse
import json
from hashlib import sha256
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.0-alpha.6"
TARGETS = {"1.20.1": 61, "1.21.1": 65, "26.1.2": 69}
README = """LumenWeave 资源复用开发候选 / Renderer Extension Alpha.6

本地测试候选；不是正式发布，也不代表已经达到 240 FPS。

1. Minecraft 1.21.1 可使用根目录的 LumenWeave-Shaders-P5-Preview.zip。
   其他版本请在 compatibility 中选择相应家族的光影 ZIP。
   光影 ZIP 不解压，放入游戏实例的 shaderpacks，然后在 Iris 中选择。
2. 光影不需要本扩展模组；需要版本匹配的 Iris / Sodium。
3. optional-mods 中仅选择与你的 Minecraft 精确版本一致的一份 JAR。
   不要同时安装三个版本。其他补丁版本尚未逐一验证。
4. 默认开启帧光照与湿材质复用。GI 历史仍为全分辨率，扩展桥接默认关闭。
5. 实验性半分辨率历史位于 GI 设置，GI_HISTORY_MODE=1。
6. 实验性持久桥接使用 EXTENSION_VOXELS=2，需要增量体素光照及模组参数：
   -Dlumenweave.renderer.independentSeeds=true
   EXTENSION_VOXELS=1 保留参考交接。没有当前帧完整确认时自动使用原路径。

完整实现、测量条件、采用结论和未覆盖项见 RESOURCE-REUSE-20261127.md。
measurements.json 区分呈现 FPS 与独立采集的 GPU 阶段时间。
SHA256SUMS.txt 包含本合集内每个有效载荷的校验值。
"""


def checked_archive(path):
    with ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError(f"Corrupt archive: {path}")
    return path.read_bytes()


def extension(path, target, major, version=VERSION):
    with ZipFile(path) as archive:
        metadata = json.loads(archive.read("fabric.mod.json"))
        if metadata["version"] != version or metadata["depends"]["minecraft"] != target:
            raise ValueError(f"Unexpected extension identity: {path}")
        for kernel in ("materialize_external_seeds", "patch_external_seeds", "publish_external_tiles"):
            archive.getinfo(f"lumenweave/{kernel}.comp")
        bytecode = archive.read("io/lumenweave/renderer/client/RendererExtension.class")
        if bytecode[:4] != b"\xca\xfe\xba\xbe" or int.from_bytes(bytecode[6:8], "big") != major:
            raise ValueError(f"Wrong Java bytecode target: {path}")
    return checked_archive(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extension-root", type=Path, required=True)
    parser.add_argument("--measurements", type=Path, required=True)
    parser.add_argument("--version",default=VERSION)
    parser.add_argument("--report",type=Path,default=ROOT/"RESOURCE-REUSE-20261127.md")
    parser.add_argument("--readme",type=Path)
    parser.add_argument("--extra-report",type=Path,action="append",default=[])
    parser.add_argument("--output-name",default="LumenWeave-Resource-Reuse-Alpha6-Candidate")
    args = parser.parse_args()
    files = {"README.zh-CN.txt": args.readme.read_bytes() if args.readme else README.encode("utf-8"),
             args.report.name: args.report.read_bytes(),
             "measurements.json": args.measurements.read_bytes()}
    for extra in args.extra_report:
        files[extra.name]=extra.read_bytes()
    preview = ROOT / "dist/LumenWeave-Shaders-P5-Preview.zip"
    files[preview.name] = checked_archive(preview)
    measurements=json.loads(files["measurements.json"])
    preview_digest=sha256(files[preview.name]).hexdigest()
    if not any(preview_digest in item.get("shader_archive","").lower() for item in measurements["instances"]):
        raise ValueError("Measurements do not contain the packaged preview")
    for family in ("1.20.x", "1.21.x", "26.x"):
        path = ROOT / f"dist/LumenWeave-Shaders-MC-{family}.zip"
        files[f"compatibility/{path.name}"] = checked_archive(path)
    for target, major in TARGETS.items():
        name = f"lumenweave-renderer-mc{target}-{args.version}.jar"
        path = args.extension_root / f"renderer-extension/build/{target}/libs/{name}"
        files[f"optional-mods/{target}/{name}"] = extension(path, target, major,args.version)
    digests = {name: sha256(data).hexdigest() for name, data in sorted(files.items())}
    files["SHA256SUMS.txt"] = "".join(f"{digest}  {name}\n" for name, digest in digests.items()).encode("utf-8")
    output = ROOT / "dist" / f"{args.output_name}.zip"
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            archive.writestr(ZipInfo(name), data, compress_type=ZIP_DEFLATED)
    with ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError("Candidate bundle failed CRC verification")
        for name, digest in digests.items():
            if sha256(archive.read(name)).hexdigest() != digest:
                raise ValueError(f"Candidate readback mismatch: {name}")
    digest = sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n", encoding="utf-8")
    print(output)
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
