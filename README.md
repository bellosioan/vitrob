# vitrob

<!-- badges: start -->
[![R-CMD-check](https://github.com/bellosioan/vitrob/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/bellosioan/vitrob/actions/workflows/R-CMD-check.yaml)
[![verify-spec](https://github.com/bellosioan/vitrob/actions/workflows/verify-spec.yaml/badge.svg)](https://github.com/bellosioan/vitrob/actions/workflows/verify-spec.yaml)
<!-- badges: end -->

R implementation of **VITROB**, a risk-of-bias tool for in vitro experiments
(tool version 1.0 draft). VITROB assesses one specified result at a time in
six domains, using signalling questions and algorithms in the style of RoB 2
and ROBINS-I V2. The questions, skip logic and algorithms live in one file,
`inst/extdata/tool.yaml`; the package, the Excel template and the
verification scripts are all driven by it.

## Installation

```r
# install.packages("pak")
pak::pak("bellosioan/vitrob")
```

The getting-started tutorial is [`vignettes/vitrob.Rmd`](vignettes/vitrob.Rmd).

## What is in the package

| Function | What it does |
| --- | --- |
| `tool_spec()` | Loads `tool.yaml` |
| `questions_table()` | All 26 signalling questions with guidance, rationale, derivation and references |
| `propose_domain()`, `propose_overall()`, `assess_result()` | Apply the algorithms |
| `write_template()`, `read_assessments()` | CSV entry sheet and reader |
| `propose_judgments()` | Adds proposed domain and overall judgments to an assessment table |
| `check_assessments()` | Flags invalid codes, missing required answers, answers to skipped questions, O1 errors, overrides without reasons, overall below worst domain |
| `verify_algorithms()` | Exhaustive property checks of every domain algorithm |
| `plot_traffic()` | Traffic-light plot: one row per result, domains plus overall |
| `plot_summary()` | Share of Low / Some concerns / High per domain, optionally weighted |
| `plot_questions()` | Heatmap of every signalling-question answer, coloured by whether it points to low or high risk |
| `plot_gaps()` | Share of "No information" answers per question: where primary studies under-report |
| `save_rob_plot()`, `theme_rob()`, `rob_colours()` | Saving with sensible sizes; theme; palettes |
| `run_app()` | Point-and-click app: upload, check, see judgments and plots, download |

Plots use a colour-blind-safe blue / amber / red palette by default
(`palette = "cochrane"` gives green / amber / red). Every judgment also
carries a symbol (+, −, ×) and a legend label, so colour is never the
only cue.

`inst/extdata/assessment_template.xlsx` is an Excel version of the entry sheet
with drop-down answers, question text in header comments, and sheets listing
the questions and algorithms.

## Quick start

```r
library(vitrob)

propose_domain("D1", c("1.1" = "Y", "1.3" = "N"))   # "Low"

write_template("my_assessments.csv")
x <- read_assessments("my_assessments.csv")
check_assessments(x)
propose_judgments(x)

ex <- read_assessments(system.file("extdata", "example_assessments.csv", package = "vitrob"))
plot_traffic(ex)
plot_summary(ex)
save_rob_plot(plot_gaps(ex), "gaps.png")
run_app()   # needs shiny; Excel upload needs readxl
```

`inst/extdata/example_assessments.csv` holds 12 fictional results (labelled
"Example study A" to "L") made by `tools/make_example.py`; they respect the
skip rules and are used in the tests.

## How the algorithms are verified

Two independent implementations must agree:

1. `tools/verify_algorithms.py` (Python) enumerates every valid answer profile
   in every domain (7,295 profiles) and every domain-judgment profile for the
   overall rule (957), checks five properties, and writes the reference files
   `inst/extdata/reference_judgments.csv`, `reference_overall.csv`,
   `verification_summary.csv` and `verification_report.md`.
2. The R tests (`tests/testthat`) recompute every judgment in R and require an
   exact match with those files, rerun the property checks in R, and require the
   same counts.

Properties checked: Low and High rules never both hold; skip logic is
consistent; all three judgments are reachable; a worse answer never gives a
better judgment; every question can change the judgment. The Python verifier
was itself tested by deliberately breaking rules, and it caught each break.

After any change to `tool.yaml`:

```sh
python3 tools/verify_algorithms.py      # must print PASSED
python3 tools/make_template.py          # rebuild the Excel template
```

then in R: `devtools::document(); devtools::test(); devtools::check()`.

## Citation

Please cite the tool paper and the package version you used:
`citation("vitrob")`. Each release is archived on Zenodo with its own DOI.

## Licences

Code: MIT. Tool content (`tool.yaml`, template): CC BY 4.0.
