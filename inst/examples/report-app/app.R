# pubflow report app: the parameters of a pipeline in the sidebar, its report
# in the document viewer, and the download of the report.
#
# Start from the pubflow package root (development version):
#   R -q -e "pkgload::load_all(); shiny::runApp('inst/examples/report-app')"
# or, with pubflow installed, run the app in the directory
# system.file("examples", "report-app", package = "pubflow").
#
# Pages: Bootstrap 3 (shiny::fluidPage, default) and Bootstrap 5
# (bslib::page_sidebar, needs bslib): add "?bs=5" to the URL.
#
# The pipeline is the ozone analysis of the vignettes (base R's airquality
# data, as in pipeflow's Get started vignette), with more params and
# sections.
#
# Sidebar: the report shown, the parameters of the pipeline
# (pub_pipeline_params_server()) and the download. Every valid change of a
# parameter is set in the pipeline, which then runs again.
# Main panel: the viewer (pub_viewer_server()) shows one of two reports of
# the same pipeline, a short and a long one. Each section of the reports is a
# step, tagged with the reports that show it; the layout step of a report
# ("short", "long") places the sections of its tag (pub_layout_inputs()),
# and the app runs only the steps of the report shown. The long
# report adds one section per selected month and the methods. The pipeline
# runs with on_error = "continue": the advanced param "Let the check fail"
# makes step "check" fail, which the document shows as an error box (and a
# notification).
# The range param filters the days by the predictor; it starts at the
# range of the data. A new predictor gets a new range param (label, limits
# and values from the data): the app sets it in the pipeline and refreshes
# the module, which renders the params again.
# Download: renders the report shown to DOCX, PDF (LaTeX or Typst) or HTML
# with pub_render(), with the session's user, the app and its version in
# the trace stamp of the footer. A report with failed steps can't be
# downloaded: pub_render() refuses its error items, which the app shows as a
# notification. The viewer and the downloads share the session's cache.
#
# The modules app (inst/examples/modules-app) shows the param modules in
# detail: what they return, locked steps and a standalone module.

demo_months <- month.name[5:9]

from_below_to <- function(x) {
    if (isTRUE(x$from < x$to)) "" else "'From' must be below 'To'"
}

add_celsius <- function(data) {
    data$Temp.Celsius <- (data$Temp - 32) * 5 / 9
    data
}

# Range of the values of a variable, rounded outwards
outer_range <- function(x) {
    c(floor(min(x, na.rm = TRUE)), ceiling(max(x, na.rm = TRUE)))
}

# Range of a predictor: label, limits and values from the data
range_param <- function(var, data) {
    limits <- outer_range(data[[var]])
    child <- \(value, label) {
        pubflow::numeric_param(
            value,
            label = label,
            min = limits[[1L]],
            max = limits[[2L]]
        )
    }
    pubflow::param_group(
        list(from = child(limits[[1L]], "From"), to = child(limits[[2L]], "To")),
        label = sprintf("Range of %s", var),
        area = "analysis",
        source = "user",
        description = "Days outside the range are left out"
    ) |>
        pubflow::add_validity(from_below_to)
}

# The labels of the predictor and its range in one colour: they belong together
# (the rows that hold their inputs; locked labels stay grey)
predictor_style <- function(id) {
    shiny::tags$style(sprintf(
        paste(
            ".pubflow-param-row:is(:has(#%1$s-xVar), :has(#%1$s-window_from))",
            ".pubflow-param-label:not(.pubflow-param-label-locked)",
            "{ color: #b45309; font-weight: 600; }"
        ),
        id
    ))
}

