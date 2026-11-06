# Parameter UI module: a Shiny module that renders a compact table of inputs for a list
# of params, validates every input change with the params' validity functions and
# returns the valid values. It keeps the config order, groups the inputs, puts advanced
# params into an "Advanced" block and renders once per structure (value changes update
# the inputs in place).
#
# All state lives in an environment per module instance (`.module_state()`); messages to
# the browser go through `.send_custom_message()`.

# ======================================================================================
# Module
# ======================================================================================

# -------------
# UI and server
# -------------
#' Parameter UI module
#'
#' A Shiny module that shows a compact table with one input per param
#' ([pub_param_input()]) and checks every change with the validity functions of the
#' params ([param_validity()]).
#'
#' @details
#' ## Functions
#'
#' * `pub_params_ui()` is the UI part: place it where the table should appear.
#' * `pub_params_server()` takes a reactive that returns the params, e.g. a
#'   [param_config()].
#' * `pub_pipeline_params_server()` reads the params from a pipeline with
#'   [pub_get_params()] and sets every valid change in the pipeline with
#'   [pipeflow::pip_set_params()] (see "Setting params" in [pub_get_params()]).
#'
#' Given a view, e.g. `pipeflow::pip_view(p, tags = "analysis")`,
#' `pub_pipeline_params_server()` shows the params of the view's steps only. It sets
#' their values in every step of the pipeline that has them, also outside the view, so
#' that a param keeps one value.
#'
#' ## Layout
#'
#' * The rows follow the order of the config (attribute `order`, see [param_config()]),
#'   then the given order.
#' * If more than one value of the attribute `group_by` occurs, each group gets a
#'   heading (from `group_labels`, else the value). Params without the attribute come
#'   under "Other".
#' * Params with `advanced = TRUE` go into a collapsed "Advanced" block of their group.
#' * Input ids are `ns(<name>)`, for param groups `ns(<name>_<child>)`.
#'
#' ## Updates
#'
#' The table is only rendered again if the structure of the params changes (names,
#' types, choices or attributes other than the validity functions, also `locked`). If
#' only values change, e.g. after a data-derived value was set in the pipeline, the
#' inputs are updated in place.
#'
#' ## Validation
#'
#' Text and numeric inputs report their value on blur or Enter (`update_on = "blur"`),
#' other inputs immediately. The value is converted to the type of the param (an empty
#' numeric input becomes `NA`) and validated:
#'
#' * A valid value is emitted in `changed` and `values`.
#' * An invalid value is shown next to the input (the first message, for about 3 s) and
#'   the input glows. The message `"'<label>' input: <message>"` is also logged with
#'   [message()] as an audit trail. What happens to the input depends on `on_invalid`:
#'   * `"restore"`: it gets back its last valid value;
#'   * `"keep"`: it keeps the invalid value, which does not reach `values`, and
#'     `valid()` is `FALSE` until the input is valid again.
#' * If a param group fails its own rule (e.g. lower limit below upper limit, see
#'   [add_validity()]), the child input that was changed is marked.
#'
#' ## Locked params
#'
#' Params with `locked = TRUE` are shown as disabled inputs (see [pub_param_input()]),
#' so their values only come from `params()`.
#'
#' * The server ignores changes of their inputs (logged as
#'   `"'<label>' input: locked, change ignored"`) and the input gets back its value.
#' * The reset button leaves them alone.
#' * `pub_pipeline_params_server()` also locks the params of a locked step
#'   ([pipeflow::pip_lock()]), also a step outside the view: `pip_set_params()` skips
#'   locked steps, so a change would leave the steps of the same name with different
#'   values. New step locks are noticed when the params are read again (`refresh`).
#'
#' ## Resetting values
#'
#' With `reset = TRUE` a button sets all inputs back to their initial values: the
#' values in `params()`. Locked params are left alone.
#'
#' * If `params()` returns new values (e.g. data-derived defaults after a run), these
#'   are the new initial values.
#' * Values that only come back from the pipeline after a change by the user (with
#'   `refresh`, or after it rejected a value) are not new initial values, so the
#'   button still restores the values from before the user's changes.
#' * If the validity rules of a param changed in the meantime and its initial value
#'   no longer passes them, that input is not reset. The user sees the validity
#'   message, as for a rejected input, and the input keeps its value. E.g. the user
#'   set `n` from 1 to 2, then `params()` gave `n` a new rule "at least 2" with the
#'   same value 2: the reset to 1 would break it.
#'
#' ## Rejected values
#'
#' If [pipeflow::pip_set_params()] fails (`pipeflow_set_params_error`, e.g. because the
#' pipeline holds stricter params than the ones read before), the input is treated like
#' an invalid one and shows the pipeline's value again.
#'
#' @param id `character(1)` module id, the same as in `pub_params_ui()`.
#' @param params A reactive returning a named list (or [param_config()]) of param
#'   objects.
#' @param on_invalid `"restore"`: an invalid input gets back the last valid value;
#'   `"keep"`: it keeps the invalid value and `valid()` is `FALSE`.
#' @param update_on `"blur"`: text and numeric inputs report a change on blur or Enter;
#'   `"change"`: on every keystroke (after a short delay).
#' @param group_by `character(1)` name of the attribute that groups the params, or
#'   `NULL`.
#' @param group_labels Named character vector or list of group headings, e.g.
#'   `c(analysis = "Analysis parameters", report = "Report parameters")`.
#' @param width Width of the inputs (CSS), e.g. `"15ch"`, or `NULL`. The inputs of a
#'   [param_group()] share it.
#' @param tooltips `TRUE`: show the description of a param as tooltip of its input.
#' @param reset `TRUE`: add a button that sets all inputs back to their initial values
#'   (see "Resetting values").
#' @param pip A pipeflow pipeline or view, or a reactive returning one.
#' @param filter Optional named list of attribute filters that is passed to
#'   [pub_get_params()], e.g., `list(source = "user")` is called with
#'   `pub_get_params(pip, source = "user")`. The default `list()` shows all params of
#'   the pipeline. See "Parameter filters" in the examples of [pub_get_params()].
#' @param refresh `NULL` or a reactive: whenever it fires, the params are read again
#'   from the pipeline. Use it after code outside the module changed the pipeline.
#' @return
#' * `pub_params_ui()`: a tag list with the container of the table and pubflow's HTML
#'   dependency (JavaScript and CSS).
#' * `pub_params_server()`: a list of reactives:
#'   * `values`: named list of the current valid plain values (`NULL` before the
#'     params are available);
#'   * `changed`: named list of the values that changed (and are valid) with the
#'     latest change; `NULL` before the first change;
#'   * `valid`: `TRUE` if no input holds an invalid value (only `FALSE` with
#'     `on_invalid = "keep"`).
#' * `pub_pipeline_params_server()`: the same as `pub_params_server()` plus:
#'   * `revision`: an integer that goes up by one whenever the module has updated the
#'     params in the pipeline (that is, [pipeflow::pip_set_params()] succeeded).
#'     Usually, it is used to trigger a pipeline run that updates the results.
#' @seealso [pub_param_input()], [pub_get_params()]
#' @examples
#' cfg <- param_config(
#'     alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 0.5,
#'                           area = "analysis"),
#'     trans = choice_param("none", choices = c("none", "log"),
#'                          label = "Transformation", area = "analysis"),
#'     title = param("Report", label = "Title", area = "report")
#' )
#'
#' ui <- shiny::fluidPage(
#'     shiny::sidebarLayout(
#'         shiny::sidebarPanel(pub_params_ui("params")),
#'         shiny::mainPanel(shiny::verbatimTextOutput("values"))
#'     )
#' )
#' server <- function(input, output, session) {
#'     params <- pub_params_server("params", shiny::reactive(cfg),
#'                                 reset = TRUE)
#'     output$values <- shiny::renderPrint(str(params$values()))
#' }
#' if (interactive()) shiny::shinyApp(ui, server)
#'
#' # Parameters of a pipeline
#' pip <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("fit", \(alpha = 0.05) alpha)
#' pipeflow::pip_set_params(pip, param_config(
#'     alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 0.5,
#'                           source = "user")
#' ), unknown = "error")
#' server <- function(input, output, session) {
#'     params <- pub_pipeline_params_server("params", pip)
#'     output$values <- shiny::renderPrint({
#'         params$revision()
#'         pipeflow::pip_run(pip, lgr = NULL)
#'         pip[["fit", "out"]]
#'     })
#' }
#' if (interactive()) shiny::shinyApp(ui, server)
#' @export
pub_params_ui <- function(id) {
    .assert_module_id(id)
    ns <- shiny::NS(id)
    htmltools::tagList(
        .pubflow_dependency(),
        shiny::uiOutput(ns("pubflow-params"), class = "pubflow-params")
    )
}

