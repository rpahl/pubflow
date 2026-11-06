# Condition constructors.
#
# All errors signalled by pubflow are rlang errors that inherit from `pubflow_error`,
# i.e. their class is
# `c(<class>, "pubflow_error", "rlang_error", "error", "condition")`. The constructors
# only create conditions; signal them with `rlang::cnd_signal()`. The message is stored
# fully formatted (header line plus bullets) in the `message` field, so `e$message`
# holds all of it.

#' Create a pubflow error condition
#'
#' @param class `character` subclass(es) in front of `"pubflow_error"`, e.g.
#'   `"pubflow_render_error"`.
#' @param message `character` message: the first element is the header line, further
#'   elements are bullets named as in [rlang::format_error_bullets()] (`"i"` info, `"x"`
#'   cross, `"*"` bullet, `"!"` warning, `" "` indent).
#' @param ... named fields stored in the condition.
#' @param parent condition that caused this error or `NULL`.
#' @param call call shown as the source of the error, or the execution environment of a
#'   running function (its call is used), or `NULL`.
#' @return an rlang error condition (not signalled).
#' @noRd
.pubflow_error <- function(class, message, ..., parent = NULL, call = NULL) {
    stopifnot(
        is.character(class),
        length(class) >= 1L,
        is.character(message),
        length(message) >= 1L
    )
    text <- message[[1L]]
    bullets <- message[-1L]
    if (length(bullets) > 0L) {
        text <- paste(
            c(text, rlang::format_error_bullets(bullets)),
            collapse = "\n"
        )
    }
    rlang::error_cnd(
        class = c(class, "pubflow_error"),
        message = text,
        ...,
        call = call,
        parent = parent
    )
}

#' Error for an invalid parameter value
#'
#' Signalled by the setter of params (`pip_param_value<-.param`) for one step and param;
#' pipeflow collects these errors into one `pipeflow_set_params_error` (field `errors`:
#' step, name, message), so that nothing is set when any value is invalid.
#'
#' @param p the param (its label is the field `label`).
#' @param message `character(1)` the validity message.
#' @param call see `.pubflow_error()`.
#' @return a `pubflow_invalid_param` condition with field `label`.
#' @noRd
.invalid_param_error <- function(p, message, call = NULL) {
    .pubflow_error(
        "pubflow_invalid_param",
        message,
        label = param_attr(p, "label", default = NA_character_),
        call = call
    )
}

#' Error for the output of a step that is not done
#'
#' @param pipeline `character(1)` name of the pipeline.
#' @param step `character(1)` name of the step.
#' @param state `character(1)` state of the step.
#' @param failed `character` the failed steps it depends on (itself included), in
#'   pipeline order.
#' @param messages `character` their messages.
#' @param call see `.pubflow_error()`.
#' @return a `pubflow_not_done` condition with fields `pipeline`, `step`, `state` and
#'   `failed`.
#' @noRd
.not_done_error <- function(
    pipeline,
    step,
    state,
    failed = character(),
    messages = character(),
    call = NULL
) {
    stopifnot(length(failed) == length(messages))
    bullets <- if (length(failed) > 0L) {
        rlang::set_names(
            sprintf("Step '%s' failed: %s", failed, messages),
            rep("x", length(failed))
        )
    } else {
        c(i = "Run the pipeline first.")
    }
    header <- sprintf(
        "The output of step '%s' of pipeline '%s' is not up to date %s.",
        step,
        pipeline,
        sprintf("(state \"%s\")", state)
    )
    .pubflow_error(
        "pubflow_not_done",
        c(header, bullets),
        pipeline = pipeline,
        step = step,
        state = state,
        failed = failed,
        call = call
    )
}

#' Error while rendering a document
#'
#' @param message see `.pubflow_error()`.
#' @param format `character(1)` output format, e.g. `"docx"`.
#' @param ... further fields, e.g. the output of a failed pandoc call.
#' @param parent,call see `.pubflow_error()`.
#' @return a `pubflow_render_error` condition with field `format`.
#' @noRd
.render_error <- function(message, format, ..., parent = NULL, call = NULL) {
    stopifnot(rlang::is_string(format))
    .pubflow_error(
        "pubflow_render_error",
        message,
        format = format,
        ...,
        parent = parent,
        call = call
    )
}

#' Error for a missing or unusable external tool
#'
#' @param tool `character(1)` tool name, e.g. `"pandoc"`.
#' @param message see `.pubflow_error()`; should tell how to install or configure the
#'   tool.
#' @param ... further fields, e.g. the candidates that were checked.
#' @param call see `.pubflow_error()`.
#' @return a `pubflow_tool_missing` condition with field `tool`.
#' @noRd
.tool_missing_error <- function(tool, message, ..., call = NULL) {
    stopifnot(rlang::is_string(tool))
    .pubflow_error(
        "pubflow_tool_missing",
        message,
        tool = tool,
        ...,
        call = call
    )
}
