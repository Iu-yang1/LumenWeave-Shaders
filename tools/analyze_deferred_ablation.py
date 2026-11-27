"""Report measured deferred1 marginal savings; ablations are not additive timings."""

import argparse
import json
import statistics
from pathlib import Path

STAGE="__frame__/deferred/deferred1"


def summarize(report):
    output=[]
    for instance in report["instances"]:
        cases=instance["cases"]
        controls=[cases[label]["gpu_exclusive_ms"][STAGE] for label in ("env_full_a","env_full_b") if label in cases]
        if not controls:
            continue
        reference=statistics.fmean(controls)
        for label,case in cases.items():
            if not label.startswith("diag_"):
                continue
            measured=case["gpu_exclusive_ms"][STAGE]
            output.append({"case":label,"directory":instance["directory"],
                           "shader_archive":instance.get("shader_archive"),
                           "control_samples_ms":controls,"control_mean_ms":reference,
                           "ablated_ms":measured,"marginal_saving_ms":reference-measured})
    return {"scope":"GPU timestamp ablations change shader work and compiler decisions. "
                    "Marginal savings may overlap and must not be summed. "
                    "These variants intentionally change visual output.",
            "stages":output}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("measurements",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    result=summarize(json.loads(args.measurements.read_text(encoding="utf-8")))
    args.output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    for stage in sorted(result["stages"],key=lambda row:-row["marginal_saving_ms"]):
        print(f'{stage["case"]}: {stage["marginal_saving_ms"]:+.4f} ms marginal saving')


if __name__=="__main__":
    main()