#' @rdname pub_params_ui
#' @export
pub_params_server <- function(
    id,
    params,
    on_invalid = c("restore", "keep"),
    update_on = c("blur", "change"),
    group_by = "area",
    group_labels = NULL,
    width = "15ch",
    tooltips = TRUE,
    reset = FALSE
) {
    .assert_module_id(id)
    if (!shiny::is.reactive(params)) {
        rlang::abort("`params` must be a reactive returning a list of params.")
    }
    opts <- .module_options(
        on_invalid = on_invalid,
        update_on = update_on,
        group_by = group_by,
        group_labels = group_labels,
        width = width,
        tooltips = tooltips,
        reset = reset
    )
    shiny::moduleServer(id, function(input, output, session) {
        .params_module(input, output, session, params, opts)
    })
}

#' @rdname pub_params_ui
#' @export
pub_pipeline_params_server <- function(
    id,
    pip,
    on_invalid = c("restore", "keep"),
    update_on = c("blur", "change"),
    group_by = "area",
    group_labels = NULL,
    width = "15ch",
    tooltips = TRUE,
    reset = FALSE,
    filter = list(),
    refresh = NULL
) {
    .assert_module_id(id)
    if (!shiny::is.reactive(pip)) {
        .assert_pipeline(pip, arg = "pip")
    }
    if (!is.list(filter) || !rlang::is_named2(filter)) {
        rlang::abort("`filter` must be a named list of attribute values.")
    }
    reserved <- setdiff(names(formals(pub_get_params)), "...")
    if (any(names(filter) %in% reserved)) {
        rlang::abort(sprintf(
            "`filter` names must not be arguments of `pub_get_params()`: %s.",
            toString(intersect(names(filter), reserved))
        ))
    }
    if (!is.null(refresh) && !shiny::is.reactive(refresh)) {
        rlang::abort("`refresh` must be `NULL` or a reactive.")
    }
    opts <- .module_options(
        on_invalid = on_invalid,
        update_on = update_on,
        group_by = group_by,
        group_labels = group_labels,
        width = width,
        tooltips = tooltips,
        reset = reset
    )
    getPip <- if (shiny::is.reactive(pip)) pip else function() pip
    shiny::moduleServer(id, function(input, output, session) {
        reread <- shiny::reactiveVal(0L)
        params <- shiny::reactive({
            reread()
            if (!is.null(refresh)) {
                refresh()
            }
            p <- getPip()
            shiny::req(p)
            .assert_pipeline(p, arg = "pip")
            do.call(pub_get_params, c(list(p), filter)) |>
                .mark_step_locks(p)
        })
        m <- .module_state(session, opts)
        module <- .params_module(input, output, session, params, opts, m)
        revision <- shiny::reactiveVal(0L)
        shiny::observe({
            ok <- .apply_values(getPip(), module$changed(), session)
            if (ok) {
                revision(revision() + 1L)
            } else {
                m$recover <- names(module$changed())
                reread(reread() + 1L)
            }
        }) |>
            shiny::bindEvent(module$changed())
        c(module, list(revision = shiny::reactive(revision())))
    })
}

