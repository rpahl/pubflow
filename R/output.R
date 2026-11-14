# Outputs. A step output is an ordinary R object; optional metadata lives in one
# attribute, `attr(x, "pubflow")` (tables also record their row roles, see
# pub_table_rows()). pub_type() tells renderers and the document builder how to show
# an output; as_pub_output() converts anything else (S3 generic for clients).

# ======================================================================================
# Metadata
# ======================================================================================

# -------------------
# Getting and setting
# -------------------
#' Metadata of an output
#'
#' Outputs are ordinary R objects (data.frames, ggplots, texts, ...). pubflow can attach
#' extra information to them, e.g. a caption or an id, called *metadata*.
#'
#' @details
#' ## Functions
#'
#' * `pub_meta()` reads the metadata;
#' * `pub_set_meta()` sets or removes single entries;
#' * `pub_meta<-` replaces all of it.
#'
#' Functions such as [pub_table()] and [pub_figure()] set metadata for you; use these
#' functions to read or change it afterwards.
#'
#' ## Keys
#'
#' | Key | Applies to | Meaning |
#' |---|---|---|
#' | `title` | any item | heading above the item |
#' | `caption` | table, figure | numbered caption ("Table 1: ..."); `""` for none |
#' | `id` | table, figure | name for cross-references (see [pub_text()]) |
#' | `width`, `height` | figure | size in inches (default 8 x 6) |
#' | `out_width` | figure | width relative to the text width, e.g. `"90%"` |
#' | `font_size` | table | font size in pt |
#' | `landscape` | table, figure | place on landscape pages (DOCX, PDF) |
#' | `locked` | table, figure | lock in DOCX against accidental edits |
#' | `fallback` | widget | static figure shown where HTML is not available |
#' | `stamp` | figure | set when a step returns a plot, not a rendered one |
#'
#' An `id` must be unique in a document. It starts with a letter, ends with a letter or
#' digit and has only letters, digits, `_` and `-` in between, e.g. `"ozone-1"`.
#'
#' You can also add keys of your own. pubflow keeps them but does not use them.
#'
#' ## Huxtables
#'
#' The caption of a huxtable lives in huxtable's own caption ([huxtable::caption()]),
#' and `pub_meta()` and friends read and write it there. Subsetting with `[` and
#' `cbind()` keep this caption but drop all other metadata. So set the metadata on the
#' final table.
#'
#' @param x An R object (not `NULL`).
#' @param key `character(1)` name of an entry or `NULL` for the whole list.
#' @param ... Named entries to set; `NULL` removes an entry.
#' @param value Named list of metadata (or `NULL` to remove all).
#' @return
#' * `pub_meta()`: the named list of metadata (empty if there is none) or the entry
#'   `key` (`NULL` if absent).
#' * `pub_set_meta()`: `x` with the new metadata.
#' * `pub_meta<-`: `x` with the new metadata.
#' @seealso [pub_type()], [pub_figure()], [pub_text()], [pub_table()]
#' @examples
#' x <- pub_set_meta(data.frame(a = 1:2), title = "Raw data", locked = TRUE)
#' pub_meta(x)
#' pub_meta(x, "title")
#'
#' x <- pub_set_meta(x, locked = NULL)
#' names(pub_meta(x))
#'
#' pub_meta(x) <- list(title = "Data")
#' pub_meta(x)
#'
#' # the target of the cross-reference `@tab:ozone` in a text
#' tab <- pub_table(airquality[1:4, c("Month", "Day", "Ozone")], caption = "Ozone")
#' tab <- pub_set_meta(tab, id = "ozone")
#' pub_meta(tab, "id")
#' @export
pub_meta <- function(x, key = NULL) {
    if (!is.null(key) && !rlang::is_string(key)) {
        rlang::abort("`key` must be a single string or `NULL`.")
    }
    meta <- attr(x, "pubflow", exact = TRUE)
    if (is.null(meta)) {
        meta <- list()
    }
    if (huxtable::is_huxtable(x)) {
        caption <- huxtable::caption(x)
        meta[["caption"]] <- if (!is.na(caption)) caption
    }
    meta <- .drop_blank_caption(meta)
    if (is.null(key)) meta else meta[[key]]
}

