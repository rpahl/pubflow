# Document tree. Nodes are S3 lists with class c("pub_<kind>", "pub_node"): a document
# holds sections and items; an item wraps one output (type, object, meta). Documents are
# made in pipeline steps (layout steps): the constructors place the outputs given to
# them right away (.expand_output()), so a document is plain data that can be saved and
# rendered without the pipeline.

# ======================================================================================
# Document tree
# ======================================================================================

# ----------------------
# Documents and sections
# ----------------------
#' Documents and sections
#'
#' `pub_doc()` creates a document and `pub_section()` is used to create sections
#' within a document. Documents are usually created as part of a pipeflow pipeline:
#' first, the parts of the document (tables, figures, text) are created in separate
#' steps, and then a *layout step* arranges them into sections (see Examples).
#'
#' @details
#' ## Children
#'
#' The children (`...`) are interpreted as follows:
#'
#' | Child | Becomes |
#' |---|---|
#' | section | a section |
#' | list | one sub-section per named element (see below) |
#' | data.frame, matrix | a table with default settings (see [pub_table()]) |
#' | huxtable | a table |
#' | character vector | Markdown text (see [pub_text()]) |
#' | ggplot, [grDevices::recordPlot()], [pub_figure()] | a figure |
#' | htmlwidget | an interactive widget |
#' | [pub_raw()] | your own code, inserted as-is |
#' | [pub_pagebreak()] | a page break (DOCX, PDF) |
#' | [pub_toc()] | a table of contents |
#' | failed step, error item of [pub_out()] | an error box |
#' | `NULL`, empty text | nothing |
#' | pipeline | an error (place the outputs of its steps instead) |
#'
#' Names of list elements become the titles of their sub-sections while unnamed elements
#' are placed directly (no sub-section). To define the caption, digits and other
#' settings of a table, use [pub_table()]. Any other classes are converted with
#' [as_pub_output()] (see [pub_type()]).
#'
#' ## Metadata
#'
#' Metadata of a document:
#'
#' | Key | Meaning |
#' |---|---|
#' | `title`, `subtitle` | title lines (also arguments) |
#' | `author` | user name, e.g. for the trace stamp |
#' | `time` | time of the document (POSIXct) |
#' | `app`, `version` | name and version of the application |
#' | `header`, `footer` | named character, keys `left`, `center`, `right` |
#'
#' A blank string (`""` or only whitespace) as title, subtitle, author, app or version
#' counts as not given. You can add keys of your own: pubflow keeps them but doesn't
#' check or use them.
#'
#' ## Failed steps
#'
#' A failed step does not have to stop the document: write the inputs of a layout step
#' as `~try(step)` and run the pipeline with
#' `pipeflow::pip_run(x, on_error = "continue")`. The document can then still be
#' rendered and shows an error box with the step's error message where the step's
#' output would be (also for steps that did not run). In contrast, with a plain `~step`
#' the layout step is skipped if the step fails, so there is no document. With the
#' default `pipeflow::pip_run(x, on_error = "stop")` the run stops immediately at the
#' first failure.
#'
#' ## Saving documents
#'
#' A document holds only the outputs, not the pipeline, so it can be saved with
#' [saveRDS()] and rendered later or in another R session. One pitfall: a ggplot
#' remembers where it was made. If a plot step is written as a lambda inside the
#' function that builds the pipeline (`\(data = ~data) ggplot(...)`), the saved
#' document includes the whole pipeline. To avoid this, define plot functions outside
#' the function that builds the pipeline. Plots that a step renders itself
#' (`pub_figure(render = TRUE)`) have no such problem.
#'
#' @param ... Children: sections and outputs (see "Children" in Details).
#' @param title `character(1)` title of the document or section.
#' @param subtitle `character(1)` subtitle of the document or `NULL`.
#' @param meta Named list of document metadata (see "Metadata" in Details).
#' @param numbered `TRUE`: the section is numbered (children of unnumbered sections are
#'   unnumbered).
#' @param landscape `TRUE`: the section is placed on landscape pages (DOCX, PDF).
#' @param page_break `NULL`: level-1 sections start on a new page in paged formats;
#'   `TRUE`/`FALSE` override this.
#' @param on_empty when an empty section is placed into a document or section, it is
#'   dropped (`"drop"`, default), kept (`"keep"`) or an error is signalled (`"stop"`).
#' @return A `pub_doc` or `pub_section` object.
#' @seealso [pub_type()], [pub_table()], [pub_text()], [pub_figure()]
#' @examples
#' p <- pipeflow::pip_new("demo") |>
#'     # Steps that make the content
#'     pipeflow::pip_add("data", \(n = 4) {
#'         data.frame(x = seq_len(n), y = seq_len(n)^2)
#'     }) |>
#'     pipeflow::pip_add("table", \(data = ~data) {
#'         pub_table(data, caption = "Data")
#'     }) |>
#'     pipeflow::pip_add("mean", \(data = ~data) {
#'         pub_format_num(mean(data$y), "Mean: %.2f")
#'     }) |>
#'     # The layout step arranges their outputs into a document
#'     pipeflow::pip_add("report", \(table = ~table, mean = ~mean) {
#'         pub_doc(
#'             pub_section("Data", table),
#'             pub_section("Results", mean),
#'             title = "Demo"
#'         )
#'     })
#'
#' # Run the pipeline and take the document from the layout step
#' pipeflow::pip_run(p, lgr = NULL)
#' doc <- p[["report", "out"]]
#' doc
#'
#' # A document can also be made directly, without a pipeline
#' pub_doc(
#'     pub_section(
#'         "Introduction",
#'         pub_text("The study has **three** batches."),
#'         data.frame(batch = c("A", "B", "C"), n = c(4L, 4L, 4L))
#'     ),
#'     pub_section("Annex", pub_session_info(), numbered = FALSE),
#'     title = "Analysis report",
#'     meta = list(author = "Jane Doe", app = "demo", version = "1.0")
#' )
#' @export
pub_doc <- function(..., title = NULL, subtitle = NULL, meta = list()) {
    if (!is.list(meta) || !rlang::is_named2(meta)) {
        rlang::abort("`meta` must be a named list.")
    }
    meta[["title"]] <- title %||% meta[["title"]]
    meta[["subtitle"]] <- subtitle %||% meta[["subtitle"]]
    meta <- .check_doc_meta(meta)
    .new_doc(.as_children(list(...)), meta)
}

