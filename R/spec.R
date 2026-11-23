#' Load the tool specification
#'
#' Reads the YAML file that defines every signalling question, its skip
#' logic, answer guidance, rationale and references, and the domain and
#' overall algorithms. The copy shipped with the package is used unless a
#' path is given.
#'
#' @param path Optional path to a `tool.yaml` file.
#' @return A list of class `rob_tool_spec`.
#' @export
tool_spec <- function(path = NULL) {
  if (is.null(path)) {
    path <- system.file("extdata", "tool.yaml", package = "vitrob")
    if (!nzchar(path)) {
      stop("tool.yaml was not found in the installed package.", call. = FALSE)
    }
  }
  spec <- yaml::read_yaml(path)
  # Pre-parse the rule strings once; they are evaluated many times.
  for (i in seq_along(spec$domains)) {
    d <- spec$domains[[i]]
    d$parsed_rules <- list(
      low = str2lang(d$rules$low),
      high = str2lang(d$rules$high)
    )
    for (k in seq_along(d$questions)) {
      q <- d$questions[[k]]
      q$id <- as.character(q$id)
      if (!is.null(q$ask_if)) q$parsed_ask_if <- str2lang(q$ask_if)
      d$questions[[k]] <- q
    }
    spec$domains[[i]] <- d
  }
  class(spec) <- c("rob_tool_spec", "list")
  spec
}

#' Domain identifiers
#' @param spec A tool specification from [tool_spec()].
#' @return Character vector, e.g. `"D1"`.
#' @export
domain_ids <- function(spec = tool_spec()) {
  vapply(spec$domains, function(d) as.character(d$id), character(1))
}

#' Signalling-question identifiers
#' @param spec A tool specification from [tool_spec()].
#' @param domain Optional domain identifier; all domains if `NULL`.
#' @return Character vector, e.g. `"1.1"`.
#' @export
question_ids <- function(spec = tool_spec(), domain = NULL) {
  doms <- if (is.null(domain)) spec$domains else list(get_domain(spec, domain))
  unlist(lapply(doms, function(d) {
    vapply(d$questions, function(q) as.character(q$id), character(1))
  }), use.names = FALSE)
}

#' Questions as a table
#'
#' One row per signalling question with its text, skip condition, answer
#' guidance, rationale, derivation and reference keys. Useful for building
#' forms or checking the tool against its documentation.
#'
#' @param spec A tool specification from [tool_spec()].
#' @return A data frame.
#' @export
questions_table <- function(spec = tool_spec()) {
  rows <- list()
  for (d in spec$domains) {
    for (q in d$questions) {
      rows[[length(rows) + 1L]] <- data.frame(
        domain = as.character(d$id),
        domain_name = d$name,
        id = q$id,
        short = if (is.null(q$short)) NA_character_ else q$short,
        text = q$text,
        ask_if = if (is.null(q$ask_if)) NA_character_ else q$ask_if,
        polarity = q$polarity,
        options = paste(question_options(q), collapse = "/"),
        y_when = q$y_when,
        n_when = q$n_when,
        rationale = q$rationale,
        derived_from = q$derived_from,
        references = paste(unlist(q$references), collapse = "; "),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

get_domain <- function(spec, id) {
  for (d in spec$domains) if (identical(as.character(d$id), id)) return(d)
  stop("Unknown domain: ", id, call. = FALSE)
}

question_options <- function(q) {
  if (!is.null(q$options)) as.character(unlist(q$options))
  else c("Y", "PY", "PN", "N", "NI")
}
