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
        voxel_bytes += 36 * size ** 3 + 4 * 128 * 32 * 32 + 16
    atmo_bytes = ATMO_BYTES if enabled("PHYSICAL_ATMOSPHERE") else 0
    ssr = enabled("MATERIAL_SSR") and enabled("DEFERRED_LIGHTING") and enabled("ADVANCED_WATER") and not enabled("LITE_LIGHTING")
    taa = int(options["AA_MODE"]) >= 2 and enabled("DEFERRED_LIGHTING")
    jitter_mode = int(options.get("PROJECTION_JITTER", "0"))
    auto_dynamic = jitter_mode == 0 and not any(enabled(name) for name in ("VOLUME_EFFECTS", "SCREEN_GI", "VOXEL_LIGHTING"))
    advanced_dynamic = taa and (jitter_mode == 2 or auto_dynamic) and any(
        enabled(name) for name in ("VOLUME_EFFECTS", "SCREEN_GI", "VOXEL_LIGHTING", "MATERIAL_SSR", "PHYSICAL_ATMOSPHERE")
    )
    # colortex12/13 plus optional history 14/15; ownership colortex3.
    # Report a single texture payload and double-buffered equivalent separately.
    extra_color_bytes = width * height * (8 * (2 + 2 * int(taa)) * int(ssr) + 8 * int(advanced_dynamic))
    return {
        "voxel_mib": voxel_bytes / MIB,
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
