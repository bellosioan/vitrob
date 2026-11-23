ref_file <- function(name) system.file("extdata", name, package = "vitrob")

test_that("domain judgments match the independent Python reference for every answer profile", {
  spec <- tool_spec()
  ref <- utils::read.csv(ref_file("reference_judgments.csv"), colClasses = "character",
                         na.strings = "", check.names = FALSE)
  qcols <- grep("^q", names(ref), value = TRUE)
  got <- vapply(seq_len(nrow(ref)), function(i) {
    vals <- unlist(ref[i, qcols], use.names = FALSE)
    names(vals) <- sub("^q", "", qcols)
    keep <- !is.na(vals) & vals != "NA"
    propose_domain(ref$domain[[i]], vals[keep], spec)
  }, character(1))
  mismatch <- which(got != ref$proposed)
  expect_length(mismatch, 0)
  expect_equal(nrow(ref), 7295L)
})

test_that("overall judgments match the reference for every domain-judgment profile", {
  ref <- utils::read.csv(ref_file("reference_overall.csv"), colClasses = "character",
                         check.names = FALSE)
  dcols <- paste0("D", 1:6)
  got <- vapply(seq_len(nrow(ref)), function(i) {
    o1 <- ref$O1[[i]]
    propose_overall(unlist(ref[i, dcols], use.names = FALSE),
                    if (identical(o1, "NA")) NA_character_ else o1)
  }, character(1))
  expect_identical(got, ref$overall)
})
