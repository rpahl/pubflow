# Rendering documents to files: HTML, DOCX, PDF and Markdown with a report spec. Every
# call works in a fresh temporary directory, so concurrent renders don't interfere;
# render-time metadata is merged into the document here, outside the pipeline.

# ======================================================================================
# Rendering files
# ======================================================================================

# ------
# Render
# ------
#' Render a document to a file
#'
#' Writes a document (see [pub_doc()]) as a report file and returns its path. The
#' *report spec* (see [pub_report_spec()]) sets the details, such as the templates,
#' front matter, table of contents, page, figure settings and post-processors.
#'
#' @details
#' ## Formats
#'
#' | `format` | Result | Needs |
#' |---|---|---|
#' | `"html"` | a standalone page | nothing |
#' | `"docx"` | a Word document | pandoc (>= 3.6) |
#' | `"pdf"` | a PDF | pandoc and xelatex or Typst |
#' | `"md"` | a Markdown file | nothing |
#'
#' **HTML**
#'
#' * The page is self-contained: stylesheet, images and the scripts and stylesheets of
#'   widgets are inlined.
#' * Math (MathJax) is loaded from a CDN, so it needs an internet connection.
#' * Files that widgets load by relative URLs (fonts, images or data referenced in
#'   their stylesheets, attachments) are not included, so such widgets may miss them.
#'
#' **DOCX** (via [pub_markdown()] and pandoc)
#'
#' * A4 with numbered headings, tables as native Word tables, math as Word equations,
#'   figures as PNG images (200 dpi) and landscape sections for items that need them.
#' * Tables of contents and caption numbers are Word fields: Word updates them when you
#'   agree to it as the file is opened.
#' * With `lock = TRUE` in the spec, the header, the footer and the tables and figures
#'   are locked against accidental editing and deletion (single tables and figures opt
#'   out with `pub_set_meta(locked = FALSE)`). By default (`lock = NULL`), only tables
#'   and figures with `pub_set_meta(locked = TRUE)` are locked; `lock = FALSE` locks
#'   nothing. See
#'   [pub_pp_docx_header_footer()] and [pub_pp_docx_lock()], which run automatically
#'   before the spec's own post-processors unless the spec lists them.
#'
#' **PDF** (via [pub_markdown()] and pandoc) with the `pdf_engine`:
#'
#' * `"xelatex"` (default): needs a TeX distribution such as TinyTeX with the LaTeX
#'   packages that huxtable needs (see [huxtable::install_latex_dependencies()]) plus
#'   pdflscape, fancyhdr, lastpage, float and newunicodechar.
#' * `"typst"`: needs Typst (see "Finding Typst" below).
#'
#' With either engine, the PDF has A4 pages, figures as PNG images (200 dpi; the
#' spec's `figure` argument allows vector images) and tables that break across pages
#' and repeat their header rows. Table cells, table captions, headers and footers show
#' as typed, while other text gets the typography of LaTeX or Typst (e.g. in LaTeX `"`
#' becomes a curly quote).
#'
#' **Markdown**
#'
#' A Markdown file (see [pub_markdown()]) that needs no pandoc. Its figures go to the
#' directory `<name>_files` next to it (files of the same name there are overwritten).
#'
#' ## Header and footer lines
#'
#' DOCX and PDF files show the `header` and `footer` lines of the document (see
#' [pub_doc()]):
#'
#' * `{trace}` in a line is replaced by a line that says who rendered the report and
#'   when, e.g. "Jane Doe at 07-Oct-2026 12:00:00 UTC (myapp v1.2.0)" (see
#'   [pub_trace_stamp()]).
#' * The footer gets "Page x / N" at the right unless the `footer` has a `right` part.
#'
#' ## Title block and table of contents
#'
#' The title block appears only if the document has a title, subtitle or author, and
#' a front matter (of the document or the spec) replaces it. A table of contents
#' follows it if the document has sections, unless the document places one itself.
#'
#' ## Render-time metadata
#'
#' `meta` holds information about the act of rendering, e.g. the author of the current
#' session, the application and its version:
#'
#' * It is merged over the document's own metadata: its entries win and `NULL` removes
#'   an entry.
#' * `time` is the render time unless one of them has a time.
#' * File name, title block, `{trace}`, front matter and post-processors all see the
#'   merged result.
#'
#' Passing this here instead of to the pipeline keeps the layout step from becoming
#' outdated with every render.
#'
#' ## Error items
#'
#' With `on_error = "continue"`, a failed step doesn't stop the pipeline. A layout step
#' then receives the failure and may place it in the document as an *error item* (see
#' [pub_doc()]). By default, `pub_render()` refuses such a document, so that a report
#' never contains errors. For a final report, therefore, run the pipeline with the
#' default `on_error = "stop"`.
#'
#' For drafts, you can instead run the pipeline with `on_error = "continue"` and set
#' `pub_report_spec(error_items = "show")`. The document is then rendered, with the
#' error items shown as error boxes and a warning.
#'
#' ## Good to know
#'
#' * Rendering needs neither the pipeline nor a Shiny session.
#' * Every call works in a fresh temporary directory. The file is only written if
#'   everything (including post-processors) succeeded.
#'
#' ## Finding Typst
#'
#' Typst is taken from the environment variable `PUBFLOW_TYPST` (the typst executable
#' or its directory), else from the PATH, else from Quarto's installation (found by
#' `QUARTO_PATH` or on the PATH).
#'
#' @param doc A `pub_doc`.
#' @param format Output format: `"html"`, `"docx"`, `"pdf"` or `"md"`.
#' @param file Path of the output file; default (`NULL`): [pub_output_filename()] in the
#'   session's temporary directory.
#' @param spec A [pub_report_spec()] for `format`. The default,
#'   `pub_report_spec(format)`, gives what is described in Details.
#' @param meta Named list of render-time metadata (see Details and [pub_doc()]), e.g.
#'   `list(author = session$user, app = "myapp", version = "1.2.0")`.
#' @param cache A [pub_cache()] or `NULL` (render every figure). Figures are cached
#'   as in [pub_html()].
#' @param pdf_engine Engine of PDF files: `"xelatex"` or `"typst"`.
#' @param quiet `FALSE`: pandoc's warnings (e.g. about missing fonts or images) become R
#'   warnings.
#' @return The path of the written file, invisibly.
#' @seealso [pub_report_spec()], [pub_trace_stamp()], [pub_html()], [pub_markdown()],
#'   [pub_output_filename()]
#' @examples
#' doc <- pub_doc(
#'     pub_section("Results", pub_text("Ozone is highest in July and August.")),
#'     title = "Demo report"
#' )
#' noon <- as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
#' path <- pub_render(doc, file = tempfile(fileext = ".html"),
#'                    meta = list(author = "Jane Doe", time = noon))
#' file.exists(path)
#' basename(pub_output_filename(list(title = "Demo report", time = noon),
#'                              "html"))
#' @export
pub_render <- function(
    doc,
    format = c("html", "docx", "pdf", "md"),
    file = NULL,
    spec = pub_report_spec(format),
    meta = list(),
    cache = NULL,
    pdf_engine = c("xelatex", "typst"),
    quiet = TRUE
) {
    .check_doc(doc)
    format <- rlang::arg_match(format)
    pdf_engine <- rlang::arg_match(pdf_engine)
    spec <- .check_report_spec(spec, format)
    .check_render_args(file, cache, quiet)
    doc <- .render_doc(doc, meta)
    settings <- .render_settings(spec, .format_target(format, pdf_engine))
    front <- .front_nodes(settings, doc)
    .guard_error_items(c(front, doc$children), spec$error_items, format)
    if (is.null(file)) {
        file <- file.path(tempdir(), pub_output_filename(doc$meta, format))
    }
    work <- tempfile("pubflow-render-")
    dir.create(work)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    stem <- tools::file_path_sans_ext(basename(file))
    out <- switch(
        format,
        html = .render_html_file(doc, settings, cache, work, front),
        docx = .render_docx(
            doc,
            settings,
            cache,
            work,
            quiet,
            front,
            call = rlang::current_env()
        ),
        pdf = .render_pdf(
            doc,
            settings,
            cache,
            work,
            quiet,
            front,
            call = rlang::current_env()
        ),
        md = .render_md(doc, settings, cache, work, stem, front)
    )
    .post_process(out, doc, spec)
    .copy_result(out, file, format)
    assets <- file.path(work, paste0(stem, "_files"))
    if (format == "md" && dir.exists(assets)) {
        .copy_result(assets, dirname(file), format)
    }
    invisible(file)
}

