# pubflow modules app: what the parameter UI modules do, shown as
# raw R output.
#
# Start from the pubflow package root (development version):
#   R -q -e "pkgload::load_all(); shiny::runApp('inst/examples/modules-app')"
# or, with pubflow installed, run the app in the directory
# system.file("examples", "modules-app", package = "pubflow").
#
# Pages: Bootstrap 3 (shiny::fluidPage, default) and Bootstrap 5
# (bslib::page_fluid, needs bslib): add "?bs=5" to the URL.
#
# Tab "Pipeline module": a small pipeline (the ozone analysis of the
# vignettes, on 10 days of the data). Left: its parameters with
# pub_pipeline_params_server(), on_invalid = "restore"; every valid change
# is set in the pipeline, which then runs again. The range param filters the
# days by the predictor; a new predictor gets a new range param (label,
# limits and values from the data), which the app sets in the pipeline: the
# module renders the params again. "Set the range from the data" sets the
# values of the range to the days of the selected months: the inputs update
# in place. "Lock step 'fit'" locks the step, as a QC workflow might: its
# params are shown as disabled inputs.
# Middle: the data the pipeline works on and its outputs. Right: what the
# module returns.
# Tab "Standalone module": a standalone module (pub_params_server(),
# on_invalid = "keep", update on every keystroke) whose params can be
# switched (structural change) or get new values (update in place); the large
# set has params locked by their attribute.
#
# The report app (inst/examples/report-app) shows a whole app: a pipeline
# with its report in the document viewer and the download.

demo_months <- month.name[5:9]

# Two complete days of each month: small enough to see what the params do
demo_data <- local({
    aq <- stats::na.omit(datasets::airquality)
    aq <- aq[stats::ave(aq$Month, aq$Month, FUN = seq_along) <= 2L, ]
    aq$Temp.Celsius <- round((aq$Temp - 32) * 5 / 9, 1)
    aq
})

from_below_to <- function(x) {
    if (isTRUE(x$from < x$to)) "" else "'From' must be below 'To'"
}

# Range of the values of a variable, rounded outwards
outer_range <- function(x) {
    c(floor(min(x, na.rm = TRUE)), ceiling(max(x, na.rm = TRUE)))
}

