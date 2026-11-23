# Colour, symbols and theme -------------------------------------------------

#' Colours used in the plots
#'
#' `"accessible"` (default) uses blue / amber / red, which stays
#' distinguishable for the common forms of colour-vision deficiency.
#' `"cochrane"` uses the conventional green / amber / red. In both, every
#' judgment also carries a symbol (+, minus, x) and a text label, so colour is
#' never the only cue.
#'
#' @param palette `"accessible"` or `"cochrane"`.
#' @return Named character vector of hex colours.
#' @export
rob_colours <- function(palette = c("accessible", "cochrane")) {
  palette <- match.arg(palette)
  judg <- switch(palette,
    accessible = c("Low" = "#2a78d6", "Some concerns" = "#eda100", "High" = "#d03b3b"),
    cochrane   = c("Low" = "#0ca30c", "Some concerns" = "#fab219", "High" = "#d03b3b")
  )
  c(judg,
    "No information" = "#a8a7a1",
    "Not asked" = "#f0efec",
    gap_bar = "#77766f",
    ink = "#0b0b0b", secondary = "#52514e", grid = "#e6e5e1", surface = "#fcfcfb")
}

judgment_symbol <- function(j) {
  out <- c("Low" = "+", "Some concerns" = "\u2212", "High" = "\u00d7")[as.character(j)]
  unname(ifelse(is.na(out), "", out))
}

# Text that sits on a coloured mark: white on dark fills, ink on light ones.
on_fill <- function(category, cols) {
  light <- c("Some concerns", "No information", "Not asked")
  unname(ifelse(as.character(category) %in% light, cols[["ink"]], "#ffffff"))
}

judgment_labels <- function() {
  c("Low" = "+  Low", "Some concerns" = "\u2212  Some concerns", "High" = "\u00d7  High")
}

#' Plot theme
#' @param base_size Base font size in points.
#' @return A ggplot2 theme.
#' @export
theme_rob <- function(base_size = 11) {
  cols <- rob_colours()
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = cols[["ink"]]),
      axis.text = ggplot2::element_text(colour = cols[["secondary"]]),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = cols[["grid"]], linewidth = 0.3),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.caption = ggplot2::element_text(hjust = 0, colour = cols[["secondary"]],
                                           size = ggplot2::rel(0.8)),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0),
      plot.background = ggplot2::element_rect(fill = cols[["surface"]], colour = NA)
    )
}

# Data preparation ------------------------------------------------------------

result_label <- function(data) {
  s <- if ("study_id" %in% names(data)) data$study_id else paste("Row", seq_len(nrow(data)))
  r <- if ("result_id" %in% names(data)) data$result_id else NA_character_
  ifelse(is.na(r) | r == "", s, paste0(s, " (", r, ")"))
}

ensure_proposed <- function(data, spec) {
  need <- c(paste0(domain_ids(spec), "_proposed"), "overall_proposed")
  if (all(need %in% names(data))) data else propose_judgments(data, spec)
}

domain_short <- function(spec) {
  vapply(spec$domains, function(d) {
    paste(d$id, if (is.null(d$short)) d$name else d$short)
  }, character(1))
}

#' Judgments in long format
#'
#' One row per result and domain (plus `Overall`), using the assessor's final
#' judgment where given and the proposed judgment otherwise
#' (`use = "final"`), or the proposed judgment only (`use = "proposed"`).
#' Results stopped at the proceed check are dropped.
#'
#' @param data Assessment table (from [read_assessments()]).
#' @param spec A tool specification from [tool_spec()].
#' @param use `"final"` or `"proposed"`.
#' @return A data frame with columns `label`, `domain`, `domain_label`,
#'   `judgment` (factor) and `row`.
#' @export
judgments_long <- function(data, spec = tool_spec(), use = c("final", "proposed")) {
  use <- match.arg(use)
  data <- ensure_proposed(data, spec)
  keep <- !is.na(data$overall_proposed)
  if (any(!keep)) {
    message(sum(!keep), " result(s) stopped at the proceed check were left out.")
  }
  data <- data[keep, , drop = FALSE]
  ids <- c(domain_ids(spec), "Overall")
  labs <- c(domain_short(spec), "Overall")
  pick <- function(id) {
    stem <- if (id == "Overall") "overall" else id
    prop <- data[[paste0(stem, "_proposed")]]
    fin <- data[[paste0(stem, "_final")]]
    if (use == "proposed" || is.null(fin)) return(prop)
    ifelse(is.na(fin) | fin == "", prop, fin)
  }
  label <- result_label(data)
  out <- do.call(rbind, lapply(seq_along(ids), function(k) {
    data.frame(row = seq_len(nrow(data)), label = label, domain = ids[k],
               domain_label = labs[k], judgment = pick(ids[k]),
               stringsAsFactors = FALSE)
  }))
  out$judgment <- factor(out$judgment, levels = JUDGMENTS)
  out$domain <- factor(out$domain, levels = ids)
  out$domain_label <- factor(out$domain_label, levels = labs)
  out$label <- factor(out$label, levels = rev(unique(label)))
  out
}

