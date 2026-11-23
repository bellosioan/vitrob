BADNESS <- list(
  good = c(Y = 0, PY = 0, NI = 1, PN = 2, N = 2),
  problem = c(N = 0, PN = 0, NI = 1, PY = 2, Y = 2)
)

# All answer profiles for a domain that respect its skip logic. `fixed`
# pins answers for questions that apply (used for monotonicity checks).
enumerate_profiles <- function(domain, fixed = NULL) {
  qs <- domain$questions
  out <- list()
  rec <- function(k, answers) {
    if (k > length(qs)) {
      out[[length(out) + 1L]] <<- answers
      return(invisible())
    }
    q <- qs[[k]]
    if (is_applicable(q, answers)) {
      pinned <- if (!is.null(fixed) && q$id %in% names(fixed)) fixed[[q$id]] else NA_character_
      choices <- if (!is.na(pinned)) pinned else question_options(q)
      for (opt in choices) {
        a <- answers
        a[[q$id]] <- opt
        rec(k + 1L, a)
      }
    } else {
      a <- answers
      a[[q$id]] <- NA_character_
      rec(k + 1L, a)
    }
  }
  rec(1L, list())
  lapply(out, unlist)
}

judge_raw <- function(domain, answers) {
  low <- eval_rule(domain$parsed_rules$low, answers)
  high <- eval_rule(domain$parsed_rules$high, answers)
  if (low && high) NA_character_ else if (high) "High" else if (low) "Low" else "Some concerns"
}

#' Verify the algorithms exhaustively
#'
#' Enumerates every valid answer profile for every domain and checks that
#' (1) no profile satisfies both the Low and the High rule, (2) skip logic is
#' consistent, (3) Low, Some concerns and High are all reachable, (4) a worse
#' answer never gives a better judgment, and (5) every question can change
#' the judgment. The same checks are run by an independent Python
#' implementation (`tools/verify_algorithms.py`).
#'
#' @param spec A tool specification from [tool_spec()].
#' @return A data frame with one row per domain.
#' @export
verify_algorithms <- function(spec = tool_spec()) {
  res <- lapply(spec$domains, function(d) {
    profiles <- enumerate_profiles(d)
    judged <- vapply(profiles, function(p) judge_raw(d, p), character(1))
    exclusive <- !anyNA(judged)
    skip_ok <- all(vapply(profiles, function(p) {
      all(vapply(d$questions, function(q) {
        is_applicable(q, as.list(p)) == !is.na(p[[q$id]])
      }, logical(1)))
    }, logical(1)))
    counts <- table(factor(judged, levels = JUDGMENTS))
    reachable <- all(counts > 0)

    mono_ok <- TRUE
    comparisons <- 0L
    influential <- set_names(rep(FALSE, length(d$questions)),
                            vapply(d$questions, function(q) q$id, character(1)))
    for (k in seq_along(profiles)) {
      p <- profiles[[k]]
      jp <- judged[[k]]
      for (q in d$questions) {
        cur <- p[[q$id]]
        if (is.na(cur)) next
        bad <- BADNESS[[q$polarity]]
        for (opt in question_options(q)) {
          if (opt == cur) next
          fixed <- as.list(p)
          fixed[[q$id]] <- opt
          for (b in enumerate_profiles(d, fixed)) {
            jb <- judge_raw(d, b)
            if (!identical(jb, jp)) influential[[q$id]] <- TRUE
            if (bad[[opt]] > bad[[cur]]) {
              comparisons <- comparisons + 1L
              if (!is.na(jb) && !is.na(jp) &&
                  match(jb, JUDGMENTS) < match(jp, JUDGMENTS)) mono_ok <- FALSE
            }
          }
        }
      }
    }
    data.frame(
      domain = as.character(d$id),
      profiles = length(profiles),
      low = as.integer(counts[["Low"]]),
      some_concerns = as.integer(counts[["Some concerns"]]),
      high = as.integer(counts[["High"]]),
      exclusive = exclusive,
      skip_logic_consistent = skip_ok,
      all_judgments_reachable = reachable,
      monotonic = mono_ok,
      monotonicity_comparisons = comparisons,
      dead_questions = paste(names(influential)[!influential], collapse = ", "),
      passed = exclusive && skip_ok && reachable && mono_ok && all(influential),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, res)
}

set_names <- function(object, nm) {
  names(object) <- nm
  object
}
