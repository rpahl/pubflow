# Pipeline integration: plain values for step functions, set values by merging them into
# the stored param objects, read param objects from a pipeline, and read the outputs of
# other pipelines' steps that are up to date. Steps are added with pipeflow's pip_add();
# figures are stamped by the output hook methods in R/figure.R.
#
# pipeflow has no param protocol: `pip_get_params()` returns the first occurrence of a
# name (possibly a plain default hiding a param object of a later step), and its setter
# overwrites unless a method of `pip_param_value<-()` merges. pubflow adds that merging
# method, picks the first param object from pipeflow's grouping by name
# (`pip_get_params(simplify = FALSE)`), and registers `pip_param_value()` to hand plain
# values to the step functions.

# ======================================================================================
# Params in pipelines
# ======================================================================================

# ----------------
# Values for steps
# ----------------
#' Plain value of a param for a step function
#'
#' pipeflow applies [pipeflow::pip_param_value()] to the unbound arguments of a step
#' before it calls the step function, so step functions receive the plain values of
#' params (param groups: named lists of plain values). The stored params keep their
#' metadata.
#' @param x a param.
#' @param ... unused.
#' @return `param_value(x)`.
#' @exportS3Method pipeflow::pip_param_value
#' @noRd
pip_param_value.param <- function(x, ...) {
    param_value(x)
}

#' Merge a value into a stored param when params are set
#'
#' [pipeflow::pip_set_params()] calls the setter for every step that has the param, on
#' the value stored in that step: a plain value is merged with `param_value<-` (label,
#' choices and validity are kept), a param replaces the stored one. With
#' `validate = TRUE` (passed through `...` of `pip_set_params()`) an invalid result is
#' an error; a value that can't be merged is one in any case. pipeflow collects the
#' errors into one `pipeflow_set_params_error` and sets nothing.
#' @param x the stored param.
#' @param ... unused.
#' @param validate `TRUE`: signal an error if the result is invalid.
#' @param value plain value or param.
#' @return the param to store.
#' @exportS3Method pipeflow::"pip_param_value<-" param
#' @noRd
`pip_param_value<-.param` <- function(x, ..., validate = TRUE, value) {
    merged <- if (is_param(value)) value else .merge_value(x, value)
    if (isTRUE(validate)) {
        message <- .validity_message(merged)
        if (nzchar(message)) {
            rlang::cnd_signal(.invalid_param_error(merged, message))
        }
    }
    merged
}

#' Merge a plain value into a param (`pubflow_invalid_param` on failure)
#' @param x a param.
#' @param value plain value to merge with `param_value<-`.
#' @return `x` with the merged value.
#' @noRd
.merge_value <- function(x, value) {
    tryCatch(
        {
            param_value(x) <- value
            x
        },
        error = \(e) {
            rlang::cnd_signal(.invalid_param_error(x, .cnd_message(e)))
        }
    )
}

#' Validity messages of a param joined into one string ("" if valid)
#'
#' Messages of group children are prefixed with the child's name.
#' @param p a param or param group.
#' @return `character(1)`.
#' @noRd
.validity_message <- function(p) {
    info <- param_validity(p)
    if (inherits(p, "param_group")) {
        prefix <- ifelse(names(info) == "group", "", paste0(names(info), ": "))
        info <- ifelse(nzchar(info), paste0(prefix, info), "")
    }
    .collapse_validity(info)
}


