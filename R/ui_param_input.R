# Input widgets for params: one Shiny input per param, chosen by `param_type()` and the
# attributes `ui_widget`, `ui_args` and `ui_style`, plus the compact parameter table of
# the param UI module.

# ======================================================================================
# Input widgets
# ======================================================================================

# -------
# Widgets
# -------
# Default widget per param type
.default_widgets <- c(
    character = "text",
    factor = "select",
    logical = "switch",
    numeric = "numeric"
)

# Widgets whose input element can be the target of a `<label for>`
.labelable_widgets <- c("text", "numeric", "slider", "select", "switch")

#' Input widget for a param
#'
#' Builds the Shiny input widget of a param, e.g. for your own layouts. The parameter
#' module ([pub_params_server()]) uses it for every row of its parameter table.
#'
#' @details
#' ## Choosing the widget
#'
#' The widget depends on the type of the value ([param_type()]). Choose another one with
#' the param attribute `ui_widget`, either a widget name or a function:
#'
#' | Type | Default widget | Other widgets |
#' |---|---|---|
#' | character | `"text"` | |
#' | factor | `"select"` | `"radio"` |
#' | logical | `"switch"` | |
#' | numeric | `"numeric"` | `"slider"` |
#'
#' The widgets are [shiny::textInput()], [shiny::selectInput()],
#' [shinyWidgets::radioGroupButtons()], [shinyWidgets::prettySwitch()],
#' [shiny::numericInput()] and [shiny::sliderInput()]. Other types need `ui_widget`.
#'
#' A [param_group()] gives the inputs of its children side by side, with the input ids
#' `<inputId>_<child>`. Their labels (else their names) are for screen readers only;
#' the group's label names the group as a whole. Its children can't be groups.
#' A `width` in `...` is the width of the whole group: the children share it equally.
#'
#' ## Widget arguments
#'
#' The param's value and attributes are passed to the widget function as follows:
#'
#' | Widget | Arguments from the param |
#' |---|---|
#' | `"text"` | `value` |
#' | `"switch"` | `value` |
#' | `"select"` | `choices` (the levels), `selected` (the current level) |
#' | `"radio"` | `choices` (the levels), `selected` (the current level) |
#' | `"numeric"` | `value`, `min`, `max`, `step` |
#' | `"slider"` | `value` (one value or a range of two), `min`, `max`, `step` |
#'
#' `min` and `max` are the param's attributes of that name (unset: no bound). Without a
#' `step` attribute, `step` is a tenth of the range if both bounds are finite. A slider
#' needs finite `min` and `max`.
#'
#' You can change these arguments:
#'
#' * Arguments in `...` override those derived from the param.
#' * Only arguments that the widget function accepts are passed, so `...` can hold
#'   arguments for some widgets only (e.g. `updateOn` or `width`).
#' * The param attribute `ui_args` (a named list) overrides all of them, e.g.
#'   `ui_args = list(multiple = TRUE)` for a select input with multiple choices.
#' * The CSS in the param attribute `ui_style` applies to the input.
#'
#' ## Locked params
#'
#' A param with `locked = TRUE` (for a group: the group's attribute) gives a disabled
#' input. It shows the value, but can't be changed, e.g. for a param that a workflow
#' fixes. The tooltip adds "(locked)". This also works for widgets given as `ui_widget`.
#'
#' ## Tooltip
#'
#' With `tooltip = TRUE` the input shows the param's `description` on hover (after 1.5
#' s, hidden after 7 s) and when it gets the keyboard focus (hidden on Escape).
#' Without a description it shows the `label`; `description = ""` turns the tooltip
#' off. This works with Bootstrap 3 and 5 and needs pubflow's JavaScript, which
#' `pub_param_input()` attaches as an HTML dependency.
#'
#' @param x A param object.
#' @param inputId `character(1)` input id (namespaced by the caller, e.g. with `ns()` in
#'   a Shiny module).
#' @param label Label of the input; `NULL` for none.
#' @param tooltip `TRUE`: show the param's description as tooltip.
#' @param ... Further arguments for the widget function; those it does not accept are
#'   dropped automatically.
#' @return A Shiny tag (with pubflow's HTML dependency attached).
#' @seealso [pub_params_server()]
#' @examples
#' alpha <- numeric_param(0.05, label = "Alpha", min = 0, max = 1)
#' pub_param_input(alpha, "alpha", updateOn = "blur")
#'
#' trans <- choice_param("log", choices = c("none", "log"), label = "Scale")
#' pub_param_input(trans, "trans")
#'
#' # Another widget by name: the attribute `ui_widget` belongs to the param
#' trans <- choice_param(
#'     "log",
#'     choices = c("none", "log"),
#'     label = "Scale",
#'     ui_widget = "radio"
#' )
#' pub_param_input(trans, "trans")
#'
#' # A slider for a single value or, with two values, for a range
#' level <- numeric_param(0.5, label = "Level", min = 0, max = 1, ui_widget = "slider")
#' pub_param_input(level, "level")
#' range <- numeric_param(
#'     c(0.2, 0.8),
#'     label = "Range",
#'     min = 0,
#'     max = 1,
#'     ui_widget = "slider"
#' )
#' pub_param_input(range, "range")
#'
#' # Your own widget function: it gets the arguments from the table above that it
#' # accepts, here `inputId`, `label` and `value`
#' notes <- param(
#'     "Some notes",
#'     label = "Notes",
#'     ui_widget = function(inputId, label, value) {
#'         shiny::textAreaInput(inputId, label, value, rows = 3)
#'     }
#' )
#' pub_param_input(notes, "notes")
#'
#' # `ui_args` adds or overrides widget arguments, `ui_style` adds CSS
#' picks <- choice_param(
#'     "a",
#'     choices = c("a", "b", "c"),
#'     label = "Pick",
#'     ui_args = list(multiple = TRUE),
#'     ui_style = "width: 12em;"
#' )
#' pub_param_input(picks, "picks")
#'
#' points <- param(TRUE, label = "Show points", description = "Plot the data")
#' pub_param_input(points, "points", tooltip = TRUE)
#'
#' limits <- param_group(
#'     list(
#'         lower = numeral_param("95", label = "Lower CI"),
#'         upper = numeral_param("105", label = "Upper CI")
#'     ),
#'     label = "Confidence limits"
#' )
#' pub_param_input(limits, inputId = "ci_limits", width = "10ch")
#'
#' # A locked param is shown, but can't be changed
#' level <- numeric_param(0.95, label = "Level", min = 0, max = 1, locked = TRUE)
#' pub_param_input(level, "level")
#' @export
pub_param_input <- function(
    x,
    inputId,
    label = param_attr(x, "label"),
    tooltip = FALSE,
    ...
) {
    .assert_param(x)
    if (!rlang::is_string(inputId) || !nzchar(inputId)) {
        rlang::abort("`inputId` must be a single non-empty string.")
    }
    ui <- .param_input(x, inputId, label, tooltip, ..., locked = .is_locked(x))
    style <- .input_style(x, inputId)
    if (!is.null(style)) {
        ui <- htmltools::tagList(style, ui)
    }
    htmltools::attachDependencies(ui, .pubflow_dependency(), append = TRUE)
}