#' @rdname pub_doc
#' @export
pub_section <- function(
    title,
    ...,
    numbered = TRUE,
    landscape = FALSE,
    page_break = NULL,
    on_empty = c("drop", "keep", "stop")
) {
    if (!rlang::is_string(title) || !nzchar(title)) {
        rlang::abort("`title` must be a non-empty string.")
    }
    if (!rlang::is_bool(numbered) || !rlang::is_bool(landscape)) {
        rlang::abort("`numbered` and `landscape` must be `TRUE` or `FALSE`.")
    }
    if (!is.null(page_break) && !rlang::is_bool(page_break)) {
        rlang::abort("`page_break` must be `NULL`, `TRUE` or `FALSE`.")
    }
    on_empty <- rlang::arg_match(on_empty)
    .new_section(
        title,
        .as_children(list(...)),
        numbered = numbered,
        landscape = landscape,
        page_break = page_break,
        on_empty = on_empty
    )
}

#' Document node
#' @param children unnamed `list` of sections and items (see `.as_children()`).
#' @param meta named `list` of checked document metadata.
#' @return a `pub_doc`.
#' @noRd
.new_doc <- function(children, meta) {
    structure(
        list(meta = meta, children = children),
        class = c("pub_doc", "pub_node")
    )
}

#' Section node
#' @param title `character(1)` title of the section.
#' @param children unnamed `list` of sections and items (see `.as_children()`).
#' @param numbered `TRUE` if the section is numbered.
#' @param landscape `TRUE` if the section is placed on landscape pages.
#' @param page_break `NULL`, `TRUE` or `FALSE` (see `pub_section()`).
#' @param on_empty `"drop"`, `"keep"` or `"stop"` (see `pub_section()`).
#' @return a `pub_section`.
#' @noRd
.new_section <- function(
    title,
    children,
    numbered = TRUE,
    landscape = FALSE,
    page_break = NULL,
    on_empty = "drop"
) {
    structure(
        list(
            title = title,
            children = children,
            numbered = numbered,
            landscape = landscape,
            page_break = page_break,
            on_empty = on_empty
        ),
        class = c("pub_section", "pub_node")
    )
}