# `data`: the data of the pipeline, with the temperature in Celsius
demo_config <- function(data) {
    pubflow::param_config(
        xVar = pubflow::choice_param(
            "Temp.Celsius",
            choices = c("Temp.Celsius", "Wind", "Solar.R"),
            label = "Predictor",
            area = "analysis",
            source = "user",
            description = "Variable that explains the ozone concentration"
        ),
        months = pubflow::param(
            factor(demo_months, demo_months),
            label = "Months",
            area = "analysis",
            source = "user",
            ui_args = list(multiple = TRUE),
            description = "Months included in the analysis"
        ),
        complete = pubflow::param(
            FALSE,
            label = "Only days without missing values?",
            area = "analysis",
            source = "user"
        ),
        window = range_param("Temp.Celsius", data),
        level = pubflow::numeric_param(
            0.95,
            label = "Confidence level",
            min = 0.8,
            max = 0.99,
            step = 0.01,
            ui_widget = "slider",
            area = "analysis",
            source = "user",
            description = "Level of the confidence limits and the check"
        ),
        title = pubflow::param(
            "Ozone in New York",
            label = "Report title",
            area = "report",
            source = "user",
            description = "Title shown above the results"
        ),
        decimals = pubflow::numeral_param(
            "3",
            label = "Decimal places",
            min = 0,
            max = 6,
            area = "report",
            source = "user"
        ),
        smooth = pubflow::choice_param(
            "off",
            choices = c("on", "off"),
            label = "Smoother",
            area = "report",
            source = "user",
            advanced = TRUE,
            ui_widget = "radio",
            ui_args = list(size = "xs")
        ),
        showPoints = pubflow::choice_param(
            "yes",
            choices = c("yes", "no"),
            label = "Show data points - bla bla bla this is a long label bla bla bla",
            area = "report",
            source = "user",
            advanced = TRUE
        ),
        failCheck = pubflow::choice_param(
            "no",
            choices = c("yes", "no"),
            label = "Let the check fail",
            area = "report",
            source = "user",
            advanced = TRUE,
            description = "Shows how the viewer marks a failed step"
        )
    )
}

# Outputs of the report steps (defined outside the pipeline constructor, so
# that figures don't keep the pipeline alive)
coef_table <- function(model, level, decimals) {
    ci <- stats::confint(model, level = level)
    coefs <- data.frame(
        term = rownames(ci),
        estimate = stats::coef(model),
        lower = ci[, 1L],
        upper = ci[, 2L]
    )
    d <- as.integer(decimals)
    pubflow::pub_table(
        coefs,
        caption = sprintf("Coefficients with %g%% confidence limits", 100 * level),
        labels = c(
            term = "Term",
            estimate = "Estimate",
            lower = "Lower",
            upper = "Upper"
        ),
        digits = c(estimate = d, lower = d, upper = d)
    )
}

scatter_plot <- function(data, xVar, smooth, showPoints) {
    xVar <- as.character(xVar)
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off())
    grDevices::dev.control("enable")
    graphics::plot(
        data[[xVar]],
        data$Ozone,
        type = if (showPoints == "yes") "p" else "n",
        pch = 19,
        xlab = xVar,
        ylab = "Ozone (ppb)"
    )
    graphics::abline(stats::lm(data$Ozone ~ data[[xVar]]), col = "red")
    if (smooth == "on") {
        ok <- stats::complete.cases(data[[xVar]], data$Ozone)
        graphics::lines(
            stats::lowess(data[[xVar]][ok], data$Ozone[ok]),
            col = "blue",
            lty = 2
        )
    }
    pubflow::pub_figure(
        grDevices::recordPlot(),
        caption = "Ozone by predictor",
        width = 6,
        height = 4,
        out_width = "70%"
    )
}

# One table per selected month: a named list, so the section that places it
# gets one sub-section per month
month_tables <- function(data) {
    tables <- lapply(split(data, data$Month), \(d) {
        stat <- \(x) {
            c(
                min(x, na.rm = TRUE),
                stats::median(x, na.rm = TRUE),
                mean(x, na.rm = TRUE),
                max(x, na.rm = TRUE)
            )
        }
        values <- rbind(stat(d$Ozone), stat(d$Temp.Celsius))
        colnames(values) <- c("min", "median", "mean", "max")
        pubflow::pub_table(
            data.frame(variable = c("Ozone (ppb)", "Temperature (Celsius)"), values),
            caption = sprintf("Ozone and temperature in %s", month.name[d$Month[[1L]]]),
            labels = c(
                variable = "",
                min = "Min",
                median = "Median",
                mean = "Mean",
                max = "Max"
            ),
            digits = c(min = 1L, median = 1L, mean = 1L, max = 1L)
        )
    })
    stats::setNames(tables, month.name[as.integer(names(tables))])
}

