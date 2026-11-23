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