#' Item node: one output in a document
#'
#' @param type `character(1)` output type (see `pub_type()`).
#' @param object the output.
#' @noRd
.new_item <- function(type, object) {
    structure(
        list(type = type, object = object, meta = pub_meta(object)),
        class = c("pub_item", "pub_node")
    )
}


# ------
# Checks
# ------
#' Check that `doc` is a document made by `pub_doc()`
#' @param doc the value to check.
#' @param call the environment of the caller, for the error message.
#' @return `doc`, invisibly.
#' @noRd
.check_doc <- function(doc, call = rlang::caller_env()) {
    if (!inherits(doc, "pub_doc")) {
        rlang::abort("`doc` must be a document made by `pub_doc()`.", call = call)
    }
    invisible(doc)
}

#' Validate the known keys of document metadata
#' @param meta named `list` of document metadata.
#' @param call the environment of the caller, for the error message.
#' @return `meta` without blank strings (see `.drop_blank_meta()`), invisibly.
#' @noRd
.check_doc_meta <- function(meta, call = rlang::caller_env()) {
    meta <- .drop_blank_meta(meta)
    for (key in intersect(
        names(meta),
        c("title", "subtitle", "author", "app", "version")
    )) {
        if (!rlang::is_string(meta[[key]])) {
            rlang::abort(
                sprintf("Metadata `%s` must be a single string.", key),
                call = call
            )
        }
    }
    time <- meta[["time"]]
    if (
        !is.null(time) &&
            !(inherits(time, "POSIXct") && length(time) == 1L && !is.na(time))
    ) {
        rlang::abort(
            "Metadata `time` must be a single date-time (POSIXct).",
            call = call
        )
    }
    for (key in intersect(names(meta), c("header", "footer"))) {
        if (!.is_head_foot(meta[[key]])) {
            rlang::abort(
                sprintf(
                    paste(
                        "Metadata `%s` must be a character vector named by",
                        "\"left\", \"center\" and \"right\"."
                    ),
                    key
                ),
                call = call
            )
        }
    }
    invisible(meta)
}

#' Document metadata without blank strings: `""` (or only whitespace) as `title`,
#' `subtitle`, `author`, `app` or `version` means not given
#' @param meta named `list` of document metadata.
#' @noRd
.drop_blank_meta <- function(meta) {
    keys <- intersect(names(meta), c("title", "subtitle", "author", "app", "version"))
    blank <- vapply(
        meta[keys],
        \(x) rlang::is_string(x) && !grepl("[^[:space:]]", x),
        logical(1)
    )
    meta[keys[blank]] <- NULL
    meta
}

#' Whether `x` is header or footer lines: character named by `left`, `center` and
#' `right`
#' @param x the value to check.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_head_foot <- function(x) {
    is.character(x) &&
        !anyNA(x) &&
        !is.null(names(x)) &&
        all(names(x) %in% c("left", "center", "right")) &&
        !anyDuplicated(names(x))
}


# ======================================================================================
# Placing outputs
# ======================================================================================

# --------
# Children
# --------
#' Children of a document or section
#'
#' @param children `list` (the `...` of a constructor).
#' @param call the environment of the constructor, for error messages.
#' @return unnamed `list` of sections and items.
#' @noRd
.as_children <- function(children, call = rlang::caller_env()) {
    if (
        length(children) > 0L &&
            !is.null(names(children)) &&
            any(nzchar(names(children)))
    ) {
        rlang::abort(
            c(
                "Children in `...` must not be named.",
                i = "Wrap named outputs in a list to get one section each."
            ),
            call = call
        )
    }
    nodes <- lapply(children, .expand_output, path = character(), call = call)
    .flatten_nodes(nodes)
}

#' Concatenate lists of nodes
#' @param nodes `list` of lists of nodes.
#' @return unnamed `list` of nodes (`list()` if there are none).
#' @noRd
.flatten_nodes <- function(nodes) {
    out <- .unlist1(nodes, use.names = FALSE)
    if (is.null(out)) list() else out
}