# --------------
# Reading params
# --------------
#' Get the param objects of a pipeline
#'
#' Returns the params stored in a pipeline or view as a named list, e.g. to build a
#' parameter UI. If a name occurs in several steps, the first occurrence that is a param
#' counts. So, unlike [pipeflow::pip_get_params()], a plain default of an earlier step
#' does not hide the param of a later step (see Examples).
#'
#' @details
#' ## Order
#'
#' The params are listed in the order in which the pipeline first uses their names, also
#' as plain defaults. With `order = "config"` they follow the order of their config
#' instead (see [param_config()]).
#'
#' ## Setting params
#'
#' Set values with [pipeflow::pip_set_params()]. pubflow extends it as follows:
#'
#' * A *plain value* is merged into the param stored in each step (label, choices and
#'   validity are kept) and checked.
#' * A *param object* replaces the stored one (and is checked too).
#' * Steps that store a plain value get the plain value.
#' * If any value is *invalid* or can't be merged (e.g. a group value without the names
#'   of the children), nothing is set and one error (`pipeflow_set_params_error`) lists
#'   all problems in its field `errors`, a data.frame with columns `step`, `name` and
#'   `message`.
#' * `validate = FALSE` skips the validity check.
#'
#' Some hints:
#'
#' * Apply a *config*, e.g. at the end of a pipeline constructor, with
#'   `pip_set_params(x, config, unknown = "error")`. The last argument catches names the
#'   pipeline does not know.
#' * *Inside a step*, `pip_set_params(.self, ...)` can be used to set derived params for
#'   later steps.
#' * *On a view*, you can set the params of the view's steps. The values still go to
#'   every step of the pipeline that has them, unless `scope = "view"` is used, which
#'   updates only the view's steps. Note that in the latter case, steps outside the view
#'   keep their old values, so the same param may hold different values in different
#'   steps.
#' * After *combining pipelines* with `rbind()`, steps also may hold different objects
#'   of the same name (pipeflow warns if their values differ). To end up with one
#'   definition per name, apply the merged configs, in which the first (more specific)
#'   definition wins: `param_config(..., .duplicates = "first")`.
#'
#' ## Defaults of step functions
#'
#' Step functions (added with [pipeflow::pip_add()]) are always defined with plain
#' defaults, e.g. `\(x = 1)` and not `\(x = numeric_param(1))`. The param config is then
#' applied on top, so the steps hold the param objects. This means that for a choice,
#' the plain default is a factor that must carry the choice levels, e.g.
#' `factor("none", levels = c("none", "log"))`.
#'
#' * pipeflow warns (`pipeflow_param_conflict`) if you add or replace a step with a
#'   default that clashes with the value in existing steps, e.g.
#'   `pip_add(p, "new_step", \(x = 2) ...)` while other steps have `x = 1`.
#' * [pipeflow::pip_replace()] takes the params from the new function's arguments. To
#'   keep the param objects and their current values, use `keep_params = TRUE`.
#'
#' ## Locked params
#'
#' Param UIs show params with a `locked = TRUE` attribute (e.g. fixed by a config)
#' as disabled inputs. [pub_pipeline_params_server()] also disables the params that
#' belong to locked steps (see [pipeflow::pip_lock()]), as a change could not reach
#' them. See also "Locked params" in [pub_params_ui()].
#'
#' @param x A pipeflow pipeline or view.
#' @param ... Optional named arguments that filter the params by their attributes,
#'   e.g. `source = "user"` keeps the params with exactly that source. Several
#'   filters are combined with "and", that is, a param is kept only if it matches all
#'   of them, e.g. `source = "user", area = "analysis"` keeps the *user* params of the
#'   *analysis* area. `NULL` keeps the params without the attribute (`source = NULL`:
#'   params with no `source`). No filter keeps all params. See also "Parameter
#'   filters" in the Examples.
#' @param order `"pipeline"`: order of first use in the pipeline. `"config"`: order of
#'   the config (attribute `order`); params without it follow in pipeline order.
#' @return Named list of param objects; names that the pipeline holds only as plain
#'   values are left out.
#' @seealso [pipeflow::pip_set_params()], [param_config()], [pub_params_table()],
#'   [pub_pipeline_params_server()]
#' @examples
#' p <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("prep", \(yUnit = "") yUnit) |>
#'     pipeflow::pip_add("plot", \(ylab = "y", yUnit = "") paste(ylab, yUnit))
#' cfg <- param_config(
#'     ylab = param("Response", label = "y-axis label", source = "user"),
#'     yUnit = param("%", label = "Unit", source = "user")
#' )
#' # Set in step 'plot' only, so the plain default of step 'prep' comes first
#' pipeflow::pip_set_params(pipeflow::pip_view(p, step = "plot"), cfg, scope = "view")
#'
#' pipeflow::pip_get_params(p)$yUnit  # plain default of step 'prep'
#' pub_get_params(p)$yUnit            # param object of step 'plot'
#'
#'
#' # Parameter filters: keep the params whose attributes match
#' p <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("fit", \(level = 0.95, xVar = "x", nMin = 3) level)
#' pipeflow::pip_set_params(p, param_config(
#'     level = numeric_param(0.95, label = "Level", source = "user",
#'                           area = "analysis"),
#'     xVar = param("x", label = "Predictor", source = "data", area = "analysis"),
#'     nMin = numeric_param(3, label = "Minimum n", source = "internal")
#' ))
#' names(pub_get_params(p, source = "user"))
#' names(pub_get_params(p, area = "analysis"))
#' names(pub_get_params(p, source = "data", area = "analysis"))  # all must match
#' names(pub_get_params(p, area = NULL))  # params without an area
#'
#'
#' # Setting merges plain values into the params and validates them
#' p <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("fit", \(alpha = 0.05,
#'                                method = factor("a", c("a", "b"))) {
#'         paste(alpha, method)
#'     })
#' pipeflow::pip_set_params(p, param_config(
#'     alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1),
#'     method = choice_param("a", choices = c("a", "b"), label = "Method")
#' ), unknown = "error")
#' pipeflow::pip_set_params(p, list(alpha = 0.1, method = "b"))
#' pub_get_params(p)$method
#'
#' err <- tryCatch(
#'     pipeflow::pip_set_params(p, list(alpha = 2, method = "c")),
#'     pipeflow_set_params_error = identity
#' )
#' err$errors
#'
#'
#' # A pipeline with the same param in two steps, used in the next examples
#' make_pipeline <- function() {
#'     pipeflow::pip_new("demo") |>
#'         pipeflow::pip_add("fit", \(alpha = 0.05, level = 0.95) alpha) |>
#'         pipeflow::pip_add("plot", \(alpha = 0.05) alpha) |>
#'         pipeflow::pip_set_params(
#'             param_config(
#'                 alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1),
#'                 level = numeric_param(0.95, label = "Level", locked = TRUE)
#'             ),
#'             unknown = "error"
#'         )
#' }
#' alpha_values <- function(p) {
#'     vapply(pipeflow::pip_get_params(p, simplify = FALSE)$alpha, as.numeric, 1)
#' }
#'
#'
#' # A view: values go to every step that has the param, unless scope = "view"
#' p <- make_pipeline()
#' plot_view <- pipeflow::pip_view(p, step = "plot")
#' pipeflow::pip_set_params(plot_view, list(alpha = 0.1))
#' alpha_values(p)
#' pipeflow::pip_set_params(plot_view, list(alpha = 0.2), scope = "view")
#' alpha_values(p)
#'
#'
#' # Replacing a step: keep_params = TRUE keeps the param objects and their values
#' p <- make_pipeline()
#' pipeflow::pip_set_params(p, list(alpha = 0.2))
#' new_plot <- \(alpha = 0.05) alpha * 2
#' kept <- pipeflow::pip_replace(p, "plot", new_plot, keep_params = TRUE)
#' alpha_values(kept)
#'
#' p <- make_pipeline()
#' pipeflow::pip_set_params(p, list(alpha = 0.2))
#' replaced <- suppressWarnings(pipeflow::pip_replace(p, "plot", new_plot))
#' alpha_values(replaced)  # the plain default of the new function
#'
#'
#' # Locked params and steps: the Shiny module shows both as disabled inputs
#' p <- make_pipeline()
#' names(pub_get_params(p, locked = TRUE))
#'
#' # pip_set_params() skips locked steps, so the values would drift apart
#' pipeflow::pip_lock(pipeflow::pip_view(p, step = "fit"))
#' pipeflow::pip_set_params(p, list(alpha = 0.3))
#' alpha_values(p)
#' @export
pub_get_params <- function(
    x,
    ...,
    order = c("config", "pipeline")
) {
    .assert_pipeline(x)
    order <- rlang::arg_match(order)
    params <- pipeflow::pip_get_params(x, simplify = FALSE) |>
        lapply(\(values) Find(is_param, values)) |>
        Filter(f = Negate(is.null)) |>
        .filter_params(list(...))
    if (length(params) == 0L) {
        # pipeflow returns an unnamed list() if no row has params
        return(rlang::set_names(list(), character(0)))
    }
    if (order == "config") {
        params <- .sort_by_config_order(params)
    }
    params
}