#' Input widget for a param, without HTML dependency
#' @param x a param object.
#' @param inputId `character(1)` input id.
#' @param label label of the input; `NULL` for none.
#' @param tooltip `TRUE`: show the param's description as tooltip.
#' @param ... further arguments for the widget function.
#' @param locked `TRUE`: disable the input (default: attribute `locked` of `x`; the
#'   children of a group take the group's).
#' @return A Shiny tag.
#' @noRd
.param_input <- function(x, inputId, label, tooltip, ..., locked = .is_locked(x)) {
    if (inherits(x, "param_group")) {
        return(.group_input(x, inputId, label, tooltip, ..., locked = locked))
    }
    ui <- if (locked) {
        .disable_input(.single_input(x, inputId, label, ..., disabled = TRUE))
    } else {
        .single_input(x, inputId, label, ...)
    }
    if (!isTRUE(tooltip)) {
        return(ui)
    }
    .with_tooltip(ui, .locked_text(.description(x), locked))
}

#' Input widget for a param that is not a group
#' @param x a param object (not a group).
#' @param inputId `character(1)` input id.
#' @param label label of the input; `NULL` for none.
#' @param ... further arguments for the widget function (dropped if it doesn't accept
#'   them, e.g. `disabled`).
#' @return A Shiny tag.
#' @noRd
.single_input <- function(x, inputId, label, ...) {
    widget <- .widget(x)
    fun <- .widget_fun(widget)
    .check_widget_value(x, widget, inputId)
    candidates <- .value_args(x, widget)
    dots <- list(...)
    dots <- dots[nzchar(rlang::names2(dots))]
    candidates[names(dots)] <- dots
    args <- c(
        list(inputId = inputId, label = label),
        .accepted_args(fun, candidates)
    )
    uiArgs <- param_attr(x, "ui_args", default = list())
    if (!is.list(uiArgs) || !rlang::is_named2(uiArgs)) {
        rlang::abort(sprintf(
            "Attribute `ui_args` of '%s' must be a named list.",
            inputId
        ))
    }
    args[names(uiArgs)] <- uiArgs
    do.call(fun, args)
}