# -------
# Outputs
# -------
#' Nodes for an output
#'
#' `NULL` and blank text -> nothing; an item -> the item; a section -> the section (or
#' nothing if empty, see `.place_section()`); a list -> one section per named element
#' and the items of the unnamed ones, in order; a document or a pipeline -> error;
#' anything else -> one item.
#' @param x an output.
#' @param path `character` names (positions for unnamed elements) of `x` inside the list
#'   given to a constructor, for error messages.
#' @param call the environment of the constructor, for error messages.
#' @return `list` of nodes.
#' @noRd
.expand_output <- function(x, path, call) {
    if (inherits(x, "pub_doc")) {
        .with_path(
            rlang::abort(
                "A document can't be part of a document.",
                call = call
            ),
            path,
            call
        )
    }
    if (inherits(x, "pub_item")) {
        return(list(x))
    }
    if (inherits(x, "pipeflow")) {
        .signal_pipeline_output(path, call)
    }
    out <- .with_path(.convert_output(x, call = call), path, call)
    x <- out$x
    if (out$type == "text" && .is_blank_text(x)) {
        return(list())
    }
    switch(
        out$type,
        null = list(),
        list = .expand_list(x, path, call),
        section = .with_path(.place_section(x, call), path, call),
        list(.with_path(.output_item(x, out$type, call), path, call))
    )
}

#' Whether a text is blank (only whitespace) and has no title: it places nothing
#' @param x a text output.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_blank_text <- function(x) {
    # text with NA is not blank: it goes on to the check that rejects it
    !anyNA(x) && !any(grepl("[^[:space:]]", x)) && is.null(pub_meta(x, "title"))
}

#' Evaluate `expr`; an error names the list entry concerned
#' @param expr the expression to evaluate (lazily).
#' @param path `character` path of the entry (see `.expand_output()`); errors are
#'   wrapped only if it is not empty.
#' @param call the environment of the constructor, for error messages.
#' @return the value of `expr`.
#' @noRd
.with_path <- function(expr, path, call) {
    if (length(path) == 0L) {
        return(expr)
    }
    tryCatch(expr, error = function(e) {
        rlang::abort(
            sprintf("Can't place entry '%s'.", paste(path, collapse = "$")),
            parent = e,
            call = call
        )
    })
}

#' Nodes for a list: a section per named element, the nodes of unnamed ones
#' @param x a plain list (or a partitioned output).
#' @param path `character` path of `x` (see `.expand_output()`).
#' @param call the environment of the constructor, for error messages.
#' @return unnamed `list` of nodes.
#' @noRd
.expand_list <- function(x, path, call) {
    nms <- names(x)
    if (is.null(nms)) {
        nms <- rep("", length(x))
    }
    nms[is.na(nms)] <- ""
    nodes <- lapply(seq_along(x), \(i) {
        name <- nms[[i]]
        isNamed <- nzchar(name)
        elPath <- c(path, if (isNamed) name else as.character(i))
        children <- .expand_output(x[[i]], elPath, call)
        if (!isNamed) {
            return(children)
        }
        if (length(children) > 0L) list(.new_section(name, children))
    })
    .flatten_nodes(nodes)
}

#' A section placed into a document or section: empty ones follow `on_empty`
#' @param x a `pub_section`.
#' @param call the environment of the constructor, for error messages.
#' @return `list()` or a list with the section.
#' @noRd
.place_section <- function(x, call) {
    if (length(x$children) > 0L || x$on_empty == "keep") {
        return(list(x))
    }
    if (x$on_empty == "stop") {
        rlang::abort(sprintf("Section '%s' is empty.", x$title), call = call)
    }
    list()
}

#' Item for an output of a supported type other than list/section/null
#'
#' Tables: data.frames and matrices are converted with `pub_table()` defaults (their
#' metadata is carried over, `pub_table()` drops it); a table without rows or columns is
#' an error. Text: lines are joined and checked for headings, as in `pub_text()`.
#' @param x a supported output.
#' @param type `character(1)` its type (see `pub_type()`).
#' @param call the environment of the constructor, for error messages.
#' @return a `pub_item`.
#' @noRd
.output_item <- function(x, type, call) {
    if (type == "table" && !huxtable::is_huxtable(x)) {
        xMeta <- pub_meta(x)
        x <- pub_table(x)
        pub_meta(x) <- xMeta
    }
    if (type == "table" && (nrow(x) == 0L || ncol(x) == 0L)) {
        rlang::abort("A table needs at least one row and one column.", call = call)
    }
    if (type == "text") {
        x <- .as_text(x, call)
    }
    if (type == "error") {
        x <- .as_error(x)
    }
    .new_item(type, x)
}

