library(shiny)
library(vitrob)

spec <- tool_spec()
example_path <- system.file("extdata", "example_assessments.csv", package = "vitrob")
template_xlsx <- system.file("extdata", "assessment_template.xlsx", package = "vitrob")

plot_ui <- function(id) {
  tagList(
    br(),
    downloadButton(paste0("dl_", id, "_png"), "PNG"),
    downloadButton(paste0("dl_", id, "_pdf"), "PDF"),
    br(), br(),
    plotOutput(paste0("plot_", id), height = "auto")
  )
}

ui <- fluidPage(
  titlePanel("VITROB: risk-of-bias tool for in vitro experiments"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      fileInput("file", "Upload assessments (CSV, or the Excel template)",
                accept = c(".csv", ".xlsx")),
      actionButton("use_example", "Use example data"),
      hr(),
      radioButtons("use", "Judgments to plot",
                   c("Final (proposed where blank)" = "final", "Proposed only" = "proposed")),
      radioButtons("palette", "Colours",
                   c("Colour-blind safe (blue/amber/red)" = "accessible",
                     "Conventional (green/amber/red)" = "cochrane")),
      hr(),
      downloadButton("dl_template_xlsx", "Excel template"),
      br(), br(),
      downloadButton("dl_template_csv", "CSV template")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Checks", br(), uiOutput("check_summary"), tableOutput("issues")),
        tabPanel("Judgments", br(),
                 downloadButton("dl_table", "Download table with proposed judgments (CSV)"),
                 br(), br(), tableOutput("judgments")),
        tabPanel("Traffic light", plot_ui("traffic")),
        tabPanel("Summary", plot_ui("summary")),
        tabPanel("Answers", plot_ui("questions")),
        tabPanel("Reporting gaps", plot_ui("gaps")),
        tabPanel("Questions", br(), tableOutput("qtable"))
      )
    )
  )
)

server <- function(input, output, session) {
  data <- reactiveVal(NULL)

  observeEvent(input$file, {
    ext <- tolower(tools::file_ext(input$file$name))
    tmp <- tempfile(fileext = paste0(".", ext))
    file.copy(input$file$datapath, tmp)
    x <- tryCatch(read_assessments(tmp), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = NULL)
      NULL
    })
    if (!is.null(x)) data(x)
  })
  observeEvent(input$use_example, data(read_assessments(example_path)))

  issues <- reactive({ req(data()); check_assessments(data(), spec) })
  proposed <- reactive({ req(data()); propose_judgments(data(), spec) })
  n_rows <- reactive(max(1, sum(!is.na(proposed()$overall_proposed))))

  output$check_summary <- renderUI({
    if (is.null(data())) return(tags$p("Upload a file or use the example data to start."))
    n <- nrow(issues())
    msg <- if (n == 0) {
      paste(nrow(data()), "results read. No entry errors found.")
    } else {
      paste(n, "issue(s) found in", nrow(data()),
            "results. Fix them in your sheet and upload it again.")
    }
    tags$p(strong(msg))
  })
  output$issues <- renderTable({ req(nrow(issues()) > 0); issues() })

  output$judgments <- renderTable({
    p <- proposed()
    ids <- domain_ids(spec)
    cols <- c("study_id", "result_id", "scope_status", paste0(ids, "_proposed"), paste0(ids, "_final"),
              "O1", "overall_proposed", "overall_final")
    p[, intersect(cols, names(p)), drop = FALSE]
  })

  plots <- list(
    traffic = reactive(plot_traffic(proposed(), spec, use = input$use, palette = input$palette)),
    summary = reactive(plot_summary(proposed(), spec, use = input$use, palette = input$palette)),
    questions = reactive(plot_questions(proposed(), spec, palette = input$palette)),
    gaps = reactive(plot_gaps(proposed(), spec))
  )
  heights <- list(
    traffic = function() 140 + 34 * n_rows(),
    summary = function() 380,
    questions = function() 170 + 26 * n_rows(),
    gaps = function() 780
  )

  for (id in names(plots)) local({
    pid <- id
    output[[paste0("plot_", pid)]] <- renderPlot(plots[[pid]](), height = heights[[pid]], res = 96)
    for (fmt in c("png", "pdf")) local({
      f <- fmt
      output[[paste0("dl_", pid, "_", f)]] <- downloadHandler(
        filename = function() paste0("vitrob_", pid, ".", f),
        content = function(file) save_rob_plot(plots[[pid]](), file, width = 9,
                                               height = heights[[pid]]() / 96)
      )
    })
  })

  output$dl_template_xlsx <- downloadHandler(
    filename = "vitrob_assessment_template.xlsx",
    content = function(file) file.copy(template_xlsx, file)
  )
  output$dl_template_csv <- downloadHandler(
    filename = "vitrob_assessment_template.csv",
    content = function(file) write_template(file, spec)
  )
  output$dl_table <- downloadHandler(
    filename = "vitrob_assessments_with_proposals.csv",
    content = function(file) utils::write.csv(proposed(), file, row.names = FALSE, na = "")
  )
  output$qtable <- renderTable(
    questions_table(spec)[, c("domain", "id", "short", "text", "ask_if", "options")]
  )
}

shinyApp(ui, server)
