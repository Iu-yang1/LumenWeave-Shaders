#!/usr/bin/env python3
"""Check the Iris preview and voxel probe with a desktop GLSL compiler."""

import argparse
import re
import shutil
import subprocess
from itertools import product
from pathlib import Path
from tempfile import TemporaryDirectory

from package import P0_CONFIG, P0_SHARED, PREVIEW, PROBE

STAGES = {".vsh": ".vert", ".fsh": ".frag", ".csh": ".comp"}
INCLUDE = re.compile(r'\s*#\s*include\s+"([^"]+)"\s*')
IRIS_CLEAR_COLOR = re.compile(r"(?m)^\s*const vec4 \w+ClearColor\s*=\s*vec4\(([^()]*)\)\s*;")
IRIS_FULLSCREEN_SAMPLER = re.compile(
    r"\buniform\s+sampler2D\s+(colortex[0-3]|gcolor|gdepth|gnormal|composite)\b"
)
RENDER_STAGES = {"SUNSET": 2, "CUSTOM_SKY": 3, "SUN": 4, "MOON": 5, "STARS": 6, "VOID": 7}
VOXEL_FEATURES = (
    "IRIS_FEATURE_CUSTOM_IMAGES", "IRIS_FEATURE_COMPUTE_SHADERS",
    "IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE", "IRIS_FEATURE_REVERSED_CULLING",
)
VOXEL_PASSES = ("begin", "prepare", "prepare1", "prepare2", "prepare3", "prepare4")
VOXEL_DIFFUSE_PASS = "prepare5"
VOXEL_IMAGES = {"image.lwVoxelOccupancy", "image.lwVoxelFirst", "image.lwVoxelSecond"}
VOXEL_GRID_SIZES = (32, 64, 96, 128)
DIMENSIONS = ("world0", "world-1", "world1")


def menu_options(config):
    options = set()
    screens = set()

    def visit(name, ancestry=()):
        if name in ancestry:
            raise ValueError(f"Settings menu cycle: {' -> '.join((*ancestry, name))}")
        if name not in config:
            raise ValueError(f"Missing settings menu: {name}")
        if name in screens:
            return
        screens.add(name)
        for token in config[name].split():
            if token in {"<profile>", "<empty>"}:
                continue
            if token.startswith("[") and token.endswith("]"):
                visit(f"screen.{token[1:-1]}", (*ancestry, name))
            else:
                options.add(token)

    visit("screen")
    return options, screens - {"screen"}


def read_source(path):
    text = path.read_text(encoding="utf-8")
    if text.startswith("\ufeff"):
        raise ValueError(f"Unexpected UTF-8 BOM: {path}")
    return text


def expand(root, path, ancestry=()):
    path = path.resolve()
    if not path.is_relative_to(root):
        raise ValueError(f"Include outside pack: {path}")
    if path in ancestry:
        raise ValueError(
            "Include cycle: " + " -> ".join(item.name for item in (*ancestry, path))
        )
    lines = []
    for line in read_source(path).splitlines():
        include = INCLUDE.fullmatch(line)
        if include:
            target = include[1]
            resolved = (
                root / target[1:] if target.startswith("/") else path.parent / target
            )
            lines.append(expand(root, resolved, (*ancestry, path)))
        elif re.match(r"\s*#\s*include\b", line):
            raise ValueError(f"Unsupported include syntax: {path}: {line}")
        else:
            lines.append(line)
    return "\n".join(lines) + "\n"


def check_iris_directives(text, path):
    for arguments in IRIS_CLEAR_COLOR.findall(text):
        if len(arguments.split(",")) != 4:
            raise ValueError(f"Iris 1.8.8 requires four explicit clear-color components: {path}")
    if Path(path).name.startswith("gbuffers_"):
        match = IRIS_FULLSCREEN_SAMPLER.search(text)
        if match:
            raise ValueError(f"Iris cannot bind {match[1]} as a gbuffers sampler: {path}")


def properties(path, source=None):
    result = {}
    for line in (read_source(path) if source is None else source).splitlines():
        if not line.strip() or line.lstrip().startswith(("#", "!")):
            continue
        name, separator, value = line.partition("=")
        name = name.strip()
        if not separator or not name or not value.strip() or name in result:
            raise ValueError(f"Invalid or duplicate property in {path}: {line}")
        result[name] = value.strip()
    return result