#' Error for a pipeline among outputs (field `path`: where it was found)
#' @param path `character` path of the pipeline (see `.expand_output()`).
#' @param call the environment of the constructor, for the error message.
#' @noRd
.signal_pipeline_output <- function(path, call) {
    where <- if (length(path) > 0L) {
        sprintf(" (entry '%s')", paste(path, collapse = "$"))
    } else {
        ""
    }
    rlang::cnd_signal(.pubflow_error(
        "pubflow_pipeline_output",
        c(
            sprintf("A pipeline can't be placed into a document%s.", where),
            i = paste(
                "Place the outputs of its steps instead, e.g.",
                "`p[[\"step\", \"out\"]]` in a step of the outer pipeline."
            )
        ),
        path = path,
        call = call
    ))
}


# ------------
# Item content
# ------------
#' Content of an error item: plain data from a failure object
#'
#' A failure object holds the condition of the failed step (with backtraces), so the
#' item keeps strings only: the step whose output it replaces (`step`), the step that
#' failed (`failed_step`, differs if `step` was not run because of it) and the message
#' of the failed step's condition (`parent`; the failure's own message adds the step
#' names, a failed partition's starts with "key '<key>': "). An error item of
#' [pub_out()] (`pub_error`) is used as-is.
#' @param x a `pipeflow_failure` condition or a `pub_error`.
#' @return a `pub_error` (see `.pub_error()`).
#' @noRd
.as_error <- function(x) {
    if (inherits(x, "pub_error")) {
        return(x)
    }
    .pub_error(
        x[["step"]],
        x[["failed_step"]],
        .cnd_message(x[["parent"]])
    )
}

#' Content of an error item
#'
#' @param step `character(1)` the step whose output the item replaces.
#' @param failed_step `character(1)` the step that failed.
#' @param message `character(1)` its message.
#' @param pipeline `character(1)` the pipeline of the steps, or `NULL` if the item comes
#'   from a failure object of the document's own pipeline.
#' @return a `pub_error` list with `step`, `failed_step`, `message` and, if given,
#'   `pipeline`.
#' @noRd
.pub_error <- function(step, failed_step, message, pipeline = NULL) {
    x <- list(step = step, failed_step = failed_step, message = message)
    x$pipeline <- pipeline
    structure(x, class = "pub_error")
}

#' One Markdown string without headings, keeping the metadata
#' @param x `character` lines.
#' @param call the environment of the constructor, for error messages.
#' @return `character(1)` with the metadata of `x`.
#' @noRd
.as_text <- function(x, call) {
    if (anyNA(x)) {
        rlang::abort("Text must not contain `NA`.", call = call)
    }
    meta <- pub_meta(x)
    text <- .join_lines(x)
    .check_markdown(text, call = call)
    pub_meta(text) <- meta
    text
}


# -----------
# Error items
# -----------
#' Error items of a document or of step outputs
#'
#' Finds the failed steps in a document or in the outputs placed into one, e.g. to
#' check a report before it is rendered ([pub_render()] refuses error items) or to list
#' its problems in an app.
#'
#' @param x A document ([pub_doc()]), a section ([pub_section()]) or step outputs:
#'   failure objects of failed steps, error items of [pub_out()], other outputs and
#'   lists of them (nested). Objects of other classes are converted with
#'   [as_pub_output()] first, as in a document.
#' @return A list of error items (class `pub_error`, as returned by [pub_out()]), in
#'   document order; empty if there are none. An error item is a list with the
#'   elements `step` (the step whose output it replaces), `failed_step` (the step that
#'   failed), `message` (its error message) and, for an item of [pub_out()], `pipeline`
#'   (the pipeline of the steps).
#' @seealso [pub_out()]
#' @examples
#' p <- pipeflow::pip_new("air") |>
#'     pipeflow::pip_add("data", \() airquality) |>
#'     pipeflow::pip_add("fit", \(data = ~data) stop("too few values")) |>
#'     pipeflow::pip_add("table", \(fit = ~fit) coef(fit))
#' suppressWarnings(pipeflow::pip_run(p, on_error = "continue"))
#'
#' parts <- list(
#'     Data = head(airquality),
#'     Fit = pub_out(p, "table", on_error = "item")
#' )
#' errors <- pub_error_items(parts)
#' length(errors)
#' errors[[1]]$message
#'
#' pub_error_items(pub_doc(parts))[[1]]$failed_step
#' @export
pub_error_items <- function(x) {
    if (inherits(x, c("pub_doc", "pub_section"))) {
        return(pub_error_items(x$children))
    }
    if (inherits(x, "pub_item")) {
        return(if (x$type == "error") list(x$object) else list())
    }
    if (inherits(x, "pipeflow")) {
        .signal_pipeline_output(character(), call = environment())
    }
    out <- .convert_output(x)
    switch(
        out$type,
        error = list(.as_error(out$x)),
        list = .flatten_nodes(lapply(out$x, pub_error_items)),
        section = pub_error_items(out$x),
        list()
    )
}


