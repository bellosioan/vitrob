# Releasing vitrob

## Every change
1. Edit `inst/extdata/tool.yaml` (content) or `R/` (code).
2. If `tool.yaml` changed: `python3 tools/verify_algorithms.py` (must print
   PASSED), `python3 tools/make_template.py`, and if needed
   `python3 tools/make_example.py`.
3. In R: `devtools::document()`, `devtools::test()`, `devtools::check()`
   (0 errors, 0 warnings, 0 notes).
4. Add a line to `NEWS.md`. Push. Both GitHub checks must be green.

## A release (new Zenodo DOI)
1. Set the same version in `DESCRIPTION`, `CITATION.cff` (`version`,
   `date-released`) and `NEWS.md`.
2. Push; wait for green checks.
3. On GitHub: Releases -> Draft a new release -> tag `v<version>` -> Publish.
   Zenodo archives it and issues a version DOI.
4. The first time only: add the Zenodo concept DOI (the one that always points
   to the latest version) to `README.md`, `CITATION.cff` (`doi:`) and
   `inst/CITATION`.

## CRAN (when ready)
1. `devtools::check_win_devel()` and `devtools::check_mac_release()`; wait
   for the emailed results.
2. Write `cran-comments.md` (test environments and check results).
3. `devtools::submit_cran()`, then confirm the emailed link.
