# vitrob 0.3.0

Tool content: VITROB 1.0 release candidate 4 (rc.4), frozen for the pilot.

Changes from rc.3, after a third-round review (decision rules unchanged;
verification repeated):

* 2.3/2.4: runs, plates or donors randomly assigned to conditions are not an
  aligned factor; a single run per condition, or treated and control
  samples processed on different days, remain inseparable.
* 2.1 assesses the planned comparator; unplanned departures go to 3.2/3.5.
* 1.2 covers only integrity problems that differ between conditions; a
  shared contaminant that reduces exposure is assessed in 3.1, one that
  interferes with the assay in 4.2, and changed biology under AP2.
* Materiality rule stated in every question with a direct route to High.
* 3.1: insufficient knockdown counts only for a target-defined effect.
* 6.1 asks whether measurement and analysis were fixed independently of the
  results, by a plan or, exceptionally, by an established procedure.
* AP1 recorded as `AP1_authentication` and `AP1_register`;
  `propose_judgments()` adds `AP1_proposed` derived from them.
* New: `calibration_scenarios.csv` (13 boundary cases from the guidance,
  checked by `make_calibration.py` and test-calibration.R) and
  `release_manifest.csv` (versions and checksums, checked by a test).

Changes from rc.2 to rc.3:

* Template and `assessment_columns()`: preliminary fields A-F as columns
  (`A_target_outcome`, `A_measurement`, `A_manipulation`, `A_comparator`,
  `A_effect_measure`, `C_effect_of_interest`, `D_allocation_unit`,
  `D_replicate`, and optional D-F fields), defined in `result_fields` in
  tool.yaml. AP2 now has one column per component (`AP2_system`,
  `AP2_manipulation`, `AP2_comparator`, `AP2_outcome`).
* `propose_judgments()` adds `scope_status` (eligible / unresolved /
  stopped). An invalid O1 code now gives an `NA` overall proposal instead of
  being read as "not Y/PY".
* `check_assessments()` also flags missing required fields, invalid O1
  codes, and invalid U1, AP1 and AP2 entries.
* Fixed: test-reference.R asserted the rc.1 profile count (7,295); it now
  takes the count from verification_summary.csv (7,511).
* Wording: 1.2 limited to integrity problems linked to condition or acting
  on the manipulation or assay; 2.1 and 4.2 require a likely important
  distortion; 5.6 and U1 refer to the independent replicate; 6.3 again
  lists exclusion rules (selection among them); 6.1 allows PY for an
  external standard that fixes measurement and analysis.

Changes from rc.1 to rc.2:

* D3 algorithm: a failed process check (3.4 N/PN) no longer leads directly
  to High. It now leads to 3.5, which judges whether the problem was likely
  to affect the result (as for deviations in 3.1-3.3).
* Reworded so that the unfavourable answer requires a difference that could
  affect the result: 2.1, 4.2. Clarified 3.3 (decisions before the outcome is
  measured), 4.1 (target outcome), 6.3 (exclusions of data now assessed only
  in D5; stopping rules added).
* Scope: uncontrolled before-after and crossover designs excluded;
  concurrent-group experiments analysing change from baseline included.
* U1 outputs renamed: unit respected / unit not respected / unclear.

Earlier changes (rc.1):

* All references checked against their sources; full citations with DOIs.
* Fifteen signalling questions reworded in the tool's own words (domains
  4-6 had followed RoB 2 wording closely); meaning, direction and judgment
  rules unchanged.
* After a content check against the 405-item INVITES-IN item bank and a
  methodological review of that mapping:
  * B3 removed from the proceed check: a misidentified test system no
    longer stops the assessment. Eligibility of such results is decided at
    review level; identity is recorded in AP1.
  * 3.1 now asks whether the manipulation was kept out of the comparator
    units (carry-over, vapour transfer).
  * 5.5 criteria: normalising to a quantity changed by the manipulation
    answers N unless the effect of interest is defined per that quantity.
  * Scope: within-unit sequential designs are stated to be outside v1.0.
* The proceed check is now read from `tool.yaml`, not hard-coded.
* Download file names in the app start with `vitrob_`; the Excel template
  says it can be uploaded directly.

# vitrob 0.2.0

* Tool renamed VITROB; package renamed `vitrob`.
* New plots: `plot_traffic()`, `plot_summary()`, `plot_questions()`,
  `plot_gaps()`, with `save_rob_plot()`, `theme_rob()` and `rob_colours()`.
  Default palette is colour-blind safe; `palette = "cochrane"` gives
  green / amber / red.
* New point-and-click app: `run_app()`. Downloaded files are named
  `vitrob_*`.
* `read_assessments()` reads the Excel template as well as CSV; the
  template's instructions say so.
* Example data (`inst/extdata/example_assessments.csv`) and a getting-started
  vignette.
* First version tested in R: all tests pass and `R CMD check --as-cran`
  gives 0 errors, 0 warnings, 0 notes.

# vitrob 0.1.0

* First development version: tool specification (`tool.yaml`), algorithms,
  assessment templates, entry checks and exhaustive algorithm verification
  against an independent Python implementation.