def preview_profiles(root, config_root=None):
    config_root = config_root or root
    path = config_root / "shaders.properties"
    config = properties(path, "\n".join(
        line for line in read_source(path).splitlines() if line.startswith(("profile.", "screen"))
    ))
    options, screens = menu_options(config)
    sources = "\n".join(
        read_source(path)
        for path in root.rglob("*")
        if path.suffix in STAGES or path.suffix == ".glsl"
    )
    choices = {}
    for option in options:
        declaration = re.search(
            rf"(?m)^(?://)?#define {re.escape(option)}(?:[ \t]+(\S+)[ \t]+// \[([^\]]+)\])?[ \t]*$",
            sources,
        )
        if not declaration:
            raise ValueError(f"Missing shader option definition: {option}")
        default, allowed = declaration.groups()
        if not allowed and not re.search(rf"(?m)^[ \t]*#ifn?def[ \t]+{re.escape(option)}\b", sources):
            raise ValueError(f"Iris cannot discover boolean option without #ifdef or #ifndef: {option}")
        choices[option] = set(allowed.split()) if allowed else {"true", "false"}
        if default is not None and default not in choices[option]:
            raise ValueError(f"Invalid default for {option}: {default}")
    profiles = {}
    for name, value in config.items():
        if not name.startswith("profile."):
            continue
        settings = {}
        for token in value.split():
            option, delimiter, selection = token.partition(":")
            if not delimiter:
                selection = "false" if option.startswith("!") else "true"
                option = option.removeprefix("!")
            if option in settings or selection not in choices.get(option, set()):
                raise ValueError(f"Invalid option in {name}: {token}")
            settings[option] = selection
        profiles[name] = settings
    if not profiles:
        raise ValueError("No preview profiles")
    quality_options = set(next(iter(profiles.values())))
    if any(set(settings) != quality_options for settings in profiles.values()):
        raise ValueError("Profiles must specify the same quality options")
    expected = set(profiles) | {f"option.{option}" for option in options} | screens
    english = set(properties(config_root / "lang/en_us.lang"))
    chinese = set(properties(config_root / "lang/zh_cn.lang"))
    if english != chinese or expected - english:
        raise ValueError(
            f"Inconsistent localization keys: {(expected - english) | (english ^ chinese)}"
        )
    return profiles


def preprocess_properties(compiler, path, defines):
    rows = {}
    values = defines if isinstance(defines, dict) else dict.fromkeys(defines, "1")
    source = ["#version 330", *(f"#define {name} {value}" for name, value in values.items())]
    for index, line in enumerate(read_source(path).splitlines()):
        directive = line.strip()
        if re.match(r"#(?:if|ifdef|ifndef|elif|else|endif|define|undef)\b", directive):
            source.append(directive)
        elif directive and not directive.startswith(("#", "!")):
            token = f"LW_PROPERTY_ROW_{index}"
            name, _, value = line.partition("=")
            rows[token] = name.strip()
            source.append(f"{token} {value.strip()}")
    with TemporaryDirectory(prefix="lumenweave-properties-") as directory:
        shader = Path(directory) / "properties.frag"
        shader.write_text("\n".join(source) + "\n", encoding="utf-8")
        result = subprocess.run([compiler, "-E", str(shader)], capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f"{path}: {result.stderr}")
    expanded = []
    for line in result.stdout.splitlines():
        parts = line.split(maxsplit=1)
        if parts and parts[0] in rows:
            expanded.append(f"{rows[parts[0]]} = {parts[1] if len(parts) > 1 else ''}")
    return properties(path, "\n".join(expanded))


