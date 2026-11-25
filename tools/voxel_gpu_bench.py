#!/usr/bin/env python3
"""Run the voxel kernels on a desktop GPU using existing LWJGL 3.3.3 JARs."""

import argparse
import os
import re
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from check_shaders import VOXEL_DIFFUSE_PASS, VOXEL_PASSES, compiler_source, expand, preview_profiles
from package import PREVIEW, PROBE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="java", help="Java 21 executable")
    parser.add_argument(
        "--lwjgl", type=Path, required=True, help="Libraries org/lwjgl directory"
    )
    parser.add_argument("--natives", default="windows" if os.name == "nt" else "linux")
    parser.add_argument("--world", action="store_true", help="Run the P4 terrain voxel kernels")
    parser.add_argument("--grid-size", type=int, choices=(32, 64, 96, 128), default=32)
    args = parser.parse_args()
    if args.grid_size != 32 and not args.world:
        parser.error("--grid-size requires --world")
    version = "3.3.3"
    jars = []
    for module in ("lwjgl", "lwjgl-glfw", "lwjgl-opengl"):
        for classifier in ("", f"-natives-{args.natives}"):
            jar = args.lwjgl / module / version / f"{module}-{version}{classifier}.jar"
            if not jar.is_file():
                parser.error(f"missing {jar}")
            jars.append(str(jar.resolve()))
    with TemporaryDirectory(prefix="lumenweave-voxel-") as directory:
        root = PREVIEW if args.world else PROBE
        sources = (
            [*(root / "world0" / f"{name}.csh" for name in (*VOXEL_PASSES, VOXEL_DIFFUSE_PASS)),
             root / "lib/voxel/inject.glsl"]
            if args.world else sorted(root.glob("*.csh"))
        )
        for shader in sources:
            source = (
                compiler_source(root, shader, {"VOXEL_GRID_SIZE": str(args.grid_size)}, ())
                if args.world else expand(root, shader)
            )
            (Path(directory) / shader.name).write_text(
                source, encoding="utf-8"
            )
        if args.world:
            screen_gi = (
                "#version 430 core\n"
                "uniform sampler2D colortex0, colortex1, colortex2, depthtex0;\n"
                "uniform mat4 gbufferProjection;\n"
                + "".join(expand(root, root / f"lib/{library}.glsl") for library in (
                    "lighting/overworld", "materials/vanilla", "materials/geometry_buffer",
                    "coordinates/reconstruct", "lighting/screen_gi",
                ))
                + """
layout(local_size_x = 4) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 bounce[4]; };
void main() {
    uint column = gl_LocalInvocationID.x;
    vec3 origin = vec3(float(column) * 0.5 - 0.75, 0.0, -2.2);
    bounce[column] = vec4(screenBounceRay(origin, vec3(0.0, 0.0, -1.0),
        mat3(1.0), vec3(0.0, 1.0, 0.0)).sky, 0.0);
}
"""
            )
            (Path(directory) / "screen-gi.csh").write_text(screen_gi, encoding="utf-8")
            gi_history = (
                "#version 430 core\nuniform mat4 gbufferModelViewInverse;\n"
                + expand(root, root / "lib/materials/geometry_buffer.glsl")
                + expand(root, root / "lib/temporal/screen_gi_history.glsl")
                + """
layout(local_size_x = 9) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 filtered[9]; };
void main() {
    uint test = gl_LocalInvocationID.x;
    if (test == 8u) {
        mat4 projection = mat4(1.0);
        projection[0][0] = 0.5;
        vec2 previousUv;
        float expectedDepth;
        bool valid = reprojectTerrain(vec3(0.5, 0.0, -2.0), previousUv, expectedDepth, projection);
        filtered[test] = vec4(previousUv, expectedDepth, valid ? 1.0 : 0.0);
        return;
    }
    vec3 position = vec3(0.0, 0.0, -2.0);
    vec3 normal = vec3(0.0, 0.0, 1.0);
    vec3 current = vec3(0.1);
    if (test == 1u) position.x = 0.5;
    if (test == 2u) position.z = -5.0;
    if (test == 3u) normal.z = -1.0;
    if (test == 4u) current = vec3(0.01);
    if (test == 5u) current = vec3(0.0, 0.1, 0.0);
    if (test == 6u) position.x = 1.1;
    if (test == 7u) position.xy = vec2(-0.5, 0.5);
    filtered[test] = vec4(temporalScreenBounce(current, position, normal, vec2(0.5)), 1.0);
}
"""
            )
            (Path(directory) / "screen-gi-history.csh").write_text(gi_history, encoding="utf-8")
            gi_spatial = (
                """#version 430 core
#define LW_VOXEL_DIFFUSE_ACTIVE
uniform sampler2D colortex1;
struct ScreenBounce { vec3 sky; vec3 block; float blockConfidence; };
ScreenBounce screenDiffuseBounce(vec3 position, vec3 normal, vec3 sun) {
    return ScreenBounce(vec3(0.0, 0.0, 0.25), vec3(0.0), 0.0);
}
"""
                + expand(root, root / "lib/materials/geometry_buffer.glsl")
                + expand(root, root / "lib/lighting/screen_gi_spatial.glsl")
                + """
layout(local_size_x = 5) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 reconstructed[10]; };
void main() {
    uint sampleIndex = gl_LocalInvocationID.x;
    vec2 uv = vec2(0.5);
    if (sampleIndex == 1u) uv.x = 0.625;
    if (sampleIndex == 2u) uv = vec2(0.75, 0.25);
    if (sampleIndex == 3u) uv = vec2(0.25, 0.75);
    float depth = sampleIndex == 2u ? 4.0 : sampleIndex == 4u ? 30.0 : 2.0;
    vec3 normal = vec3(0.0, 0.0, sampleIndex == 3u ? -1.0 : 1.0);
    ScreenBounce bounce = spatialScreenBounce(vec3(0.0, 0.0, -depth), normal,
        vec3(0.0, 1.0, 0.0), uv);
    reconstructed[2u * sampleIndex] = vec4(bounce.sky, 0.0);
    reconstructed[2u * sampleIndex + 1u] = vec4(bounce.block, bounce.blockConfidence);
}
"""
            )
            (Path(directory) / "screen-gi-spatial.csh").write_text(gi_spatial, encoding="utf-8")
            taa_options = {**preview_profiles(root)["profile.Standard"], "TEMPORAL_AA": "true"}
            distant_taa = compiler_source(
                root, root / "world0/composite.fsh", taa_options, ("DISTANT_HORIZONS",)
            ).replace("#version 330 compatibility", "#version 430 core")
            distant_taa = re.sub(r"layout\(location = \d+\) out ", "", distant_taa)
            distant_taa = distant_taa.replace(
                "in vec2 texCoord;", "vec2 texCoord;\nvec4 sampleCoord;"
            ).replace("gl_FragCoord", "sampleCoord").replace("void main()", "void resolveTemporal()")
            distant_taa += """
layout(local_size_x = 4) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 resolvedHistory[4]; };
void main() {
    float column = float(gl_LocalInvocationID.x) + 0.5;
    sampleCoord = vec4(column, 0.5, 0.0, 1.0);
    texCoord = vec2(column / 4.0, 0.5);
    resolveTemporal();
    resolvedHistory[gl_LocalInvocationID.x] = colorHistory;
}
"""
            (Path(directory) / "distant-taa.csh").write_text(distant_taa, encoding="utf-8")
            history_filter = distant_taa[:distant_taa.index("layout(local_size_x = 4) in;")] + """
layout(local_size_x = 7) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 samples[7]; };
void main() {
    uint test = gl_LocalInvocationID.x;
    vec2 uv = vec2(test == 0u ? 0.25 : 0.5, 0.5);
    if (test == 4u || test == 5u) uv.x = 0.875;
    if (test == 6u) uv.x = -0.3;
    samples[test] = filteredHistory(uv, test == 2u ? 20.0 : test == 4u || test == 5u ? 200.0 : 2.0,
        test == 5u ? vec2(-1.0, 0.0) : vec2(0.0), test == 3u);
}
"""
            (Path(directory) / "taa-filter.csh").write_text(history_filter, encoding="utf-8")
            shadow_filter = (
                "#version 430 core\n#define SOFT_SHADOWS\n#define SHADOW_MAP 2048\n#define SHADOW_RANGE 128.0\n"
                + expand(root, root / "lib/lighting/overworld.glsl")
                + expand(root, root / "lib/lighting/lite_shadows.glsl")
                + """
layout(local_size_x = 4) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 samples[4]; };
void main() {
    uint test = gl_LocalInvocationID.x;
    float uv = test == 0u ? 0.125 : test == 1u ? 0.25 : test == 2u ? 0.375 : 0.0;
    samples[test] = vec4(filteredShadow(vec2(uv, 0.5), 0.5, textureSize(shadowtex0, 0)));
}
"""
            )
            (Path(directory) / "shadow-filter.csh").write_text(shadow_filter, encoding="utf-8")
            wave_test = "#version 430 core\n" + expand(root, root / "lib/water/waves.glsl") + """
layout(local_size_x = 4) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 samples[4]; };
void main() {
    uint test = gl_LocalInvocationID.x;
    vec2 position = vec2(2.37, -9.41);
    vec2 footprint = test == 2u ? vec2(100.0) : vec2(0.001);
    vec2 slope = waterWaveSlope(position, vec2(footprint.x, 0.0), vec2(0.0, footprint.y),
        test == 1u ? 0.01 : 0.0, test == 3u ? 100.0 : 0.016);
    samples[test] = vec4(slope, length(slope), 1.0);
}
"""
            (Path(directory) / "water-waves.csh").write_text(wave_test, encoding="utf-8")
            dimension_test = (
                "#version 430 core\n#define DISTANT_HORIZONS\n"
                + "".join(expand(root, root / f"lib/{library}.glsl") for library in (
                    "lighting/overworld", "lighting/surface", "lighting/fog", "atmosphere/volume",
                ))
                + """
layout(local_size_x = 11) in;
layout(std430, binding = 0) writeonly buffer Result { vec4 samples[11]; };
void main() {
    uint test = gl_LocalInvocationID.x;
    vec3 sun = vec3(0.0, 1.0, 0.0);
    vec3 scene = vec3(0.2, 0.3, 0.4);
    vec3 result;
    if (test == 0u) result = celestialIrradiance(sun);
    else if (test == 1u) result = celestialIrradiance(-sun);
    else if (test == 2u) result = ambientIrradiance(vec2(0.0), 1.0, sun);
    else if (test == 3u) result = ambientIrradiance(vec2(1.0, 0.0), 1.0, sun);
    else if (test == 4u) result = skyRadiance(vec3(0.0, 0.0, 1.0), sun);
    else if (test == 5u) result = skyRadiance(sun, sun);
    else if (test == 6u) result = applyCloudVolume(scene, vec3(0.0, 63.0, 0.0), sun, sun, 640.0);
    else if (test == 7u) result = applyLightShafts(scene, vec3(0.0, 63.0, 0.0), sun, sun, 640.0);
    else if (test == 8u) result = surfaceRadiance(vec3(0.5), vanillaMaterial(0, vec3(0.5)),
        sun, sun, sun, vec2(0.0, 1.0), vec3(0.0, -1.0, -3.0));
    else if (test == 9u) result = applySceneFog(scene, vec3(0.0, 0.0, -200.0));
    else result = sunDirection();
    samples[test] = vec4(result, 1.0);
}
"""
            )
            (Path(directory) / "dimension-lighting.csh").write_text(dimension_test, encoding="utf-8")
            spatial_aa = (
                "#version 430 core\n"
                + expand(root, root / "lib/color/scene.glsl")
                + expand(root, root / "lib/color/spatial_aa.glsl")
                + """
layout(local_size_x = 4, local_size_y = 4) in;
uniform sampler2D scene;
layout(std430, binding = 0) writeonly buffer Result { vec4 filtered[16]; };
void main() {
    ivec2 cell = ivec2(gl_LocalInvocationID.xy);
    vec2 uv = (vec2(cell) + 0.5) / vec2(textureSize(scene, 0));
    vec3 center = texelFetch(scene, cell, 0).rgb;
    filtered[cell.y * 4 + cell.x] = vec4(spatialAntialias(scene, uv, center, 0.0), 1.0);
}
"""
            )
            (Path(directory) / "spatial-aa.csh").write_text(spatial_aa, encoding="utf-8")
        command = [
            args.java,
            f"-Djava.io.tmpdir={directory}",
            f"-Dorg.lwjgl.system.SharedLibraryExtractPath={directory}",
            "-cp",
            os.pathsep.join(jars),
            str(Path(__file__).with_name("VoxelGpuBench.java")),
            directory,
        ]
        if args.world:
            command.extend(("--world", str(args.grid_size)))
        raise SystemExit(subprocess.run(command).returncode)


if __name__ == "__main__":
    main()