#' @rdname pub_meta
#' @export
pub_set_meta <- function(x, ...) {
    entries <- list(...)
    if (!rlang::is_named2(entries)) {
        rlang::abort("All metadata entries in `...` must be named.")
    }
    meta <- pub_meta(x)
    meta[names(entries)] <- entries
    .set_meta(x, meta)
}

#' @rdname pub_meta
#' @export
`pub_meta<-` <- function(x, value) {
    .set_meta(x, value)
}

#' Metadata without a blank caption (`""` or only whitespace): it means no caption
#' @param meta named list of metadata.
#' @noRd
.drop_blank_caption <- function(meta) {
    caption <- meta[["caption"]]
    if (rlang::is_string(caption) && !grepl("[^[:space:]]", caption)) {
        meta[["caption"]] <- NULL
    }
    meta
}

#' Replace the metadata of `x`
#' @param x an R object.
#' @param value named list of metadata or `NULL`.
#' @param call the environment of the caller, for the error message.
#' @return `x` with the new metadata.
#' @noRd
.set_meta <- function(x, value, call = rlang::caller_env()) {
    if (is.null(x)) {
        rlang::abort("Can't set metadata of `NULL`.", call = call)
    }
    if (is.null(value)) {
        value <- list()
    }
    if (!is.list(value) || !rlang::is_named2(value)) {
        rlang::abort("Metadata must be a named list.", call = call)
    }
    value <- value[!vapply(value, is.null, logical(1))]
    .check_meta(value, call)
    value <- .drop_blank_caption(value)
    if (huxtable::is_huxtable(x)) {
        caption <- value[["caption"]]
        huxtable::caption(x) <- if (is.null(caption)) NA else caption
        value[["caption"]] <- NULL
    }
    attr(x, "pubflow") <- if (length(value) > 0L) value
    x
}


# ------
# Checks
# ------
#' Validate the known metadata keys
#' @param meta named list of metadata; keys pubflow doesn't know are not checked.
#' @param call the environment of the caller, for the error message.
#' @return `meta`, invisibly.
#' @noRd
.check_meta <- function(meta, call = rlang::caller_env()) {
    checks <- list(
        title = rlang::is_string,
        caption = rlang::is_string,
        id = \(x) {
            rlang::is_string(x) &&
                grepl(paste0("^", .ref_id_pattern(), "\\z"), x, perl = TRUE)
        },
        width = .is_positive_number,
        height = .is_positive_number,
        out_width = .is_percentage,
        font_size = .is_positive_number,
        landscape = rlang::is_bool,
        locked = rlang::is_bool
    )
    expected <- c(
        title = "a single string",
        caption = "a single string",
        id = paste(
            "a string of letters, digits, `_` and `-` that starts with a letter and",
            "ends with a letter or digit"
        ),
        width = "a positive number",
        height = "a positive number",
        out_width = "a positive percentage such as \"90%\"",
        font_size = "a positive number",
        landscape = "`TRUE` or `FALSE`",
        locked = "`TRUE` or `FALSE`"
    )
    for (key in intersect(names(meta), names(checks))) {
        if (!checks[[key]](meta[[key]])) {
            msg <- sprintf("Metadata `%s` must be %s.", key, expected[[key]])
            rlang::abort(msg, call = call)
        }
    }
    invisible(meta)
}

#' A string such as "90%" or "12.5%" (a positive decimal number)
#' @param x the value to check.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_percentage <- function(x) {
    rlang::is_string(x) &&
        grepl("^([0-9]+|[0-9]*\\.[0-9]+)%$", x) &&
        as.numeric(sub("%", "", x, fixed = TRUE)) > 0
}