#' Check and collect the options of the param module
#' @param on_invalid,update_on,group_by,group_labels,width,tooltips,reset the options
#'   of `pub_params_server()`.
#' @return named list of the checked options.
#' @noRd
.module_options <- function(
    on_invalid = c("restore", "keep"),
    update_on = c("blur", "change"),
    group_by = "area",
    group_labels = NULL,
    width = "15ch",
    tooltips = TRUE,
    reset = FALSE
) {
    call <- rlang::caller_env()
    on_invalid <- rlang::arg_match(on_invalid, error_call = call)
    update_on <- rlang::arg_match(update_on, error_call = call)
    if (!is.null(group_by) && !rlang::is_string(group_by)) {
        rlang::abort("`group_by` must be `NULL` or a single string.", call = call)
    }
    isNamedVector <- (is.atomic(group_labels) || is.list(group_labels)) &&
        rlang::is_named(group_labels)
    labelsOk <- is.null(group_labels) || isNamedVector
    if (!labelsOk) {
        rlang::abort("`group_labels` must be named.", call = call)
    }
    if (!is.null(width) && !rlang::is_string(width)) {
        rlang::abort("`width` must be `NULL` or a single string.", call = call)
    }
    if (!rlang::is_bool(tooltips) || !rlang::is_bool(reset)) {
        rlang::abort("`tooltips` and `reset` must be `TRUE` or `FALSE`.", call = call)
    }
    list(
        on_invalid = on_invalid,
        update_on = update_on,
        group_by = group_by,
        group_labels = group_labels,
        width = width,
        tooltips = tooltips,
        reset = reset
    )
}

#' Signal an error if `id` is not a valid module id
#' @param id the module id to check.
#' @param call the environment of the caller, for the error message.
#' @return `NULL`, invisibly.
#' @noRd
.assert_module_id <- function(id, call = rlang::caller_env()) {
    if (!rlang::is_string(id) || !nzchar(id)) {
        rlang::abort("`id` must be a single non-empty string.", call = call)
    }
    invisible(NULL)
}

#' Mark the params held by a locked step as locked
#'
#' A name is locked if any step of the pipeline that holds it unbound is locked, also a
#' step outside the view: [pipeflow::pip_set_params()] (`scope = "pipeline"`) would
#' set its value in the other steps only, so they would hold different values. Marks
#' the params the module reads, not those of [pub_get_params()]: set back with
#' `pip_set_params()` (e.g. as a config), they would keep the lock after
#' [pipeflow::pip_unlock()].
#' @param params named `list` of params.
#' @param x a pipeflow pipeline or view.
#' @return `params`, with attribute `locked = TRUE` on the params of locked steps.
#' @noRd
.mark_step_locks <- function(params, x) {
    full <- .full_pipeline(x)
    isLocked <- full[["locked"]]
    if (!any(isLocked)) {
        return(params)
    }
    held <- names(pipeflow::pip_get_params(full[isLocked], simplify = FALSE))
    for (name in intersect(names(params), held)) {
        attr(params[[name]], "locked") <- TRUE
    }
    params
}