# Sections of the reports (steps tagged "short" and/or "long"); their
# inputs may arrive failed and are placed as they are (error boxes)
results_section <- function(
    summary = ~ try(summary),
    table = ~ try(coef_table),
    plot = ~ try(scatter)
) {
    pubflow::pub_section(
        "Results",
        summary,
        pubflow::pub_text("The model is $y = a + b \\cdot x$."),
        table,
        plot
    )
}

significance_section <- function(check = ~ try(check_text)) {
    pubflow::pub_section("Significance", check)
}

months_section <- function(tables = ~ try(month_tables)) {
    pubflow::pub_section("Data per month", tables)
}

methods_section <- function() {
    pubflow::pub_section(
        "Methods",
        pubflow::pub_section(
            "Data",
            pubflow::pub_text(
                "Daily air quality measurements in New York in 1973 (`airquality`)."
            )
        ),
        pubflow::pub_section(
            "Model",
            pubflow::pub_text(
                "Linear regression of the ozone concentration on the predictor."
            )
        ),
        numbered = FALSE
    )
}

# Layout step of a report: its sections in pipeline order (unnamed, so
# that they keep their own titles); DOCX and PDF show the trace stamp in the
# footer
report_layout <- function(title) {
    force(title)
    function(...) {
        pubflow::pub_doc(
            unname(list(...)),
            title = title,
            meta = list(app = "pubflow report app", footer = c(left = "{trace}"))
        )
    }
}

demo_reports <- c(short = "Short report", long = "Long report")

# Download choices: the arguments of pub_render() for each
download_targets <- list(
    docx = list(format = "docx"),
    pdf_xelatex = list(format = "pdf", pdf_engine = "xelatex"),
    pdf_typst = list(format = "pdf", pdf_engine = "typst"),
    html = list(format = "html")
)
download_labels <- c(
    DOCX = "docx",
    "PDF (LaTeX)" = "pdf_xelatex",
    "PDF (Typst)" = "pdf_typst",
    HTML = "html"
)

demo_xvar <- factor("Temp.Celsius", c("Temp.Celsius", "Wind", "Solar.R"))

