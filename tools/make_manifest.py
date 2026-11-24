#!/usr/bin/env python3
"""Write inst/extdata/release_manifest.csv: versions and MD5 checksums of the
files that define and test the tool, so that a release can be checked as one
consistent set (specification, template, reference files, verification).

Run last, after verify_algorithms.py, make_template.py, make_example.py and
make_calibration.py.  Usage: python3 tools/make_manifest.py
"""
import csv
import hashlib
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / "inst/extdata"
FILES = ["tool.yaml", "assessment_template.xlsx", "example_assessments.csv",
         "reference_judgments.csv", "reference_overall.csv", "verification_summary.csv",
         "verification_report.json", "calibration_scenarios.csv"]
GUIDANCE = "VITROB 1.0 guidance, release candidate 4"


def main():
    spec = yaml.safe_load((EXT / "tool.yaml").read_text(encoding="utf-8"))
    desc = (ROOT / "DESCRIPTION").read_text(encoding="utf-8")
    pkg = re.search(r"^Version:\s*(\S+)", desc, re.M).group(1)
    rows = [("tool_version", spec["tool"]["version"]), ("package_version", pkg),
            ("guidance_version", GUIDANCE)]
    for f in FILES:
        rows.append((f"md5:{f}", hashlib.md5((EXT / f).read_bytes()).hexdigest()))
    out = EXT / "release_manifest.csv"
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["item", "value"])
        w.writerows(rows)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