#' Keep the params whose attributes are identical to the given filters
#'
#' Elements without the attribute (including plain values) are dropped; no partial
#' matching of attribute names.
#' @param x named `list` of params (and plain values).
#' @param filters named `list` `<attribute> = <value>`; all must match.
#' @param call see `rlang::abort()`.
#' @return `x` with the matching elements.
#' @noRd
.filter_params <- function(x, filters, call = rlang::caller_env()) {
    if (!rlang::is_named2(filters)) {
        rlang::abort("all filters in `...` must be named", call = call)
    }
    for (name in names(filters)) {
        value <- filters[[name]]
        x <- Filter(\(p) identical(attr(p, name, exact = TRUE), value), x)
    }
    x
}

#' Sort params by their `order` attribute; others last in given order
#'
#' Ties keep the given order; an `order` that is not one number counts as missing.
#' @param params named `list` of params.
#' @return `params`, sorted.
#' @noRd
.sort_by_config_order <- function(params) {
    rank <- vapply(
        params,
        FUN = \(p) {
            order <- if (is_param(p)) param_attr(p, "order")
            if (is.numeric(order) && length(order) == 1L) {
                as.numeric(order)
            } else {
                NA_real_
            }
        },
        FUN.VALUE = numeric(1)
    )
    params[order(rank, na.last = TRUE, method = "radix")]
}


