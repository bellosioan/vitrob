example <- function() {
  read_assessments(system.file("extdata", "example_assessments.csv", package = "vitrob"))
}

test_that("the example data has no entry errors and gives the reference judgments", {
  x <- example()
  expect_equal(nrow(check_assessments(x)), 0L)
  p <- propose_judgments(x)
  # Overall judgments computed independently by tools/make_example.py
  expect_identical(p$overall_proposed,
                   c("High", "High", "Some concerns", "High", "Some concerns", "Some concerns",
                     "High", "High", "High", "High", "High", NA))
})

test_that("every plot builds on the example data", {
  skip_if_not_installed("ggplot2")
  x <- example()
  plots <- list(
    suppressMessages(plot_traffic(x)),
    suppressMessages(plot_traffic(x, use = "proposed", palette = "cochrane")),
    suppressMessages(plot_summary(x)),
    suppressMessages(plot_questions(x)),
    suppressMessages(plot_gaps(x))
  )
  for (p in plots) {
    expect_s3_class(p, "ggplot")
    expect_error(ggplot2::ggplot_build(p), NA)
  }
})

test_that("plots can be saved", {
  skip_if_not_installed("ggplot2")
  f <- tempfile(fileext = ".png")
  save_rob_plot(suppressMessages(plot_summary(example())), f, height = 4, dpi = 72)
  expect_true(file.exists(f))
})