#' Inputs of the children of a param group, side by side
#' @param x a param group.
#' @param inputId `character(1)` input id of the group.
#' @param label label of the group; `NULL` for none.
#' @param tooltip `TRUE`: show the children's descriptions as tooltips.
#' @param ... further arguments for the widget functions.
#' @param width width of the whole group (CSS) or `NULL`; the children share it.
#' @param locked `TRUE`: disable the inputs of all children.
#' @return A Shiny tag.
#' @noRd
.group_input <- function(
    x,
    inputId,
    label,
    tooltip,
    ...,
    width = NULL,
    locked = FALSE
) {
    ids <- .input_ids(x, inputId)
    # no width: the widgets keep their own default
    childArgs <- if (!is.null(width)) list(width = "100%")
    items <- lapply(names(x), \(child) {
        input <- rlang::inject(.child_input(
            x[[child]],
            ids[[child]],
            .child_label(x[[child]], child),
            tooltip,
            ...,
            !!!childArgs,
            locked = locked
        ))
        htmltools::div(class = "pubflow-param-item", input)
    })
    if (is.null(label)) {
        return(.group_row(items, width))
    }
    labelId <- paste0(inputId, "-param-label")
    htmltools::div(
        class = "form-group shiny-input-container",
        htmltools::tags$label(class = "control-label", id = labelId, label),
        .group_row(items, width, labelId)
    )
}

#' Input of a child of a param group, labelled for screen readers only
#'
#' A visually hidden `<label for>` if the widget is labelable (see `.label_for()`),
#' else a `role="group"` named with `aria-label` around the input.
#' @param x a param object (not a group).
#' @param inputId `character(1)` input id.
#' @param label `character(1)` label of the child.
#' @param tooltip,...,locked as for `.param_input()`.
#' @return A tag or tag list.
#' @noRd
.child_input <- function(x, inputId, label, tooltip, ..., locked) {
    input <- .param_input(x, inputId, NULL, tooltip, ..., locked = locked)
    labelFor <- .label_for(x, inputId)
    if (is.null(labelFor)) {
        return(htmltools::div(role = "group", `aria-label` = label, input))
    }
    htmltools::tagList(
        htmltools::tags$label(
            class = "pubflow-visually-hidden",
            `for` = labelFor,
            label
        ),
        input
    )
}

#' Row of the inputs of a group's children, a named group if `labelId` is given
#' @param items list of the children's inputs.
#' @param width width of the whole group (CSS) or `NULL`.
#' @param labelId `character(1)` id of the group's label or `NULL`.
#' @return A `div` tag.
#' @noRd
.group_row <- function(items, width, labelId = NULL) {
    htmltools::div(
        class = "pubflow-param-group",
        role = if (!is.null(labelId)) "group",
        `aria-labelledby` = labelId,
        style = htmltools::css(width = width),
        items
    )
}