# ------------
# Server logic
# ------------
#' Server logic of the param module (inside `moduleServer()`)
#' @param input,output,session the arguments of the module server function.
#' @param params a reactive returning the params.
#' @param opts options from `.module_options()`.
#' @param m module state from `.module_state()`.
#' @return list of reactives `values`, `changed` and `valid`.
#' @noRd
.params_module <- function(
    input,
    output,
    session,
    params,
    opts,
    m = .module_state(session, opts)
) {
    shiny::observe(priority = 1, {
        p <- .check_params(params())
        shiny::isolate(.on_params(m, p, input))
    })
    shiny::observe({
        m$render()
        raws <- .read_inputs(input, m$params)
        known <- names(input)
        shiny::isolate(.on_inputs(m, raws, known))
    })
    if (isTRUE(opts$reset)) {
        shiny::observe(.on_reset(m)) |>
            shiny::bindEvent(input[["pubflow-reset"]], ignoreInit = TRUE)
    }
    output[["pubflow-params"]] <- shiny::renderUI({
        m$render()
        shiny::isolate(.params_table(m$params, ns = session$ns, opts = opts))
    })
    list(
        values = shiny::reactive(m$values()),
        changed = shiny::reactive(m$emission()$values),
        valid = shiny::reactive(m$valid())
    )
}

#' State of one param module instance
#'
#' Plain fields: `params` (current params, sorted), `signature` (structure of the
#' rendered params), `validValues` (last valid plain value per name), `initial` (plain
#' values restored by the reset button), `seen` (last processed raw input value per
#' input id), `invalid` (names of params whose input is invalid, `on_invalid = "keep"`)
#' and `recover` (names whose values are read again after the pipeline rejected them;
#' they do not change the reset baseline). Reactive fields: `render` (render counter),
#' `values`, `emission` (`list(n, values)`) and `valid`.
#' @param session the module session.
#' @param opts options from `.module_options()`.
#' @return an environment.
#' @noRd
.module_state <- function(session, opts) {
    m <- new.env(parent = emptyenv())
    m$session <- session
    m$opts <- opts
    m$params <- rlang::set_names(list(), character(0))
    m$signature <- NULL
    m$validValues <- list()
    m$initial <- list()
    m$seen <- list()
    m$invalid <- character(0)
    m$recover <- character(0)
    m$render <- shiny::reactiveVal(0L)
    m$values <- shiny::reactiveVal(NULL)
    m$emission <- shiny::reactiveVal(NULL)
    m$valid <- shiny::reactiveVal(TRUE)
    m
}


# ======================================================================================
# Server to browser
# ======================================================================================

# ----------
# New params
# ----------
#' Check the result of `params()` and sort it in config order
#' @param params the result of `params()`.
#' @return named list of params in config order.
#' @noRd
.check_params <- function(params) {
    if (inherits(params, "param_config")) {
        params <- unclass(params)
    }
    ok <- is.list(params) &&
        !is.data.frame(params) &&
        rlang::is_named2(params) &&
        all(vapply(params, is_param, logical(1)))
    if (!ok) {
        rlang::abort("`params()` must return a named list of params.")
    }
    if (length(params) == 0L) {
        return(rlang::set_names(list(), character(0)))
    }
    ids <- unlist(lapply(names(params), \(n) .input_ids(params[[n]], n)))
    if (anyDuplicated(ids) > 0L) {
        rlang::abort(sprintf(
            "Input ids of the params must be unique, duplicated: %s.",
            toString(unique(ids[duplicated(ids)]))
        ))
    }
    reserved <- startsWith(ids, "pubflow-")
    if (any(reserved)) {
        rlang::abort(sprintf(
            "Input ids of the params must not start with 'pubflow-': %s.",
            toString(ids[reserved])
        ))
    }
    .sort_by_config_order(params)
}

#' New params: re-render if their structure changed, else update values
#' @param m module state.
#' @param params checked params from `.check_params()`.
#' @param input the module's `input`.
#' @noRd
.on_params <- function(m, params, input) {
    signature <- .structure_signature(params)
    m$params <- params
    if (identical(signature, m$signature)) {
        .update_values(m)
    } else {
        values <- lapply(params, param_value)
        m$initial <- .carry_initial(m, signature, values)
        m$signature <- signature
        m$validValues <- values
        # Inputs keep their old values until the new widgets report theirs
        m$seen <- .present_inputs(input)
        m$invalid <- character(0)
        m$render(m$render() + 1L)
    }
    m$recover <- character(0)
    m$values(m$validValues)
    m$valid(length(m$invalid) == 0L)
}

#' Structure of params: everything that is rendered except the values
#' @param params named list of params.
#' @return list of signatures (`.param_signature()`) by name.
#' @noRd
.structure_signature <- function(params) {
    lapply(params, .param_signature)
}

