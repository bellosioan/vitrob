#!/usr/bin/env python3
"""Independent reference implementation and exhaustive verification of the
domain and overall algorithms defined in inst/extdata/tool.yaml.

It is deliberately separate from the R package: the R tests compare their
output against the golden file written here, so two independent
implementations must agree on every answer combination.

Usage:
    python3 tools/verify_algorithms.py [path/to/tool.yaml] [output_dir]

Writes:
    reference_judgments.csv   every valid answer profile -> proposed judgment
    reference_overall.csv     every domain-judgment profile (+ O1) -> overall
    verification_report.md    property checks, counts and any failures
    verification_report.json  same, machine-readable
"""
import csv
import itertools
import json
import sys
from collections import Counter
from pathlib import Path

import yaml

JUDGMENTS = ["Low", "Some concerns", "High"]
RANK = {j: i for i, j in enumerate(JUDGMENTS)}
DEFAULT_OPTIONS = ["Y", "PY", "PN", "N", "NI"]
NA = "NA"

# How bad an answer is for each question polarity (higher = worse).
BADNESS = {
    "good": {"Y": 0, "PY": 0, "NI": 1, "PN": 2, "N": 2},
    "problem": {"N": 0, "PN": 0, "NI": 1, "PY": 2, "Y": 2},
}


def make_env(answers):
    def yes(q):
        return answers.get(q, NA) in ("Y", "PY")

    def no(q):
        return answers.get(q, NA) in ("N", "PN")

    def ni(q):
        return answers.get(q, NA) == "NI"

    return {"__builtins__": {}, "yes": yes, "no": no, "ni": ni}


def evaluate(expr, answers):
    return bool(eval(expr, make_env(answers)))  # noqa: S307 (trusted file)


def applicable(question, answers):
    cond = question.get("ask_if")
    return True if cond is None else evaluate(cond, answers)


def options(question):
    return question.get("options", DEFAULT_OPTIONS)


def enumerate_profiles(domain):
    """All valid answer profiles, respecting skip logic in question order."""
    qs = domain["questions"]

    def rec(i, answers):
        if i == len(qs):
            yield dict(answers)
            return
        q = qs[i]
        if applicable(q, answers):
            for opt in options(q):
                answers[q["id"]] = opt
                yield from rec(i + 1, answers)
            del answers[q["id"]]
        else:
            answers[q["id"]] = NA
            yield from rec(i + 1, answers)
            del answers[q["id"]]

    yield from rec(0, {})


def judge(domain, answers):
    low = evaluate(domain["rules"]["low"], answers)
    high = evaluate(domain["rules"]["high"], answers)
    if low and high:
        return None  # contradiction, reported by the checks
    if high:
        return "High"
    if low:
        return "Low"
    return "Some concerns"


def completions(domain, fixed):
    """Valid profiles that agree with `fixed` wherever `fixed` still applies."""
    qs = domain["questions"]

    def rec(i, answers):
        if i == len(qs):
            yield dict(answers)
            return
        q = qs[i]
        qid = q["id"]
        if applicable(q, answers):
            choices = [fixed[qid]] if fixed.get(qid, NA) != NA else options(q)
            for opt in choices:
                answers[qid] = opt
                yield from rec(i + 1, answers)
            del answers[qid]
        else:
            answers[qid] = NA
            yield from rec(i + 1, answers)
            del answers[qid]

    yield from rec(0, {})


def check_domain(domain):
    qs = domain["questions"]
    profiles = list(enumerate_profiles(domain))
    results = {}
    failures = []

    # 1. Exclusivity and completeness: exactly one judgment per profile.
    judged = []
    for p in profiles:
        j = judge(domain, p)
        if j is None:
            failures.append(("exclusivity", p))
        judged.append((p, j))
    results["profiles"] = len(profiles)
    results["exclusive"] = not any(f[0] == "exclusivity" for f in failures)

    # 2. Skip logic: every NA question is not applicable and vice versa.
    skip_ok = True
    for p in profiles:
        for q in qs:
            app = applicable(q, p)
            if app == (p[q["id"]] == NA):
                skip_ok = False
                failures.append(("skip_logic", p))
    results["skip_logic_consistent"] = skip_ok

    # 3. Reachability of each judgment.
    counts = Counter(j for _, j in judged)
    results["counts"] = {j: counts.get(j, 0) for j in JUDGMENTS}
    results["all_judgments_reachable"] = all(counts.get(j, 0) > 0 for j in JUDGMENTS)

    # 4. Monotonicity: a worse answer never gives a better judgment,
    #    whatever the newly applicable follow-up questions are answered.
    mono_ok = True
    checked = 0
    for p, j in judged:
        for q in qs:
            qid = q["id"]
            if p[qid] == NA:
                continue
            bad = BADNESS[q["polarity"]]
            for opt in options(q):
                if bad[opt] <= bad[p[qid]]:
                    continue
                fixed = dict(p)
                fixed[qid] = opt
                for b in completions(domain, fixed):
                    checked += 1
                    jb = judge(domain, b)
                    if jb is not None and j is not None and RANK[jb] < RANK[j]:
                        mono_ok = False
                        failures.append(("monotonicity", {"from": p, "to": b, "j_from": j, "j_to": jb}))
    results["monotonic"] = mono_ok
    results["monotonicity_comparisons"] = checked

    # 5. No dead questions: each question can change the judgment when only
    #    it (and the follow-ups it switches on or off) changes.
    dead = []
    for q in qs:
        qid = q["id"]
        influential = False
        for p, j in judged:
            if p[qid] == NA:
                continue
            for opt in options(q):
                if opt == p[qid]:
                    continue
                fixed = dict(p)
                fixed[qid] = opt
                for b in completions(domain, fixed):
                    if judge(domain, b) != j:
                        influential = True
                        break
                if influential:
                    break
            if influential:
                break
        if not influential:
            dead.append(qid)
    results["dead_questions"] = dead
    results["no_dead_questions"] = not dead

    results["passed"] = all([
        results["exclusive"], results["skip_logic_consistent"],
        results["all_judgments_reachable"], results["monotonic"],
        results["no_dead_questions"],
    ])
    return results, judged, failures[:20]