# ======================================================================================
# Output types
# ======================================================================================

# -----
# Types
# -----
#' Type of an output
#'
#' Returns how pubflow treats an output, e.g. `"table"` for a data.frame. A document
#' ([pub_doc()]) shows each output according to its type.
#'
#' Call `pub_type()` to check what pubflow makes of an object, e.g. if an output does
#' not appear in the document as expected, or to test an [as_pub_output()] method for a
#' class of your own.
#'
#' @details
#' | Type | Outputs |
#' |---|---|
#' | `"section"` | a section ([pub_section()]) |
#' | `"list"` | a plain list (also a split pipeflow output), holding further outputs |
#' | `"table"` | a huxtable, data.frame or matrix (see [pub_table()]) |
#' | `"figure"` | a plot, image files or a rendered plot ([pub_figure()]) |
#' | `"text"` | a character vector, also e.g. `glue` (Markdown, see [pub_text()]) |
#' | `"widget"` | an htmlwidget |
#' | `"raw"`, `"pagebreak"`, `"toc"` | see [pub_raw()], [pub_pagebreak()], [pub_toc()] |
#' | `"error"` | a failed step or an error item of [pub_out()] (an error box) |
#' | `"missing"` | a missing part ([pub_missing()], a placeholder) |
#' | `"null"` | `NULL`, skipped |
#'
#' Objects of any other class are converted with [as_pub_output()] first.
#'
#' @param x A step output.
#' @return `character(1)`, one of the types in Details.
#' @seealso [as_pub_output()], [pub_meta()]
#' @examples
#' pub_type("Some *Markdown* text")
#' pub_type(data.frame(a = 1))
#' pub_type(list(a = "text", b = data.frame(a = 1)))
#' pub_type(pub_pagebreak())
#' pub_type(NULL)
#' @export
pub_type <- function(x) {
    .convert_output(x)$type
}

#' A supported output and its type
#'
#' Calls `as_pub_output()` once for objects of an unknown type.
#' @param x a step output.
#' @param call the environment of the caller, for the error message.
#' @return `list(x = <supported output>, type = <character(1)>)`.
#' @noRd
.convert_output <- function(x, call = rlang::caller_env()) {
    type <- .output_type(x)
    if (is.na(type)) {
        x <- as_pub_output(x)
        type <- .output_type(x)
    }
    if (is.na(type)) {
        rlang::abort(
            sprintf(
                "`as_pub_output()` returned an unsupported output of class <%s>.",
                paste(class(x), collapse = "/")
            ),
            call = call
        )
    }
    list(x = x, type = type)
}

#' Type of a supported output or `NA`
#' @param x a step output.
#' @return `character(1)`, a type of [pub_type()] or `NA` if `x` is not supported.
#' @noRd
.output_type <- function(x) {
    if (is.null(x)) {
        return("null")
    }
    cls <- c(
        pub_png = "figure",
        pub_section = "section",
        pub_raw = "raw",
        pub_pagebreak = "pagebreak",
        pub_toc = "toc",
        huxtable = "table",
        data.frame = "table",
        ggplot = "figure",
        recordedplot = "figure",
        htmlwidget = "widget",
        pipeflow_failure = "error",
        pub_error = "error",
        pub_missing = "missing"
    )
    hit <- cls[vapply(names(cls), \(cl) inherits(x, cl), logical(1))]
    if (length(hit) > 0L) {
        return(unname(hit[[1L]]))
    }
    if (is.matrix(x)) {
        return("table")
    }
    if (is.character(x)) {
        isFigure <- identical(pub_meta(x, "type"), "figure")
        return(if (isFigure) "figure" else "text")
    }
    if (.is_plain_list(x)) "list" else NA_character_
}


