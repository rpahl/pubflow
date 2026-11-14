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

#' Label of a child of a param group: its attribute `label`, else its name
#' @param x a param object.
#' @param name name of the child.
#' @return `character(1)`.
#' @noRd
.child_label <- function(x, name) {
    label <- param_attr(x, "label")
    if (rlang::is_string(label) && nzchar(label)) label else name
}

#' Paragraphs of the Markdown of a table cell, as commonmark XML nodes
#'
#' The table writers that translate Markdown cells themselves (Word, Typst) read them
#' with strikethrough as pandoc does. They support paragraphs of text with strong,
#' emphasis, strikethrough and line breaks; other Markdown is an error naming the cell
#' (see `.cell_markdown_error()`).
#' @param text `character(1)`: the Markdown of the cell.
#' @param cell `integer(2)`: row and column of the cell, for errors.
#' @param format `"docx"` or `"typst"`, for errors.
#' @return `xml_nodeset` of the paragraphs.
#' @noRd
.cell_markdown_blocks <- function(text, cell, format) {
    xml <- xml2::read_xml(
        # commonmark's XML writer would turn control characters into U+FFFD
        commonmark::markdown_xml(.strip_control(text), extensions = "strikethrough")
    )
    blocks <- xml2::xml_children(xml)
    for (name in setdiff(xml2::xml_name(blocks), "paragraph")) {
        .cell_markdown_error(name, cell, format)
    }
    blocks
}

#' Signal a render error for unsupported Markdown in a table cell
#' @param name the name of the commonmark node.
#' @param cell `integer(2)`: row and column of the cell.
#' @param format `"docx"` or `"typst"`.
#' @noRd
.cell_markdown_error <- function(name, cell, format) {
    rlang::cnd_signal(.render_error(
        sprintf(
            paste(
                "Can't write table cell [%d, %d] to %s: Markdown cells may",
                "only use strong, emphasis and strikethrough (found %s)."
            ),
            cell[[1L]],
            cell[[2L]],
            c(docx = "Word", typst = "Typst")[[format]],
            gsub("_", " ", name)
        ),
        format = format
    ))
}

#' Drop the control characters that XML 1.0 does not allow
#' @param x `character`.
#' @noRd
.strip_control <- function(x) {
    gsub("[\x01-\x08\x0B\x0C\x0E-\x1F]", "", x, perl = TRUE)
}