# `raw` may hold more months than the params select (the outputs keep only
# the selected ones)
demo_pipeline <- function(raw = datasets::airquality) {
    pip <- pipeflow::pip_new("demo") |>
        pipeflow::pip_add(
            "data",
            \(
                data = raw,
                months = factor(demo_months, demo_months),
                complete = FALSE
            ) {
                data <- add_celsius(data)
                data <- data[month.name[data$Month] %in% as.character(months), ]
                if (complete) data[stats::complete.cases(data), ] else data
            }
        ) |>
        pipeflow::pip_add(
            "prep",
            \(
                data = ~data,
                xVar = demo_xvar,
                window = list(from = -Inf, to = Inf)
            ) {
                x <- data[[as.character(xVar)]]
                data[!is.na(x) & x >= window$from & x <= window$to, ]
            }
        ) |>
        pipeflow::pip_add("fit", \(data = ~prep, xVar = demo_xvar) {
            stats::lm(paste("Ozone ~", xVar), data = data)
        }) |>
        pipeflow::pip_add(
            "summary",
            \(
                model = ~fit,
                title = "",
                xVar = demo_xvar,
                smooth = factor("off", c("on", "off")),
                showPoints = factor("yes", c("yes", "no"))
            ) {
                sprintf(
                    paste(
                        "%s: %s explains %.0f%% of the variance",
                        "(%d days; smoother %s, points: %s)"
                    ),
                    title,
                    xVar,
                    100 * summary(model)$r.squared,
                    stats::nobs(model),
                    smooth,
                    showPoints
                )
            }
        ) |>
        pipeflow::pip_add(
            "coef_table",
            \(
                model = ~fit,
                level = 0.95,
                decimals = "3"
            ) {
                coef_table(model, level, decimals)
            }
        ) |>
        pipeflow::pip_add(
            "scatter",
            \(
                data = ~prep,
                xVar = demo_xvar,
                smooth = factor("off", c("on", "off")),
                showPoints = factor("yes", c("yes", "no"))
            ) {
                scatter_plot(data, xVar, smooth, showPoints)
            }
        ) |>
        pipeflow::pip_add(
            "check",
            \(
                model = ~fit,
                level = 0.95,
                failCheck = factor("no", c("yes", "no"))
            ) {
                if (failCheck == "yes") {
                    stop("the check failed on request")
                }
                ci <- stats::confint(model, level = level)[2L, ]
                ci[[1L]] > 0 || ci[[2L]] < 0
            }
        ) |>
        pipeflow::pip_add("check_text", \(check = ~check) {
            sprintf(
                "The effect of the predictor is %ssignificant.",
                if (check) "" else "not "
            )
        }) |>
        pipeflow::pip_add("month_tables", \(data = ~prep) month_tables(data)) |>
        pipeflow::pip_add(
            "results_section",
            results_section,
            tags = c("short", "long")
        ) |>
        pipeflow::pip_add(
            "significance_section",
            significance_section,
            tags = c("short", "long")
        ) |>
        pipeflow::pip_add("months_section", months_section, tags = "long") |>
        pipeflow::pip_add("methods_section", methods_section, tags = "long")
    # The layout steps come last: pub_layout_inputs() reads the tagged
    # steps now
    for (report in names(demo_reports)) {
        view <- pipeflow::pip_view(pip, tags = report)
        pipeflow::pip_add(
            pip,
            report,
            report_layout(demo_reports[[report]]),
            params = pubflow::pub_layout_inputs(view)
        )
    }
    pipeflow::pip_set_params(pip, demo_config(add_celsius(raw)), unknown = "error")
}

# Replace the range param when the predictor changed (keeping its place in the
# config); returns the predictor of the range
follow_predictor <- function(pip, rangeVar, data) {
    params <- pubflow::pub_get_params(pip)
    xVar <- as.character(pubflow::param_value(params$xVar))
    if (identical(xVar, rangeVar)) {
        return(rangeVar)
    }
    window <- range_param(xVar, data)
    attr(window, "order") <- pubflow::param_attr(params$window, "order")
    pipeflow::pip_set_params(pip, list(window = window))
    xVar
}

# Show the message of a condition as a notification: without the ANSI
# colours and hyperlinks that rlang and cli add in a terminal, one bullet
# per line
notify <- function(cnd, type, ...) {
    ansi <- "\033\\[[0-9;?]*[ -/]*[@-~]|\033\\][^\a\033]*(\a|\033\\\\)"
    text <- gsub(ansi, "", conditionMessage(cnd), perl = TRUE)
    shiny::showNotification(
        shiny::div(style = "white-space: pre-line;", text),
        type = type,
        ...
    )
}

# Render a report for download; pubflow's errors (error items, a missing
# tool) are shown as a notification, and the download fails. A download that
# works removes the notification of an earlier one.
render_download <- function(doc, target, file, cache, meta) {
    args <- list(doc, file = file, meta = meta, cache = cache)
    tryCatch(
        {
            do.call(pubflow::pub_render, c(args, target))
            shiny::removeNotification("download")
        },
        pubflow_error = function(e) {
            notify(e, type = "error", duration = NULL, id = "download")
            stop(e)
        }
    )
}