# ======================================================================================
# Step outputs
# ======================================================================================

# ------------------
# Up-to-date outputs
# ------------------
#' Get up-to-date step outputs from outside pipelines
#'
#' @description
#' Returns the output of a step like `x[[step, "out"]]`, but only if the step is
#' "done", i.e. up to date in its own pipeline. Otherwise, it signals an error or
#' returns an error item (see `on_error`).
#'
#' In a single pipeline, a *layout step* arranges the outputs of other steps into a
#' document with [pub_doc()], and pipeflow handles inputs that failed or are outdated.
#' When a document combines the outputs of several pipelines that are run separately,
#' nothing does. `pub_out()` closes that gap, so that error objects, old results or
#' missing outputs never end up in a document.
#'
#' @details
#' ## Steps that are not done
#'
#' * A step that **failed** (state `"failed"`): its output is the error condition.
#' * A step **skipped** because a step it depends on failed (state `"outdated"` or
#'   `"new"`): it keeps its earlier output or has none.
#' * A step that **did not run yet** after a change, e.g. of its parameters or of a step
#'   it depends on (state `"outdated"`), or that was just added (state `"new"`): it
#'   keeps its earlier output or has none.
#'
#' ## What `pub_out()` does then
#'
#' * `on_error = "stop"`: an error of class `pubflow_not_done` names the pipeline, the
#'   step, its state and the failed steps it depends on.
#' * `on_error = "item"`: for the first two cases, an *error item* is returned. A
#'   document shows it as an error box, like a failed input of a layout step (see
#'   [pub_doc()]), while [pub_render()] refuses it unless the report spec allows error
#'   items. The third case is always an error, as no failure is involved.
#'
#' The message is the one of the failed step's last attempt. A step that failed itself
#' is named as the cause, otherwise the first failed step it depends on (failures
#' before a step that is done, e.g. one that recovered with `~try()`, don't count).
#'
#' ## Split steps
#'
#' A step downstream of a step with `exec = "split"` runs once per partition key and
#' can fail for some keys only. It then keeps the outputs of the keys that succeeded.
#'
#' * `on_error = "item"` returns the partitioned output with an error item for each
#'   failed key, so a document shows the results of the other keys and one error box per
#'   failed key.
#' * `on_error = "stop"` signals an error that names the failed keys.
#'
#' @param x A pipeflow pipeline or view.
#' @param step `character(1)` name of the step.
#' @param on_error What to return if the step is not done because of a failure: `"stop"`
#'   signals an error, `"item"` returns an error item.
#' @return The output of `step`, or an error item (class `pub_error`). For a step that
#'   failed for some partition keys and `on_error = "item"`, its partitioned output with
#'   an error item for each failed key.
#' @seealso [pub_doc()]
#' @examples
#' test_pipeline <- function(name, values) {
#'     pipeflow::pip_new(name) |>
#'         pipeflow::pip_add("data", \(values = 1) values) |>
#'         pipeflow::pip_add("mean", \(x = ~data) {
#'             if (anyNA(x)) stop("missing values")
#'             mean(x)
#'         }) |>
#'         pipeflow::pip_add("content", \(m = ~mean) {
#'             pub_text(paste("Mean:", pub_format_num(m, 2)))
#'         }) |>
#'         pipeflow::pip_set_params(list(values = values))
#' }
#' tests <- list(
#'     Assay = test_pipeline("Assay", c(99.1, 98.7)),
#'     Water = test_pipeline("Water", c(0.4, NA))
#' )
#' for (p in tests) {
#'     suppressWarnings(
#'         pipeflow::pip_run(p, lgr = NULL, on_error = "continue")
#'     )
#' }
#'
#' pub_out(tests$Assay, "content")
#' try(pub_out(tests$Water, "content"))
#'
#' # One section per test; the failed one shows an error box
#' parts <- lapply(tests, pub_out, step = "content", on_error = "item")
#' pub_doc(parts, title = "Tests")
#' @export
pub_out <- function(x, step, on_error = c("stop", "item")) {
    .assert_pipeline(x)
    if (!rlang::is_string(step)) {
        rlang::abort("`step` must be a string.")
    }
    on_error <- rlang::arg_match(on_error)
    state <- x[[step, "state"]]
    if (identical(state, "done")) {
        return(x[[step, "out"]])
    }
    full <- .full_pipeline(x)
    failed <- .failed_upstream(full, step)
    messages <- vapply(
        failed,
        \(s) .failure_message(full[[s, "out"]]),
        character(1)
    )
    if (on_error == "item" && length(failed) > 0L) {
        if (identical(state, "failed")) {
            partial <- .with_error_items(x[[step, "out"]], x[["name"]])
            if (!is.null(partial)) {
                return(partial)
            }
        }
        cause <- if (step %in% failed) step else failed[[1L]]
        return(.pub_error(step, cause, messages[[cause]], x[["name"]]))
    }
    rlang::cnd_signal(.not_done_error(
        x[["name"]],
        step,
        state,
        failed,
        unname(messages),
        call = rlang::current_env()
    ))
}