#' Check the `file`, `cache` and `quiet` arguments of `pub_render()`
#' @param file `NULL` or the path of the output file.
#' @param cache a `pub_cache` or `NULL`.
#' @param quiet `TRUE` or `FALSE`.
#' @param call the environment of the caller, for the error message.
#' @return `NULL`, invisibly.
#' @noRd
.check_render_args <- function(file, cache, quiet, call = rlang::caller_env()) {
    .check_cache(cache, call = call)
    if (!is.null(file) && !rlang::is_string(file)) {
        rlang::abort("`file` must be a single string or `NULL`.", call = call)
    }
    if (!rlang::is_bool(quiet)) {
        rlang::abort("`quiet` must be `TRUE` or `FALSE`.", call = call)
    }
    invisible()
}

#' The document with render-time metadata
#'
#' `meta` is merged over the document's metadata (`NULL` removes an entry); `time` is
#' now unless one of them has one.
#' @param doc a `pub_doc`.
#' @param meta named list of render-time metadata.
#' @param call the environment of the caller, for the error message.
#' @return `doc` with the merged metadata.
#' @noRd
.render_doc <- function(doc, meta, call = rlang::caller_env()) {
    if (!is.list(meta) || !rlang::is_named2(meta)) {
        rlang::abort("`meta` must be a named list.", call = call)
    }
    merged <- doc$meta
    meta <- .drop_blank_meta(meta)
    for (key in names(meta)) {
        merged[[key]] <- meta[[key]]
    }
    if (is.null(merged[["time"]])) {
        merged[["time"]] <- Sys.time()
    }
    doc$meta <- .check_doc_meta(merged, call = call)
    doc
}