# ----------
# Conversion
# ----------
#' Convert an object into a supported output
#'
#' A document only knows a few kinds of outputs (see [pub_type()]). If you put an object
#' of another class into a document, pubflow calls `as_pub_output()` to turn it into
#' one it knows. By default this signals an error. To make a class of your own usable
#' in documents, write a method for it (see Examples).
#'
#' A method must return a supported output, typically a table, a ggplot, a character
#' string or a list of those.
#'
#' @param x An object.
#' @param ... Passed on to methods.
#' @return A supported output (see [pub_type()]).
#' @seealso [pub_type()]
#' @examples
#' # A client class and its method
#' as_pub_output.my_result <- function(x, ...) {
#'     pub_table(x$table, caption = x$label)
#' }
#' res <- structure(
#'     list(table = data.frame(a = 1), label = "Result"),
#'     class = "my_result"
#' )
#' registerS3method("as_pub_output", "my_result", as_pub_output.my_result)
#' pub_type(res)
#'
#' try(as_pub_output(structure(1, class = "unknown")))
#' @export
as_pub_output <- function(x, ...) {
    UseMethod("as_pub_output")
}

#' @rdname as_pub_output
#' @export
as_pub_output.default <- function(x, ...) {
    cls <- paste(class(x), collapse = "/")
    cnd <- .pubflow_error(
        "pubflow_unsupported_output",
        sprintf(
            "unsupported output of class <%s>; provide an as_pub_output() %s",
            cls,
            "method"
        ),
        class_name = class(x)
    )
    rlang::cnd_signal(cnd)
}


# ======================================================================================
# Content nodes
# ======================================================================================

# ---------------------------------------------
# Page break, table of contents and raw content
# ---------------------------------------------
#' Page break, table of contents and raw content
#'
#' Outputs for the structure of a document: page breaks, tables of contents and raw
#' content.
#'
#' @details
#' ## Functions
#'
#' * `pub_pagebreak()` starts a new page;
#' * `pub_toc()` adds a table of contents, or a list of figures or tables;
#' * `pub_raw()` inserts your own code for one or more output formats.
#'
#' | Output | HTML | Markdown | DOCX, PDF |
#' |---|---|---|---|
#' | `pub_pagebreak()` | ignored | ignored | page break |
#' | `pub_toc()` (sections) | table of contents | ignored | table of contents |
#' | `pub_toc(what = "figures")`, `"tables"` | ignored | ignored | list |
#' | `pub_raw()` | `html` | `md` | `docx`, `latex`, `typst` |
#'
#' A format without raw content shows nothing for that output.
#'
#' In DOCX, Word fills in tables of contents and lists when it updates fields. The lists
#' of figures and tables come without a title there, like the table of contents, while
#' in PDF they are titled "List of Figures" and "List of Tables".
#'
#' @param depth `integer(1)` deepest heading level listed (1-6); only for
#'   `what = "sections"`.
#' @param what `"sections"` (table of contents), `"figures"` or `"tables"`.
#' @param html,docx,latex,typst,md Raw content for the format (character; several
#'   strings are joined by line breaks), or `NULL` for none. `docx` takes OpenXML.
#' @return
#' * `pub_pagebreak()`: an object of class `pub_pagebreak`.
#' * `pub_toc()`: an object of class `pub_toc`.
#' * `pub_raw()`: an object of class `pub_raw`.
#' @seealso [pub_type()], [pub_session_info()]
#' @examples
#' pub_type(pub_pagebreak())
#' pub_toc(depth = 2)
#' pub_toc(what = "figures")
#' pub_raw(html = "<hr>", latex = "\\hrule", md = "---")
#' @export
pub_pagebreak <- function() {
    structure(list(), class = "pub_pagebreak")
}

#' @rdname pub_pagebreak
#' @export
pub_toc <- function(depth = 3L, what = c("sections", "figures", "tables")) {
    what <- rlang::arg_match(what)
    isDepth <- rlang::is_scalar_integerish(depth) &&
        !is.na(depth) &&
        depth >= 1L &&
        depth <= 6L
    if (!isDepth) {
        rlang::abort("`depth` must be a whole number between 1 and 6.")
    }
    structure(list(depth = as.integer(depth), what = what), class = "pub_toc")
}