#' Structure of one param: attributes except validity (functions by their code), length
#' (not of a factor)
#'
#' Functions (e.g. a `ui_widget` function) are often created anew each time a config is
#' built; compared with `identical()`, they would render the table again on every
#' update. Their code (formals and body) is compared instead, so another widget renders
#' again; values a function finds in its environment don't count.
#' @param x a param or param group.
#' @noRd
.param_signature <- function(x) {
    attrs <- attributes(x)
    attrs$validity <- NULL
    attrs <- lapply(attrs, \(a) if (is.function(a)) deparse(a) else a)
    # `param_value<-` may reorder the attributes
    attrs <- attrs[order(names(attrs))]
    if (inherits(x, "param_group")) {
        return(list(attrs, lapply(unclass(x), .param_signature)))
    }
    # the length of a factor is a value (multiple choice), not structure
    list(attrs, if (!is.factor(x)) length(x))
}

#' Update the inputs whose param values changed (structure unchanged)
#'
#' A changed value also becomes the value restored by the reset button; a value equal to
#' the current valid value (e.g. the user's own change read back from a pipeline) does
#' not.
#' @param m module state.
#' @noRd
.update_values <- function(m) {
    for (name in names(m$params)) {
        x <- m$params[[name]]
        value <- param_value(x)
        isChanged <- !identical(value, m$validValues[[name]])
        if (isChanged && !name %in% m$recover) {
            m$initial[[name]] <- value
        }
        if (!isChanged && !name %in% m$invalid) {
            next
        }
        .set_param_input(x, name, value, m$session)
        m$validValues[[name]] <- value
        .clear_invalid(m, name)
    }
}

#' Reset baselines after a structure change
#'
#' A param whose lock (attribute `locked`) is all that changed keeps its baseline if
#' its value did not change either: locking a step must not cost the other params their
#' reset. Every other param starts from its new value.
#' @param m module state (before the change).
#' @param signature the new structure signature.
#' @param values named `list` of the new plain values.
#' @return named `list` of the reset baselines.
#' @noRd
.carry_initial <- function(m, signature, values) {
    initial <- values
    dropLock <- function(s) {
        s[[1L]]$locked <- NULL
        s
    }
    for (name in intersect(names(values), names(m$signature))) {
        isKept <- identical(values[[name]], m$validValues[[name]]) &&
            identical(dropLock(signature[[name]]), dropLock(m$signature[[name]]))
        if (isKept) {
            initial[name] <- m$initial[name]
        }
    }
    initial
}


# --------------
# Setting inputs
# --------------
#' Set the inputs of a param to a value from the server
#'
#' Updates the widgets and synchronises Shiny's input values, so that the next user
#' input is seen as a change even if it equals the value before (e.g. clearing an input
#' twice). The inputs of a group are synchronised in one message: one by one, the
#' server would see a child's new value next to the old values of the others and take
#' the mix as a change.
#' @param x a param or param group.
#' @param name name of the param.
#' @param value plain value of the param.
#' @param session the module session.
#' @noRd
.set_param_input <- function(x, name, value, session) {
    ids <- .input_ids(x, name)
    params <- if (inherits(x, "param_group")) unclass(x) else list(x)
    values <- if (inherits(x, "param_group")) value[names(x)] else list(value)
    inputs <- lapply(seq_along(ids), \(i) {
        inputValue <- .input_form(params[[i]], values[[i]])
        .update_input(params[[i]], ids[[i]], inputValue, session)
        list(id = session$ns(ids[[i]]), value = inputValue)
    })
    .send_custom_message(
        "pubflow:syncInputValue",
        list(inputs = inputs),
        session = session
    )
    invisible(NULL)
}

#' Plain value in the form its widget reports it
#' @param x a param (not a group).
#' @param value plain value of `x`.
#' @noRd
.input_form <- function(x, value) {
    if (is.factor(value)) as.character(value) else value
}

#' Update the widget of a param (not a group) with `update*Input()`
#'
#' Custom widget functions get the generic input message `list(value = )`.
#' @param x a param (not a group).
#' @param inputId input id (not namespaced).
#' @param value value from `.input_form()`.
#' @param session the module session.
#' @noRd
.update_input <- function(x, inputId, value, session) {
    widget <- .widget(x)
    if (is.function(widget)) {
        return(session$sendInputMessage(inputId, list(value = value)))
    }
    switch(
        widget,
        text = shiny::updateTextInput(
            session = session,
            inputId = inputId,
            value = value
        ),
        numeric = shiny::updateNumericInput(
            session = session,
            inputId = inputId,
            value = value
        ),
        slider = shiny::updateSliderInput(
            session = session,
            inputId = inputId,
            value = value
        ),
        select = shiny::updateSelectInput(
            session = session,
            inputId = inputId,
            selected = value
        ),
        radio = shinyWidgets::updateRadioGroupButtons(
            session = session,
            inputId = inputId,
            selected = value
        ),
        switch = shinyWidgets::updatePrettySwitch(
            session = session,
            inputId = inputId,
            value = value
        )
    )
    invisible(NULL)
}