#' Copy a rendered file (or the directory of its figures) to its destination
#' @param from path of the rendered file or directory.
#' @param to path of the destination (for a directory: the directory to copy it into).
#' @param format output format, for the error.
#' @param call the environment of the caller, for the error message.
#' @return `to`; a `pubflow_render_error` if `from` is missing (e.g. moved by
#'   `pandoc_args` or a post-processor).
#' @noRd
.copy_result <- function(from, to, format, call = rlang::caller_env()) {
    if (!file.exists(from)) {
        rlang::cnd_signal(.render_error(
            c(
                sprintf("The rendered file '%s' is missing.", basename(from)),
                i = "Did `pandoc_args` or a post-processor move or remove it?"
            ),
            format = format,
            call = call
        ))
    }
    res <- .file_op(file.copy(from, to, overwrite = TRUE, recursive = dir.exists(from)))
    if (!res$ok) {
        rlang::cnd_signal(.render_error(
            c(sprintf("Can't write '%s'.", to), i = res$reason),
            format = format,
            call = call
        ))
    }
    invisible(to)
}


# ----------
# File names
# ----------
#' File name of a rendered document
#'
#' Makes a file name from the time and the title of a document.
#'
#' @details
#' ## Format
#'
#' The name has the form `<YYYYMMDDTHHMMSSZ>_<title>.<ext>`:
#'
#' * the time (`time` in the metadata, else now) in UTC;
#' * the title in lower case, where every run of characters other than ASCII letters
#'   and digits is replaced by `_` (`"document"` without a title). Other letters, e.g.
#'   accented ones, are dropped, as their transliteration depends on the platform.
#'
#' @param meta Document metadata (`doc$meta`, see [pub_doc()]) or a document.
#' @param ext `character(1)` file extension without the dot, e.g. `"docx"`.
#' @return `character(1)` file name.
#' @seealso [pub_render()]
#' @examples
#' meta <- list(title = "Ozone report: May",
#'              time = as.POSIXct("2026-10-05 14:30:00", tz = "UTC"))
#' pub_output_filename(meta, "docx")
#' @export
pub_output_filename <- function(meta, ext) {
    if (inherits(meta, "pub_doc")) {
        meta <- meta$meta
    }
    if (!is.list(meta)) {
        rlang::abort("`meta` must be a list of document metadata.")
    }
    if (!rlang::is_string(ext) || !grepl("^[A-Za-z0-9]+$", ext)) {
        rlang::abort("`ext` must be a file extension such as \"docx\".")
    }
    meta <- .check_doc_meta(meta)
    time <- meta[["time"]] %||% Sys.time()
    title <- tolower(gsub("[^A-Za-z0-9]+", "_", meta[["title"]] %||% ""))
    title <- gsub("^_+|_+$", "", title)
    if (!nzchar(title)) {
        title <- "document"
    }
    sprintf("%s_%s.%s", format(time, "%Y%m%dT%H%M%SZ", tz = "UTC"), title, ext)
}


