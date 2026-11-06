# Small helpers used across the package.

#' `y` if `x` is `NULL`, otherwise `x`
#'
#' Same as `%||%` in base R >= 4.4.0, defined here for R 4.3. `y` is only evaluated
#' if `x` is `NULL`.
#' @param x,y any values.
#' @return `x`, or `y` if `x` is `NULL`.
#' @noRd
`%||%` <- function(x, y) {
    if (is.null(x)) y else x
}

#' Run a file operation, keeping base R's warnings as the reason of a failure
#'
#' The caller's error then says why (e.g. "No such file or directory") without a
#' warning ahead of it.
#' @param expr the file operation (`file.copy()`, `dir.create()`, ...).
#' @return `list(ok, reason)`: `ok` is `TRUE` if every value of `expr` is `TRUE`;
#'   `reason` the message of the last warning, or `NULL`.
#' @noRd
.file_op <- function(expr) {
    reason <- NULL
    value <- withCallingHandlers(expr, warning = function(w) {
        reason <<- conditionMessage(w)
        invokeRestart("muffleWarning")
    })
    list(ok = isTRUE(all(value)), reason = reason)
}

#' TRUE if `x` is one finite number greater than zero
#' @param x the value to check.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_positive_number <- function(x) {
    is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0
}

#' Lines of Markdown as one string with `\n` as the only line ending
#'
#' CommonMark also ends lines at `\r\n` and `\r`; the converters split at `\n`.
#' @param x `character` lines.
#' @return `character(1)`.
#' @noRd
.join_lines <- function(x) {
    gsub("\r\n?", "\n", paste(x, collapse = "\n"))
}

#' Message of a condition as plain text
#'
#' In a terminal, rlang and cli colour the bullets of messages with ANSI escape codes
#' and cli may add hyperlinks; messages that are shown in a browser or a document drop
#' both.
#' @param cnd a condition.
#' @return `character(1)`.
#' @noRd
.cnd_message <- function(cnd) {
    gsub(.ansi_pattern, "", conditionMessage(cnd), perl = TRUE)
}

#' Pattern of ANSI escape sequences: CSI (e.g. colours) and OSC (e.g. hyperlinks)
#' @noRd
.ansi_pattern <- "\033\\[[0-9;?]*[ -/]*[@-~]|\033\\][^\a\033]*(\a|\033\\\\)"

#' Unlist one level: the elements of the elements of a list
#' @param x a list.
#' @param ... passed to [unlist()] (e.g. `use.names`).
#' @return a list (`NULL` if `x` has no elements).
#' @noRd
.unlist1 <- function(x, ...) {
    unlist(x, recursive = FALSE, ...)
}

#' First non-blank line of a text, shortened to `width` characters (ending in "...")
#' @param text `character` lines (joined with newlines first).
#' @param width `integer(1)` maximum number of characters, at least 4.
#' @return `character(1)`, `""` for blank text.
#' @noRd
.first_line <- function(text, width) {
    lines <- strsplit(paste(text, collapse = "\n"), "\n", fixed = TRUE)[[1L]]
    line <- c(lines[grepl("[^[:space:]]", lines)], "")[[1L]]
    if (nchar(line) > width) {
        line <- paste0(substr(line, 1L, width - 3L), "...")
    }
    line
}

#' TRUE if a param is locked (attribute `locked = TRUE`): the UI shows it disabled
#' @param x a param.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_locked <- function(x) {
    isTRUE(param_attr(x, "locked"))
}