# ======================================================================================
# Browser to server
# ======================================================================================

# --------------
# Reading inputs
# --------------
#' Raw input values of params
#' @param input the module's `input`.
#' @param params named list of params.
#' @return named list (by param) of named lists (by input id).
#' @noRd
.read_inputs <- function(input, params) {
    lapply(rlang::set_names(names(params)), \(name) {
        ids <- .input_ids(params[[name]], name)
        lapply(rlang::set_names(ids), \(id) input[[id]])
    })
}

#' Current values of the inputs that exist (not namespaced ids)
#' @param input the module's `input`.
#' @return named list by input id.
#' @noRd
.present_inputs <- function(input) {
    ids <- names(input)
    lapply(rlang::set_names(ids), \(id) input[[id]])
}

#' Process the inputs of all params; emit the valid changes
#' @param m module state.
#' @param raws raw input values from `.read_inputs()`.
#' @param known names of the inputs known to Shiny (`names(input)`).
#' @noRd
.on_inputs <- function(m, raws, known) {
    changed <- list()
    for (name in intersect(names(m$params), names(raws))) {
        value <- .process_input(m, name, raws[[name]], known)
        if (!is.null(value)) {
            changed[[name]] <- value
        }
    }
    m$valid(length(m$invalid) == 0L)
    if (length(changed) > 0L) {
        .emit(m, changed)
    }
}

#' Process the raw input of one param
#'
#' Skips inputs that did not change since they were last processed and params whose
#' input ids are not all known to Shiny yet (after a render; a NULL value, e.g. of an
#' empty multiple choice select, counts). Inputs that keep their old value hold their
#' new widget's value: Shiny sends the initial values of a render in one message and
#' does not resend equal values.
#' @param m module state.
#' @param name name of the param.
#' @param raw named list of raw input values (by input id).
#' @param known names of the inputs known to Shiny (`names(input)`).
#' @return the new valid plain value, or `NULL` (no valid change).
#' @noRd
.process_input <- function(m, name, raw, known) {
    ids <- names(raw)
    isNew <- vapply(
        ids,
        FUN = \(id) !identical(raw[[id]], m$seen[[id]]),
        FUN.VALUE = logical(1)
    )
    if (!any(isNew)) {
        return(NULL)
    }
    m$seen[ids] <- raw
    if (!all(ids %in% known)) {
        return(NULL)
    }
    edited <- names(.input_ids(m$params[[name]], name))[isNew]
    .evaluate_input(m, name, unname(raw), edited)
}

#' Convert, compare and validate the input of one param
#' @param m module state.
#' @param name name of the param.
#' @param raw list of raw input values (one per input id, children order).
#' @param edited names of the group children whose input changed.
#' @return the new valid plain value, or `NULL`.
#' @noRd
.evaluate_input <- function(m, name, raw, edited = NULL) {
    x <- m$params[[name]]
    previous <- m$validValues[[name]]
    candidate <- tryCatch(.input_to_param(raw, x), error = identity)
    if (.is_locked(x)) {
        return(.ignore_locked_input(m, x, name, previous, candidate))
    }
    if (inherits(candidate, "error")) {
        info <- .cnd_message(candidate)
        if (rlang::is_string(candidate$child)) {
            names(info) <- candidate$child
        }
        return(.reject_input(m, name, info, NULL, edited))
    }
    value <- param_value(candidate)
    if (identical(value, previous)) {
        .clear_invalid(m, name)
        return(NULL)
    }
    info <- Filter(nzchar, param_validity(candidate))
    if (length(info) > 0L) {
        return(.reject_input(m, name, info[1L], value, edited))
    }
    .clear_invalid(m, name)
    value
}

#' Ignore a change of a locked param: log it and restore the input
#'
#' A disabled widget alone is no guarantee (the browser can still send a value), so the
#' server ignores changes of locked params: the change is logged with [message()] (audit
#' trail) and the input gets back the last valid value.
#' @param m module state.
#' @param x the param.
#' @param name name of the param.
#' @param previous the last valid plain value.
#' @param candidate the param with the input's value, or the error of its conversion.
#' @return `NULL`.
#' @noRd
.ignore_locked_input <- function(m, x, name, previous, candidate) {
    isChanged <- inherits(candidate, "error") ||
        !identical(param_value(candidate), previous)
    if (isChanged) {
        label <- param_attr(x, "label", default = name)
        message(sprintf("'%s' input: locked, change ignored", label))
        .set_param_input(x, name, previous, m$session)
    }
    NULL
}

#' The param `x` with the value of its raw input(s)
#' @param raw list of raw input values (one per input id, children order).
#' @param x a param or param group.
#' @noRd
.input_to_param <- function(raw, x) {
    value <- if (inherits(x, "param_group")) {
        rlang::set_names(
            lapply(seq_along(raw), \(i) {
                tryCatch(
                    .input_value(raw[[i]], x[[i]]),
                    error = \(e) {
                        # name the child whose conversion failed
                        rlang::abort(conditionMessage(e), child = names(x)[[i]])
                    }
                )
            }),
            names(x)
        )
    } else {
        .input_value(raw[[1L]], x)
    }
    param_value(x) <- value
    x
}

