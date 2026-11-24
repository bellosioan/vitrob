#!/usr/bin/env python3
"""Write inst/extdata/calibration_scenarios.csv.

Each scenario states the answers that the guidance prescribes for a
boundary case and the judgment the domain algorithm must then give. The
script stops if the specification gives a different judgment, so the
guidance (section 15.1), this file and the R test (test-calibration.R)
cannot drift apart.

Usage: python3 tools/make_calibration.py
"""
import csv
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from verify_algorithms import make_env  # noqa: E402

# (id, description, domain, answers, intended judgment)
SCENARIOS = [
    ("C1a", "Ten runs randomly assigned to each condition, common protocol, analysis by run",
     "D2", {"2.1": "Y", "2.2": "Y", "2.3": "N"}, "Low"),
    ("C1b", "One run per condition; treated on one day, controls on another",
     "D2", {"2.1": "Y", "2.2": "Y", "2.3": "Y", "2.4": "N"}, "High"),
    ("C2a", "Valid planned comparator; unplanned extra wash in treated wells, stable endpoint",
     "D3", {"3.1": "Y", "3.2": "N", "3.3": "PY", "3.4": "Y", "3.5": "N"}, "Some concerns"),
    ("C2b", "As C2a, but the extra wash removes the analyte being measured",
     "D3", {"3.1": "Y", "3.2": "N", "3.3": "PY", "3.4": "Y", "3.5": "Y"}, "High"),
    ("C3a", "Mycoplasma detected in all cultures after the experiment; not linked to condition",
     "D1", {"1.1": "N", "1.2": "N", "1.3": "N"}, "Some concerns"),
    ("C3b", "Same contaminant inactivates the test compound in all conditions",
     "D3", {"3.1": "N", "3.2": "Y", "3.3": "PY", "3.4": "Y", "3.5": "Y"}, "High"),
    ("C4", "Incomplete knockdown; effect of interest is applying the reagent (field C)",
     "D3", {"3.1": "PY", "3.2": "Y", "3.3": "PY", "3.4": "Y"}, "Low"),
    ("C5a", "Minor starting-state difference of unknown importance",
     "D1", {"1.1": "Y", "1.3": "NI"}, "Some concerns"),
    ("C5b", "Normalisation reference not shown to be stable; impact cannot be determined",
     "D5", {"5.1": "Y", "5.5": "NI", "5.6": "Y"}, "Some concerns"),
    ("C6", "Coded images excluded by an automated low-signal filter, more in treated wells",
     "D5", {"5.1": "N", "5.2": "N", "5.3": "Y", "5.4": "Y", "5.5": "Y", "5.6": "Y"}, "High"),
    ("C6d4", "Same study, measurement domain: automated, masked readout",
     "D4", {"4.1": "N", "4.2": "N", "4.3": "N"}, "Low"),
    ("C7a", "No plan; test guideline fixes time point, exclusions, normalisation and analysis",
     "D6", {"6.1": "PY", "6.2": "N", "6.3": "N"}, "Low"),
    ("C7b", "No plan; credible alternative time points or normalisations exist",
     "D6", {"6.1": "NI", "6.2": "PN", "6.3": "PN"}, "Some concerns"),
]


def judge(dom, answers):
    full = {q["id"]: answers.get(q["id"], "NA") for q in dom["questions"]}
    env = make_env(full)
    for q in dom["questions"]:
        if q.get("ask_if"):
            asked = eval(q["ask_if"], env)  # noqa: S307 - rule language from tool.yaml
            if asked != (full[q["id"]] != "NA"):
                raise SystemExit(f"skip logic violated for {q['id']}")
    if eval(dom["rules"]["high"], env):  # noqa: S307
        return "High"
    if eval(dom["rules"]["low"], env):  # noqa: S307
        return "Low"
    return "Some concerns"


def main():
    spec = yaml.safe_load((ROOT / "inst/extdata/tool.yaml").read_text(encoding="utf-8"))
    doms = {d["id"]: d for d in spec["domains"]}
    qids = [q["id"] for d in spec["domains"] for q in d["questions"]]
    rows = []
    for sid, desc, dom, ans, intended in SCENARIOS:
        got = judge(doms[dom], ans)
        if got != intended:
            raise SystemExit(f"{sid}: specification gives {got}, guidance intends {intended}")
        row = {"scenario": sid, "description": desc, "domain": dom, "expected": intended}
        for q in qids:
            row["q" + q] = ans.get(q, "") if q.split(".")[0] == dom[1:] else ""
        rows.append(row)
    out = ROOT / "inst/extdata/calibration_scenarios.csv"
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["scenario", "description", "domain", "expected"]
                           + ["q" + q for q in qids])
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {out} ({len(rows)} scenarios, all match the specification)")


if __name__ == "__main__":
    main()
