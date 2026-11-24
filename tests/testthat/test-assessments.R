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
  study_id = "S1", result_id = "Fig2A",
  A_target_outcome = "IL-6 secreted", A_measurement = "ELISA",
  A_manipulation = "Compound X 10 uM", A_comparator = "0.1% DMSO",
  A_effect_measure = "Ratio of means", C_effect_of_interest = "Applying",
  D_allocation_unit = "Well", D_replicate = "Run",
  B1 = "Y", B2 = "Y",
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

test_that("a failed process check is judged by its consequence (3.5)", {
  minor <- do.call(full_row, modifyList(valid_answers, list(q3.4 = "N", q3.5 = "N")))
  expect_equal(nrow(check_assessments(minor)), 0L)
  expect_identical(propose_judgments(minor)$D3_proposed, "Some concerns")
  major <- do.call(full_row, modifyList(valid_answers, list(q3.4 = "N", q3.5 = "Y")))
  expect_identical(propose_judgments(major)$D3_proposed, "High")
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

test_that("invalid O1, U1, AP1 and AP2 entries and missing fields are flagged", {
  bad <- modifyList(valid_answers, list(
    O1 = "Maybe", U1 = "valid", AP1 = "Checked", AP2_system = "Partly",
    A_target_outcome = NA_character_, C_effect_of_interest = "Both"
  ))
  row <- do.call(full_row, bad)
  issues <- check_assessments(row)
  for (f in c("O1", "U1", "AP1", "AP2_system", "A_target_outcome", "C_effect_of_interest")) {
    expect_true(any(issues$field == f), info = f)
  }
  # An invalid O1 code must not be read as "not Y/PY".
  expect_true(is.na(propose_judgments(row)$overall_proposed))
})

test_that("AP1 is derived from authentication and register components", {
  ap1 <- function(a, r) {
    propose_judgments(do.call(full_row, modifyList(valid_answers,
      list(AP1_authentication = a, AP1_register = r))))$AP1_proposed
  }
  expect_identical(ap1("Confirms declared identity", "Not listed"), "Verified")
  expect_identical(ap1("Confirms declared identity", "Listed"), "Verified")
  expect_identical(ap1("Not reported", "Listed"), "Listed as misidentified")
  expect_identical(ap1("Not reported", "Not applicable"), "Not verified")
  expect_true(is.na(ap1(NA_character_, NA_character_)))
  bad <- do.call(full_row, modifyList(valid_answers, list(AP1_register = "Maybe")))
  expect_true(any(check_assessments(bad)$field == "AP1_register"))
})

test_that("scope status is derived from the proceed check", {
  st <- function(b1, b2) {
    propose_judgments(do.call(full_row, modifyList(valid_answers, list(B1 = b1, B2 = b2))))$scope_status
  }
  expect_identical(st("Y", "PY"), "eligible")
  expect_identical(st("Y", "NI"), "unresolved")
  expect_identical(st("PN", "NI"), "stopped")
})

test_that("answers to skipped questions never change the judgment", {
  expect_identical(propose_domain("D1", c("1.1" = "Y", "1.2" = "Y", "1.3" = "N")), "Low")
})

test_that("rows stopped at the proceed check get no proposals", {
  row <- do.call(full_row, modifyList(valid_answers, list(B1 = "N")))
  expect_true(is.na(propose_judgments(row)$overall_proposed))
})
