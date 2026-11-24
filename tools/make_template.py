#!/usr/bin/env python3
"""Build the Excel entry template from inst/extdata/tool.yaml.

Usage: python3 tools/make_template.py [tool.yaml] [output.xlsx]

The 'Assessments' sheet uses the same column names as
vitrob::assessment_columns(), so a sheet saved as CSV can be read with
vitrob::read_assessments(). Every answer cell has a drop-down list and
each question header carries the question text as a cell comment.
"""
import sys
from pathlib import Path

import yaml
from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

ROWS = 500
DEFAULT = ["Y", "PY", "PN", "N", "NI"]
JUDG = ["Low", "Some concerns", "High"]


def main():
    root = Path(__file__).resolve().parents[1]
    spec_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "inst/extdata/tool.yaml"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "inst/extdata/assessment_template.xlsx"
    spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    doms = [d["id"] for d in spec["domains"]]
    ap = {a["id"]: a for a in spec["additional_outputs"]}

    cols = []  # (name, options or None, comment)
    cols += [("study_id", None, "Study identifier"), ("result_id", None, "Figure/panel/table"),
             ("assessor", None, None), ("module", None, "System module")]
    for f in spec.get("result_fields", []):
        req = "Required. " if f.get("required") else ""
        cols.append((f["id"], f.get("options"), f"Field {f['field']}. {req}{f['label']}"))
    for b in spec["proceed_check"]:
        cols.append((b["id"], DEFAULT, b["text"].strip()))
    for d in spec["domains"]:
        for q in d["questions"]:
            note = q["text"].strip()
            if q.get("ask_if"):
                note = f"Asked only if {q['ask_if']}. " + note
            cols.append(("q" + q["id"], q.get("options", DEFAULT), note))
    for d in doms:
        cols.append((f"{d}_final", JUDG, f"{d}: final judgment (leave blank to accept the proposal)"))
    for d in doms:
        cols.append((f"{d}_reason", None, f"{d}: reason if the final judgment differs from the proposal"))
    cols.append(("O1", DEFAULT, spec["overall"]["o1"]["text"].strip()))
    cols.append(("overall_final", JUDG, "Final overall judgment"))
    cols.append(("overall_reason", None, "Reason if the overall judgment differs from the proposal"))
    cols.append(("U1", DEFAULT, ap["U1"]["text"].strip()))
    for comp, opts in ap["AP1"]["components"].items():
        cols.append((f"AP1_{comp}", opts, f"AP1, {comp}. " + ap["AP1"]["text"].strip()))
    cols.append(("AP1", ap["AP1"]["outputs"], "Final AP1 output. " + ap["AP1"]["derivation"].strip()))
    for comp in ap["AP2"]["components"]:
        cols.append((f"AP2_{comp}", ap["AP2"]["outputs"], f"AP2, {comp}: " + ap["AP2"]["text"].strip()))
    cols.append(("notes", None, None))

    wb = Workbook()
    ws = wb.active
    ws.title = "Assessments"
    head_fill = PatternFill("solid", fgColor="E7F1FB")
    for j, (name, opts, note) in enumerate(cols, start=1):
        c = ws.cell(row=1, column=j, value=name)
        c.font = Font(bold=True)
        c.fill = head_fill
        if note:
            c.comment = Comment(note, "tool.yaml", width=320, height=140)
        ws.column_dimensions[get_column_letter(j)].width = 16 if opts == JUDG else 9 if opts else 18
        if opts:
            dv = DataValidation(type="list", formula1='"' + ",".join(opts) + '"', allow_blank=True,
                                showErrorMessage=True, errorTitle="Invalid entry",
                                error="Choose one of: " + ", ".join(opts))
            ws.add_data_validation(dv)
            col = get_column_letter(j)
            dv.add(f"{col}2:{col}{ROWS + 1}")
    ws.freeze_panes = "E2"

    qs = wb.create_sheet("Questions")
    hdr = ["Domain", "ID", "Question", "Asked if", "Options", "Y/PY when", "N/PN when", "Why included", "Derived from", "References"]
    qs.append(hdr)
    for d in spec["domains"]:
        for q in d["questions"]:
            qs.append([d["id"] + " " + d["name"], q["id"], q["text"].strip(), q.get("ask_if", ""),
                       "/".join(q.get("options", DEFAULT)), q["y_when"].strip(), q["n_when"].strip(),
                       q["rationale"].strip(), q["derived_from"], "; ".join(q["references"])])
    for c in qs[1]:
        c.font = Font(bold=True)
        c.fill = head_fill
    for j, w in enumerate([28, 6, 60, 22, 14, 40, 40, 50, 22, 30], start=1):
        qs.column_dimensions[get_column_letter(j)].width = w
    for row in qs.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical="top")
    qs.freeze_panes = "C2"

    rules = wb.create_sheet("Algorithms")
    rules.append(["Domain", "Low when", "High when", "Otherwise"])
    for d in spec["domains"]:
        rules.append([d["id"] + " " + d["name"], d["rules"]["low"], d["rules"]["high"], "Some concerns"])
    rules.append(["Overall", spec["overall"]["rule"].strip(), "", ""])
    for c in rules[1]:
        c.font = Font(bold=True)
    for j, w in enumerate([45, 50, 40, 15], start=1):
        rules.column_dimensions[get_column_letter(j)].width = w
    for row in rules.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical="top")

    info = wb.create_sheet("How to use")
    lines = [
        spec["tool"]["name"] + ", version " + str(spec["tool"]["version"]),
        "",
        "1. One row per assessed result. Record the review-level planning decisions (P1) separately.",
        "2. Answer the proceed check (B1-B2). If it stops the assessment, leave the domain questions blank.",
        "3. Answer each signalling question from the drop-down list. Leave a question blank when its 'Asked if' condition is not met (see the header comment or the Questions sheet).",
        "4. Leave the *_final columns blank to accept the proposed judgment; if you enter a different judgment, give a reason.",
        "5. Answer O1 only when two or more domains are Some concerns and none is High.",
        "6. Upload this file in the app (vitrob::run_app()), or read it in R with vitrob::read_assessments(), then run vitrob::check_assessments() and vitrob::propose_judgments().",
        "",
        "Rule language: yes(q) = Y or PY; no(q) = N or PN; ni(q) = NI; & = and; | = or.",
        "Generated from tool.yaml; do not edit the column names.",
    ]
    for ln in lines:
        info.append([ln])
    info.column_dimensions["A"].width = 120
    info["A1"].font = Font(bold=True, size=13)
    wb.move_sheet("How to use", offset=-3)
    wb.active = 1
    wb.save(out)
    print(f"Wrote {out} with {len(cols)} columns")


if __name__ == "__main__":
    main()
