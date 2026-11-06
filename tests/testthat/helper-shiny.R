# Fixtures for the param UI tests.

# Params covering every widget
ui_test_params <- function() {
    param_config(
        factor_single = choice_param(
            "log2",
            choices = c("log2", "log10", "identity", "don't select me"),
            label = "Factor parameter (single select)"
        ) |>
            add_validity(\(x) {
                if (identical(as.character(x), "don't select me")) {
                    return("please select a valid transformation")
                }
                ""
            }),
        factor_multi = param(
            factor("standard", levels = c("brief", "detailed", "standard")),
            label = "Factor parameter (multi-select)",
            validity = \(x) {
                if (length(x) == 0) {
                    return("select at least one factor")
                }
                if (length(x) > 2) {
                    return("select one or two factors")
                }
                ""
            },
            ui_args = list(multiple = TRUE)
        ),
        group = param_group(
            list(
                lower = numeral_param("0.80", label = "Lower bound", min = 0),
                upper = numeral_param("1.25", label = "Upper bound", max = 2),
                use = param(
                    TRUE,
                    label = "Use",
                    ui_args = list(status = "info")
                )
            ),
            label = "Group of parameters",
            validity = \(x) {
                if (isTRUE(as.numeric(x$lower) >= as.numeric(x$upper))) {
                    return("lower bound must be less than upper bound")
                }
                ""
            }
        ),
        num = param(
            0.05,
            label = "Numeric parameter",
            min = 0,
            max = 1,
            step = 0.01,
            description = "Input for numeric parameter"
        ) |>
            add_validity(\(x) {
                if (any(x <= 0)) {
                    return("value must be greater than 0")
                }
                if (any(x >= 1)) {
                    return("value must be less than 1")
                }
                ""
            }),
        num_slider = numeric_param(
            5,
            label = "Numeric parameter (slider widget)",
            min = 1,
            max = 8,
            step = 1,
            ui_widget = "slider",
            ui_args = list(ticks = FALSE),
            ui_style = "font-size: 12px; height: 40px;",
            description = "Input for numeric parameter with slider UI"
        ) |>
            add_validity(\(x) {
                if (x %% 1 != 0) "value must be an integer" else ""
            }),
        on_off = choice_param(
            "off",
            c("on", "off"),
            label = "On/Off parameter",
            description = "Binary On/Off parameter",
            ui_widget = "radio",
            ui_args = list(size = "xs")
        ),
        switch = param(
            FALSE,
            label = "TRUE/FALSE switch",
            description = "Boolean TRUE/FALSE switch",
            ui_args = list(status = "info")
        ),
        txt = param("Theoretical Concentration", label = "Text parameter") |>
            add_validity(\(x) if (x == "") "label cannot be empty" else "")
    )
}

# The input values the widgets of ui_test_params() report when they appear
ui_test_inputs <- function() {
    list(
        factor_single = "log2",
        factor_multi = "standard",
        group_lower = "0.80",
        group_upper = "1.25",
        group_use = TRUE,
        num = 0.05,
        num_slider = 5,
        on_off = "off",
        switch = FALSE,
        txt = "Theoretical Concentration"
    )
}

# Simulate the browser showing the rendered inputs (inside testServer())
mount_inputs <- function(session, inputs = ui_test_inputs()) {
    do.call(session$setInputs, inputs)
}

# Record the messages a module sends to the browser (inside testServer()): custom
# messages (session$sendCustomMessage) and input messages (session$sendInputMessage,
# used by the update*Input() functions).
capture_messages <- function(session) {
    log <- new.env(parent = emptyenv())
    log$custom <- list()
    log$input <- list()
    root <- session$rootScope()
    root$sendCustomMessage <- function(type, message) {
        log$custom[[length(log$custom) + 1L]] <- list(
            type = type,
            message = message
        )
    }
    root$sendInputMessage <- function(inputId, message) {
        log$input[[length(log$input) + 1L]] <- list(
            id = inputId,
            message = message
        )
    }
    log$types <- function() {
        vapply(log$custom, \(m) m$type, character(1))
    }
    log$of_type <- function(type) {
        Filter(\(m) identical(m$type, type), log$custom)
    }
    # The inputs of all syncInputValue messages, as list(id, value) each
    log$synced <- function() {
        unlist(
            lapply(log$of_type("pubflow:syncInputValue"), \(m) m$message$inputs),
            recursive = FALSE
        )
    }
    log$reset <- function() {
        log$custom <- list()
        log$input <- list()
    }
    log
}

# HTML of tags rendered inside a Bootstrap 3 or 5 page
render_page <- function(ui, bootstrap = c("3", "5")) {
    bootstrap <- match.arg(bootstrap)
    page <- if (bootstrap == "3") {
        shiny::fluidPage(ui)
    } else {
        bslib::page_fluid(ui)
    }
    htmltools::renderTags(page)
}

# Version of the Bootstrap dependency of a page rendered by render_page()
bootstrap_version <- function(rendered) {
    deps <- Filter(\(d) d$name == "bootstrap", rendered$dependencies)
    as.character(deps[[1L]]$version)
}

html_of <- function(x) {
    as.character(htmltools::renderTags(x)$html)
}

# Environment with the objects of an example app (inst/examples/<name>/app.R)
example_app_env <- function(name) {
    file <- system.file("examples", name, "app.R", package = "pubflow")
    env <- new.env(parent = globalenv())
    sys.source(file, envir = env)
    env
}
