"""Compile near AO and half-GI reconstruction across raster and capability modes."""

import argparse

from check_shaders import PREVIEW, STAGES, VOXEL_FEATURES, compile_pack, preview_profiles


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler",required=True)
    args=parser.parse_args()
    profiles=preview_profiles(PREVIEW)
    extreme={**profiles["profile.Extreme"],"GEOMETRY_TAAU_SCALE":"100"}
    cases={
        "ao-reference":extreme,
        "ao-near-auto":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","PROJECTION_JITTER":"0"},
        "ao-near-fixed":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","PROJECTION_JITTER":"1"},
        "ao-near-dynamic":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","PROJECTION_JITTER":"2"},
        "ao-near-geometry":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GEOMETRY_TAAU_SCALE":"75"},
        "ao-near-no-gi":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","SCREEN_GI":"false"},
        "ao-near-no-taa":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","AA_MODE":"0"},
        "ao-near-disabled":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","AO_RECONSTRUCTION":"0"},
        "ao-gi-near-half":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"1"},
        "ao-gi-near-half-reference":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GI_HISTORY_MODE":"1"},
        "ao-gi-adaptive-support":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"2"},
        "ao-gi-support-no-cache":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"2","LOW_FREQ_CACHE":"0","APPROX_REUSE":"0"},
        "ao-gi-no-surface-cache":{**extreme,"AO_NEAR_RECONSTRUCTION":"1","GI_HISTORY_MODE":"1","GI_EDGE_RECONSTRUCTION":"2","SURFACE_REUSE":"0"},
        "ao-visual-reference":{**extreme,"LW_DEFERRED_DIAGNOSTIC":"9"},
        "ao-visual-near":{**extreme,"LW_DEFERRED_DIAGNOSTIC":"9","AO_NEAR_RECONSTRUCTION":"1"},
    }
    names={"deferred","deferred1","deferred2","composite","composite1"}
    sources=[path for path in PREVIEW.rglob("*") if path.suffix in STAGES and path.stem in names]
    compile_pack(args.compiler,PREVIEW,cases,sources=sources,
                 environment=(*VOXEL_FEATURES,"MC_TEXTURE_FORMAT_LAB_PBR_1_3","DISTANT_HORIZONS"))
    compile_pack(args.compiler,PREVIEW,{
        "ao-near-lite":{**profiles["profile.Potato"],"AO_NEAR_RECONSTRUCTION":"1"},
        "ao-near-unsupported":cases["ao-gi-near-half"],
    },sources=sources)


if __name__=="__main__":
    main()
