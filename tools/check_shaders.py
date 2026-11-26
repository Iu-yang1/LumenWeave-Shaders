#!/usr/bin/env python3
"""Check the Iris preview and voxel probe with a desktop GLSL compiler."""

import argparse
from functools import partial
from hashlib import sha256
import re
import shutil
import subprocess
from itertools import product
from pathlib import Path
from tempfile import TemporaryDirectory

from package import P0_CONFIG, P0_SHARED, PREVIEW, PROBE, TAAU_PROBE
from compatibility import DIMENSION_DEFINES

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
    # Iris ComputeDirectiveParser splits constructor arguments by comma and
    # indexes each component, even after logging a wrong argument count.
    # GLSL scalar splats and constant expressions compile but can crash Iris.
    for name, constructor, value in re.findall(
        r"(?m)^\s*const\s+(?:ivec3|vec2)\s+(workGroups(?:Render)?)\s*=\s*(\w+)\s*\(([^;]*)\)\s*;",
        text,
    ):
        parts = [part.strip() for part in value.split(",")]
        if name == "workGroups":
            if constructor != "ivec3" or len(parts) != 3 or any(
                not re.fullmatch(r"[0-9]+", part) or int(part) <= 0 for part in parts
            ):
                raise ValueError(f"Iris requires three explicit positive integer workGroups components: {path}")
        elif constructor != "vec2" or len(parts) != 2 or any(
            not re.fullmatch(r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)", part) or float(part) <= 0
            for part in parts
        ):
            raise ValueError(f"Iris requires two explicit positive numeric workGroupsRender components: {path}")

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
    values = {"MC_VERSION": "12101", "HIZ_MODE": "1", "AO_RECONSTRUCTION": "1", "PROJECTION_JITTER": "0", "VOXEL_FUSION": "1", "ATMO_PREBAKED": "1", "ATMO_UPDATE_MODE": "1", "CLOUD_DENSITY_CACHE": "1", "CLOUD_NOISE_MODE": "1", "VOLUME_RECONSTRUCTION": "1", "GI_REUSE_MODE": "1", "AA_MODE": "2", "SCENE_TAAU_SCALE": "100", "GEOMETRY_TAAU_SCALE": "100", "RAIN_GEOMETRY":"1", "VOXEL_DIFFUSE_SMOOTHING":"1", "RAIN_RISE_TIME":"20.0", "RAIN_FALL_TIME":"40.0", **(defines if isinstance(defines, dict) else dict.fromkeys(defines, "1"))}
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


