#!/usr/bin/env python3
"""Compile resource reuse layouts and their reference/fallback paths."""

import argparse

from check_shaders import PREVIEW, STAGES, VOXEL_FEATURES, compile_pack, preprocess_properties, preview_profiles


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", required=True)
    args = parser.parse_args()
    profiles = preview_profiles(PREVIEW)
    extreme = profiles["profile.Extreme"]
    cases = {
        "reuse-reference": {**extreme, "FRAME_LIGHTING_REUSE": "0", "SURFACE_REUSE": "0"},
        "reuse-exact": extreme,
        "reuse-half-native": {**extreme, "GI_HISTORY_MODE": "1", "GEOMETRY_TAAU_SCALE": "100"},
        "reuse-half-reduced": {**extreme, "GI_HISTORY_MODE": "1"},
        "reuse-half-raw-history": {**extreme, "GI_HISTORY_MODE": "1", "GI_REUSE_MODE": "2"},
        "reuse-half-no-ao": {**extreme, "GI_HISTORY_MODE": "1", "SCREEN_AO": "false"},
        "reuse-half-no-block": {**profiles["profile.Ultra"], "GI_HISTORY_MODE": "1"},
        "reuse-half-minimal": {
            **profiles["profile.High"], "GI_HISTORY_MODE": "1", "SCREEN_GI": "true",
            "SCREEN_GI_SPATIAL": "true", "SCREEN_GI_HISTORY": "true", "PROJECTION_JITTER": "0",
        },
        "reuse-half-dynamic-fallback": {
            **extreme, "GI_HISTORY_MODE": "1", "PROJECTION_JITTER": "2",
            "GEOMETRY_TAAU_SCALE": "100",
        },
    }
    for size in (32,64,96,128):
        cases[f"reuse-incremental-{size}"]={
            **extreme,"GI_HISTORY_MODE":"1","EXTENSION_VOXELS":"2","VOXEL_GRID_SIZE":str(size),
        }
    for name, options in cases.items():
        defines={key:("1" if value=="true" else value) for key,value in options.items() if value!="false"}
        config=preprocess_properties(args.compiler,PREVIEW/"shaders.properties",
                                     {**defines,**dict.fromkeys(VOXEL_FEATURES,"1")})
        expected=options.get("GI_HISTORY_MODE")=="1" and options.get("PROJECTION_JITTER")!="2"
        if ("size.buffer.colortex6" in config)!=expected or ("size.buffer.colortex7" in config)!=expected:
            raise ValueError(f"GI attachment layout mismatch: {name}")
        if sum(key.startswith("image.") for key in config)>16:
            raise ValueError(f"Image slot budget exceeded: {name}")
    names = {"deferred", "deferred1", "composite_b", "begin", "prepare", "shadow",
             "prepare1","prepare2","prepare3","prepare4","prepare5","prepare6","prepare7"}
    sources = [path for path in PREVIEW.rglob("*") if path.suffix in STAGES and path.stem in names]
    compile_pack(args.compiler, PREVIEW, cases, sources=sources,
                   environment=(*VOXEL_FEATURES, "DISTANT_HORIZONS", "MC_TEXTURE_FORMAT_LAB_PBR_1_3"))
    compile_pack(args.compiler,PREVIEW,{"reuse-no-capabilities":cases["reuse-incremental-32"]},
                 sources=sources)


if __name__ == "__main__":
    main()
