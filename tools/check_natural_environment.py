"""Compile environment coupling, half-GI edges and deferred diagnostic variants."""

import argparse

from check_shaders import PREVIEW, STAGES, VOXEL_FEATURES, compile_pack, preview_profiles


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler",required=True)
    args=parser.parse_args()
    profiles=preview_profiles(PREVIEW)
    extreme={**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":"100"}
    cases={
        "environment-native":extreme,
        "environment-reference":{**extreme,"WEATHER_COUPLING":"0"},
        "environment-half-edges":{**extreme,"GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"1"},
        "environment-half-reference":{**extreme,"GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"0"},
        "environment-half-dynamic":{**extreme,"GI_HISTORY_MODE":"1","PROJECTION_JITTER":"2"},
        "environment-style-warm":{**profiles["profile.Low"],"COLOR_STYLE":"1"},
        "environment-style-muted":{**profiles["profile.Ultra"],"COLOR_STYLE":"2"},
    }
    stages={"deferred","deferred1","gbuffers_terrain","shadow","gbuffers_water",
            "dh_water","composite","composite_a","composite_b","begin4","begin5","final"}
    sources=[path for path in PREVIEW.rglob("*") if path.suffix in STAGES and path.stem in stages]
    compile_pack(args.compiler,PREVIEW,cases,sources=sources,
                 environment=(*VOXEL_FEATURES,"DISTANT_HORIZONS","MC_TEXTURE_FORMAT_LAB_PBR_1_3"))
    diagnostics={f"deferred-diagnostic-{mode}":{**extreme,"LW_DEFERRED_DIAGNOSTIC":str(mode)} for mode in range(1,9)}
    compile_pack(args.compiler,PREVIEW,diagnostics,
                 sources=[path for path in sources if path.stem=="deferred1"],
                 environment=VOXEL_FEATURES)
    compile_pack(args.compiler,PREVIEW,{"environment-lite":profiles["profile.Potato"],
                                       "environment-no-capabilities":extreme},sources=sources)


if __name__=="__main__":
    main()