def check_modern_properties(compiler, path):
    base = dict.fromkeys((*VOXEL_FEATURES, "VOXEL_LIGHTING", "INCREMENTAL_VOXELS",
                         "PHYSICAL_ATMOSPHERE", "VOLUME_EFFECTS", "DEFERRED_LIGHTING",
                         "ADVANCED_WATER", "SCREEN_GI", "MATERIAL_SSR", "IRIS_FEATURE_SSBO"), "1")
    for minecraft, iris, ssbo, indirect in (
        ("12001", "10700", True, False),
        ("12101", "10808", True, False),
        ("260300", "11106", True, False),
        ("260300", "11107", False, False),
        ("260300", "11107", True, True),
    ):
        flags = {**base, "MC_VERSION": minecraft, "IRIS_VERSION": iris, "VOXEL_GRID_SIZE": "96"}
        if not ssbo:
            flags.pop("IRIS_FEATURE_SSBO")
        config = preprocess_properties(compiler, path, flags)
        if ("indirect.prepare1" in config) != indirect or ("bufferObject.0" in config) != indirect:
            raise ValueError(f"Incorrect indirect dispatch capability gate: {minecraft}/{iris}/{ssbo}")
        if config.get("allowConcurrentCompute") != "false":
            raise ValueError("Dependent compute dispatch must be serial")
        if config.get("program.world1/begin1.enabled") != "false":
            raise ValueError("End must not update Overworld sky LUT")
        if len([key for key in config if key.startswith("image.")]) != 14:
            raise ValueError("Fused custom image allocation must equal 14")
    # Full feature path, plus the 16-image legacy propagation fallback.
    flags={**base,"SCREEN_GI_SPATIAL":"1","SCREEN_GI_HISTORY":"1","TEMPORAL_REUSE":"1",
           "PROJECTION_JITTER":"1","VOLUME_TEMPORAL":"1","VOLUME_RECONSTRUCTION":"1",
           "AA_MODE":"2","GI_REUSE_MODE":"1","VOXEL_FUSION":"1","VOXEL_GRID_SIZE":"128"}
    config=preprocess_properties(compiler,path,flags)
    if len([k for k in config if k.startswith("image.")])!=15 or "image.lwVolumeHistory" not in config:
        raise ValueError("Volume history allocation must fit fused image budget")
    for overrides,count,history,cache in (
        ({"VOXEL_FUSION":"0"},16,True,True),
        ({"ATMO_PREBAKED":"0"},16,True,True),
        ({"VOXEL_FUSION":"0","ATMO_PREBAKED":"0"},16,False,False),
        ({"GI_REUSE_MODE":"2"},14,False,True),
        ({"PROJECTION_JITTER":"2"},14,False,True),
        ({"VOLUME_TEMPORAL":"0"},14,False,True),
    ):
        config=preprocess_properties(compiler,path,{**flags,**overrides})
        if (len([k for k in config if k.startswith("image.")])!=count or
            ("image.lwVolumeHistory" in config)!=history or
            ("image.lwAtmoState" in config)!=cache):
            raise ValueError(f"Volume/atmosphere image budget violated: {overrides}")
    # Exposure must not displace an existing GI/voxel image when the loader has
    # reached its 16-image ceiling. Check real preprocessed declarations.
    for overrides, expected, half in (
        ({}, True, True),
        ({"VOXEL_FUSION":"0"}, False, True),
        ({"ATMO_PREBAKED":"0"}, False, True),
        ({"VOXEL_FUSION":"0","ATMO_PREBAKED":"0"}, False, True),
        ({"GI_REUSE_MODE":"2","VOXEL_GI":"1"}, True, False),
        ({"GI_REUSE_MODE":"1","VOXEL_GI":"1"}, True, True),
    ):
        config=preprocess_properties(compiler,path,{**flags,"AUTO_EXPOSURE":"1","DOF_MODE":"1",**overrides})
        if len([k for k in config if k.startswith("image.")])>16 or ("image.lwExposureState" in config)!=expected:
            raise ValueError(f"Exposure image budget violated: {overrides}")
        if (config.get("program.world0/composite5.enabled")!="false")!=half:
            raise ValueError(f"DOF and persistent GI overlap: {overrides}")
        if overrides.get("VOXEL_GI")=="1" and config.get("program.world-1/composite5.enabled")!="false":
            raise ValueError(f"DOF overwrites Nether GI history: {overrides}")
    for size in (32,64,96,128):
        config=preprocess_properties(compiler,path,{**flags,"SMOOTH_LIGHTING":"1","VOXEL_GRID_SIZE":str(size)})
        if config["image.lwVoxelFirst"].split()[-3:]!=[str(size),str(size),str(2*size+3)]:
            raise ValueError("Smoothed voxel slab dimensions incorrect")
        weather=preprocess_properties(compiler,path,{**flags,"SMOOTH_LIGHTING":"1","WET_SURFACES":"1","VOXEL_GRID_SIZE":str(size)})
        wet_only=preprocess_properties(compiler,path,{**flags,"WET_SURFACES":"1","VOXEL_GRID_SIZE":str(size)})
        if wet_only["image.lwVoxelFirst"].split()[-3:]!=[str(size),str(size),str(size+1)]:
            raise ValueError("Rain columns must not depend on lighting smoothing")
        if weather.get("program.world0/prepare7.enabled")=="false" or weather.get("program.world-1/prepare7.enabled")!="false":
            raise ValueError("Rain column stage dimension gate incorrect")
        diffuse=preprocess_properties(compiler,path,{**flags,"SMOOTH_LIGHTING":"1","VOXEL_GRID_SIZE":str(size),"VOXEL_GI":"1"})
        if diffuse["image.lwVoxelSecond"].split()[-3:]!=[str(size),str(size),str(2*size)]:
            raise ValueError("Diffuse temporal slab dimensions incorrect")
        if len([k for k in diffuse if k.startswith("image.")])>16:
            raise ValueError("Diffuse slab exceeded custom image budget")
        if config.get("program.world0/prepare8.enabled")=="false":
            raise ValueError("Smoothed voxel occupancy expansion disabled")
        if len([k for k in config if k.startswith("image.")])>16:
            raise ValueError("Smoothed voxel image budget exceeded")
    for mode in (0,1,2):
        config=preprocess_properties(compiler,path,{**flags,"SSR_HALF_RES":"1","GI_REUSE_MODE":str(mode),"PROJECTION_JITTER":"1"})
        for dimension in DIMENSIONS:
            allowed=mode==0 or (mode==1 and dimension=="world0")
            if (config.get(f"program.{dimension}/deferred2_a.enabled")!="false")!=allowed:
                raise ValueError("Rough reflection prepass overwrites raw GI history")
    for scale in (50,67,75,85,100):
        for aa in (1,2):
            config=preprocess_properties(compiler,path,{"SCENE_TAAU_SCALE":str(scale),"AA_MODE":str(aa),"DEFERRED_LIGHTING":"1"})
            for dimension in DIMENSIONS:
                expected=scale<100 and aa>=2
                if (config.get(f"program.{dimension}/composite.enabled")=="true")!=expected:
                    raise ValueError("Scene TAAU composition gate incorrect")
    for scale in (50,67,75,85,100):
        config=preprocess_properties(compiler,path,{"GEOMETRY_TAAU_SCALE":str(scale),"AA_MODE":"2","DEFERRED_LIGHTING":"1"})
        if ("uniform.int.lwRasterFrame" in config)!=(scale<100):
            raise ValueError("Geometry raster frame uniform gate incorrect")
    for mode in (0,1,2):
        geometry=preprocess_properties(compiler,path,{**flags,"GEOMETRY_TAAU_SCALE":"75","PROJECTION_JITTER":str(mode),"GI_REUSE_MODE":"2","VOXEL_GI":"1","DOF_MODE":"1","AUTO_EXPOSURE":"1"})
        if geometry.get("program.world0/composite5.enabled")!="false":
            raise ValueError("Geometry mode must preserve persistent raw block GI")
        if geometry.get("program.world0/deferred2_a.enabled")!="false":
            raise ValueError("Geometry mode must preserve persistent raw sky GI")
    print("Modern/legacy compute, exposure and volume history capability matrix: OK")


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
    marker = DIMENSION_DEFINES.get(source.parent.name)
    if marker and not re.search(rf"(?m)^#define {marker}(?:\s|$)",body):
        macros += f"#define {marker}\n"
    if "LW_TEST_LEGACY_IRIS" in environment:
        macros += "#define MC_VERSION 12001\n"
    elif "LW_TEST_MODERN_IRIS" not in environment:
        macros += "#define MC_VERSION 12101\n"
    if "LW_TEST_MODERN_IRIS" in environment:
        macros += "#define IRIS_VERSION 11107\n#define MC_VERSION 260300\n"
    if "DISTANT_HORIZONS" in environment and source.name == "dh_shadow.vsh":
        # Iris injects this attribute and mini-ID. Offline compile needs a declaration.
        macros += "#define DH_BLOCK_WATER 1\nin int dhMaterialId;\n"
    return version + newline + macros + body


