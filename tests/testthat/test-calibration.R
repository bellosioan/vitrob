test_that("calibration scenarios in the guidance give the stated judgments", {
  sc <- utils::read.csv(system.file("extdata", "calibration_scenarios.csv", package = "vitrob"),
                        colClasses = "character", na.strings = "", check.names = FALSE)
  expect_gt(nrow(sc), 0L)
  qcols <- grep("^q", names(sc), value = TRUE)
  for (i in seq_len(nrow(sc))) {
    vals <- unlist(sc[i, qcols], use.names = FALSE)
    names(vals) <- sub("^q", "", qcols)
    vals <- vals[!is.na(vals)]
    expect_identical(propose_domain(sc$domain[[i]], vals), sc$expected[[i]],
                     info = sc$scenario[[i]])
  }
})

test_that("installed files match the release manifest", {
  man <- utils::read.csv(system.file("extdata", "release_manifest.csv", package = "vitrob"),
                         colClasses = "character", check.names = FALSE)
  expect_identical(man$value[man$item == "tool_version"], tool_spec()$tool$version)
  files <- man[startsWith(man$item, "md5:"), , drop = FALSE]
  expect_gt(nrow(files), 0L)
  for (k in seq_len(nrow(files))) {
    f <- sub("^md5:", "", files$item[[k]])
    got <- unname(tools::md5sum(system.file("extdata", f, package = "vitrob")))
    expect_identical(got, files$value[[k]], info = f)
  }
})