def check_voxel_properties(compiler, path):
    for size, (shadows, voxels, diffuse, deferred) in product(
        VOXEL_GRID_SIZES, product((False, True), repeat=4)
    ):
        options = tuple(
            name for enabled, name in (
                (shadows, "SCENE_SHADOWS"), (voxels, "VOXEL_LIGHTING"),
                (diffuse, "VOXEL_GI"), (deferred, "DEFERRED_LIGHTING"),
            )
            if enabled
        )
        for features in (VOXEL_FEATURES, (), *(
            tuple(flag for flag in VOXEL_FEATURES if flag != missing) for missing in VOXEL_FEATURES
        )):
            defines = {**dict.fromkeys((*options, *features), "1"), "VOXEL_GRID_SIZE": str(size)}
            config = preprocess_properties(compiler, path, defines)
            voxel_active = voxels and features == VOXEL_FEATURES
            shadow_active = shadows or voxel_active
            expected = {
                "shadow.enabled": str(shadow_active).lower(),
                "program.world0/shadow.enabled": None if shadow_active else "false",
                "shadow.culling": "reversed" if voxel_active else None,
                "allowConcurrentCompute": "false" if voxel_active else None,
                f"program.world0/{VOXEL_DIFFUSE_PASS}.enabled": (
                    None if voxel_active and diffuse and deferred else "false"
                ),
                **{f"program.world0/{program}.enabled": None if voxel_active else "false"
                   for program in VOXEL_PASSES},
            }
            for dimension in DIMENSIONS[1:]:
                expected.update({
                    key.replace("world0/", dimension + "/"): value
                    for key, value in tuple(expected.items()) if "world0/" in key
                })
            images = {key for key in config if key.startswith("image.lwVoxel")}
            if any(config.get(key) != value for key, value in expected.items()) or (
                images != (VOXEL_IMAGES if voxel_active else set())
            ):
                raise ValueError(f"Inconsistent shadow or voxel configuration: {options}, {features}")
            for image in images:
                if tuple(config[image].split()[-3:]) != (str(size),) * 3:
                    raise ValueError(f"Inconsistent voxel image dimensions: {image}, {size}")


