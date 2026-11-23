full_row <- function(...) {
  spec <- tool_spec()
  cols <- assessment_columns(spec)
  row <- as.data.frame(as.list(setNames_(rep(NA_character_, length(cols)), cols)),
                       stringsAsFactors = FALSE, check.names = FALSE)
  vals <- list(...)
  for (n in names(vals)) row[[n]] <- vals[[n]]
  row
}
setNames_ <- function(x, nm) { names(x) <- nm; x }

# A complete, valid result: every domain Some concerns or Low.
valid_answers <- list(
  study_id = "S1", result_id = "Fig2A", B1 = "Y", B2 = "Y", B3 = "N",
  q1.1 = "NI", q1.2 = "N", q1.3 = "N",
  q2.1 = "Y", q2.2 = "NI", q2.3 = "N",
  q3.1 = "Y", q3.2 = "Y", q3.3 = "NI", q3.4 = "Y",
  q4.1 = "N", q4.2 = "N", q4.3 = "NI", q4.4 = "N",
  q5.1 = "Y", q5.5 = "Y", q5.6 = "Y",
  q6.1 = "N", q6.2 = "N", q6.3 = "N",
  O1 = "N"
)

test_that("a valid row has no issues and gets the expected proposals", {
  row <- do.call(full_row, valid_answers)
  expect_equal(nrow(check_assessments(row)), 0L)
  p <- propose_judgments(row)
  expect_identical(unname(unlist(p[1, paste0("D", 1:6, "_proposed")])),
                   c("Some concerns", "Some concerns", "Some concerns", "Low", "Low", "Some concerns"))
  expect_identical(p$overall_proposed, "Some concerns")
})

test_that("O1 = Y raises the overall judgment to High", {
  row <- do.call(full_row, modifyList(valid_answers, list(O1 = "Y")))
  expect_identical(propose_judgments(row)$overall_proposed, "High")
})

test_that("entry errors are flagged", {
  bad <- modifyList(valid_answers, list(
    q1.1 = "Y",          # makes 1.2 a skipped question, which is still answered
    q2.1 = "Maybe",      # invalid code
    q5.1 = "N", q5.2 = "NI",  # NI not allowed for 5.2
    D3_final = "Low"     # override without a reason
  ))
  issues <- check_assessments(do.call(full_row, bad))
  expect_true(any(issues$field == "q1.2" & grepl("skip", issues$problem)))
  expect_true(any(issues$field == "q2.1" & grepl("Invalid", issues$problem)))
  expect_true(any(issues$field == "q5.2" & grepl("Invalid", issues$problem)))
  expect_true(any(issues$field == "D3_reason"))
})

test_that("answers to skipped questions never change the judgment", {
  expect_identical(propose_domain("D1", c("1.1" = "Y", "1.2" = "Y", "1.3" = "N")), "Low")
})

test_that("rows stopped at the proceed check get no proposals", {
  row <- do.call(full_row, modifyList(valid_answers, list(B1 = "N")))
  expect_true(is.na(propose_judgments(row)$overall_proposed))
})