# Range of a predictor: label, limits and values from the data
range_param <- function(var, data = demo_data) {
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

demo_config <- function() {
    pubflow::param_config(
        title = pubflow::param(
            "Ozone in New York",
            label = "Title",
            area = "report",
            description = "Title of the summary"
        ),
        xVar = pubflow::choice_param(
            "Temp.Celsius",
            choices = c("Temp.Celsius", "Wind", "Solar.R"),
            label = "Predictor",
            area = "analysis",
            description = "Variable that explains the ozone concentration"
        ),
        months = pubflow::param(
            factor(demo_months, demo_months),
            label = "Months",
            area = "analysis",
            ui_args = list(multiple = TRUE),
            description = "Months included in the analysis"
        ),
        window = range_param("Temp.Celsius"),
        level = pubflow::numeric_param(
            0.95,
            label = "Confidence level",
            min = 0.8,
            max = 0.99,
            step = 0.01,
            ui_widget = "slider",
            area = "analysis",
            description = "Level of the confidence limits"
        )
    )
}

demo_xvar <- factor("Temp.Celsius", c("Temp.Celsius", "Wind", "Solar.R"))

demo_pipeline <- function() {
    pipeflow::pip_new("modules") |>
        pipeflow::pip_add(
            "data",
            \(
                data = demo_data,
                months = factor(demo_months, demo_months)
            ) {
                data[month.name[data$Month] %in% as.character(months), ]
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
        pipeflow::pip_add("coefs", \(model = ~fit, level = 0.95) {
            ci <- stats::confint(model, level = level)
            data.frame(
                term = rownames(ci),
                estimate = stats::coef(model),
                lower = ci[, 1L],
                upper = ci[, 2L]
            )
        }) |>
        pipeflow::pip_add("summary", \(model = ~fit, title = "", xVar = demo_xvar) {
            sprintf(
                "%s: %s explains %.0f%% of the variance (%d days)",
                title,
                xVar,
                100 * summary(model)$r.squared,
                stats::nobs(model)
            )
        }) |>
        pipeflow::pip_set_params(demo_config(), unknown = "error")
}

# Replace the range param when the predictor changed (keeping its place in the
# config); returns the predictor of the range
follow_predictor <- function(pip, rangeVar) {
    params <- pubflow::pub_get_params(pip)
    xVar <- as.character(pubflow::param_value(params$xVar))
    if (identical(xVar, rangeVar)) {
        return(rangeVar)
    }
    window <- range_param(xVar)
    attr(window, "order") <- pubflow::param_attr(params$window, "order")
    pipeflow::pip_set_params(pip, list(window = window))
    xVar
}

# Params of the standalone module: two structures
standalone_params <- list(
    small = pubflow::param_config(
        name = pubflow::param("abc", label = "Name"),
        count = pubflow::numeric_param(3L, label = "Count (integer)", min = 0, max = 10)
    ),
    large = pubflow::param_config(
        name = pubflow::param("abc", label = "Name"),
        count = pubflow::numeric_param(
            3L,
            label = "Count (integer)",
            min = 0,
            max = 10
        ),
        ratio = pubflow::numeric_param(0.5, label = "Ratio", min = 0, max = 1),
        choice = pubflow::choice_param(
            "b",
            c("a", "b", "c"),
            label = "Choice",
            ui_widget = "radio"
        ),
        level = pubflow::numeric_param(
            0.95,
            label = "Level",
            min = 0,
            max = 1,
            locked = TRUE,
            description = "Fixed by the workflow"
        ),
        method = pubflow::choice_param(
            "ols",
            c("ols", "wls"),
            label = "Method",
            ui_widget = "radio",
            locked = TRUE
        )
    )
)

# Two tabs: the pipeline module and the standalone module
page_content <- function(bootstrap) {
    other <- if (bootstrap == 3) "5" else "3"
    shiny::tagList(
        predictor_style("pipeline"),
        shiny::h3(sprintf("pubflow parameter modules (Bootstrap %s)", bootstrap)),
        shiny::p(shiny::a(
            href = sprintf("?bs=%s", other),
            sprintf("Switch to the Bootstrap %s page", other)
        )),
        shiny::tabsetPanel(
            shiny::tabPanel("Pipeline module", pipeline_tab()),
            shiny::tabPanel("Standalone module (keep invalid input)", standalone_tab())
        )
    )
}

pipeline_tab <- function() {
    shiny::fluidRow(
        style = "margin-top: 1em;",
        shiny::column(
            4,
            shiny::h4("Pipeline parameters"),
            pubflow::pub_params_ui("pipeline"),
            shiny::hr(),
            shiny::div(
                shiny::actionButton("derive", "Set the range from the data")
            ),
            shiny::helpText(
                "Sets the range to the data of the selected months: the inputs",
                "update in place and values() follows; changed() only reports",
                "changes made in the inputs."
            ),
            shiny::checkboxInput("lockFit", "Lock step 'fit'"),
            shiny::helpText(
                "Its params are shown disabled (also those that other",
                "steps hold); the step keeps its output."
            )
        ),
        shiny::column(
            4,
            shiny::h4("Pipeline data and outputs"),
            shiny::h5("Output of step 'data' (used: in the range)"),
            shiny::div(style = "overflow-x: auto;", shiny::tableOutput("data")),
            shiny::tableOutput("coefs"),
            shiny::textOutput("summary")
        ),
        shiny::column(
            4,
            shiny::h4("What the module returns"),
            shiny::verbatimTextOutput("revision"),
            shiny::h5("values()"),
            shiny::verbatimTextOutput("pipelineValues"),
            shiny::h5("changed() (latest change in the inputs)"),
            shiny::verbatimTextOutput("pipelineChanged")
        )
    )
}

standalone_tab <- function() {
    shiny::fluidRow(
        style = "margin-top: 1em;",
        shiny::column(
            4,
            pubflow::pub_params_ui("standalone"),
            shiny::hr(),
            shiny::radioButtons(
                "structure",
                "Params",
                c("small", "large"),
                inline = TRUE
            ),
            shiny::actionButton("newValues", "New values")
        ),
        shiny::column(
            4,
            shiny::h5("valid()"),
            shiny::verbatimTextOutput("standaloneValid"),
            shiny::h5("values()"),
            shiny::verbatimTextOutput("standaloneValues")
        )
    )
}

ui <- function(request) {
    query <- shiny::parseQueryString(request$QUERY_STRING)
    if (identical(query$bs, "5")) {
        bslib::page_fluid(
            page_content(5),
            title = "pubflow parameter modules",
            lang = "en"
        )
    } else {
        shiny::fluidPage(
            page_content(3),
            title = "pubflow parameter modules",
            lang = "en"
        )
    }
}

shown_columns <- c("Month", "Ozone", "Temp.Celsius", "Wind", "Solar.R", "used")

server <- function(input, output, session) {
    # Pipelines are reference objects: one per session
    pip <- demo_pipeline()
    refresh <- shiny::reactiveVal(0L)
    params <- pubflow::pub_pipeline_params_server(
        "pipeline",
        pip,
        refresh = refresh,
        group_labels = c(analysis = "Analysis", report = "Report"),
        reset = TRUE
    )

    # A new predictor gets its range before the pipeline runs again (higher
    # priority than the outputs)
    rangeVar <- "Temp.Celsius"
    shiny::observe(priority = 10, {
        xVar <- follow_predictor(pip, rangeVar)
        if (!identical(xVar, rangeVar)) {
            rangeVar <<- xVar
            refresh(refresh() + 1L)
        }
    }) |>
        shiny::bindEvent(params$revision())

    results <- shiny::reactive({
        params$revision()
        refresh()
        pipeflow::pip_run(pip, lgr = NULL)
        data <- pip[["data", "out"]]
        data$used <- rownames(data) %in% rownames(pip[["prep", "out"]])
        list(
            data = data[shown_columns],
            coefs = pip[["coefs", "out"]],
            summary = pip[["summary", "out"]]
        )
    })
    output$revision <- shiny::renderText(
        sprintf("revision: %d", params$revision())
    )
    output$pipelineValues <- shiny::renderPrint(str(params$values()))
    output$pipelineChanged <- shiny::renderPrint(str(params$changed()))
    output$data <- shiny::renderTable(
        results()$data,
        digits = 1,
        spacing = "xs"
    )
    output$coefs <- shiny::renderTable(results()$coefs)
    output$summary <- shiny::renderText(results()$summary)

    shiny::observe({
        limits <- outer_range(pip[["data", "out"]][[rangeVar]])
        pipeflow::pip_set_params(
            pip,
            list(window = list(from = limits[[1L]], to = limits[[2L]]))
        )
        refresh(refresh() + 1L)
    }) |>
        shiny::bindEvent(input$derive)

    shiny::observe({
        fit <- pipeflow::pip_view(pip, step = "fit")
        if (isTRUE(input$lockFit)) {
            pipeflow::pip_lock(fit)
        } else {
            pipeflow::pip_unlock(fit)
        }
        refresh(refresh() + 1L)
    }) |>
        shiny::bindEvent(input$lockFit, ignoreInit = TRUE)

    # Standalone module
    current <- shiny::reactiveVal(standalone_params$small)
    shiny::observe(current(standalone_params[[input$structure]])) |>
        shiny::bindEvent(input$structure, ignoreInit = TRUE)
    shiny::observe({
        p <- current()
        pubflow::param_value(p$name) <- paste(sample(letters, 3), collapse = "")
        pubflow::param_value(p$count) <- sample(0:10, 1)
        current(p)
    }) |>
        shiny::bindEvent(input$newValues)
    standalone <- pubflow::pub_params_server(
        "standalone",
        current,
        on_invalid = "keep",
        update_on = "change"
    )
    output$standaloneValid <- shiny::renderPrint(standalone$valid())
    output$standaloneValues <- shiny::renderPrint(str(standalone$values()))
}

shiny::shinyApp(ui, server)