# ======================================================================================
# Steps of rendering
# ======================================================================================

# -----------
# Error items
# -----------
#' Refuse or show error items, as the spec says
#' @param nodes list of nodes (front matter and body).
#' @param error_items `"refuse"` or `"show"` (the spec's `error_items`).
#' @param format output format, for the error.
#' @param call the environment of the caller, for the error message.
#' @noRd
.guard_error_items <- function(nodes, error_items, format, call = rlang::caller_env()) {
    if (error_items == "refuse") {
        .check_no_error_items(nodes, format, call = call)
    } else {
        .warn_error_items(nodes)
    }
}

#' Refuse error items (in the front matter and the body)
#' @param nodes list of nodes.
#' @param format output format, for the error.
#' @param call the environment of the caller, for the error message.
#' @return `NULL`, invisibly, if there are none.
#' @noRd
.check_no_error_items <- function(nodes, format, call = rlang::caller_env()) {
    errors <- pub_error_items(nodes)
    if (length(errors) == 0L) {
        return(invisible())
    }
    rlang::cnd_signal(.render_error(
        c(
            "Can't render a document with error items (failed steps):",
            .error_bullets(errors),
            i = paste(
                "Reports run the pipeline with `on_error = \"stop\"`;",
                "error items are for the viewer."
            )
        ),
        format = format,
        call = call
    ))
}

#' Warn about the error items a report shows
#' @param nodes list of nodes.
#' @return `NULL`, invisibly.
#' @noRd
.warn_error_items <- function(nodes) {
    errors <- pub_error_items(nodes)
    if (length(errors) > 0L) {
        rlang::warn(
            c("The report shows error items (failed steps):", .error_bullets(errors)),
            class = "pubflow_render_warning"
        )
    }
    invisible()
}

#' Bullets (`x`) with the error texts of error items
#' @param errors list of error items (`pub_error`).
#' @return named character vector.
#' @noRd
.error_bullets <- function(errors) {
    rlang::set_names(
        vapply(errors, .error_text, character(1)),
        rep("x", length(errors))
    )
}


# ---------------
# Post-processors
# ---------------
#' Apply the post-processors of a spec to a rendered file
#' @param path path of the rendered file.
#' @param doc the `pub_doc` (with the render-time metadata).
#' @param spec the `pub_report_spec`.
#' @param call the environment of the caller, for the error message.
#' @return `path`, invisibly.
#' @noRd
.post_process <- function(path, doc, spec, call = rlang::caller_env()) {
    pp <- .post_processors(spec)
    for (i in seq_along(pp)) {
        tryCatch(
            pp[[i]](path, doc, spec),
            error = function(e) {
                rlang::cnd_signal(.render_error(
                    paste(names(pp)[[i]], "failed."),
                    format = spec$format,
                    parent = e,
                    call = call
                ))
            }
        )
    }
    invisible(path)
}

#' Post-processors of a report: DOCX reports get the header and footer and (with
#' `lock = TRUE`) the lock first, unless the spec lists them
#' @param spec a `pub_report_spec`.
#' @return named list of post-processors (the names describe them in error messages).
#' @noRd
.post_processors <- function(spec) {
    pp <- rlang::set_names(
        spec$post_process,
        sprintf("Post-processor %d of the spec", seq_along(spec$post_process))
    )
    if (spec$format != "docx") {
        return(pp)
    }
    auto <- list(pub_pp_docx_header_footer = pub_pp_docx_header_footer())
    if (isTRUE(spec$lock)) {
        auto$pub_pp_docx_lock <- pub_pp_docx_lock()
    }
    listed <- vapply(
        names(auto),
        \(class) {
            any(vapply(pp, inherits, logical(1), class))
        },
        logical(1)
    )
    auto <- auto[!listed]
    names(auto) <- sprintf("The automatic post-processor `%s()`", names(auto))
    c(auto, pp)
}


