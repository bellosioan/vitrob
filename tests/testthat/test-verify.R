test_that("every domain passes the exhaustive property checks, with the same counts as the Python verifier", {
  skip_on_cran()  # enumerates every answer profile; takes up to a minute
  v <- verify_algorithms()
  expect_true(all(v$passed))
  expect_true(all(v$dead_questions == ""))

  py <- utils::read.csv(system.file("extdata", "verification_summary.csv", package = "vitrob"),
                        stringsAsFactors = FALSE)
  m <- merge(v, py, by = "domain", suffixes = c("_r", "_py"))
  expect_equal(nrow(m), 6L)
  for (col in c("profiles", "low", "some_concerns", "high", "monotonicity_comparisons")) {
    expect_equal(m[[paste0(col, "_r")]], m[[paste0(col, "_py")]], info = col)
  }
})
