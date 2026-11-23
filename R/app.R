#' Run the web app
#'
#' Opens a point-and-click app: upload a completed CSV or Excel template (or
#' use the example data), see entry errors, proposed judgments and all plots,
#' and download them. Needs the shiny package; reading Excel files also needs
#' readxl.
#'
#' @param ... Passed to [shiny::runApp()].
#' @return Called for its side effect.
#' @export
run_app <- function(...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The app needs the shiny package: install.packages('shiny')", call. = FALSE)
  }
  dir <- system.file("shiny", package = "vitrob")
  if (!nzchar(dir)) stop("App files not found in the installed package.", call. = FALSE)
  shiny::runApp(dir, ...)
}