# ---------------
# Standalone HTML
# ---------------
#' Write a standalone HTML file into a work directory
#' @param doc a `pub_doc`.
#' @param settings render settings of the spec (`.render_settings()`).
#' @param cache a `pub_cache` or `NULL`.
#' @param work the work directory.
#' @param front list of front matter nodes.
#' @return its path.
#' @noRd
.render_html_file <- function(doc, settings, cache, work, front) {
    out <- file.path(work, "document.html")
    html <- .standalone_html(doc, settings, cache, front)
    writeLines(enc2utf8(html), out, useBytes = TRUE)
    out
}

#' Standalone HTML page of a document
#'
#' A placeholder colour of the spec overrides the stylesheet's.
#' @param doc a `pub_doc`.
#' @param settings render settings of the spec (`.render_settings()`).
#' @param cache a `pub_cache` or `NULL`.
#' @param front list of front matter nodes.
#' @return `character(1)` HTML.
#' @noRd
.standalone_html <- function(doc, settings, cache, front) {
    body <- .html_doc(
        doc,
        cache,
        toc = .wants_toc(settings, doc, front),
        math = "mathjax",
        figure = settings$figure,
        labels = settings$labels,
        toc_depth = settings$toc_depth,
        numbered = settings$number_sections,
        front = front,
        refs = "error"
    )
    deps <- htmltools::resolveDependencies(htmltools::htmlDependencies(body))
    title <- doc$meta[["title"]] %||% "Document"
    color <- settings$placeholder_color
    paste(
        c(
            "<!DOCTYPE html>",
            "<html lang=\"en\">",
            "<head>",
            "<meta charset=\"utf-8\">",
            paste0(
                "<meta name=\"viewport\" content=\"width=device-width, ",
                "initial-scale=1\">"
            ),
            sprintf("<title>%s</title>", .esc(title)),
            unlist(lapply(deps, .inline_dependency)),
            if (!is.null(color)) {
                sprintf(
                    paste0(
                        "<style>\n.pubflow-doc .pubflow-placeholder ",
                        "{ color: #%s; }\n</style>"
                    ),
                    tolower(color)
                )
            },
            "</head>",
            "<body>",
            "<main class=\"pubflow-page\">",
            as.character(body),
            "</main>",
            "</body>",
            "</html>"
        ),
        collapse = "\n"
    )
}

#' Head lines of an HTML dependency: file contents inlined, URLs linked
#' @param dep an `html_dependency`.
#' @return character vector of head lines.
#' @noRd
.inline_dependency <- function(dep) {
    scripts <- vapply(dep$script, \(s) if (is.list(s)) s$src else s, character(1))
    href <- dep$src[["href"]]
    if (!is.null(href)) {
        return(c(
            sprintf("<link rel=\"stylesheet\" href=\"%s/%s\">", href, dep$stylesheet),
            sprintf("<script src=\"%s/%s\"></script>", href, scripts),
            dep$head
        ))
    }
    dir <- dep$src[["file"]]
    if (!is.null(dep$package)) {
        dir <- system.file(dir, package = dep$package)
    }
    read <- \(f) {
        lines <- readLines(file.path(dir, f), warn = FALSE, encoding = "UTF-8")
        paste(lines, collapse = "\n")
    }
    c(
        vapply(
            dep$stylesheet,
            \(f) sprintf("<style>\n%s\n</style>", read(f)),
            character(1),
            USE.NAMES = FALSE
        ),
        vapply(
            scripts,
            \(f) {
                code <- gsub("</script", "<\\\\/script", read(f), ignore.case = TRUE)
                sprintf("<script>\n%s\n</script>", code)
            },
            character(1),
            USE.NAMES = FALSE
        ),
        dep$head
    )
}
