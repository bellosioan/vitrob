JUDGMENTS <- c("Low", "Some concerns", "High")

# Environment in which rule expressions are evaluated. Only yes(), no() and
# ni() are added; operators come from base R.
answer_env <- function(answers) {
  get_answer <- function(q) {
    if (is.null(answers) || !(q %in% names(answers))) return(NA_character_)
    v <- answers[[q]]
    if (length(v) == 0L || is.na(v)) NA_character_ else as.character(v)
  }
  env <- new.env(parent = baseenv())
  env$yes <- function(q) { v <- get_answer(q); !is.na(v) && v %in% c("Y", "PY") }
  env$no  <- function(q) { v <- get_answer(q); !is.na(v) && v %in% c("N", "PN") }
  env$ni  <- function(q) { v <- get_answer(q); !is.na(v) && v == "NI" }
  env
}

eval_rule <- function(expr, answers) {
  isTRUE(eval(expr, envir = answer_env(answers)))
}

is_applicable <- function(q, answers) {
  if (is.null(q$parsed_ask_if)) TRUE else eval_rule(q$parsed_ask_if, answers)
}

# Keep only answers to questions that apply, walking the questions in order,
# so an answer given to a skipped question can never affect the judgment.
clean_answers <- function(domain, answers) {
  answers <- as.list(answers)
  out <- list()
  for (q in domain$questions) {
    if (is_applicable(q, out)) {
      v <- answers[[q$id]]
      out[[q$id]] <- if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
    } else {
      out[[q$id]] <- NA_character_
    }
  }
  unlist(out)
}

#' Propose a domain judgment
#'
#' Applies the domain's algorithm to the signalling-question answers.
#' Answers to questions that should have been skipped are ignored.
#'
#' @param domain Domain identifier, e.g. `"D1"`.
#' @param answers Named character vector or list, names are question ids
#'   (e.g. `c("1.1" = "Y", "1.3" = "N")`), values are `Y`, `PY`, `PN`, `N`
#'   or `NI`.
#' @param spec A tool specification from [tool_spec()].
#' @return `"Low"`, `"Some concerns"` or `"High"`.
#' @export
#' @examples
#' propose_domain("D1", c("1.1" = "Y", "1.3" = "N"))
propose_domain <- function(domain, answers, spec = tool_spec()) {
  d <- if (is.character(domain)) get_domain(spec, domain) else domain
  a <- clean_answers(d, answers)
  low <- eval_rule(d$parsed_rules$low, a)
  high <- eval_rule(d$parsed_rules$high, a)
  if (low && high) {
    stop("Rules for ", d$id, " give both Low and High for these answers; ",
         "the tool specification is inconsistent.", call. = FALSE)
  }
  if (high) "High" else if (low) "Low" else "Some concerns"
}

#' Is question O1 asked?
#' @param domain_judgments Character vector of domain judgments.
#' @return `TRUE` when two or more domains are Some concerns and none is High.
#' @export
o1_applies <- function(domain_judgments) {
  j <- as.character(domain_judgments)
  sum(j == "Some concerns") >= 2L && !any(j == "High")
}

#' Propose the overall judgment
#'
#' Low if all domains are Low; High if any domain is High or if O1 is Y/PY;
#' otherwise Some concerns (RoB 2 overall rule made explicit through O1).
#'
#' @param domain_judgments Character vector of the six domain judgments.
#' @param o1 Answer to O1, or `NA` when not asked.
#' @return `"Low"`, `"Some concerns"` or `"High"`.
#' @export
propose_overall <- function(domain_judgments, o1 = NA_character_) {
  j <- as.character(domain_judgments)
  if (anyNA(j) || !all(j %in% JUDGMENTS)) {
    stop("Domain judgments must be Low, Some concerns or High.", call. = FALSE)
  }
  if (any(j == "High")) return("High")
  if (all(j == "Low")) return("Low")
  if (o1_applies(j) && !is.na(o1) && o1 %in% c("Y", "PY")) return("High")
  "Some concerns"
}

#' Assess one result
#'
#' @param answers Named vector or list of answers for all questions.
#' @param o1 Answer to O1, or `NA`.
#' @param spec A tool specification from [tool_spec()].
#' @return A named character vector: one proposed judgment per domain and
#'   `overall`.
#' @export
#' @examples
#' a <- c("1.1" = "NI", "1.2" = "N", "1.3" = "N",
#'        "2.1" = "Y", "2.2" = "NI", "2.3" = "N",
#'        "3.1" = "Y", "3.2" = "Y", "3.3" = "NI", "3.4" = "Y",
#'        "4.1" = "N", "4.2" = "N", "4.3" = "NI", "4.4" = "N",
#'        "5.1" = "Y", "5.5" = "Y", "5.6" = "Y",
#'        "6.1" = "N", "6.2" = "N", "6.3" = "N")
#' assess_result(a)
assess_result <- function(answers, o1 = NA_character_, spec = tool_spec()) {
  ids <- domain_ids(spec)
  dj <- vapply(ids, function(id) propose_domain(id, answers, spec), character(1))
  c(dj, overall = propose_overall(dj, o1))
}