# ======================================================================================
# Printing
# ======================================================================================

# -------------
# Print methods
# -------------
#' @export
print.pub_doc <- function(x, ...) {
    title <- x$meta[["title"]]
    header <- "<pubflow document>"
    if (!is.null(title)) {
        header <- paste(header, encodeString(title, quote = "\""))
    }
    cat(c(header, .format_nodes(x$children, level = 1L)), sep = "\n")
    invisible(x)
}

#' @export
print.pub_section <- function(x, ...) {
    cat(.format_nodes(list(x), level = 1L), sep = "\n")
    invisible(x)
}

#' @export
print.pub_item <- function(x, ...) {
    cat(paste("<pubflow item>", .format_item(x)), sep = "\n")
    invisible(x)
}


# ----------
# Formatting
# ----------
#' Lines showing nodes, indented by level
#' @param nodes `list` of sections and items.
#' @param level `integer(1)` level of the nodes (1 for the children of a document).
#' @return `character` lines.
#' @noRd
.format_nodes <- function(nodes, level) {
    lines <- lapply(nodes, .format_node, level = level)
    out <- unlist(lines, use.names = FALSE)
    if (is.null(out)) character() else out
}

#' Lines showing a node: an item or a section heading with its children
#' @param node a section or an item.
#' @param level `integer(1)` level of the node.
#' @return `character` lines.
#' @noRd
.format_node <- function(node, level) {
    indent <- strrep("  ", level - 1L)
    if (inherits(node, "pub_item")) {
        return(paste0(indent, .format_item(node)))
    }
    heading <- paste(strrep("#", level), node$title)
    flags <- .section_flags(node)
    if (length(flags) > 0L) {
        heading <- sprintf("%s [%s]", heading, toString(flags))
    }
    c(paste0(indent, heading), .format_nodes(node$children, level + 1L))
}

#' Settings of a section that differ from the defaults, for printing
#' @param x a `pub_section`.
#' @return `character` flags or `NULL` if all settings are the defaults.
#' @noRd
.section_flags <- function(x) {
    c(
        if (!x$numbered) "unnumbered",
        if (x$landscape) "landscape",
        if (isTRUE(x$page_break)) "page break",
        if (isFALSE(x$page_break)) "no page break",
        if (x$on_empty != "drop") sprintf("on empty: %s", x$on_empty)
    )
}

#' One line for an item: type and label (no class)
#' @param x a `pub_item`.
#' @return `character(1)`.
#' @noRd
.format_item <- function(x) {
    label <- x$meta[["caption"]] %||% x$meta[["title"]]
    if (is.null(label) && x$type == "text") {
        label <- .first_line(x$object, 40L)
    }
    if (x$type == "error") {
        label <- .first_line(.error_text(x$object), 60L)
    }
    if (is.null(label)) {
        return(x$type)
    }
    paste(x$type, encodeString(label, quote = "\""))
}

#' Text of an error item: failed step and message
#' @param x a `pub_error`.
#' @return `character(1)`.
#' @noRd
.error_text <- function(x) {
    sprintf("step %s failed: %s", .failed_label(x), x$message)
}

#' The failed step of an error item, quoted, with its pipeline if known
#' @param x a `pub_error`.
#' @return `character(1)`.
#' @noRd
.failed_label <- function(x) {
    label <- sprintf("'%s'", x$failed_step)
    if (!is.null(x$pipeline)) {
        label <- sprintf("%s of pipeline '%s'", label, x$pipeline)
    }
    label
}