# Domain names under the traffic-light plot, three per line.
domain_caption <- function(domain_label) {
  labs <- setdiff(levels(domain_label), "Overall")
  lines <- split(labs, ceiling(seq_along(labs) / 3))
  paste(vapply(lines, paste, character(1), collapse = "    "), collapse = "\n")
}

# Plots -----------------------------------------------------------------------

#' Traffic-light plot
#'
#' One row per result, one column per domain plus the overall judgment.
#' Each judgment is shown by colour, symbol and legend label.
#'
#' @inheritParams judgments_long
#' @param palette `"accessible"` (default) or `"cochrane"`; see [rob_colours()].
#' @param point_size Point size.
#' @return A ggplot object.
#' @export
#' @examples
#' x <- read_assessments(system.file("extdata", "example_assessments.csv",
#'                                   package = "vitrob"))
#' plot_traffic(x)
plot_traffic <- function(data, spec = tool_spec(), use = c("final", "proposed"),
                         palette = c("accessible", "cochrane"), point_size = 7) {
  use <- match.arg(use)
  cols <- rob_colours(match.arg(palette))
  long <- judgments_long(data, spec, use)
  long$symbol <- judgment_symbol(long$judgment)
  long$symbol_colour <- on_fill(long$judgment, cols)
  ggplot2::ggplot(long, ggplot2::aes(x = domain, y = label)) +
    ggplot2::geom_point(ggplot2::aes(fill = judgment), shape = 21, size = point_size,
                        colour = cols[["surface"]], stroke = 0.8) +
    ggplot2::geom_text(ggplot2::aes(label = symbol, colour = symbol_colour),
                       size = point_size * 0.55, fontface = "bold") +
    ggplot2::scale_fill_manual(values = cols[JUDGMENTS], labels = judgment_labels(),
                               drop = FALSE, na.translate = FALSE) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(x = NULL, y = NULL, caption = domain_caption(long$domain_label)) +
    theme_rob() +
    ggplot2::theme(panel.grid.major = ggplot2::element_blank(),
                   axis.text.x = ggplot2::element_text(face = "bold", colour = cols[["ink"]]))
}

