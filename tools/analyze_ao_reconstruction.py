"""Compare fixed-camera AO diagnostic output, not raw linear visibility."""

import argparse
import hashlib
import json
from pathlib import Path


REGIONS={
    "wall":(50,150,550,450),
    "left_contact":(50,470,650,620),
    "right_contact":(1440,520,1900,850),
    "floor":(680,620,1300,900),
    "thin_geometry":(40,600,600,760),
}


def compare(directory,left,right):
    from PIL import Image, ImageChops

    result={"left":left,"right":right,"regions":{}}
    with Image.open(directory/f"{left}.png") as first, Image.open(directory/f"{right}.png") as second:
        if first.size!=(1920,1080) or second.size!=first.size:
            raise ValueError("The interior fixture regions require native 1920x1080")
        for name,bounds in REGIONS.items():
            difference=ImageChops.difference(first.crop(bounds).convert("RGB"),second.crop(bounds).convert("RGB"))
            histogram=difference.histogram()
            combined=[sum(histogram[value+channel*256] for channel in range(3)) for value in range(256)]
            count=sum(combined)
            def percentile(fraction):
                cumulative=0
                for value,frequency in enumerate(combined):
                    cumulative+=frequency
                    if cumulative>=count*fraction:
                        return value
                return 255
            result["regions"][name]={
                "bounds":bounds,
                "mae_code8":sum(value*frequency for value,frequency in enumerate(combined))/count,
                "p95_code8":percentile(.95),
                "p99_code8":percentile(.99),
                "fraction_above_4":sum(combined[5:])/count,
            }
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("instance",type=Path)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    pairs=(("ao_visual_ref_a","ao_visual_near_a"),("ao_visual_ref_b","ao_visual_near_b"),
           ("ao_visual_ref_a","ao_visual_ref_b"),("ao_visual_near_a","ao_visual_near_b"))
    report={
        "scope":"AO diagnostic after display/post processing; excludes HUD/chat regions. Not a raw AO error bound or motion acceptance.",
        "instance":str(args.instance),
        "shader_archive":(args.instance/"shader-pack-sha256.txt").read_text(encoding="utf-8").strip(),
        "comparisons":[compare(args.instance,*pair) for pair in pairs],
        "images":{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(args.instance.glob("ao_visual*.png"))},
    }
    args.output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(args.output)


if __name__=="__main__":
    main()