def check_voxel_dispatch(compiler):
    for size, stage, dimension in product(VOXEL_GRID_SIZES, (*VOXEL_PASSES, VOXEL_DIFFUSE_PASS), DIMENSIONS):
        path = PREVIEW / dimension / f"{stage}.csh"
        text = compiler_source(PREVIEW, path, {"VOXEL_GRID_SIZE": str(size)}, ())
        with TemporaryDirectory(prefix="lumenweave-dispatch-") as directory:
            source = Path(directory) / "dispatch.comp"
            source.write_text(text, encoding="utf-8")
            result = subprocess.run([compiler, "-E", str(source)], capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f"{path}: {result.stderr}")
        dispatch = re.findall(
            r"const\s+ivec3\s+workGroups\s*=\s*ivec3\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)",
            result.stdout,
        )
        if dispatch != [(str(size // 4),) * 3]:
            raise ValueError(f"Invalid Iris work group literals for {stage}, {size}: {dispatch}")


def compiler_source(root, source, options, environment):
    text = expand(root, source)
    check_iris_directives(text, source)
    for option, selection in options.items():
        replacement = {
            "false": "",
            "true": f"#define {option}",
        }.get(selection, f"#define {option} {selection}")
        text = re.sub(
            rf"(?m)^(?://)?#define {re.escape(option)}(?:[ \t][^\n]*)?$",
            replacement,
            text,
        )
    if root != PREVIEW or source.parent.name not in DIMENSIONS:
        return text
    version, newline, body = text.partition("\n")
    macros = "".join(
        f"#define MC_RENDER_STAGE_{stage} {value}\n"
        for stage, value in RENDER_STAGES.items()
    )
    macros += "".join(f"#define {macro} 1\n" for macro in environment)
    return version + newline + macros + body


def compile_pack(compiler, root, profiles, sources=None, environment=()):
    groups = {}
    for path in sorted(sources if sources is not None else root.rglob("*")):
        if path.suffix in STAGES:
            groups.setdefault(path.with_suffix(""), []).append(path)
    if not groups:
        raise ValueError(f"No shader programs: {root}")
    for name, options in profiles.items():
        with TemporaryDirectory(prefix="lumenweave-") as directory:
            for index, (program, stages) in enumerate(groups.items()):
                if {source.suffix for source in stages} not in (
                    {".csh"},
                    {".fsh", ".vsh"},
                ):
                    raise ValueError(
                        f"Missing render stage: {program.relative_to(root)}"
                    )
                compiled = []
                for source in stages:
                    text = compiler_source(root, source, options, environment)
                    target = (
                        Path(directory)
                        / f"{index}-{program.name}{STAGES[source.suffix]}"
                    )
                    target.write_text(text, encoding="utf-8")
                    compiled.append(str(target))
                result = subprocess.run(
                    [compiler, "-l", *compiled], capture_output=True, text=True
                )
                if result.returncode:
                    raise ValueError(
                        f"{name}/{program.relative_to(root)}\n{result.stdout}{result.stderr}"
                    )
                print(f"{name}/{program.relative_to(root).as_posix()}: OK")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--compiler",
        default=shutil.which("glslangValidator") or shutil.which("glslang"),
    )
    args = parser.parse_args()
    if not args.compiler:
        parser.error("install glslang or supply --compiler")
    try:
        profiles = preview_profiles(PREVIEW)
        check_voxel_properties(args.compiler, PREVIEW / "shaders.properties")
        check_voxel_dispatch(args.compiler)
        print("Shadow and voxel capability matrix: 384 configurations OK")
        print("Voxel dispatch: 84 dimension/stage/size combinations OK")
        profiles["color-chart"] = {**profiles["profile.Natural"], "SHOW_COLOR_CHART": "true"}
        profiles["temporal"] = {**profiles["profile.Standard"], "AA_MODE": "2"}
        profiles["volume"] = {**profiles["temporal"], "VOLUME_EFFECTS": "true"}
        profiles["ultra-no-volume"] = {**profiles["profile.Ultra"], "VOLUME_EFFECTS": "false"}
        profiles["ultra-no-history"] = {**profiles["profile.Ultra"], "SCREEN_GI_HISTORY": "false"}
        profiles["ultra-no-spatial"] = {**profiles["profile.Ultra"], "SCREEN_GI_SPATIAL": "false"}
        profiles["screen-gi"] = {**profiles["profile.Standard"], "SCREEN_AO": "false", "SCREEN_GI": "true"}
        profiles["screen-gi-history-no-taa-water"] = {
            **profiles["screen-gi"], "SCREEN_GI_HISTORY": "true", "ADVANCED_WATER": "false"
        }
        profiles["screen-gi-spatial"] = {**profiles["screen-gi"], "SCREEN_GI_SPATIAL": "true"}
        profiles["post-camera-bloom"] = {
            **profiles["profile.High"], "AA_MODE": "3", "MOTION_BLUR": "true",
            "BLOOM": "true", "IMAGE_SHARPENING": "0.3", "COLOR_CONTRAST": "1.05",
        }
        profiles["forward-post"] = {
            **profiles["profile.Low"], "AA_MODE": "2", "MOTION_BLUR": "true", "BLOOM": "true",
            "WAVING_LEAVES": "false", "WAVING_GRASS": "false",
        }
        profiles["no-aa-no-wind"] = {
            **profiles["profile.High"], "AA_MODE": "0",
            "WAVING_LEAVES": "false", "WAVING_GRASS": "false", "WATER_REFLECTION_STEPS": "0",
        }
        compile_pack(args.compiler, PREVIEW, profiles)
        compile_pack(
            args.compiler, PREVIEW, {"lab-pbr": profiles["profile.Standard"]},
            environment=("MC_TEXTURE_FORMAT_LAB_PBR", "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        voxel_profiles = {
            "world-voxels": {**profiles["profile.Standard"], "VOXEL_LIGHTING": "true"},
            "world-voxels-no-shadow-filter": {**profiles["profile.Natural"], "VOXEL_LIGHTING": "true"},
        }
        compile_pack(args.compiler, PREVIEW, voxel_profiles, environment=VOXEL_FEATURES)
        compile_pack(
            args.compiler, PREVIEW,
            {"ultra-voxel": profiles["profile.Ultra"], "extreme-gi": profiles["profile.Extreme"]},
            environment=(*VOXEL_FEATURES, "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        compile_pack(
            args.compiler, PREVIEW,
            {"grid-64": {**profiles["profile.Extreme"], "VOXEL_GRID_SIZE": "64"}},
            environment=VOXEL_FEATURES,
        )
        compile_pack(
            args.compiler, PREVIEW, {name: profiles[f"profile.{name}"] for name in ("Medium", "High", "Ultra", "Extreme")},
            environment=(*VOXEL_FEATURES, "DISTANT_HORIZONS"),
        )
        compile_pack(
            args.compiler, PREVIEW,
            {"extreme-spatial": {**profiles["profile.Extreme"], "SCREEN_GI_SPATIAL": "true"}},
            environment=(*VOXEL_FEATURES, "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        compile_pack(args.compiler, PREVIEW, {"world-voxels-fallback": voxel_profiles["world-voxels"]})
        compile_pack(
            args.compiler, PREVIEW, preview_profiles(PREVIEW, P0_CONFIG),
            [PREVIEW / name for name in P0_SHARED],
        )
        properties(PROBE / "shaders.properties")
        compile_pack(args.compiler, PROBE, {"voxel-probe": {}})
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
