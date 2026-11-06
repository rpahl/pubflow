# Benchmark (DESIGN.md §4): initial render of the parameter UI for 20 params,
# server side, target < 100 ms. Not run on CI; record results in the PR.
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE)
#               source('inst/bench/param_ui.R')"
# or with pubflow installed:
#   Rscript -e "library(pubflow); source(system.file('bench', 'param_ui.R',
#               package = 'pubflow'))"

bench_params <- function() {
    areas <- c("analysis", "criteria", "report")
    params <- list()
    for (i in 1:6) {
        params[[sprintf("num%d", i)]] <- numeric_param(
            i / 10, label = sprintf("Numeric parameter %d", i),
            min = 0, max = 1, area = areas[[i %% 3 + 1]],
            description = "A number between 0 and 1"
        )
    }
    for (i in 1:4) {
        params[[sprintf("txt%d", i)]] <- param(
            sprintf("Text %d", i), label = sprintf("Text parameter %d", i),
            area = "report"
        )
    }
    for (i in 1:4) {
        params[[sprintf("sel%d", i)]] <- choice_param(
            "log", choices = c("none", "log", "sqrt", "exp"),
            label = sprintf("Choice parameter %d", i), area = "analysis",
            advanced = i > 3
        )
    }
    params$radio1 <- choice_param("on", c("on", "off"), label = "Radio 1",
                                  area = "report", ui_widget = "radio")
    params$radio2 <- choice_param("no", c("yes", "no"), label = "Radio 2",
                                  area = "report", ui_widget = "radio")
    params$switch1 <- param(TRUE, label = "Switch 1", area = "analysis")
    params$switch2 <- param(FALSE, label = "Switch 2", area = "analysis",
                            advanced = TRUE)
    params$slider <- numeric_param(5, label = "Slider", min = 1, max = 10,
                                   ui_widget = "slider", area = "analysis")
    params$limits <- param_group(
        list(
            lower = numeral_param("95", label = "LSL"),
            upper = numeral_param("105", label = "USL")
        ),
        label = "Specification limits", area = "criteria"
    )
    param_config(params)
}

# Median time in ms of `n` evaluations of `expr` (after one warm-up run)
time_ms <- function(expr, n = 50L) {
    expr <- substitute(expr)
    env <- parent.frame()
    eval(expr, env)
    times <- vapply(seq_len(n), function(i) {
        start <- proc.time()[["elapsed"]]
        eval(expr, env)
        proc.time()[["elapsed"]] - start
    }, numeric(1))
    stats::median(times) * 1000
}

params <- bench_params()
stopifnot(length(params) == 20L)
opts <- pubflow:::.module_options(reset = TRUE)
ns <- shiny::NS("params")

# 1. Build the table (tags) and render it to HTML
build <- time_ms(pubflow:::.params_table(params, ns, opts))
html <- time_ms(
    htmltools::renderTags(pubflow:::.params_table(params, ns, opts))
)

# 2. The module: start, read params, render the output (testServer()
#    renders outputs during the flush), minus the overhead of testServer()
#    itself (a module rendering one div)
module <- time_ms(
    shiny::testServer(
        pub_params_server,
        args = list(params = shiny::reactive(params), reset = TRUE),
        {
            session$flushReact()
            output[["pubflow-params"]]
        }
    ),
    n = 50L
)
overhead <- time_ms(
    shiny::testServer(
        function(id) {
            shiny::moduleServer(id, function(input, output, session) {
                output$x <- shiny::renderUI(htmltools::div("x"))
            })
        },
        {
            session$flushReact()
            output$x
        }
    ),
    n = 50L
)

cat(sprintf(
    paste0(
        "Param UI, 20 params (median, ms):\n",
        "  build table tags:                 %6.1f\n",
        "  build + render to HTML:           %6.1f\n",
        "  module start incl. output:        %6.1f\n",
        "  testServer() overhead:            %6.1f\n",
        "  initial render (module - overhead): %4.1f (target < 100)\n"
    ),
    build, html, module, overhead, module - overhead
))