def check_projection_sampling(compiler, profiles):
    # Inspect the actual preprocessed entry points, not only shader option declarations.
    cases = (
        ("Medium auto", "Medium", "0", True),
        ("High auto", "High", "0", True),
        ("Ultra auto", "Ultra", "0", False),
        ("Extreme auto", "Extreme", "0", False),
        ("Ultra dynamic override", "Ultra", "2", True),
        ("High fixed override", "High", "1", False),
        ("Medium fixed default", "Medium", "1", False),
        ("Ultra fixed default", "Ultra", "1", False),
        ("Extreme fixed default", "Extreme", "1", False),
        ("Extreme dynamic override", "Extreme", "2", True),
    )
    stages = ("gbuffers_terrain.vsh", "gbuffers_water.vsh", "dh_terrain.vsh",
              "dh_water.vsh", "deferred1.fsh", "composite1.fsh")
    for label, profile, mode, dynamic in cases:
        options = {**profiles[f"profile.{profile}"], "PROJECTION_JITTER": mode, "GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"100"}
        for dimension, stage in product(DIMENSIONS, stages):
            path = PREVIEW / dimension / stage
            shader = compiler_source(PREVIEW, path, options, (*VOXEL_FEATURES, "DISTANT_HORIZONS"))
            with TemporaryDirectory(prefix="lumenweave-projection-") as directory:
                target = Path(directory) / ("sampling" + STAGES[path.suffix])
                target.write_text(shader, encoding="utf-8")
                result = subprocess.run([compiler, "-E", str(target)], capture_output=True, text=True)
            if result.returncode:
                raise ValueError(f"{label}/{dimension}/{stage}: {result.stderr}")
            function = re.search(r"vec2\s+jitterOffset\s*\([^)]*\)\s*\{([^}]+)\}", result.stdout)
            if not function:
                raise ValueError(f"Missing jitter contract: {label}/{dimension}/{stage}")
            body = function.group(1)
            zero = bool(re.search(r"return\s+vec2\s*\(\s*0\.0\s*\)\s*;", body))
            if zero == dynamic or ("sequence" in body) != dynamic:
                raise ValueError(f"Projection sampling mismatch: {label}/{dimension}/{stage}")
            if stage == "composite1.fsh":
                if "colorHistory" not in result.stdout or "temporalColor" not in result.stdout:
                    raise ValueError(f"Temporal resolve was unexpectedly removed: {label}/{dimension}")
                stable_path = not dynamic or profile in ("Ultra", "Extreme")
                spatial_shift = bool(re.search(r"stableUv\s*\+\s*jitterOffset\s*\(",result.stdout))
                if spatial_shift == stable_path:
                    raise ValueError(f"Current radiance grid mismatch: {label}/{dimension}")
    for scale,mode,dimension,stage in product(("50","67","75","85"),("1","2"),DIMENSIONS,stages):
        path=PREVIEW/dimension/stage
        options={**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":scale,"PROJECTION_JITTER":mode}
        shader=compiler_source(PREVIEW,path,options,(*VOXEL_FEATURES,"DISTANT_HORIZONS"))
        with TemporaryDirectory(prefix="lumenweave-geometry-") as directory:
            target=Path(directory)/("geometry"+STAGES[path.suffix])
            target.write_text(shader,encoding="utf-8")
            result=subprocess.run([compiler,"-E",str(target)],capture_output=True,text=True)
        if result.returncode or "lwGeometryJitter" not in result.stdout:
            raise ValueError(f"Geometry jitter contract: {scale}/{dimension}/{stage}: {result.stderr}")
        function=re.search(r"vec2\s+lwGeometryJitter\s*\([^)]*\)\s*\{([^}]+)\}",result.stdout)
        if not function or (("sequence" in function.group(1))!=(mode=="2")):
            raise ValueError(f"Geometry fixed/dynamic sampling mismatch: {scale}/{mode}/{dimension}/{stage}")
        if stage.endswith(".vsh") and "lwRasterClip" not in result.stdout:
            raise ValueError(f"Missing scaled geometry viewport: {dimension}/{stage}")
        if stage=="composite1.fsh" and "lwRasterSize" not in result.stdout:
            raise ValueError("Missing active raster reconstruction")
    print(f"Projection sampling: {len(cases) * len(DIMENSIONS) * len(stages)} native entry points and 144 geometry entry points OK")


def compile_shard(root, name, program, environment, count):
    """Stable partition of complete vertex/fragment links and compute programs."""
    key = "\\0".join((root.name, name, program.relative_to(root).as_posix(), *sorted(environment)))
    return int.from_bytes(sha256(key.encode("utf-8")).digest()[:8], "big") % count


def compile_pack(compiler, root, profiles, sources=None, environment=(), *, shard_index=0, shard_count=1):
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
                if compile_shard(root, name, program, environment, shard_count) != shard_index:
                    continue
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
    parser.add_argument("--v4-focused", action="store_true", help="Compile the changed V4 program families across feature paths")
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--shard-count", type=int, default=1)
    args = parser.parse_args()
    if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
        parser.error("invalid compile shard index/count")
    if args.v4_focused and args.shard_count != 1:
        parser.error("focused validation must run unsharded")
    compile_matrix = partial(compile_pack, shard_index=args.shard_index, shard_count=args.shard_count)
    if not args.compiler:
        parser.error("install glslang or supply --compiler")
    try:
        profiles = preview_profiles(PREVIEW)
        if args.v4_focused:
            check_modern_properties(args.compiler, PREVIEW / "shaders.properties")
            names = {"prepare5","prepare6","prepare6_a","prepare7","prepare8","deferred","deferred_a","deferred1","deferred2","deferred2_a","composite","composite_a","composite_b","composite1","composite2","composite3","composite4","composite5","final","gbuffers_terrain","gbuffers_water","gbuffers_weather","dh_terrain","dh_water"}
            sources = [p for p in PREVIEW.rglob("*") if p.suffix in STAGES and p.stem in names]
            variants = {
                "v5-geometry-dynamic": {**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":"75","PROJECTION_JITTER":"2"},
                "v5-native": {**profiles["profile.Ultra"],"GEOMETRY_TAAU_SCALE":"100"},
                "v5-geometry-half": {**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":"50","DOF_MODE":"2","MOTION_BLUR":"true"},
                "v5-geometry-full-hiz": {**profiles["profile.Ultra"],"GEOMETRY_TAAU_SCALE":"67","HIZ_MODE":"2","GI_REUSE_MODE":"2"},
                "v5-geometry-default": profiles["profile.Extreme"],
                "v5-geometry-wet-no-smooth": {**profiles["profile.Ultra"],"SMOOTH_LIGHTING":"false"},
                "v5-geometry-wet-off": {**profiles["profile.Ultra"],"RAIN_GEOMETRY":"0"},
                "v5-geometry-no-diffuse-history": {**profiles["profile.Extreme"],"VOXEL_DIFFUSE_SMOOTHING":"0"},
                "v4-taau-diffuse": {**profiles["profile.Extreme"], "GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"75", "DOF_MODE":"1"},
                "v4-taau-wet-no-smooth": {**profiles["profile.Ultra"], "GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"67", "SMOOTH_LIGHTING":"false"},
                "v4-taau-dynamic": {**profiles["profile.High"], "GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"85", "PROJECTION_JITTER":"2", "MOTION_BLUR":"true"},
                "v4-taau-history": {**profiles["profile.Extreme"], "GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"50", "GI_REUSE_MODE":"2", "DOF_MODE":"3"},
            }
            compile_matrix(args.compiler, PREVIEW, variants, sources=sources, environment=(*VOXEL_FEATURES,"DISTANT_HORIZONS","MC_TEXTURE_FORMAT_LAB_PBR_1_3"))
            compile_matrix(args.compiler, PREVIEW, {"v4-fallback":profiles["profile.High"]}, sources=sources)
            compile_matrix(args.compiler,TAAU_PROBE,{f"taau-{scale}":{"TAAU_SCALE":scale} for scale in ("0.5","0.67","0.75","0.85","1.0")})
            print("Focused V4 capability and shader matrix: OK")
            return
        if args.shard_index == 0:
            check_voxel_properties(args.compiler, PREVIEW / "shaders.properties")
            check_modern_properties(args.compiler, PREVIEW / "shaders.properties")
            check_voxel_dispatch(args.compiler)
            check_projection_sampling(args.compiler, profiles)
            print("Shadow and voxel capability matrix: 384 configurations OK")
            print("Voxel dispatch: 84 dimension/stage/size combinations OK")
        profiles["color-chart"] = {**profiles["profile.Natural"], "SHOW_COLOR_CHART": "true"}
        profiles["temporal"] = {**profiles["profile.Standard"], "AA_MODE": "2"}
        profiles["volume"] = {**profiles["temporal"], "VOLUME_EFFECTS": "true"}
        profiles["ultra-no-volume"] = {**profiles["profile.Ultra"], "VOLUME_EFFECTS": "false"}
        profiles["ultra-no-history"] = {**profiles["profile.Ultra"], "SCREEN_GI_HISTORY": "false"}
        profiles["ultra-no-spatial"] = {**profiles["profile.Ultra"], "SCREEN_GI_SPATIAL": "false"}
        profiles["ultra-dynamic-projection"] = {**profiles["profile.Ultra"], "PROJECTION_JITTER": "2", "GEOMETRY_TAAU_SCALE":"100"}
        profiles["ultra-legacy-voxel"] = {**profiles["profile.Ultra"], "VOXEL_FUSION": "0"}
        profiles["cinematic-auto"] = {**profiles["profile.High"], "DOF_MODE": "1", "LENS_GHOSTS": "true", "LENS_STAR": "true"}
        profiles["cinematic-manual"] = {**profiles["profile.Ultra"], "DOF_MODE": "2", "SOLAR_GLARE": "true"}
        profiles["water-phase-experiment"] = {**profiles["profile.High"], "WATER_PHASE_LUT": "1"}
        profiles["sky-original-grid"] = {**profiles["profile.Ultra"], "SKY_ENV_REUSE": "0", "BRDF_REUSE": "0"}
        profiles["cloud-cache-off"] = {**profiles["profile.Ultra"], "CLOUD_DENSITY_CACHE": "0", "CLOUD_OPTICAL_CACHE": "0"}
        profiles["medium-volume-no-gi"] = {**profiles["profile.Medium"], "VOLUME_EFFECTS": "true"}
        profiles["legacy-atmo-and-voxel"] = {**profiles["profile.Ultra"], "ATMO_PREBAKED": "0", "VOXEL_FUSION": "0"}
        profiles["end-procedural"] = {**profiles["profile.Natural"], "END_NEBULA_ASSET": "0"}
        profiles["atmosphere-original"] = {**profiles["profile.Ultra"], "ATMO_PREBAKED": "0", "ATMO_UPDATE_MODE": "0"}
        profiles["volume-history-off"] = {**profiles["profile.Ultra"], "VOLUME_TEMPORAL": "0", "LOCAL_SCATTER_ADAPTIVE": "0"}
        profiles["legacy-volume-budget"] = {**profiles["profile.Ultra"], "SCENE_BUDGET": "0", "CLOUD_NOISE_MODE": "0", "CLOUD_ADAPTIVE": "0", "CLOUD_EMPTY_SKIP": "0", "SHAFT_ADAPTIVE": "0", "CLOUD_LIGHT_REUSE": "0"}
        profiles["dimension-performance"] = {**profiles["profile.Ultra"], "OVERWORLD_BUDGET": "2", "NETHER_BUDGET": "2", "END_BUDGET": "2"}
        profiles["dimension-full"] = {**profiles["profile.Ultra"], "OVERWORLD_BUDGET": "0", "NETHER_BUDGET": "0", "END_BUDGET": "0"}
        profiles["ultra-original-hdr"] = {**profiles["profile.Ultra"], "HDR_REUSE": "0", "VOLUME_RECONSTRUCTION": "0"}
        profiles["ultra-full-ao"] = {**profiles["profile.Ultra"], "AO_RECONSTRUCTION": "0"}
        profiles["high-fixed-projection"] = {**profiles["profile.High"], "PROJECTION_JITTER": "1", "GEOMETRY_TAAU_SCALE":"100"}
        profiles["screen-gi"] = {**profiles["profile.Standard"], "SCREEN_AO": "false", "SCREEN_GI": "true"}
        profiles["screen-gi-history-no-taa-water"] = {
            **profiles["screen-gi"], "SCREEN_GI_HISTORY": "true", "ADVANCED_WATER": "false"
        }
        profiles["screen-gi-spatial"] = {**profiles["screen-gi"], "SCREEN_GI_SPATIAL": "true"}
        profiles["post-camera-bloom"] = {
            **profiles["profile.High"], "AA_MODE": "3", "MOTION_BLUR": "true",
            "BLOOM": "true", "IMAGE_SHARPENING": "0.3", "COLOR_CONTRAST": "1.05",
        }
        profiles["bloom-wide"] = {**profiles["profile.High"], "BLOOM": "true", "BLOOM_FILTER": "2"}
        profiles["forward-post"] = {
            **profiles["profile.Low"], "AA_MODE": "2", "MOTION_BLUR": "true", "BLOOM": "true",
            "WAVING_LEAVES": "false", "WAVING_GRASS": "false",
        }
        profiles["no-aa-no-wind"] = {
            **profiles["profile.High"], "AA_MODE": "0",
            "WAVING_LEAVES": "false", "WAVING_GRASS": "false", "WATER_REFLECTION_STEPS": "0",
        }
        compile_matrix(args.compiler, PREVIEW, profiles)
        scene_entries=[p for p in PREVIEW.rglob("*") if p.suffix in STAGES and p.stem in ("composite","composite1","composite2","composite3","composite4","composite5","final")]
        compile_matrix(args.compiler,PREVIEW,{"scene-taau-ultra":{**profiles["profile.Ultra"],"GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"75"},"scene-taau-extreme":{**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"50","DOF_MODE":"1"},"scene-taau-dynamic":{**profiles["profile.High"],"GEOMETRY_TAAU_SCALE":"100", "SCENE_TAAU_SCALE":"67","PROJECTION_JITTER":"2","MOTION_BLUR":"true"}},sources=scene_entries,environment=(*VOXEL_FEATURES,"DISTANT_HORIZONS"))
        camera_entries=[p for p in PREVIEW.rglob("*") if p.suffix in STAGES and p.stem in ("final","composite3","composite4","composite5","deferred2","deferred2_a","prepare6","prepare6_a","prepare8")]
        compile_matrix(args.compiler,PREVIEW,{"camera-ultra":{**profiles["profile.Ultra"],"DOF_MODE":"1"},"camera-extreme-history":{**profiles["profile.Extreme"],"DOF_MODE":"3","GI_REUSE_MODE":"2"}},sources=camera_entries,environment=(*VOXEL_FEATURES,"DISTANT_HORIZONS","MC_TEXTURE_FORMAT_LAB_PBR_1_3"))
        compile_matrix(
            args.compiler, PREVIEW, {"lab-pbr": profiles["profile.Standard"]},
            environment=("MC_TEXTURE_FORMAT_LAB_PBR", "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        voxel_profiles = {
            "world-voxels": {**profiles["profile.Standard"], "VOXEL_LIGHTING": "true"},
            "world-voxels-no-shadow-filter": {**profiles["profile.Natural"], "VOXEL_LIGHTING": "true"},
            "world-local-scatter-full-rebuild": {**profiles["profile.High"], "VOXEL_LIGHTING": "true", "VOLUME_EFFECTS": "true", "INCREMENTAL_VOXELS": "false"},
        }
        compile_matrix(args.compiler, PREVIEW, voxel_profiles, environment=VOXEL_FEATURES)
        compile_matrix(
            args.compiler, PREVIEW,
            {"ultra-voxel": profiles["profile.Ultra"], "extreme-gi": profiles["profile.Extreme"]},
            environment=(*VOXEL_FEATURES, "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        compile_matrix(
            args.compiler, PREVIEW,
            {"grid-64": {**profiles["profile.Extreme"], "VOXEL_GRID_SIZE": "64"}},
            environment=VOXEL_FEATURES,
        )
        compile_matrix(
            args.compiler, PREVIEW, {name: profiles[f"profile.{name}"] for name in ("Medium", "High", "Ultra", "Extreme")},
            environment=(*VOXEL_FEATURES, "DISTANT_HORIZONS"),
        )
        compile_matrix(
            args.compiler, PREVIEW,
            {"extreme-spatial": {**profiles["profile.Extreme"], "SCREEN_GI_SPATIAL": "true"}},
            environment=(*VOXEL_FEATURES, "MC_TEXTURE_FORMAT_LAB_PBR_1_3"),
        )
        compile_matrix(args.compiler, PREVIEW, {"world-voxels-fallback": voxel_profiles["world-voxels"]})
        volume_entries=[p for p in PREVIEW.rglob("*") if p.suffix in STAGES and p.stem in ("deferred","deferred1","composite","composite_a","composite_b","setup","setup1","setup3","setup4","begin1","begin2","begin3","begin4","begin5")]
        compile_matrix(args.compiler, PREVIEW, {"medium-volume-no-gi":profiles["medium-volume-no-gi"],"atmosphere-original":profiles["atmosphere-original"],"cloud-cache-off":profiles["cloud-cache-off"],"sky-original-grid":profiles["sky-original-grid"],"legacy-atmo-and-voxel":profiles["legacy-atmo-and-voxel"]},sources=volume_entries,environment=VOXEL_FEATURES)
        compile_matrix(args.compiler, PREVIEW, {"extreme-volume-hardware":profiles["profile.Extreme"]},sources=volume_entries,
            environment=(*VOXEL_FEATURES,"DISTANT_HORIZONS","IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS"))
        compile_matrix(args.compiler, PREVIEW, {"modern-compaction": profiles["profile.Ultra"]},
            environment=(*VOXEL_FEATURES,"IRIS_FEATURE_SSBO","LW_TEST_MODERN_IRIS"))
        compile_matrix(args.compiler, PREVIEW, {"hybrid-shadow": profiles["profile.High"], "hybrid-hard": profiles["profile.Medium"]}, environment=("IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS",))
        compile_matrix(args.compiler, PREVIEW, {"full-hiz": {**profiles["profile.Ultra"], "HIZ_MODE": "2"}},
            environment=VOXEL_FEATURES)
        compile_matrix(args.compiler, PREVIEW, {"adaptive-off": {**profiles["profile.Ultra"], "ADAPTIVE_SHADING": "false", "TEMPORAL_REUSE": "false", "ADAPTIVE_SHADOWS": "false"}},
            environment=VOXEL_FEATURES)
        compile_matrix(args.compiler, PREVIEW, {"legacy-1.20": profiles["profile.High"]},
            environment=("LW_TEST_LEGACY_IRIS",))

        compile_matrix(args.compiler, PREVIEW, {
            "research-ssr": {**profiles["profile.High"], "MATERIAL_SSR": "true"},
            "research-ssr-gi": {**profiles["profile.Extreme"], "MATERIAL_SSR": "true", "DH_SHADOWS": "true", "PHYSICAL_ATMOSPHERE": "true", "INCREMENTAL_VOXELS": "true"},
            "research-atmosphere": {**profiles["profile.High"], "PHYSICAL_ATMOSPHERE": "true"},
            "research-incremental": {**profiles["profile.Ultra"], "INCREMENTAL_VOXELS": "true"},
            "research-dynamic-all": {**profiles["profile.Extreme"], "GEOMETRY_TAAU_SCALE":"100", "PROJECTION_JITTER": "2", "MATERIAL_SSR": "true", "DH_SHADOWS": "true", "PHYSICAL_ATMOSPHERE": "true", "INCREMENTAL_VOXELS": "true"},
        }, environment=(*VOXEL_FEATURES, "DISTANT_HORIZONS", "MC_TEXTURE_FORMAT_LAB_PBR_1_3"))
        compile_matrix(
            args.compiler, PREVIEW, preview_profiles(PREVIEW, P0_CONFIG),
            [PREVIEW / name for name in P0_SHARED],
        )
        properties(PROBE / "shaders.properties")
        compile_matrix(args.compiler, PROBE, {"voxel-probe": {}})
        compile_matrix(args.compiler,TAAU_PROBE,{f"taau-{scale}":{"TAAU_SCALE":scale} for scale in ("0.5","0.67","0.75","0.85","1.0")})
        if args.shard_index == 0:
            for source in sorted((PREVIEW.parent / "experiments" / "voxel_compaction").glob("*.comp")):
                result = subprocess.run([args.compiler, "-S", "comp", str(source)], capture_output=True, text=True)
                if result.returncode:
                    raise ValueError(f"{source}: {result.stdout}{result.stderr}")
                print(f"compaction-probe/{source.name}: OK")
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