#' Partitioned output with error items for its failed keys
#'
#' @param out the output of a failed step.
#' @param pipeline `character(1)` the name of its pipeline.
#' @return `out` with a `pub_error` instead of each failure object, or `NULL` if `out`
#'   is not a partitioned output holding failures.
#' @noRd
.with_error_items <- function(out, pipeline) {
    if (!inherits(out, "pipeflow_partitioned")) {
        return(NULL)
    }
    failed <- vapply(out, inherits, logical(1), what = "pipeflow_failure")
    if (!any(failed)) {
        return(NULL)
    }
    out[failed] <- lapply(out[failed], \(f) {
        .pub_error(
            f[["step"]],
            f[["failed_step"]],
            .cnd_message(f[["parent"]]),
            pipeline
        )
    })
    out
}

#' The full pipeline of a pipeline or view
#' @param x a pipeflow pipeline or view.
#' @return `x` without its view.
#' @noRd
.full_pipeline <- function(x) {
    x[["view"]] <- NULL
    x
}

#' Failed steps that a step depends on (itself included)
#'
#' The search stops at steps that are done: a failure upstream of them (e.g. one they
#' received through `~try()`) doesn't explain the state of the steps after them.
#' @param x a full pipeline.
#' @param step `character(1)` name of the step.
#' @return `character`, in pipeline order.
#' @noRd
.failed_upstream <- function(x, step) {
    depends <- x[["depends"]]
    states <- x[["state"]]
    seen <- character()
    todo <- step
    while (length(todo) > 0L) {
        seen <- c(seen, todo)
        open <- todo[states[todo] != "done"]
        todo <- setdiff(unlist(depends[open], use.names = FALSE), seen)
    }
    names(states)[names(states) %in% seen & states == "failed"]
}

#' Message of a failed step from its output
#'
#' pipeflow keeps the condition of a step's last attempt as its output (in runs with
#' `on_error = "stop"` since pipeflow 0.5.0.9026). A mapped step that failed for some
#' keys keeps the outputs of the other keys and a failure object for each failed key;
#' the message joins the messages of the failed keys. Other outputs (set from outside)
#' have no message.
#' @param out the output of a failed step.
#' @return `character(1)`.
#' @noRd
.failure_message <- function(out) {
    if (inherits(out, "condition")) {
        return(.cnd_message(out))
    }
    failures <- if (inherits(out, "pipeflow_partitioned")) {
        Filter(\(o) inherits(o, "pipeflow_failure"), out)
    }
    if (length(failures) > 0L) {
        return(paste(
            vapply(failures, \(f) .cnd_message(f[["parent"]]), character(1)),
            collapse = "; "
        ))
    }
    "no message kept"
}


