#' Column names of the assessment table
#'
#' One row per assessed result. Signalling questions are columns named
#' `q<id>` (e.g. `q1.1`). Each domain has `<D>_final` and `<D>_reason`
#' columns for the assessor's final judgment and the reason for any
#' override; the proposed judgments are added by [propose_judgments()].
#'
#' @param spec A tool specification from [tool_spec()].
#' @return Character vector of column names.
#' @export
assessment_columns <- function(spec = tool_spec()) {
  d <- domain_ids(spec)
  c("study_id", "result_id", "assessor", "module",
    "B1", "B2", "B3",
    paste0("q", question_ids(spec)),
    paste0(d, "_final"), paste0(d, "_reason"),
    "O1", "overall_final", "overall_reason",
    "U1", "AP1", "AP2", "notes")
}

#' Write an empty assessment template (CSV)
#'
#' @param path File to write.
#' @param spec A tool specification from [tool_spec()].
#' @return `path`, invisibly.
#' @export
write_template <- function(path, spec = tool_spec()) {
  cols <- assessment_columns(spec)
  empty_cols <- rep(list(character(0)), length(cols))
  names(empty_cols) <- cols
  empty <- as.data.frame(empty_cols, stringsAsFactors = FALSE, check.names = FALSE)
  utils::write.csv(empty, path, row.names = FALSE, na = "")
  invisible(path)
}

#' Read completed assessments (CSV or Excel)
#'
#' @param path A CSV file in the layout of [write_template()], or an `.xlsx`
#'   file made from the package's Excel template (sheet "Assessments";
#'   needs the readxl package).
#' @return A data frame with every column as character; empty cells are `NA`.
#' @export
read_assessments <- function(path) {
  if (grepl("\\.xlsx?$", path, ignore.case = TRUE)) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Reading Excel files needs the readxl package: install.packages('readxl')",
           call. = FALSE)
    }
    sheets <- readxl::excel_sheets(path)
    sheet <- if ("Assessments" %in% sheets) "Assessments" else 1
    x <- as.data.frame(readxl::read_excel(path, sheet = sheet, col_types = "text"),
                       stringsAsFactors = FALSE, check.names = FALSE)
    x[] <- lapply(x, function(v) { v[!is.na(v) & trimws(v) == ""] <- NA_character_; v })
    keep <- rowSums(!is.na(x)) > 0  # drop the template's empty rows
    return(x[keep, , drop = FALSE])
  }
  utils::read.csv(path, colClasses = "character", na.strings = c("", "NA"),
                  check.names = FALSE, stringsAsFactors = FALSE)
}

row_answers <- function(row, spec) {
  ids <- question_ids(spec)
  cols <- paste0("q", ids)
  vals <- vapply(cols, function(cl) {
    if (cl %in% names(row)) as.character(row[[cl]]) else NA_character_
  }, character(1))
  names(vals) <- ids
  vals
}

stopped_at_gate <- function(row) {
  g <- function(x) if (x %in% names(row)) as.character(row[[x]]) else NA_character_
  isTRUE(g("B1") %in% c("N", "PN")) || isTRUE(g("B2") %in% c("N", "PN")) ||
    isTRUE(g("B3") %in% c("Y", "PY"))
}

#' Add proposed judgments to an assessment table
#'
#' For each row, adds `<D>_proposed` for every domain and
#' `overall_proposed`. The overall proposal uses the assessor's final domain
#' judgments where given, otherwise the proposed ones. Rows stopped at the
#' proceed check get `NA`.
#'
#' @param data A data frame from [read_assessments()].
#' @param spec A tool specification from [tool_spec()].
#' @return `data` with proposed-judgment columns added.
#' @export
propose_judgments <- function(data, spec = tool_spec()) {
  ids <- domain_ids(spec)
  prop <- matrix(NA_character_, nrow(data), length(ids),
                 dimnames = list(NULL, paste0(ids, "_proposed")))
  overall <- rep(NA_character_, nrow(data))
  for (i in seq_len(nrow(data))) {
    row <- data[i, , drop = FALSE]
    if (stopped_at_gate(row)) next
    a <- row_answers(row, spec)
    dj <- vapply(ids, function(id) propose_domain(id, a, spec), character(1))
    prop[i, ] <- dj
    final_cols <- paste0(ids, "_final")
    final <- vapply(seq_along(ids), function(k) {
      cl <- final_cols[k]
      v <- if (cl %in% names(row)) row[[cl]] else NA_character_
      if (is.na(v)) dj[[k]] else as.character(v)
    }, character(1))
    o1 <- if ("O1" %in% names(row)) row[["O1"]] else NA_character_
    overall[i] <- if (all(final %in% JUDGMENTS)) propose_overall(final, o1) else NA_character_
  }
  cbind(data, as.data.frame(prop, stringsAsFactors = FALSE),
        overall_proposed = overall, stringsAsFactors = FALSE)
}