# Sidebar and main panel, shared by the Bootstrap 3 and 5 pages; the viewer
# fills the height of the window and scrolls inside
page_parts <- function(bootstrap) {
    other <- if (bootstrap == 3) "5" else "3"
    list(
        sidebar = shiny::tagList(
            predictor_style("params"),
            shiny::radioButtons(
                "report",
                "Report",
                stats::setNames(names(demo_reports), demo_reports),
                inline = TRUE
            ),
            pubflow::pub_params_ui("params"),
            # Format and button in one row, right below the params
            shiny::div(
                style = paste(
                    "display: flex; gap: 0.5em; align-items: flex-end;",
                    "margin-top: 1em;"
                ),
                shiny::selectInput(
                    "format",
                    "Download as",
                    download_labels,
                    width = "12em"
                ),
                shiny::div(
                    style = "margin-bottom: 15px;",
                    shiny::downloadButton("download", "Download")
                )
            ),
            shiny::tags$small(shiny::a(
                href = sprintf("?bs=%s", other),
                sprintf("Bootstrap %s page", other)
            ))
        ),
        main = pubflow::pub_viewer_ui("viewer", height = "calc(100vh - 110px)")
    )
}

app_title <- "Ozone in New York"

ui <- function(request) {
    query <- shiny::parseQueryString(request$QUERY_STRING)
    if (identical(query$bs, "5")) {
        parts <- page_parts(5)
        bslib::page_sidebar(
            title = app_title,
            lang = "en",
            sidebar = bslib::sidebar(parts$sidebar, width = 460),
            parts$main
        )
    } else {
        parts <- page_parts(3)
        shiny::fluidPage(
            shiny::titlePanel(app_title),
            lang = "en",
            shiny::sidebarLayout(
                shiny::sidebarPanel(
                    parts$sidebar,
                    style = "max-height: calc(100vh - 110px); overflow-y: auto;"
                ),
                shiny::mainPanel(parts$main, width = 8)
            )
        )
    }
}

server <- function(input, output, session) {
    # Pipelines are reference objects: one per session
    pip <- demo_pipeline()
    cache <- pubflow::pub_cache()
    refresh <- shiny::reactiveVal(0L)
    params <- pubflow::pub_pipeline_params_server(
        "params",
        pip,
        refresh = refresh,
        group_labels = c(analysis = "Analysis", report = "Report"),
        reset = TRUE
    )

    # A new predictor gets its range before the pipeline runs again (higher
    # priority than the outputs)
    rangeVar <- "Temp.Celsius"
    data <- add_celsius(datasets::airquality)
    shiny::observe(priority = 10, {
        xVar <- follow_predictor(pip, rangeVar, data)
        if (!identical(xVar, rangeVar)) {
            rangeVar <<- xVar
            refresh(refresh() + 1L)
        }
    }) |>
        shiny::bindEvent(params$revision())

    # Run the steps of the report shown, with on_error = "continue": failed
    # steps become error boxes in the document; the run's warning is
    # handled here (shown and logged)
    doc <- shiny::reactive({
        params$revision()
        report <- if (is.null(input$report)) "short" else input$report
        withCallingHandlers(
            pipeflow::pip_run(
                pipeflow::pip_view(pip, step = report),
                lgr = NULL,
                on_error = "continue"
            ),
            pipeflow_run_failed = function(w) {
                notify(w, type = "warning")
                message(conditionMessage(w))
                invokeRestart("muffleWarning")
            }
        )
        pip[[report, "out"]]
    })
    pubflow::pub_viewer_server("viewer", doc, cache = cache)

    # The render time is set by filename() (Shiny calls it before
    # content()), so that the file name and the trace stamp show the same time
    renderTime <- NULL
    output$download <- shiny::downloadHandler(
        filename = function() {
            d <- doc()
            shiny::req(inherits(d, "pub_doc"))
            renderTime <<- Sys.time()
            meta <- list(title = d$meta$title, time = renderTime)
            pubflow::pub_output_filename(
                meta,
                download_targets[[input$format]]$format
            )
        },
        content = function(file) {
            user <- session$user
            meta <- list(
                author = if (isTRUE(nzchar(user))) user else "demo user",
                version = as.character(utils::packageVersion("pubflow")),
                time = if (is.null(renderTime)) Sys.time() else renderTime
            )
            render_download(doc(), download_targets[[input$format]], file, cache, meta)
        }
    )
}

shiny::shinyApp(ui, server)