#' Summary plot of judgments by domain
#'
#' Share of results judged Low, Some concerns and High in each domain and
#' overall. Shares of 8% or more are labelled in the bars.
#'
#' @inheritParams plot_traffic
#' @param weight Optional name of a numeric column in `data` (e.g. a
#'   meta-analysis weight) used to weight the shares.
#' @return A ggplot object.
#' @export
plot_summary <- function(data, spec = tool_spec(), use = c("final", "proposed"),
                         palette = c("accessible", "cochrane"), weight = NULL) {
  use <- match.arg(use)
  cols <- rob_colours(match.arg(palette))
  long <- judgments_long(data, spec, use)
  w <- rep(1, nrow(long))
  if (!is.null(weight)) {
    keep_rows <- which(!is.na(ensure_proposed(data, spec)$overall_proposed))
    wv <- suppressWarnings(as.numeric(data[[weight]]))[keep_rows]
    if (anyNA(wv)) stop("Column '", weight, "' must be numeric with no missing values.", call. = FALSE)
    w <- wv[long$row]
  }
  agg <- stats_sum(w, long$domain_label, long$judgment)
  totals <- tapply(agg$total, agg$domain_label, sum)
  agg$share <- agg$total / as.numeric(totals[agg$domain_label])
  agg$share[is.nan(agg$share)] <- 0
  agg$text <- ifelse(agg$share >= 0.08, paste0(round(100 * agg$share), "%"), "")
  agg$text_colour <- on_fill(agg$judgment, cols)
  agg$domain_label <- factor(agg$domain_label, levels = rev(levels(long$domain_label)))
  ggplot2::ggplot(agg, ggplot2::aes(x = share, y = domain_label, fill = judgment)) +
    ggplot2::geom_col(width = 0.62, colour = cols[["surface"]], linewidth = 0.6,
                      position = ggplot2::position_stack(reverse = TRUE)) +
    ggplot2::geom_text(ggplot2::aes(label = text, colour = text_colour), size = 3.3,
                       position = ggplot2::position_stack(vjust = 0.5, reverse = TRUE)) +
    ggplot2::scale_fill_manual(values = cols[JUDGMENTS], labels = judgment_labels(), drop = FALSE) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"),
                                expand = c(0, 0), breaks = c(0, 0.25, 0.5, 0.75, 1)) +
    ggplot2::labs(x = if (is.null(weight)) "Share of results" else "Weighted share of results",
                  y = NULL) +
    theme_rob() +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}

# Sum weights by two factors without dropping empty combinations.
stats_sum <- function(w, f1, f2) {
  g <- expand.grid(domain_label = levels(f1), judgment = levels(f2), stringsAsFactors = FALSE)
  g$total <- vapply(seq_len(nrow(g)), function(i) {
    sum(w[as.character(f1) == g$domain_label[i] & as.character(f2) %in% g$judgment[i]])
  }, numeric(1))
  g$judgment <- factor(g$judgment, levels = levels(f2))
  g
}

