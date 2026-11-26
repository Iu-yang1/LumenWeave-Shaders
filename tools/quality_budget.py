#!/usr/bin/env python3
"""Estimate named shader texture payloads, not actual GPU memory or frame time."""

import argparse
import csv
import sys

from check_shaders import preview_profiles
from package import PREVIEW

MIB = 1024 ** 2
TIERS = ("Potato", "Low", "Medium", "High", "Ultra", "Extreme")
ATMO_BYTES = 8 * (128 * 32 + 32 * 16 + 128 * 64 + 2 * 32 * 32 * 16)


def resource_budget(options, width, height):
    def enabled(name):
        return options.get(name) == "true"

    if min(width, height) <= 0:
        raise ValueError("Positive framebuffer dimensions required")
    size = int(options["VOXEL_GRID_SIZE"])
    voxel_bytes = 20 * size ** 3 if enabled("VOXEL_LIGHTING") else 0
    if voxel_bytes and enabled("INCREMENTAL_VOXELS"):
        voxel_bytes += (18 if options.get("VOXEL_FUSION", "1") == "1" else 34) * size ** 3 + 128 * 32 * 32 + 16
    smooth_bytes=8*size**2*(size+2) if voxel_bytes and enabled("INCREMENTAL_VOXELS") and enabled("SMOOTH_LIGHTING") else 0
    voxel_bytes+=smooth_bytes
    legacy_full=bool(voxel_bytes and enabled("INCREMENTAL_VOXELS") and options.get("VOXEL_FUSION")=="0" and enabled("PHYSICAL_ATMOSPHERE") and options.get("ATMO_PREBAKED")=="0")
    atmo_bytes = (ATMO_BYTES+16*int(options.get("ATMO_UPDATE_MODE","1")=="1" and not legacy_full)) if enabled("PHYSICAL_ATMOSPHERE") else 0
    ssr = enabled("MATERIAL_SSR") and enabled("DEFERRED_LIGHTING") and enabled("ADVANCED_WATER") and not enabled("LITE_LIGHTING")
    taa = int(options["AA_MODE"]) >= 2 and enabled("DEFERRED_LIGHTING")
    jitter_mode = int(options.get("PROJECTION_JITTER", "0"))
    auto_dynamic = jitter_mode == 0 and not any(enabled(name) for name in ("VOLUME_EFFECTS", "SCREEN_GI", "VOXEL_LIGHTING"))
    advanced_dynamic = taa and (jitter_mode == 2 or auto_dynamic) and any(
        enabled(name) for name in ("VOLUME_EFFECTS", "SCREEN_GI", "VOXEL_LIGHTING", "MATERIAL_SSR", "PHYSICAL_ATMOSPHERE")
    )
    # colortex12/13 plus optional history 14/15; ownership colortex3.
    # Report a single texture payload and double-buffered equivalent separately.
    extra_color_bytes = width * height * ((12 + 16 * int(taa)) * int(ssr) + 8 * int(advanced_dynamic))
    hiz_mode = int(options.get("HIZ_MODE", "1"))
    hiz_bytes = int(width*(.035 if hiz_mode == 1 else .30))*int(height*(.035 if hiz_mode == 1 else .35))*8 if hiz_mode > 0 and enabled("DEFERRED_LIGHTING") and (enabled("SCREEN_GI") or ssr or (hiz_mode == 2 and enabled("ADVANCED_WATER"))) else 0
    volume_noise=1024**2 if enabled("VOLUME_EFFECTS") and options.get("CLOUD_NOISE_MODE")=="1" else 0
    volume_history=8*int(width*1.5)*height if enabled("VOLUME_EFFECTS") and taa and jitter_mode==1 and options.get("VOLUME_RECONSTRUCTION")=="1" and options.get("VOLUME_TEMPORAL")=="1" and not (enabled("TEMPORAL_REUSE") and enabled("SCREEN_GI") and enabled("SCREEN_GI_SPATIAL") and enabled("SCREEN_GI_HISTORY") and options.get("GI_REUSE_MODE")=="2") and not legacy_full else 0
    cloud_cache=bool(enabled("VOLUME_EFFECTS") and options.get("CLOUD_NOISE_MODE")=="1" and options.get("CLOUD_DENSITY_CACHE")=="1" and not (voxel_bytes and enabled("INCREMENTAL_VOXELS") and enabled("PHYSICAL_ATMOSPHERE") and (options.get("VOXEL_FUSION")=="0" or options.get("ATMO_PREBAKED")=="0")))
    return {
        "water_normal_mib": 66*100*2/MIB if options.get("WATER_HYBRID_WAVES","1")=="1" else 0,
        "opaque_hdr_single_mib": width*height*4/MIB if enabled("DEFERRED_LIGHTING") and enabled("ADVANCED_WATER") else 0,
        "water_phase_mib": 514/MIB if enabled("ADVANCED_WATER") and options.get("WATER_PHASE_LUT")=="1" else 0,
        "cloud_cache_mib": 513*512*4/MIB if cloud_cache else 0,
        "end_nebula_mib": (256*256*2/MIB) if options.get("END_NEBULA_ASSET")=="1" else 0,
        "cloud_noise_mib": volume_noise/MIB,
        "volume_history_mib": volume_history/MIB,
        "hiz_mib": hiz_bytes / MIB,
        "voxel_mib": voxel_bytes / MIB,
        "voxel_smooth_mib": smooth_bytes / MIB,
        "atmosphere_mib": atmo_bytes / MIB,
        "extra_color_single_mib": extra_color_bytes / MIB,
        "extra_color_double_mib": 2 * extra_color_bytes / MIB,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()
    profiles = preview_profiles(PREVIEW)
    rows = [{"profile": tier, **resource_budget(profiles[f"profile.{tier}"], args.width, args.height)}
            for tier in TIERS]
    writer = csv.DictWriter(sys.stdout, fieldnames=list(rows[0]))
    writer.writeheader()
    for row in rows:
        writer.writerow({key: f"{value:.3f}" if isinstance(value, float) else value for key, value in row.items()})


if __name__ == "__main__":
    main()