#' Plain value of one raw input, before conversion to the param's class
#'
#' An empty input (`NULL`) becomes `NA` for numeric and logical params and an empty
#' vector for character and factor params.
#' @param raw raw value of one input.
#' @param x a param (not a group).
#' @noRd
.input_value <- function(raw, x) {
    type <- param_type(x)
    if (is.null(raw)) {
        return(switch(
            type,
            numeric = NA_real_,
            logical = NA,
            factor = ,
            character = character(0),
            raw
        ))
    }
    if (type != "numeric") {
        return(raw)
    }
    value <- suppressWarnings(as.numeric(raw))
    if (is.integer(x) && any(value != round(value), na.rm = TRUE)) {
        rlang::abort("value must be a whole number")
    }
    value
}


# --------------
# Invalid inputs
# --------------
#' Handle an invalid input: notify, then restore or keep and mark it
#' @param m module state.
#' @param name name of the param.
#' @param info `character(1)` message, possibly named by group child.
#' @param value the invalid plain value, or `NULL` if the conversion failed.
#' @param edited names of the group children whose input changed.
#' @return `NULL`.
#' @noRd
.reject_input <- function(m, name, info, value, edited = NULL) {
    x <- m$params[[name]]
    previous <- m$validValues[[name]]
    keep <- m$opts$on_invalid == "keep"
    .notify_invalid_param_input(
        x,
        name,
        info,
        value = value,
        previous = previous,
        session = m$session,
        persistent = keep,
        edited = edited
    )
    if (keep) {
        m$invalid <- union(m$invalid, name)
    } else {
        .set_param_input(x, name, previous, m$session)
    }
    NULL
}

#' Remove the invalid mark of a param (`on_invalid = "keep"`)
#' @param m module state.
#' @param name name of the param.
#' @noRd
.clear_invalid <- function(m, name) {
    if (!name %in% m$invalid) {
        return(invisible(NULL))
    }
    m$invalid <- setdiff(m$invalid, name)
    ids <- .input_ids(m$params[[name]], name)
    for (id in ids) {
        .send_custom_message(
            "pubflow:setInputAttrib",
            list(id = m$session$ns(id), attrib = list(`aria-invalid` = FALSE)),
            session = m$session
        )
    }
    invisible(NULL)
}

#' Notify about an invalid input
#'
#' Logs `"'<label>' input: <info>"` with [message()] (audit trail), shows `info` inline
#' next to the input and lets the input glow. For a param group the input of the child
#' concerned is used: the child named by `info`, else the first child just edited, else
#' the first child whose value differs between `value` and `previous`, else the first
#' child.
#' @param x a param or param group.
#' @param name name of the param.
#' @param info `character(1)` message, possibly named by group child.
#' @param value the invalid plain value, or `NULL`.
#' @param previous the last valid plain value.
#' @param session the module session.
#' @param persistent `TRUE`: mark the input `aria-invalid` until it is valid again
#'   (`.clear_invalid()`), else only while it glows.
#' @param edited names of the group children whose input changed.
#' @return the (not namespaced) input id concerned, invisibly.
#' @noRd
.notify_invalid_param_input <- function(
    x,
    name,
    info,
    value = NULL,
    previous = NULL,
    session = shiny::getDefaultReactiveDomain(),
    persistent = FALSE,
    edited = NULL
) {
    target <- .invalid_target(x, name, info, value, previous, edited)
    text <- unname(info)
    message(sprintf("'%s' input: %s", target$label, text))
    id <- session$ns(target$id)
    invalid <- list(`aria-invalid` = "true")
    .send_custom_message(
        "pubflow:showInputInlineMessage",
        list(id = id, text = text),
        session = session
    )
    glow <- list(id = id, what = "pubflow-warn-glow")
    if (!persistent) {
        glow$attrib <- invalid
    }
    .send_custom_message("pubflow:triggerClassAttrib", glow, session = session)
    if (persistent) {
        .send_custom_message(
            "pubflow:setInputAttrib",
            list(id = id, attrib = invalid),
            session = session
        )
    }
    invisible(target$id)
}

#' Input id and label concerned by an invalid value of a param
#' @param x,name,info,value,previous,edited see `.notify_invalid_param_input()`.
#' @return `list(id, label)`.
#' @noRd
.invalid_target <- function(x, name, info, value, previous, edited = NULL) {
    label <- param_attr(x, "label", default = name)
    ids <- .input_ids(x, name)
    if (!inherits(x, "param_group")) {
        return(list(id = ids[[1L]], label = label))
    }
    child <- names(info)
    if (rlang::is_string(child) && child %in% names(ids)) {
        childLabel <- param_attr(x[[child]], "label", default = child)
        return(list(
            id = ids[[child]],
            label = sprintf("%s (%s)", label, childLabel)
        ))
    }
    edited <- intersect(edited, names(ids))
    if (length(edited) > 0L) {
        return(list(id = ids[[edited[[1L]]]], label = label))
    }
    differs <- vapply(
        names(ids),
        FUN = \(n) {
            is.list(value) && is.list(previous) && !identical(value[[n]], previous[[n]])
        },
        FUN.VALUE = logical(1)
    )
    child <- if (any(differs)) names(ids)[differs][[1L]] else names(ids)[[1L]]
    list(id = ids[[child]], label = label)
}