#' @rdname pub_pagebreak
#' @export
pub_raw <- function(html = NULL, docx = NULL, latex = NULL, typst = NULL, md = NULL) {
    content <- list(html = html, docx = docx, latex = latex, typst = typst, md = md)
    content <- content[!vapply(content, is.null, logical(1))]
    if (length(content) == 0L) {
        rlang::abort("`pub_raw()` needs content for at least one target.")
    }
    for (target in names(content)) {
        value <- content[[target]]
        if (!is.character(value) || anyNA(value)) {
            rlang::abort(sprintf("`%s` must be a character vector.", target))
        }
        content[[target]] <- paste(value, collapse = "\n")
    }
    structure(content, class = "pub_raw")
}

#' @export
print.pub_pagebreak <- function(x, ...) {
    cat("<pubflow page break>\n")
    invisible(x)
}

#' @export
print.pub_toc <- function(x, ...) {
    if (x$what == "sections") {
        cat(sprintf("<pubflow table of contents, depth %d>\n", x$depth))
    } else {
        cat(sprintf("<pubflow list of %s>\n", x$what))
    }
    invisible(x)
}

#' @export
print.pub_raw <- function(x, ...) {
    cat(sprintf("<pubflow raw content for %s>\n", toString(names(x))))
    invisible(x)
}


# -------------
# Missing parts
# -------------
#' Placeholder for a missing part
#'
#' `pub_missing()` stands in for a part of a document that doesn't exist yet, e.g. the
#' results of an analysis that has not been run. It is neither content nor an error:
#' the viewer shows the message as a neutral placeholder, while [pub_render()] refuses
#' a document with missing parts, like one with error items. [pub_error_items()] finds
#' both before rendering.
#'
#' Place it like any other output (see [pub_doc()]), e.g. in a layout step for a part
#' whose input is not available. For drafts, `pub_report_spec(error_items = "show")`
#' renders missing parts as an italic paragraph.
#'
#' @param message `character(1)` what is missing and how to get it, as plain text on
#'   one line (line breaks become spaces in documents).
#' @return An object of class `pub_missing`.
#' @seealso [pub_error_items()], [pub_type()]
#' @examples
#' x <- pub_missing("Run the analysis first.")
#' pub_type(x)
#'
#' doc <- pub_doc(pub_section("Results", x))
#' pub_error_items(doc)[[1]]$message
#' @export
pub_missing <- function(message) {
    if (!rlang::is_string(message) || !grepl("[^[:space:]]", message)) {
        rlang::abort("`message` must be a non-blank string.")
    }
    structure(list(message = message), class = "pub_missing")
}

#' @export
print.pub_missing <- function(x, ...) {
    cat(sprintf("<pubflow missing part> %s\n", encodeString(x$message, quote = "\"")))
    invisible(x)
}


# ------------
# Session info
# ------------
#' Session info section
#'
#' A section with the output of [utils::sessionInfo()] as a code block, e.g. for the
#' annex of a report to document the R version and packages used. Place it in a
#' document like any other output (see [pub_doc()]).
#'
#' @param title `character(1)` section title.
#' @return A named list with the `title` as name and the session info as text (a
#'   code block), which a document turns into a section.
#' @seealso [pub_text()]
#' @examples
#' x <- pub_session_info()
#' names(x)
#' cat(substr(x[[1]], 1, 60))
#' @export
pub_session_info <- function(title = "Session info") {
    if (!rlang::is_string(title) || !nzchar(title)) {
        rlang::abort("`title` must be a non-empty string.")
    }
    info <- utils::capture.output(print(utils::sessionInfo()))
    text <- paste(c("```", info, "```"), collapse = "\n")
    rlang::set_names(list(text), title)
}