#' Input ids of a param: the id itself or, for groups, `<id>_<child>`
#' @param x a param object.
#' @param inputId `character(1)` input id of the param.
#' @return `character`; for groups named by child.
#' @noRd
.input_ids <- function(x, inputId) {
    if (inherits(x, "param_group")) {
        nested <- vapply(unclass(x), inherits, logical(1), "param_group")
        if (any(nested)) {
            rlang::abort(sprintf(
                paste(
                    "Can't build inputs for '%s': a param group in the UI can't",
                    "contain param groups (%s)."
                ),
                inputId,
                toString(names(x)[nested])
            ))
        }
        return(rlang::set_names(paste0(inputId, "_", names(x)), names(x)))
    }
    inputId
}

#' Disable an input: its form controls, selectize and slider
#'
#' Puts the input into a disabled `fieldset`, which disables every form control in it,
#' also those that tag functions render (e.g. the buttons of
#' `shinyWidgets::radioGroupButtons()`), and sets `disabled` on the `input`, `select`,
#' `textarea` and `button` tags it can reach (for CSS that selects `[disabled]`, e.g.
#' the switch of `shinyWidgets::prettySwitch()`) and `data-disable` on sliders
#' (ion.rangeSlider ignores a disabled `fieldset`; selectize doesn't).
#' The wrapping `div` of class `pubflow-param-locked` takes the tooltip: its CSS lets it
#' receive the mouse events that disabled controls don't get.
#' @param ui the input (a tag or tag list).
#' @return A `div` tag.
#' @noRd
.disable_input <- function(ui) {
    fieldset <- htmltools::tags$fieldset(
        class = "pubflow-param-fieldset",
        disabled = NA,
        ui
    )
    q <- htmltools::tagQuery(htmltools::div(class = "pubflow-param-locked", fieldset))
    for (element in c("input", "select", "textarea", "button")) {
        q$resetSelected()$find(element)$addAttrs(disabled = NA)
    }
    q$resetSelected()$find(".js-range-slider")$addAttrs(`data-disable` = "true")
    q$allTags()
}


# -------------
# Widget choice
# -------------
#' Widget of a param: attribute `ui_widget` or the default of its type
#' @param x a param object (not a group).
#' @return `character(1)` widget name or a function.
#' @noRd
.widget <- function(x) {
    widget <- param_attr(x, "ui_widget")
    if (is.null(widget)) {
        type <- param_type(x)
        widget <- .default_widgets[type]
        if (is.na(widget)) {
            rlang::abort(sprintf(
                paste(
                    "Can't build an input for a parameter of type '%s';",
                    "set the attribute `ui_widget`."
                ),
                type
            ))
        }
        return(unname(widget))
    }
    if (!is.function(widget) && !rlang::is_string(widget)) {
        rlang::abort("Attribute `ui_widget` must be a widget name or function.")
    }
    widget
}

#' Widget function for a widget name (or the function itself)
#' @param widget `character(1)` widget name or a function.
#' @return The widget function.
#' @noRd
.widget_fun <- function(widget) {
    if (is.function(widget)) {
        return(widget)
    }
    switch(
        widget,
        text = shiny::textInput,
        numeric = shiny::numericInput,
        slider = shiny::sliderInput,
        select = shiny::selectInput,
        radio = shinyWidgets::radioGroupButtons,
        switch = shinyWidgets::prettySwitch,
        rlang::abort(sprintf(
            "Unknown widget '%s'; use one of %s, or a function.",
            widget,
            toString(c("text", "numeric", "slider", "select", "radio", "switch"))
        ))
    )
}

