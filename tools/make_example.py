#!/usr/bin/env python3
"""Write a fictional example assessment table (inst/extdata/example_assessments.csv).

Answers are drawn with a fixed seed, respect the skip logic, and O1 is
answered exactly when it applies, so check_assessments() must report no
issues. The study names are invented and labelled as examples.
"""
import csv
import random
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_algorithms import applicable, judge, o1_applies, options  # noqa: E402

# Probability weights per answer, shaped like poorly reported in vitro papers:
# many NI for allocation, masking and plans.
WEIGHTS = {
    "good": {"Y": 6, "PY": 2, "PN": 0.6, "N": 0.4, "NI": 2},
    "problem": {"Y": 0.3, "PY": 0.5, "PN": 2, "N": 6, "NI": 1.5},
    "1.1": {"Y": 2, "PY": 1, "PN": 1, "N": 1, "NI": 6},
    "2.2": {"Y": 1, "PY": 1, "PN": 1, "N": 1, "NI": 8},
    "3.3": {"Y": 1, "PY": 1, "PN": 1, "N": 1, "NI": 6},
    "4.3": {"Y": 3, "PY": 1, "PN": 1, "N": 2, "NI": 6},
    "6.1": {"Y": 1, "PY": 0, "PN": 1, "N": 6, "NI": 2},
    # problem-polarity questions: mostly no problem
    "1.2": {"Y": 0.5, "PY": 0.5, "PN": 2, "N": 5, "NI": 2},
    "1.3": {"Y": 0.4, "PY": 0.6, "PN": 2, "N": 6, "NI": 3},
    "2.3": {"Y": 1, "PY": 1, "PN": 2, "N": 5, "NI": 3},
    "4.1": {"Y": 0.3, "PY": 0.5, "PN": 2, "N": 8, "NI": 1},
    "4.2": {"Y": 0.4, "PY": 0.6, "PN": 2, "N": 6, "NI": 3},
    "6.2": {"Y": 0.5, "PY": 1, "PN": 2, "N": 5, "NI": 3},
    "6.3": {"Y": 0.4, "PY": 0.6, "PN": 2, "N": 5, "NI": 3},
}
MODULES = ["Cell lines", "Primary cells", "3D models", "Microbial", "Cell-free", "Materials"]


def draw(rng, q, opts):
    w = WEIGHTS.get(q["id"], WEIGHTS[q["polarity"]])
    return rng.choices(opts, weights=[w.get(o, 1) for o in opts])[0]


def main():
    root = Path(__file__).resolve().parents[1]
    spec = yaml.safe_load((root / "inst/extdata/tool.yaml").read_text(encoding="utf-8"))
    rng = random.Random(20261123)
    doms = [d["id"] for d in spec["domains"]]
    qids = [q["id"] for d in spec["domains"] for q in d["questions"]]
    cols = (["study_id", "result_id", "assessor", "module", "B1", "B2", "B3"]
            + ["q" + q for q in qids] + [d + "_final" for d in doms] + [d + "_reason" for d in doms]
            + ["O1", "overall_final", "overall_reason", "U1", "AP1", "AP2", "notes"])
    rows = []
    for k in range(12):
        row = {c: "" for c in cols}
        row.update(study_id=f"Example study {chr(65 + k)}", result_id=f"Fig {k % 4 + 1}{'ABC'[k % 3]}",
                   assessor="Example", module=MODULES[k % len(MODULES)], B1="Y", B2="Y", B3="N")
        if k == 11:  # one result stopped at the proceed check
            row.update(B1="N", notes="No concurrent comparator; not assessed")
            rows.append(row)
            continue
        judg = []
        for d in spec["domains"]:
            ans = {}
            for q in d["questions"]:
                if applicable(q, ans):
                    ans[q["id"]] = draw(rng, q, options(q))
                else:
                    ans[q["id"]] = "NA"
            for q in d["questions"]:
                row["q" + q["id"]] = "" if ans[q["id"]] == "NA" else ans[q["id"]]
            judg.append(judge(d, ans))
        if o1_applies(judg):
            row["O1"] = "N" if rng.random() < 0.8 else "Y"
        row["U1"] = rng.choice(["Y", "N", "NI", "NI"])
        row["AP1"] = rng.choice(["Verified", "Not verified", "Not verified"])
        row["AP2"] = rng.choice(["Direct", "Direct", "Limited", "Uncertain"])
        rows.append(row)
    out = root / "inst/extdata/example_assessments.csv"
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {out} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