# -------------
# Layout inputs
# -------------
#' Inputs of a layout step: the steps of a view
#'
#' Helps to make a layout step (see [pub_doc()]) that shows all steps of a view, e.g.
#' all steps tagged for one report, so you don't have to list them by hand. The tags
#' decide what a report shows and the layout step arranges it.
#'
#' It returns `~try(step)` for every step of the view. Pass the result as `params` of a
#' layout step whose function takes `...` (see Examples). The references work as usual:
#'
#' * running the layout step runs only the steps it needs
#'   (`pipeflow::pip_run(pipeflow::pip_view(x, step = "doc"))`);
#' * an input that failed in a run with `on_error = "continue"` arrives as a failure
#'   object, which the document shows as an error box (see [pub_doc()]).
#'
#' @details
#' ## Sections
#'
#' * `pub_doc(list(...))` makes one section per step, titled by the step name;
#' * `pub_doc(unname(list(...)))` places the outputs one after the other.
#'
#' ## Add the layout step last
#'
#' The steps are read when `pub_layout_inputs()` is called, so add the layout step
#' after the steps it should show. Steps added or tagged later (also steps added during
#' a run through `.self`) are not part of it.
#'
#' ## Split steps
#'
#' If the view has steps downstream of a split step (partitioned outputs) and other
#' steps, add the layout step with `exec = "reduce"`. It then runs once and places each
#' partitioned output as one sub-section per key. Otherwise pipeflow runs it once per
#' partition.
#'
#' @param x A pipeflow pipeline or view.
#' @return Named list (by step, in pipeline order) of one-sided formulas `~try(<step>)`.
#' @seealso [pub_doc()]
#' @examples
#' p <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("data", \(n = 4) {
#'         data.frame(x = seq_len(n), y = seq_len(n)^2)
#'     }) |>
#'     pipeflow::pip_add("table", \(data = ~data) {
#'         pub_table(data, caption = "Data")
#'     }, tags = "short") |>
#'     pipeflow::pip_add("mean", \(data = ~data) {
#'         pub_format_num(mean(data$y), "Mean: %.2f")
#'     }, tags = c("short", "long")) |>
#'     pipeflow::pip_add("max", \(data = ~data) {
#'         pub_format_num(max(data$y), "Maximum: %.2f")
#'     }, tags = "long")
#'
#' pub_layout_inputs(pipeflow::pip_view(p, tags = "short"))
#'
#' # One layout step per report
#' p |>
#'     pipeflow::pip_add("short", \(...) {
#'         pub_doc(list(...), title = "Short report")
#'     }, params = pub_layout_inputs(pipeflow::pip_view(p, tags = "short"))) |>
#'     pipeflow::pip_add("long", \(...) {
#'         pub_doc(unname(list(...)), title = "Long report")
#'     }, params = pub_layout_inputs(pipeflow::pip_view(p, tags = "long")))
#'
#' # Runs only the steps the short report needs
#' pipeflow::pip_run(pipeflow::pip_view(p, step = "short"), lgr = NULL)
#' p[["short", "out"]]
#' @export
pub_layout_inputs <- function(x) {
    .assert_pipeline(x)
    steps <- unname(x[["step"]])
    if (length(steps) == 0L) {
        rlang::abort("`x` has no steps.")
    }
    inputs <- lapply(steps, \(s) {
        f <- eval(call("~", call("try", as.name(s))), baseenv())
        environment(f) <- emptyenv()
        f
    })
    names(inputs) <- steps
    inputs
}


# ======================================================================================
# Helpers
# ======================================================================================

# -------
# Asserts
# -------
#' Signal an error if `x` is not a pipeflow pipeline or view
#' @param x the value to check.
#' @param arg name of the argument, for the error message.
#' @param call the environment of the caller, for the error message.
#' @return `NULL`, invisibly.
#' @noRd
.assert_pipeline <- function(x, arg = "x", call = rlang::caller_env()) {
    if (!inherits(x, "pipeflow")) {
        rlang::abort(
            sprintf("`%s` must be a pipeflow pipeline or view.", arg),
            call = call
        )
    }
    invisible(NULL)
}