answers_long <- function(data, spec) {
  data <- ensure_proposed(data, spec)
  data <- data[!is.na(data$overall_proposed), , drop = FALSE]
  label <- result_label(data)
  rows <- list()
  for (d in spec$domains) {
    for (q in d$questions) {
      cl <- paste0("q", q$id)
      v <- if (cl %in% names(data)) as.character(data[[cl]]) else rep(NA_character_, nrow(data))
      v[!is.na(v) & v == ""] <- NA_character_
      good <- q$polarity == "good"
      category_v <- ifelse(is.na(v), "Not asked",
             ifelse(v == "NI", "No information",
             ifelse(v %in% c("Y", "PY"), if (good) "Favourable" else "Unfavourable",
                    if (good) "Unfavourable" else "Favourable")))
      rows[[length(rows) + 1L]] <- data.frame(
        label = label, domain = paste(d$id, if (is.null(d$short)) "" else d$short),
        question = q$id, short = if (is.null(q$short)) q$id else q$short,
        answer = ifelse(is.na(v), "", v), category = category_v, stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, rows)
  out$label <- factor(out$label, levels = rev(unique(label)))
  out$domain <- factor(out$domain, levels = unique(out$domain))
  out$question <- factor(out$question, levels = unique(out$question))
  out
}

#' Heatmap of signalling-question answers
#'
#' One row per result, one column per signalling question, grouped by
#' domain. Cells show the answer code and are coloured by whether the
#' answer points towards low risk (favourable), high risk (unfavourable) or
#' no information, taking each question's polarity into account.
#'
#' @inheritParams plot_traffic
#' @return A ggplot object.
#' @export
plot_questions <- function(data, spec = tool_spec(), palette = c("accessible", "cochrane")) {
  cols <- rob_colours(match.arg(palette))
  long <- answers_long(data, spec)
  levels_cat <- c("Favourable", "No information", "Unfavourable", "Not asked")
  long$category <- factor(long$category, levels = levels_cat)
  fills <- c("Favourable" = cols[["Low"]], "No information" = cols[["No information"]],
             "Unfavourable" = cols[["High"]], "Not asked" = cols[["Not asked"]])
  long$text_colour <- ifelse(long$category %in% c("Favourable", "Unfavourable"),
                             "#ffffff", cols[["ink"]])
  ggplot2::ggplot(long, ggplot2::aes(x = question, y = label, fill = category)) +
    ggplot2::geom_tile(colour = cols[["surface"]], linewidth = 0.8) +
    ggplot2::geom_text(ggplot2::aes(label = answer, colour = text_colour), size = 2.8) +
    ggplot2::facet_grid(. ~ domain, scales = "free_x", space = "free_x",
                        labeller = ggplot2::label_wrap_gen(width = 14)) +
    ggplot2::scale_fill_manual(values = fills, drop = FALSE) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(x = NULL, y = NULL,
                  caption = "Favourable / unfavourable take each question's polarity into account. Blank cells: question not asked under the skip rules.") +
    theme_rob(base_size = 10) +
    ggplot2::theme(panel.grid.major = ggplot2::element_blank(),
                   panel.spacing.x = ggplot2::unit(6, "pt"))
}

#' Reporting gaps: share of "No information" answers
#'
#' For each signalling question, the share of results (among those for which
#' the question was asked) answered NI. High bars show where primary studies
#' most often fail to report what the tool needs.
#'
#' @inheritParams plot_traffic
#' @return A ggplot object.
#' @export
plot_gaps <- function(data, spec = tool_spec()) {
  cols <- rob_colours()
  long <- answers_long(data, spec)
  asked <- long[long$category != "Not asked", , drop = FALSE]
  keys <- unique(long[, c("domain", "question", "short")])
  keys$asked <- vapply(seq_len(nrow(keys)), function(i) {
    sum(asked$question == keys$question[i])
  }, numeric(1))
  keys$ni <- vapply(seq_len(nrow(keys)), function(i) {
    sum(asked$question == keys$question[i] & asked$category == "No information")
  }, numeric(1))
  keys$share <- ifelse(keys$asked > 0, keys$ni / keys$asked, NA_real_)
  keys$text <- ifelse(is.na(keys$share), "not asked",
                      paste0(round(100 * keys$share), "% (", keys$ni, "/", keys$asked, ")"))
  keys$item <- factor(paste(keys$question, keys$short),
                      levels = rev(paste(keys$question, keys$short)))
  keys$share0 <- ifelse(is.na(keys$share), 0, keys$share)
  ggplot2::ggplot(keys, ggplot2::aes(x = share0, y = item)) +
    ggplot2::geom_col(fill = cols[["gap_bar"]], width = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = text), hjust = -0.08, size = 3,
                       colour = cols[["secondary"]]) +
    ggplot2::facet_grid(domain ~ ., scales = "free_y", space = "free_y",
                        labeller = ggplot2::label_wrap_gen(width = 16)) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"),
                                limits = c(0, 1.25), breaks = c(0, 0.25, 0.5, 0.75, 1),
                                expand = c(0, 0)) +
    ggplot2::labs(x = "Share of results answered \"No information\"", y = NULL) +
    theme_rob() +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                   strip.text.y = ggplot2::element_text(angle = 0, hjust = 0))
}

#' Save a plot with sensible defaults
#'
#' @param plot A ggplot object.
#' @param file File name; the extension sets the format (png, pdf, svg, tiff).
#' @param width,height Size in inches. Height defaults to a value based on
#'   the number of rows in the plot.
#' @param dpi Resolution for raster formats.
#' @return `file`, invisibly.
#' @export
save_rob_plot <- function(plot, file, width = 8, height = NULL, dpi = 300) {
  if (is.null(height)) {
    n <- tryCatch(length(unique(plot$data[[row_variable(plot)]])), error = function(e) 10L)
    height <- max(3, min(20, 1.2 + 0.32 * n))
  }
  ggplot2::ggsave(file, plot, width = width, height = height, dpi = dpi, bg = "#fcfcfb")
  invisible(file)
}

row_variable <- function(plot) {
  for (cand in c("label", "item", "domain_label")) if (cand %in% names(plot$data)) return(cand)
  names(plot$data)[1]
}

utils::globalVariables(c("domain", "label", "judgment", "symbol", "symbol_colour",
                         "share", "domain_label", "text", "text_colour", "question",
                         "category", "answer", "share0", "item"))