def overall(domain_judgments, o1):
    if any(j == "High" for j in domain_judgments):
        return "High"
    if all(j == "Low" for j in domain_judgments):
        return "Low"
    if o1 in ("Y", "PY"):
        return "High"
    return "Some concerns"


def o1_applies(domain_judgments):
    return (sum(j == "Some concerns" for j in domain_judgments) >= 2
            and not any(j == "High" for j in domain_judgments))


def check_overall(n_domains):
    rows, ok_mono, ok_floor = [], True, True
    combos = list(itertools.product(JUDGMENTS, repeat=n_domains))
    for combo in combos:
        o1_opts = DEFAULT_OPTIONS if o1_applies(combo) else [NA]
        for o1 in o1_opts:
            res = overall(combo, o1)
            rows.append((combo, o1, res))
            worst = max(RANK[j] for j in combo)
            if RANK[res] < worst:
                ok_floor = False
    # Monotonic in each domain judgment (O1 held at NA/N where it applies).
    for combo in combos:
        base = overall(combo, "N" if o1_applies(combo) else NA)
        for i in range(n_domains):
            for worse in JUDGMENTS[RANK[combo[i]] + 1:]:
                c2 = list(combo)
                c2[i] = worse
                for o1 in (DEFAULT_OPTIONS if o1_applies(c2) else [NA]):
                    if RANK[overall(c2, o1)] < RANK[base]:
                        ok_mono = False
    return rows, {"profiles": len(rows), "never_below_worst_domain": ok_floor,
                  "monotonic": ok_mono, "passed": ok_floor and ok_mono}


def main():
    root = Path(__file__).resolve().parents[1]
    spec_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "inst/extdata/tool.yaml"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "inst/extdata"
    out.mkdir(parents=True, exist_ok=True)
    spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))

    report = {"tool_version": spec["tool"]["version"], "domains": {}}
    all_ids = [q["id"] for d in spec["domains"] for q in d["questions"]]
    report["n_questions"] = len(all_ids)

    with open(out / "reference_judgments.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["domain", "profile"] + ["q" + i for i in all_ids] + ["proposed"])
        for d in spec["domains"]:
            res, judged, failures = check_domain(d)
            res["failures"] = failures
            report["domains"][d["id"]] = res
            ids = [q["id"] for q in d["questions"]]
            for k, (p, j) in enumerate(judged, start=1):
                row = [p.get(i, "") if i in ids else "" for i in all_ids]
                w.writerow([d["id"], k] + row + [j])

    rows, ov = check_overall(len(spec["domains"]))
    report["overall"] = ov
    with open(out / "reference_overall.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow([d["id"] for d in spec["domains"]] + ["O1", "overall"])
        for combo, o1, res in rows:
            w.writerow(list(combo) + [o1, res])

    with open(out / "verification_summary.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["domain", "profiles", "low", "some_concerns", "high", "monotonicity_comparisons", "passed"])
        for did, r in report["domains"].items():
            c = r["counts"]
            w.writerow([did, r["profiles"], c["Low"], c["Some concerns"], c["High"],
                        r["monotonicity_comparisons"], str(r["passed"]).upper()])

    report["passed"] = all(r["passed"] for r in report["domains"].values()) and ov["passed"]
    (out / "verification_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    lines = [
        f"# Algorithm verification, tool version {report['tool_version']}",
        "",
        f"Overall result: **{'PASSED' if report['passed'] else 'FAILED'}**. "
        f"{report['n_questions']} signalling questions in {len(spec['domains'])} domains.",
        "",
        "| Domain | Valid answer profiles | Low | Some concerns | High | Exclusive | Skip logic | All judgments reachable | Monotonic (comparisons) | Dead questions |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for did, r in report["domains"].items():
        c = r["counts"]
        lines.append(
            f"| {did} | {r['profiles']} | {c['Low']} | {c['Some concerns']} | {c['High']} | "
            f"{'yes' if r['exclusive'] else 'NO'} | {'yes' if r['skip_logic_consistent'] else 'NO'} | "
            f"{'yes' if r['all_judgments_reachable'] else 'NO'} | "
            f"{'yes' if r['monotonic'] else 'NO'} ({r['monotonicity_comparisons']}) | "
            f"{', '.join(r['dead_questions']) or 'none'} |")
    lines += [
        "",
        f"Overall rule: {ov['profiles']} domain-judgment profiles (including O1 answers); "
        f"never below the worst domain: {'yes' if ov['never_below_worst_domain'] else 'NO'}; "
        f"monotonic: {'yes' if ov['monotonic'] else 'NO'}.",
        "",
        "Properties checked for every domain:",
        "",
        "1. **Exclusive:** no answer profile satisfies both the Low and the High rule.",
        "2. **Skip logic:** a question is answered exactly when its condition holds.",
        "3. **Reachable:** Low, Some concerns and High each occur.",
        "4. **Monotonic:** replacing any answer with a worse one (for that question's polarity; NI ranks between yes and no) never gives a better judgment, for every way of answering follow-up questions that become applicable.",
        "5. **No dead questions:** every question can change the judgment.",
    ]
    fails = {d: r["failures"] for d, r in report["domains"].items() if r["failures"]}
    if fails:
        lines += ["", "## Failures (first 20 per domain)", "", "```", json.dumps(fails, indent=1), "```"]
    (out / "verification_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    sys.exit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