#' Check that the value of a param fits its widget
#' @param x a param object (not a group).
#' @param widget `character(1)` widget name or a function (not checked).
#' @param inputId `character(1)` input id, for the error message.
#' @return `NULL`, invisibly.
#' @noRd
.check_widget_value <- function(x, widget, inputId) {
    if (is.function(widget)) {
        return(invisible(NULL))
    }
    n <- length(x)
    ok <- switch(
        widget,
        text = is.character(x) && n == 1L,
        switch = n == 1L,
        numeric = n == 1L,
        slider = n %in% 1:2,
        TRUE
    )
    if (!ok) {
        rlang::abort(sprintf(
            "Can't build a '%s' input for '%s' from a value of length %d.",
            widget,
            inputId,
            n
        ))
    }
    invisible(NULL)
}


# ----------------
# Widget arguments
# ----------------
#' Candidate widget arguments derived from the value of a param
#'
#' Only those accepted by the widget function are passed (see `.accepted_args()`).
#' @param x a param object (not a group).
#' @param widget `character(1)` widget name or a function.
#' @return named list of arguments.
#' @noRd
.value_args <- function(x, widget) {
    value <- param_value(x)
    switch(
        param_type(x),
        factor = list(
            choices = levels(value),
            selected = as.character(value),
            value = as.character(value)
        ),
        numeric = c(list(value = value), .numeric_bounds(x, widget)),
        list(value = value)
    )
}

#' `min`, `max` and `step` of a numeric widget
#' @param x a numeric param.
#' @param widget `character(1)` widget name or a function.
#' @return `list(min, max, step)`; `NA` for a missing or non-finite attribute (and a
#'   step that isn't positive).
#' @noRd
.numeric_bounds <- function(x, widget) {
    scalar <- function(which) {
        v <- param_attr(x, which, default = NA_real_)
        if (is.numeric(v) && length(v) == 1L && is.finite(v)) v else NA_real_
    }
    min <- scalar("min")
    max <- scalar("max")
    step <- scalar("step")
    if (!is.na(step) && step <= 0) {
        step <- NA_real_
    }
    if (is.na(step) && !is.na(min) && !is.na(max) && max > min) {
        step <- (max - min) / 10
    }
    if (identical(widget, "slider") && (is.na(min) || is.na(max))) {
        rlang::abort("A slider input needs finite attributes `min` and `max`.")
    }
    list(min = min, max = max, step = step)
}

#' The arguments of `args` that function `fun` accepts by name
#' @param fun a function.
#' @param args named list of candidate arguments.
#' @return The subset of `args`.
#' @noRd
.accepted_args <- function(fun, args) {
    accepted <- setdiff(names(formals(fun)), "...")
    args[names(args) %in% accepted]
}


# -------------------------
# Tooltips and dependencies
# -------------------------
#' Description of a param for its tooltip
#' @param x a param object.
#' @return The attribute `description`, else `label`, else `""`.
#' @noRd
.description <- function(x) {
    param_attr(x, "description", default = param_attr(x, "label", default = ""))
}

#' A label or description with the hint `" (locked)"` for locked inputs
#' @param text `character(1)` label or description (`""` or no string: unchanged).
#' @param locked `TRUE`: add the hint.
#' @return `text`, with the hint if `locked`.
#' @noRd
.locked_text <- function(text, locked) {
    if (locked && rlang::is_string(text) && nzchar(text)) {
        paste(text, "(locked)")
    } else {
        text
    }
}

#' Add a tooltip showing `text` to an input
#'
#' Adds the tooltip attributes of Bootstrap 3 (`data-*`) and 5 (`data-bs-*`) to the
#' outer tag of the input (a wrapping `div` if the input is no single tag); pubflow.js
#' initialises the tooltips when the mouse enters (also for inputs inserted later) and
#' hides them after `autohide` ms.
#' @param ui the input (a tag or tag list).
#' @param text tooltip text; no tooltip unless a non-empty string.
#' @param delay show delay in ms.
#' @param autohide time in ms after which the tooltip hides.
#' @return The input with tooltip attributes.
#' @noRd
.with_tooltip <- function(ui, text, delay = 1500L, autohide = 7000L) {
    if (!rlang::is_string(text) || !nzchar(text)) {
        return(ui)
    }
    if (!inherits(ui, "shiny.tag")) {
        ui <- htmltools::div(class = "pubflow-tooltip-wrapper", ui)
    }
    delayJson <- sprintf('{"show":%d,"hide":100}', delay)
    htmltools::tagAppendAttributes(
        ui,
        class = "pubflow-tooltip",
        title = text,
        `data-toggle` = "tooltip",
        `data-bs-toggle` = "tooltip",
        `data-trigger` = "hover",
        `data-bs-trigger` = "hover",
        `data-container` = "body",
        `data-bs-container` = "body",
        `data-delay` = delayJson,
        `data-bs-delay` = delayJson,
        `data-pubflow-tooltip-autohide-ms` = autohide
    )
}