#' First validity message of a param for a value (named by group child)
#' @param x a param or param group.
#' @param value plain value to check.
#' @param default returned if the value is valid.
#' @return `character(1)` message (also of a failing conversion), or `default`.
#' @noRd
.first_invalid_message <- function(x, value, default) {
    info <- tryCatch(
        {
            param_value(x) <- value
            Filter(nzchar, param_validity(x))
        },
        error = .cnd_message
    )
    if (length(info) > 0L) info[1L] else default
}


# ----------------------
# Emitting and resetting
# ----------------------
#' Emit valid changes in `changed` and `values`
#' @param m module state.
#' @param changed named list of the changed valid plain values.
#' @noRd
.emit <- function(m, changed) {
    m$validValues[names(changed)] <- changed
    m$values(m$validValues)
    n <- m$emission()$n
    m$emission(list(n = if (is.null(n)) 1L else n + 1L, values = changed))
}

#' Reset button: restore the initial values (see `.update_values()`)
#'
#' An initial value that the current validity rules reject is reported like an invalid
#' input and not restored. Locked params are left alone.
#' @param m module state.
#' @noRd
.on_reset <- function(m) {
    changed <- list()
    for (name in names(m$params)) {
        x <- m$params[[name]]
        if (.is_locked(x)) {
            next
        }
        initial <- m$initial[[name]]
        isChanged <- !identical(initial, m$validValues[[name]])
        info <- if (isChanged) .first_invalid_message(x, initial, NULL)
        if (!is.null(info)) {
            .notify_invalid_param_input(
                x,
                name,
                info,
                value = initial,
                previous = m$validValues[[name]],
                session = m$session
            )
            next
        }
        if (isChanged || name %in% m$invalid) {
            .set_param_input(x, name, initial, m$session)
            .clear_invalid(m, name)
        }
        if (isChanged) {
            changed[[name]] <- initial
        }
    }
    m$valid(length(m$invalid) == 0L)
    if (length(changed) > 0L) {
        .emit(m, changed)
    }
}

#' Set changed values in a pipeline
#'
#' On `pipeflow_set_params_error` nothing is set, and every invalid param (once, also if
#' several steps hold it) is reported like an invalid input (see
#' `.notify_invalid_param_input()`) of the param the UI shows. On a view, the values go
#' to every step of the pipeline that has them, so a step outside the view may reject a
#' value: the value is checked with the param object of the rejecting step (a step of
#' the view first), and the label and previous value come from the shown param.
#' @param pip a pipeflow pipeline or view.
#' @param values named list of plain values to set.
#' @param session the module session.
#' @return `TRUE` if the values were set, else `FALSE`.
#' @noRd
.apply_values <- function(pip, values, session) {
    error <- tryCatch(
        {
            pipeflow::pip_set_params(pip, values)
            NULL
        },
        pipeflow_set_params_error = identity
    )
    if (is.null(error)) {
        return(TRUE)
    }
    shown <- pub_get_params(pip, order = "pipeline")
    steps <- pipeflow::pip_data(pip)
    stored <- rlang::set_names(steps$params, steps$step)
    errors <- error$errors[order(!error$errors$step %in% pip[["step"]]), , drop = FALSE]
    invalid <- errors[!duplicated(errors$name), , drop = FALSE]
    for (i in seq_len(nrow(invalid))) {
        name <- invalid$name[[i]]
        x <- shown[[name]]
        if (!is_param(x)) {
            message(sprintf("'%s' input: %s", name, invalid$message[[i]]))
            next
        }
        rejecting <- stored[[invalid$step[[i]]]][[name]]
        check <- if (is_param(rejecting)) rejecting else x
        info <- .first_invalid_message(check, values[[name]], invalid$message[[i]])
        .notify_invalid_param_input(
            x,
            name,
            info,
            value = values[[name]],
            previous = param_value(x),
            session = session
        )
    }
    FALSE
}


# ======================================================================================
# Helpers
# ======================================================================================

# --------
# Messages
# --------
#' Send a custom message to the browser (no-op without a session)
#' @param type message type, e.g. `"pubflow:syncInputValue"`.
#' @param message list sent as JSON.
#' @param session a Shiny session or `NULL`.
#' @noRd
.send_custom_message <- function(
    type,
    message,
    session = shiny::getDefaultReactiveDomain()
) {
    if (is.null(session)) {
        return(invisible(NULL))
    }
    session$sendCustomMessage(type = type, message = message)
    invisible(NULL)
}