#' Check an assessment table for entry errors
#'
#' Flags invalid answer codes, missing required answers, answers given to
#' questions that should have been skipped, O1 answered or missing
#' wrongly, invalid judgments, overrides without a reason, and overall
#' judgments lower than the worst domain judgment.
#'
#' @param data A data frame from [read_assessments()].
#' @param spec A tool specification from [tool_spec()].
#' @return A data frame of issues (`row`, `study_id`, `result_id`, `field`,
#'   `problem`); zero rows when nothing is wrong.
#' @export
check_assessments <- function(data, spec = tool_spec()) {
  issues <- list()
  add <- function(i, field, problem) {
    row <- data[i, , drop = FALSE]
    issues[[length(issues) + 1L]] <<- data.frame(
      row = i,
      study_id = if ("study_id" %in% names(row)) row[["study_id"]] else NA_character_,
      result_id = if ("result_id" %in% names(row)) row[["result_id"]] else NA_character_,
      field = field, problem = problem, stringsAsFactors = FALSE)
  }
  ids <- domain_ids(spec)
  props <- propose_judgments(data, spec)
  for (i in seq_len(nrow(data))) {
    row <- data[i, , drop = FALSE]
    for (b in c("B1", "B2", "B3")) {
      v <- if (b %in% names(row)) row[[b]] else NA_character_
      if (is.na(v)) add(i, b, "Proceed-check answer missing")
      else if (!v %in% c("Y", "PY", "PN", "N", "NI")) add(i, b, paste0("Invalid code '", v, "'"))
    }
    if (stopped_at_gate(row)) next
    for (d in spec$domains) {
      given <- list()
      for (q in d$questions) {
        cl <- paste0("q", q$id)
        v <- if (cl %in% names(row)) row[[cl]] else NA_character_
        applies <- is_applicable(q, given)
        if (applies) {
          if (is.na(v)) {
            add(i, cl, "Required answer missing")
          } else if (!v %in% question_options(q)) {
            add(i, cl, paste0("Invalid code '", v, "'; allowed: ",
                              paste(question_options(q), collapse = "/")))
          }
          given[[q$id]] <- v
        } else {
          if (!is.na(v)) add(i, cl, "Answered although the skip rule says this question is not asked")
          given[[q$id]] <- NA_character_
        }
      }
      fcl <- paste0(d$id, "_final")
      rcl <- paste0(d$id, "_reason")
      f <- if (fcl %in% names(row)) row[[fcl]] else NA_character_
      r <- if (rcl %in% names(row)) row[[rcl]] else NA_character_
      p <- props[i, paste0(d$id, "_proposed")]
      if (!is.na(f) && !f %in% JUDGMENTS) add(i, fcl, paste0("Invalid judgment '", f, "'"))
      if (!is.na(f) && !is.na(p) && f != p && is.na(r)) {
        add(i, rcl, paste0("Final judgment differs from proposed (", p, ") without a reason"))
      }
    }
    final <- vapply(ids, function(id) {
      f <- row[[paste0(id, "_final")]]
      if (is.null(f) || is.na(f)) props[i, paste0(id, "_proposed")] else f
    }, character(1))
    o1 <- if ("O1" %in% names(row)) row[["O1"]] else NA_character_
    if (all(final %in% JUDGMENTS)) {
      if (o1_applies(final) && is.na(o1)) add(i, "O1", "O1 must be answered (two or more domains are Some concerns, none High)")
      if (!o1_applies(final) && !is.na(o1)) add(i, "O1", "O1 answered although it is not asked")
      of <- if ("overall_final" %in% names(row)) row[["overall_final"]] else NA_character_
      if (!is.na(of)) {
        if (!of %in% JUDGMENTS) {
          add(i, "overall_final", paste0("Invalid judgment '", of, "'"))
        } else if (match(of, JUDGMENTS) < max(match(final, JUDGMENTS))) {
          add(i, "overall_final", "Overall judgment is lower than the worst domain judgment")
        } else if (of != props$overall_proposed[i] &&
                   (!"overall_reason" %in% names(row) || is.na(row[["overall_reason"]]))) {
          add(i, "overall_reason", "Overall judgment differs from proposed without a reason")
        }
      }
    }
  }
  if (length(issues) == 0L) {
    return(data.frame(row = integer(0), study_id = character(0), result_id = character(0),
                      field = character(0), problem = character(0), stringsAsFactors = FALSE))
  }
  do.call(rbind, issues)
}