#' HTML dependency with pubflow's JavaScript and CSS (inst/www)
#' @noRd
.pubflow_dependency <- function() {
    htmltools::htmlDependency(
        name = "pubflow",
        version = unname(getNamespaceVersion("pubflow")),
        src = "www",
        package = "pubflow",
        script = "pubflow.js",
        stylesheet = "pubflow.css",
        all_files = FALSE
    )
}


# ======================================================================================
# Parameter table
# ======================================================================================

# -----
# Table
# -----
#' Compact parameter table of the param UI module
#'
#' Rows in the order of `params` (sorted by the caller), a heading per group if there is
#' more than one group, params with attribute `advanced = TRUE` in a collapsed
#' "Advanced" block per group, and optionally a reset button.
#' @param params named list of params.
#' @param ns namespace function for the input ids.
#' @param opts module options (see `.module_options()`).
#' @noRd
.params_table <- function(params, ns, opts) {
    groups <- .param_groups(params, opts$group_by)
    headings <- length(groups) > 1L
    body <- lapply(groups, \(g) {
        heading <- if (headings) .group_label(g$value, opts$group_labels)
        .params_group(params[g$names], ns, opts, heading)
    })
    htmltools::div(
        class = "pubflow-params-table",
        body,
        if (isTRUE(opts$reset)) {
            shiny::actionButton(
                ns("pubflow-reset"),
                "Reset",
                class = "btn-sm pubflow-params-reset"
            )
        }
    )
}

#' Split params into groups by the value of attribute `group_by`
#' @param params named list of params.
#' @param group_by name of the attribute to group by; `NULL`: one group.
#' @return list of `list(value, names)` in the order of first appearance; params without
#'   the attribute have value `NA`.
#' @noRd
.param_groups <- function(params, group_by) {
    values <- vapply(
        params,
        FUN = \(p) {
            value <- if (!is.null(group_by)) param_attr(p, group_by)
            if (rlang::is_string(value)) value else NA_character_
        },
        FUN.VALUE = character(1)
    )
    lapply(unique(values), \(value) {
        list(value = value, names = names(params)[values %in% value])
    })
}

#' Heading of a group of params
#' @param value the group's value of the `group_by` attribute (`NA`: none).
#' @param labels named labels of the group values.
#' @return `character(1)` heading.
#' @noRd
.group_label <- function(value, labels) {
    if (is.na(value)) {
        return("Other")
    }
    if (value %in% names(labels)) labels[[value]] else value
}

#' Heading, rows and "Advanced" block of one group of params
#' @param params named list of params.
#' @param ns namespace function for the input ids.
#' @param opts module options (see `.module_options()`).
#' @param heading heading of the group; `NULL` for none.
#' @return A tag list.
#' @noRd
.params_group <- function(params, ns, opts, heading = NULL) {
    advanced <- vapply(
        params,
        FUN = \(p) isTRUE(param_attr(p, "advanced")),
        FUN.VALUE = logical(1)
    )
    content <- htmltools::tagList(
        if (any(!advanced)) .params_rows(params[!advanced], ns, opts),
        if (any(advanced)) {
            htmltools::tags$details(
                class = "pubflow-params-advanced",
                htmltools::tags$summary("Advanced"),
                .params_rows(params[advanced], ns, opts)
            )
        }
    )
    if (is.null(heading)) {
        return(content)
    }
    # a fieldset, not a heading: the page decides the levels of its headings
    htmltools::tags$fieldset(
        class = "pubflow-params-section",
        htmltools::tags$legend(class = "pubflow-params-heading", heading),
        content
    )
}

