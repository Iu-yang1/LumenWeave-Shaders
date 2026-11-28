"""Verify candidate identity and functional readbacks from isolated game instances."""

import argparse
import hashlib
import json
import re
from pathlib import Path


def readbacks(text):
    records={}
    for stage,line in re.findall(r"LumenWeave P4 readback (\S+) ([^\r\n]+)",text):
        fields=dict(re.findall(r"(\w+)=(\S+)",line))
        camera=re.search(r"camera=\(([^)]+)\)",line)
        if camera:
            fields["camera_position"]=[float(value) for value in camera[1].split()]
        records[stage]=fields
    return records


def validate_instance(directory,digest,stages,external,gi=True):
    manifest=(directory/"shader-pack-sha256.txt").read_text(encoding="utf-8").split()
    actual=manifest[0].lower() if manifest else ""
    installed=directory/"shaderpacks/LumenWeave-Shaders-P5-Preview.zip"
    if actual!=digest or hashlib.sha256(installed.read_bytes()).hexdigest()!=digest:
        raise ValueError(f"Candidate mismatch: {directory}")
    options=(directory/"options.txt").read_text(encoding="utf-8")
    if "soundCategory_master:0.0" not in options.splitlines():
        raise ValueError(f"Master audio is not zero: {directory}")
    log=(directory/"logs/latest.log").read_text(encoding="utf-8")
    if re.search(r"ShaderCompileException|ParseCancellationException|GL error=[1-9]",log):
        raise ValueError(f"Shader or OpenGL failure: {directory}")
    records=readbacks(log)
    for stage in stages:
        record=records.get(stage)
        if not record or record.get("error")!="0" or int(record.get("externalFlag","-1"))!=external:
            raise ValueError(f"Missing valid handoff/readback: {directory}/{stage}")
        expected={"resize-720p":"1280x720","resize-odd":"1919x1079"}.get(stage,"1920x1080")
        if record.get("framebuffer")!=expected:
            raise ValueError(f"Unexpected raster dimensions: {directory}/{stage}")
        dimension={"visual-nether":"minecraft:the_nether","visual-the_end":"minecraft:the_end"}.get(stage,"minecraft:overworld")
        if record.get("dimension")!=dimension:
            raise ValueError(f"Unexpected dimension: {directory}/{stage}")
        if gi and (record.get("giTargets")!="2" or int(record.get("giLit","0"))<=0):
            raise ValueError(f"GI is not contributing: {directory}/{stage}")
        if not gi and record.get("giTargets")!="0":
            raise ValueError(f"Low path unexpectedly owns GI history: {directory}/{stage}")
    return {"directory":str(directory),"shader_archive":actual,
            "readbacks":{stage:records[stage] for stage in stages}}


def motion(directory,digest,external):
    result=validate_instance(directory,digest,("static","halfway","arrived"),external)
    positions=[record["camera_position"] for record in result["readbacks"].values()]
    if positions[0]==positions[-1]:
        raise ValueError(f"Camera did not move: {directory}")
    histories={}
    for stage in ("static","halfway","arrived"):
        fields=dict(re.findall(r"(\w+)=(\S+)",(directory/f"gi-check-{stage}.txt").read_text(encoding="utf-8")))
        if fields.get("GLerror")!="0" or fields.get("previousFresh")!="true" or int(fields.get("compared","0"))<=0:
            raise ValueError(f"Invalid GI history readback: {directory}/{stage}")
        histories[stage]=fields
    result["histories"]=histories
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack",required=True,type=Path)
    parser.add_argument("--standalone-motion",required=True,type=Path)
    parser.add_argument("--extension-motion",required=True,type=Path)
    parser.add_argument("--extension-visual",required=True,type=Path)
    parser.add_argument("--low",required=True,type=Path)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    digest=hashlib.sha256(args.pack.read_bytes()).hexdigest()
    visual_stages=("visual-day","visual-water","visual-underwater","visual-night","visual-rain",
                   "visual-nether","visual-the_end","visual-return","visual-interior",
                   "visual-interior_rain","visual-interior_light_removed","visual-interior_return",
                   "resize-720p","resize-odd","resize-1080p")
    visual=validate_instance(args.extension_visual,digest,visual_stages,2)
    records=visual["readbacks"]
    before=records["visual-interior"]
    removed=records["visual-interior_light_removed"]
    restored=records["visual-interior_return"]
    if int(before["seedEmitters"])-int(removed["seedEmitters"])!=1 or restored["seedChecksum"]!=before["seedChecksum"]:
        raise ValueError("Interior source removal/restoration did not preserve the seed contract")
    report={"scope":"Functional readbacks at a 60 FPS cap; not performance or complete motion-image acceptance.",
            "candidate_sha256":digest,
            "standalone_motion":motion(args.standalone_motion,digest,0),
            "extension_motion":motion(args.extension_motion,digest,2),
            "extension_visual":visual,
            "low":validate_instance(args.low,digest,("static",),0,gi=False)}
    args.output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(args.output)


if __name__=="__main__":
    main()