#' Table with one row (label and input) per param
#' @param params named list of params.
#' @param ns namespace function for the input ids.
#' @param opts module options (see `.module_options()`).
#' @return A `<table>` tag.
#' @noRd
.params_rows <- function(params, ns, opts) {
    htmltools::tags$table(
        class = "pubflow-params-rows",
        lapply(names(params), \(name) {
            .param_row(params[[name]], name, ns, opts)
        })
    )
}

#' Table row of one param: label cell and input cell
#' @param x a param object.
#' @param name name of the param.
#' @param ns namespace function for the input ids.
#' @param opts module options (see `.module_options()`).
#' @return A `<tr>` tag.
#' @noRd
.param_row <- function(x, name, ns, opts) {
    inputId <- ns(name)
    label <- param_attr(x, "label", default = name)
    locked <- .is_locked(x)
    input <- .param_input(
        x,
        inputId,
        label = NULL,
        tooltip = opts$tooltips,
        width = opts$width,
        updateOn = opts$update_on,
        locked = locked
    )
    labelFor <- .label_for(x, inputId)
    labelId <- NULL
    if (is.null(labelFor)) {
        # no input element to point to: the label names a group around the input
        labelId <- paste0(inputId, "-param-label")
        input <- htmltools::div(role = "group", `aria-labelledby` = labelId, input)
    }
    htmltools::tags$tr(
        class = "pubflow-param-row",
        htmltools::tags$td(
            class = "pubflow-param-label-cell",
            htmltools::tags$label(
                class = c(
                    "pubflow-param-label",
                    if (locked) "pubflow-param-label-locked"
                ),
                id = labelId,
                `for` = labelFor,
                title = .locked_text(label, locked),
                label
            )
        ),
        htmltools::tags$td(
            class = "pubflow-param-input-cell",
            .input_style(x, inputId),
            input
        )
    )
}

#' Id of the element a param's label refers to (`NULL`: none)
#'
#' Only widgets with one input element can be the target of a `<label for>`; param
#' groups have none either: their label names the group as a whole.
#' @param x a param object.
#' @param inputId `character(1)` input id of the param.
#' @noRd
.label_for <- function(x, inputId) {
    if (inherits(x, "param_group")) {
        return(NULL)
    }
    widget <- param_attr(
        x,
        "ui_widget",
        default = .default_widgets[
            param_type(x)
        ]
    )
    if (rlang::is_string(widget) && widget %in% .labelable_widgets) inputId
}


# ------
# Styles
# ------
#' CSS rules for the attribute `ui_style` of a param (or its children)
#' @param x a param object.
#' @param inputId `character(1)` input id of the param.
#' @return a `<style>` tag or `NULL`.
#' @noRd
.input_style <- function(x, inputId) {
    if (inherits(x, "param_group")) {
        ids <- .input_ids(x, inputId)
        styles <- lapply(names(x), \(child) {
            .input_style_rule(x[[child]], ids[[child]])
        })
        styles <- unlist(styles)
    } else {
        styles <- .input_style_rule(x, inputId)
    }
    if (length(styles) > 0L) {
        htmltools::tags$style(htmltools::HTML(paste(styles, collapse = "\n")))
    }
}

#' CSS rule `#<id> {<ui_style>}` or `NULL`
#' @param x a param object (not a group).
#' @param inputId `character(1)` input id.
#' @noRd
.input_style_rule <- function(x, inputId) {
    style <- param_attr(x, "ui_style")
    if (rlang::is_string(style) && nzchar(style)) {
        sprintf("#%s {%s}", .escape_css_id(inputId), style)
    }
}

#' Escape a string for use as a CSS id selector
#'
#' Adds a backslash before any character that is not a letter, digit, underscore or
#' hyphen, so that e.g. `X.PS._1` becomes `X\.PS\._1`.
#' @param id `character(1)` element id.
#' @noRd
.escape_css_id <- function(id) {
    gsub("([^a-zA-Z0-9_-])", "\\\\\\1", id)
}
