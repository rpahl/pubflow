# Report specs: how a document becomes a report in one format. pub_render() and
# pub_markdown() take a spec; .render_settings() resolves it for one target (pubflow's
# templates by default, the page in cm, the figure device). Every field acts in every
# format that can show it, and a field set for a format that can't use it is an error.

# ======================================================================================
# Report specs
# ======================================================================================

# ---------------
# Specs and pages
# ---------------
#' Report specs and pages
#'
#' A report spec describes how a document becomes a report in one format: templates,
#' front matter, table of contents, page, figures, caption labels and more.
#'
#' @details
#' ## Functions
#'
#' * `pub_report_spec()` creates a spec. Pass it as `spec` to [pub_render()] or
#'   [pub_markdown()].
#' * `pub_page()` describes the page (size, orientation, margins) of DOCX and PDF
#'   reports.
#'
#' All arguments except `format` and `error_items` are optional: `NULL` means the
#' default (for `figure` and `labels`, an empty list does too).
#'
#' ## Which argument acts where
#'
#' Every argument acts in every format that can show it. Setting an argument that the
#' format can't use is an error, e.g. `placeholder_color` for DOCX, where the reference
#' document's "Placeholder" style sets the colour.
#'
#' | Argument | html | docx | pdf (LaTeX / Typst) | md |
#' |---|---|---|---|---|
#' | `reference_docx` | - | template | - | - |
#' | `latex_preamble`, `typst_template` | - | - | templates | - |
#' | `front_matter` replaces | header | title block | title block | YAML |
#' | `toc`, `toc_depth` | navigation | TOC field | contents | ignored |
#' | `number_sections` | numbers | heading styles | numbers | numbers |
#' | `labels` | captions | captions | captions | captions |
#' | `page` | - | every section | page | - |
#' | `figure` devices | png, svg | png | png, pdf / png, svg | png, svg |
#' | `placeholder_color` | CSS colour | - | text colour | - |
#' | `lock` | - | tables, figures, header, footer | - | - |
#' | `pandoc_args` | - | added | added | - |
#'
#' ## Variants of a spec
#'
#' To make variants (e.g. one per report and format, sharing the front matter), call
#' `pub_report_spec()` again, e.g. from a helper function of your app. A value that you
#' edit afterwards (`spec$toc <- FALSE`) is checked only when the spec is used.
#'
#' ## The arguments in detail
#'
#' * `front_matter`: a `function(doc, format)` that returns the front matter, e.g. a
#'   title page with a signature table. It replaces the title block (in HTML the header)
#'   in every format; the title and author stay in the file's properties.
#'   * Without it, the document's front matter is used (see "Front matter" in
#'     [pub_doc()]), which the viewer shows too.
#'   * It returns what a document can hold: sections, outputs or lists of them (see
#'     [pub_doc()]).
#'   * `doc` is the document with the render-time metadata (see [pub_render()]) and
#'     `format` the output format.
#'   * Its sections are unnumbered (the numbers of the body start at 1), while its
#'     tables and figures count in the caption numbers.
#'   * End it with [pub_pagebreak()] to start the table of contents on a new page.
#' * `toc`: `TRUE` adds a table of contents of the headings up to level `toc_depth`
#'   after the front matter (or title block).
#'   * It is left out if the document has no sections, or if the document or the front
#'     matter places a [pub_toc()] itself.
#'   * Word fills it in when its fields are updated.
#'   * For lists of figures and tables, place `pub_toc(what = "figures")` or
#'     `pub_toc(what = "tables")`, e.g. in the front matter.
#' * `number_sections`: `FALSE` leaves every heading unnumbered (in Word the "Heading n
#'   Unnumbered" styles).
#' * `labels`: the words before the caption numbers, `list(table, figure)`.
#' * `page`: a [pub_page()].
#'   * By default, DOCX keeps the page of the reference document and PDF is A4 portrait
#'     with margins of 2.5 cm (2 cm at the bottom).
#'   * An explicit page applies to every section of a DOCX file.
#'   * A landscape page turns the whole document, so landscape sections and items in it
#'     stay on the same pages.
#' * `figure`: `list(device, res)`, the image format and the resolution of PNG images
#'   in dpi. It is merged over the default: PNG with 200 dpi, as in the viewer, so a
#'   report after viewing reuses the cached figures and shows them as the viewer did.
#'   `"svg"` (HTML, Markdown and PDF via Typst) and `"pdf"` (PDF via LaTeX) give vector
#'   images.
#' * `placeholder_color`: colour of `[text]{.placeholder}` spans, e.g. `"#0083c0"` (the
#'   default of PDF; HTML uses `#0077b0` for better contrast).
#' * `lock`: DOCX only. `TRUE` locks the header, the footer and every table and figure
#'   that isn't `pub_set_meta(locked = FALSE)` against accidental editing and deletion
#'   (see [pub_pp_docx_lock()]). `NULL` (default) locks only the tables and figures
#'   with `pub_set_meta(locked = TRUE)`, and the header and footer if `post_process`
#'   lists [pub_pp_docx_lock()]. `FALSE` locks nothing, and `post_process` can't list
#'   [pub_pp_docx_lock()].
#' * `error_items`: what [pub_render()] does with error items (failed steps placed by a
#'   layout step run with `on_error = "continue"`, see [pub_doc()]) and missing parts
#'   ([pub_missing()]):
#'   * `"refuse"` (default) signals a `pubflow_render_error`;
#'   * `"show"` writes their error boxes and placeholders and warns
#'     (`pubflow_render_warning`), naming the failed steps and missing parts.
#' * `post_process`: a list of functions `function(path, doc, spec)` that change the
#'   rendered file before it is copied to its destination.
#'   * They are called in order. `path` is the file, `doc` the document with the
#'     render-time metadata and `spec` this spec.
#'   * They change the file in place; their value is ignored. A failing one is a
#'     `pubflow_render_error` and no file is written.
#'   * DOCX reports first get [pub_pp_docx_header_footer()] and (with `lock`)
#'     [pub_pp_docx_lock()]. List one of them to give it arguments or another place.
#'   * [pub_pp_docx_header_footer()] and [pub_pp_docx_lock()] can't be used for other
#'     formats.
#' * `pandoc_args`: pandoc options added after pubflow's (so they override them), one
#'   argument per element.
#'
#' ## Custom templates
#'
#' Start from pubflow's template and keep what pubflow writes into it:
#'
#' * `reference_docx` (start from
#'   `system.file("templates", "reference.docx", package = "pubflow")`):
#'   * paragraph styles "Heading 1"-"Heading 5", "Heading 1 Unnumbered"-"Heading 5
#'     Unnumbered", "Item Title", "Table Caption", "Image Caption", "Figure" and
#'     "Error", and the character style "Placeholder" (missing styles are added
#'     unformatted);
#'   * for header and footer lines, the bookmarks `header_left`, `header_center`,
#'     `header_right`, `footer_left`, `footer_center` and `footer_right` in its header
#'     and footer (only those of the lines you use, see [pub_pp_docx_header_footer()]).
#' * `latex_preamble`: a file included after pubflow's header (which loads the packages
#'   for tables, landscape pages, header and footer, and the frame of error items) and
#'   before the document's header and footer lines.
#' * `typst_template` (start from
#'   `system.file("templates", "pubflow.typ", package = "pubflow")`): a pandoc template
#'   that
#'   * writes `$header-includes$` (page orientation and caption labels);
#'   * shows the title block only if `$title-block$` is set;
#'   * takes the header and footer lines from `$header-left$` to `$footer-right$` (an
#'     empty part also sets `$footer-right-empty$` etc.).
#'
#' @param format Output format: `"html"`, `"docx"`, `"pdf"` or `"md"`.
#' @param reference_docx Path of the reference document of DOCX reports, or `NULL`
#'   (pubflow's).
#' @param latex_preamble Path of a LaTeX file included in the preamble of PDF reports
#'   made with xelatex, or `NULL`.
#' @param typst_template Path of the pandoc template of PDF reports made with Typst, or
#'   `NULL` (pubflow's).
#' @param front_matter `function(doc, format)` returning the front matter (`NULL`: the
#'   title block, `list()`: none), or `NULL` (the document's front matter, else the
#'   title block: title, subtitle, author and time; shown only with a title, subtitle
#'   or author).
#' @param toc `TRUE`: add a table of contents (see Details).
#' @param toc_depth `integer(1)` deepest heading level in it (1-6).
#' @param number_sections `TRUE`: number the sections.
#' @param labels Named list of the caption words `table` and `figure`.
#' @param page A [pub_page()] or `NULL`.
#' @param figure Device settings of figures (see Details) or `NULL`.
#' @param placeholder_color Colour of placeholders (`"#rrggbb"`) or `NULL`.
#' @param lock `TRUE`, `FALSE` or `NULL` (see Details).
#' @param error_items `"refuse"` or `"show"`.
#' @param post_process List of post-processors (see Details).
#' @param pandoc_args `character` extra arguments of pandoc.
#' @param size Paper size: `"a4"` or `"letter"`.
#' @param orientation `"portrait"` or `"landscape"`.
#' @param margins Named numeric margins in cm (`top`, `bottom`, `left`, `right`; missing
#'   ones are 2.5, at the bottom 2), or `NULL`.
#' @return A `pub_report_spec` or `pub_page` object.
#' @seealso [pub_render()], [pub_trace_stamp()], [pub_pp_docx_header_footer()]
#' @examples
#' # A spec for one format; printing it shows what it uses
#' spec <- pub_report_spec(
#'     "pdf",
#'     page = pub_page("letter", margins = c(left = 3)),
#'     labels = list(table = "Tab.", figure = "Fig."),
#'     front_matter = function(doc, format) {
#'         list(pub_text(paste("Prepared by", doc$meta$author)),
#'              pub_pagebreak())
#'     }
#' )
#' spec
#' pub_report_spec("docx", toc = FALSE, error_items = "show")
#'
#' # Landscape page and vector figures
#' pub_report_spec("pdf", page = pub_page("a4", "landscape"),
#'                 figure = list(device = "pdf"))
#'
#' # Use a spec to render (HTML needs nothing but pubflow)
#' doc <- pub_doc(
#'     pub_section("Results", pub_text("Ozone is highest in July and August.")),
#'     meta = list(title = "Demo report", author = "Jane Doe")
#' )
#' html <- pub_report_spec("html", toc = FALSE, number_sections = FALSE)
#' path <- pub_render(doc, "html", file = tempfile(fileext = ".html"), spec = html)
#'
#' # A post-processor changes the finished file, here by appending a comment
#' add_note <- function(path, doc, spec) {
#'     writeLines(c(readLines(path), "<!-- checked -->"), path)
#' }
#' html <- pub_report_spec("html", post_process = add_note)
#' path <- pub_render(doc, "html", file = tempfile(fileext = ".html"), spec = html)
#' tail(readLines(path), 1)
#'
#' # Variants: one spec per format that share the front matter and the labels
#' title_page <- function(doc, format) {
#'     list(pub_text(paste("Prepared by", doc$meta$author)), pub_pagebreak())
#' }
#' my_report_spec <- function(format) {
#'     pub_report_spec(
#'         format,
#'         front_matter = title_page,
#'         labels = list(table = "Tab.", figure = "Fig.")
#'     )
#' }
#' my_report_spec("docx")
#' my_report_spec("md")
#'
#' # An argument that the format can't use is refused
#' try(pub_report_spec("docx", placeholder_color = "#0083c0"))
#' @export
pub_report_spec <- function(
    format = c("html", "docx", "pdf", "md"),
    # Templates and includes
    reference_docx = NULL,
    latex_preamble = NULL,
    typst_template = NULL,
    # Content
    front_matter = NULL,
    toc = TRUE,
    toc_depth = 3L,
    number_sections = TRUE,
    labels = list(table = "Table", figure = "Figure"),
    # Look
    page = NULL,
    figure = NULL,
    placeholder_color = NULL,
    # Checks and protection
    lock = NULL,
    error_items = c("refuse", "show"),
    # After rendering
    post_process = list(),
    pandoc_args = character()
) {
    fields <- as.list(environment())
    fields$format <- rlang::arg_match(format)
    fields$error_items <- rlang::arg_match(error_items)
    .new_report_spec(fields)
}

#' Validate and normalise the fields of a spec
#'
#' Used by `pub_report_spec()` and again by `.check_report_spec()`, so a field edited
#' after `pub_report_spec()` gets the same checks and defaults.
#' @param fields named list of the arguments of `pub_report_spec()`.
#' @param call the environment of the caller, for the error message.
#' @return An object of class `pub_report_spec`.
#' @noRd
.new_report_spec <- function(fields, call = rlang::caller_env()) {
    pp <- fields[["post_process"]]
    spec <- list(
        format = fields[["format"]],
        reference_docx = .check_spec_file(
            fields[["reference_docx"]],
            "reference_docx",
            call
        ),
        latex_preamble = .check_spec_file(
            fields[["latex_preamble"]],
            "latex_preamble",
            call
        ),
        typst_template = .check_spec_file(
            fields[["typst_template"]],
            "typst_template",
            call
        ),
        front_matter = fields[["front_matter"]],
        toc = fields[["toc"]] %||% TRUE,
        toc_depth = fields[["toc_depth"]] %||% 3L,
        number_sections = fields[["number_sections"]] %||% TRUE,
        page = fields[["page"]],
        figure = if (!identical(fields[["figure"]], list())) fields[["figure"]],
        labels = .check_spec_labels(fields[["labels"]] %||% list(), call),
        placeholder_color = fields[["placeholder_color"]],
        lock = fields[["lock"]],
        error_items = fields[["error_items"]],
        post_process = if (is.function(pp)) list(pp) else pp %||% list(),
        pandoc_args = fields[["pandoc_args"]] %||% character()
    )
    .check_spec_values(spec, call)
    .check_spec_formats(spec, call)
    spec$toc_depth <- as.integer(spec$toc_depth)
    structure(spec, class = "pub_report_spec")
}

#' @rdname pub_report_spec
#' @export
pub_page <- function(
    size = c("a4", "letter"),
    orientation = c("portrait", "landscape"),
    margins = NULL
) {
    size <- rlang::arg_match(size)
    orientation <- rlang::arg_match(orientation)
    default <- c(top = 2.5, bottom = 2, left = 2.5, right = 2.5)
    if (!is.null(margins)) {
        named <- !is.null(names(margins)) &&
            all(names(margins) %in% names(default)) &&
            !anyDuplicated(names(margins))
        ok <- is.numeric(margins) &&
            length(margins) > 0L &&
            named &&
            all(is.finite(margins)) &&
            all(margins >= 0)
        if (!ok) {
            rlang::abort(paste(
                "`margins` must be non-negative numbers (cm) named by",
                "\"top\", \"bottom\", \"left\" and \"right\"."
            ))
        }
        default[names(margins)] <- margins
    }
    dims <- .page_size(size, orientation)
    if (
        default[["left"]] + default[["right"]] >= dims[[1L]] ||
            default[["top"]] + default[["bottom"]] >= dims[[2L]]
    ) {
        rlang::abort(sprintf(
            "The margins leave no text area on the page (%s %s, %s x %s cm).",
            .page_name(size),
            orientation,
            dims[[1L]],
            dims[[2L]]
        ))
    }
    structure(
        list(size = size, orientation = orientation, margins = default),
        class = "pub_page"
    )
}

#' Width and height of a page in cm
#' @param size paper size: `"a4"` or `"letter"`.
#' @param orientation `"portrait"` or `"landscape"`.
#' @return `numeric(2)` width and height.
#' @noRd
.page_size <- function(size, orientation) {
    dims <- switch(size, a4 = c(21, 29.7), letter = c(21.59, 27.94))
    if (orientation == "landscape") rev(dims) else dims
}


# --------
# Printing
# --------
#' @export
print.pub_report_spec <- function(x, ...) {
    cat(sprintf("<pubflow report spec: %s>\n", x$format))
    lines <- .spec_lines(x)
    cat(sprintf("  %-17s %s\n", names(lines), lines), sep = "")
    invisible(x)
}

#' @export
print.pub_page <- function(x, ...) {
    cat(sprintf("<pubflow page: %s>\n", .page_text(x)))
    invisible(x)
}

#' The fields of a spec that its format uses, as text
#' @param x a `pub_report_spec`.
#' @return named `character` (the field names), one line each.
#' @noRd
.spec_lines <- function(x) {
    default <- \(value, text = "default") {
        if (is.null(value)) text else value
    }
    files <- switch(
        x$format,
        docx = c(reference_docx = default(x$reference_docx)),
        pdf = c(
            latex_preamble = default(x$latex_preamble, "none"),
            typst_template = default(x$typst_template)
        ),
        character()
    )
    c(
        files,
        front_matter = if (is.null(x$front_matter)) {
            "document's or title block"
        } else {
            "function"
        },
        toc = if (x$toc && x$format != "md") {
            sprintf("depth %d", x$toc_depth)
        } else {
            "no"
        },
        number_sections = if (x$number_sections) "yes" else "no",
        page = if (x$format %in% c("docx", "pdf")) {
            if (is.null(x$page)) {
                if (x$format == "docx") "reference document" else "A4"
            } else {
                .page_text(x$page)
            }
        },
        figure = if (is.null(x$figure)) {
            "default"
        } else {
            paste(names(x$figure), unlist(x$figure), sep = " = ", collapse = ", ")
        },
        labels = paste(x$labels$table, x$labels$figure, sep = ", "),
        placeholder_color = if (x$format %in% c("html", "pdf")) {
            default(x$placeholder_color)
        },
        lock = if (x$format == "docx") default(x$lock, "marked items"),
        error_items = x$error_items,
        post_process = if (length(x$post_process) == 0L) {
            "none"
        } else {
            sprintf("%d function(s)", length(x$post_process))
        },
        pandoc_args = if (x$format %in% c("docx", "pdf")) {
            if (length(x$pandoc_args) == 0L) {
                "none"
            } else {
                paste(x$pandoc_args, collapse = " ")
            }
        }
    )
}

#' A page as text: size, orientation and margins
#' @param x a `pub_page`.
#' @return `character(1)`.
#' @noRd
.page_text <- function(x) {
    sprintf(
        "%s %s, margins %s cm",
        .page_name(x$size),
        x$orientation,
        paste(sprintf("%s %g", names(x$margins), x$margins), collapse = ", ")
    )
}

#' Display name of a paper size
#' @param size `"a4"` or `"letter"`.
#' @return `character(1)`, e.g. `"A4"`.
#' @noRd
.page_name <- function(size) {
    c(a4 = "A4", letter = "Letter")[[size]]
}


# ------
# Checks
# ------
#' Path of a template file: an existing file (normalised) or `NULL`
#' @param path the path to check or `NULL`.
#' @param arg name of the argument, for the error message.
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_spec_file <- function(path, arg, call = rlang::caller_env()) {
    if (is.null(path)) {
        return(NULL)
    }
    if (!rlang::is_string(path) || !file.exists(path) || dir.exists(path)) {
        rlang::abort(
            sprintf("`%s` must be the path of an existing file.", arg),
            call = call
        )
    }
    normalizePath(path)
}

#' Caption labels merged over the defaults
#' @param labels named list of the caption words `table` and/or `figure`.
#' @param call the environment of the caller, for the error message.
#' @return `list(table, figure)`.
#' @noRd
.check_spec_labels <- function(labels, call = rlang::caller_env()) {
    default <- list(table = "Table", figure = "Figure")
    ok <- is.list(labels) &&
        rlang::is_named2(labels) &&
        all(names(labels) %in% names(default)) &&
        all(vapply(labels, \(x) rlang::is_string(x) && nzchar(x), logical(1)))
    if (!ok) {
        rlang::abort(
            paste(
                "`labels` must be a list of non-empty strings named \"table\"",
                "and \"figure\"."
            ),
            call = call
        )
    }
    utils::modifyList(default, labels)
}

#' Validate the values of a spec's fields
#' @param spec the list of a spec's fields (before the class is set).
#' @param call the environment of the caller, for the error message.
#' @return `spec`, invisibly.
#' @noRd
.check_spec_values <- function(spec, call = rlang::caller_env()) {
    abort <- \(msg) rlang::abort(msg, call = call)
    if (!rlang::is_string(spec$error_items, c("refuse", "show"))) {
        abort("`error_items` must be \"refuse\" or \"show\".")
    }
    if (!is.null(spec$front_matter) && !is.function(spec$front_matter)) {
        abort("`front_matter` must be a function or `NULL`.")
    }
    for (arg in c("toc", "number_sections")) {
        if (!rlang::is_bool(spec[[arg]])) {
            abort(sprintf("`%s` must be `TRUE` or `FALSE`.", arg))
        }
    }
    depth <- spec$toc_depth
    if (
        !rlang::is_scalar_integerish(depth) || is.na(depth) || depth < 1L || depth > 6L
    ) {
        abort("`toc_depth` must be a whole number between 1 and 6.")
    }
    if (!is.null(spec$page) && !inherits(spec$page, "pub_page")) {
        abort("`page` must be made by `pub_page()` or `NULL`.")
    }
    .check_spec_figure(spec$figure, spec$format, call)
    color <- spec$placeholder_color
    if (
        !is.null(color) &&
            !(rlang::is_string(color) && grepl("^#[0-9A-Fa-f]{6}$", color))
    ) {
        abort("`placeholder_color` must be a colour such as \"#0083c0\".")
    }
    if (!is.null(spec$lock) && !rlang::is_bool(spec$lock)) {
        abort("`lock` must be `TRUE`, `FALSE` or `NULL`.")
    }
    pp <- spec$post_process
    if (!is.list(pp) || !all(vapply(pp, is.function, logical(1)))) {
        abort("`post_process` must be a list of functions.")
    }
    if (
        isFALSE(spec$lock) &&
            any(vapply(pp, inherits, logical(1), "pub_pp_docx_lock"))
    ) {
        abort(paste(
            "`lock = FALSE` locks nothing, so `post_process` can't",
            "list `pub_pp_docx_lock()`."
        ))
    }
    if (!is.character(spec$pandoc_args) || anyNA(spec$pandoc_args)) {
        abort("`pandoc_args` must be a character vector.")
    }
    invisible(spec)
}

#' Validate figure settings of a spec (devices of its format)
#' @param figure the `figure` field or `NULL`.
#' @param format output format of the spec.
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_spec_figure <- function(figure, format, call) {
    if (is.null(figure)) {
        return(invisible())
    }
    if (
        !is.list(figure) ||
            !rlang::is_named(figure) ||
            !all(names(figure) %in% c("device", "res"))
    ) {
        rlang::abort("`figure` must be a list with `device` and/or `res`.", call = call)
    }
    devices <- .spec_devices[[format]]
    device <- figure$device
    if (
        !is.null(device) &&
            !(rlang::is_string(device) && device %in% devices)
    ) {
        rlang::abort(
            sprintf(
                "`figure$device` of %s reports must be %s.",
                format,
                paste0("\"", devices, "\"", collapse = " or ")
            ),
            call = call
        )
    }
    if (!is.null(figure$res) && !.is_positive_number(figure$res)) {
        rlang::abort("`figure$res` must be a positive number.", call = call)
    }
    invisible()
}

#' Figure devices per format
#' @noRd
.spec_devices <- list(
    html = c("png", "svg"),
    docx = "png",
    pdf = c("png", "pdf", "svg"),
    md = c("png", "svg")
)

#' Refuse fields that the spec's format can't use
#' @param spec the list of a spec's fields.
#' @param call the environment of the caller, for the error message.
#' @return `spec`, invisibly.
#' @noRd
.check_spec_formats <- function(spec, call = rlang::caller_env()) {
    used <- list(
        reference_docx = "docx",
        latex_preamble = "pdf",
        typst_template = "pdf",
        page = c("docx", "pdf"),
        placeholder_color = c("html", "pdf"),
        lock = "docx",
        pandoc_args = c("docx", "pdf")
    )
    for (field in names(used)) {
        set <- length(spec[[field]]) > 0L
        if (set && !spec$format %in% used[[field]]) {
            rlang::abort(
                sprintf(
                    "`%s` can't be used for %s reports, only for %s.",
                    field,
                    spec$format,
                    paste(used[[field]], collapse = " and ")
                ),
                call = call
            )
        }
    }
    docx <- c("pub_pp_docx_header_footer", "pub_pp_docx_lock")
    if (
        spec$format != "docx" &&
            any(vapply(spec$post_process, inherits, logical(1), docx))
    ) {
        rlang::abort(
            sprintf(
                paste(
                    "`pub_pp_docx_header_footer()` and `pub_pp_docx_lock()` can't",
                    "be used for %s reports, only for docx."
                ),
                spec$format
            ),
            call = call
        )
    }
    invisible(spec)
}

#' Check that a spec is one for the output format (fields edited after
#' `pub_report_spec()` are checked and normalised again)
#' @param spec the value to check.
#' @param format the output format it must be for.
#' @param call the environment of the caller, for the error message.
#' @return The spec, normalised as by `pub_report_spec()`.
#' @noRd
.check_report_spec <- function(spec, format, call = rlang::caller_env()) {
    if (!inherits(spec, "pub_report_spec")) {
        rlang::abort("`spec` must be made by `pub_report_spec()`.", call = call)
    }
    if (!identical(spec$format, format)) {
        rlang::abort(
            sprintf("`spec` is for \"%s\" output, not \"%s\".", spec$format, format),
            call = call
        )
    }
    unknown <- setdiff(names(spec), names(formals(pub_report_spec)))
    if (length(unknown) > 0L) {
        rlang::abort(
            sprintf("`spec` has unknown fields: %s.", toString(unknown)),
            call = call
        )
    }
    .new_report_spec(unclass(spec), call)
}


# ======================================================================================
# Settings of a target
# ======================================================================================

# -------
# Targets
# -------
#' Output format of a target (`"latex"` and `"typst"` make PDF)
#' @param target `"html"`, `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @return `character(1)` format.
#' @noRd
.target_format <- function(target) {
    if (target %in% c("latex", "typst")) "pdf" else target
}

#' Target of an output format (PDF: by engine)
#' @param format `"html"`, `"docx"`, `"pdf"` or `"md"`.
#' @param pdf_engine `"xelatex"` (target `"latex"`) or `"typst"`.
#' @return `character(1)` target.
#' @noRd
.format_target <- function(format, pdf_engine = "xelatex") {
    if (format != "pdf") {
        return(format)
    }
    if (pdf_engine == "xelatex") "latex" else "typst"
}


# --------
# Settings
# --------
#' Resolve a report spec for a target
#'
#' @param spec a `pub_report_spec`.
#' @param target `"html"`, `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @return `list(target, format, reference_docx, latex_preamble, typst_template, labels,
#'   placeholder_color, page, figure, front_matter, toc, toc_depth, number_sections,
#'   lock, pandoc_args)`: templates are paths (pubflow's by default; LaTeX: pubflow's
#'   header, then the spec's), `page` is
#'   `list(paper, width, height, top, bottom, left, right, turn)` in cm (width and
#'   height swapped for a landscape page, `turn` `TRUE`) or `NULL` (DOCX without a page,
#'   HTML, Markdown), `figure` is `list(device, res)`, the colour a hex string without
#'   `#` (or `NULL`), `lock` the spec's in DOCX (`TRUE`, `FALSE` or `NULL`), else
#'   `FALSE`.
#' @param call the environment of the caller, for the error message.
#' @noRd
.render_settings <- function(spec, target, call = rlang::caller_env()) {
    list(
        target = target,
        format = spec$format,
        reference_docx = if (target == "docx") {
            spec$reference_docx %||% .template_file("reference.docx")
        },
        latex_preamble = if (target == "latex") {
            c(.template_file("pubflow-header.tex"), spec$latex_preamble)
        },
        typst_template = if (target == "typst") {
            spec$typst_template %||% .template_file("pubflow.typ")
        },
        labels = spec$labels,
        placeholder_color = .settings_color(spec$placeholder_color, target),
        page = .settings_page(spec$page, target),
        figure = .settings_figure(spec$figure, target, spec$format, call),
        front_matter = spec$front_matter,
        toc = spec$toc,
        toc_depth = spec$toc_depth,
        number_sections = spec$number_sections,
        lock = if (target == "docx") spec$lock else FALSE,
        pandoc_args = spec$pandoc_args
    )
}

#' Placeholder colour of a target: hex without `#`; PDF default #0083c0 (HTML keeps its
#' stylesheet's colour unless one is set)
#' @param color the spec's `placeholder_color` or `NULL`.
#' @param target the target.
#' @noRd
.settings_color <- function(color, target) {
    if (target %in% c("latex", "typst")) {
        color <- color %||% "#0083C0"
    }
    if (is.null(color) || !target %in% c("html", "latex", "typst")) {
        return(NULL)
    }
    sub("^#", "", color)
}

#' Page of a target in cm (see `.render_settings()`)
#' @param page a `pub_page` or `NULL`.
#' @param target the target.
#' @noRd
.settings_page <- function(page, target) {
    if (
        !target %in% c("docx", "latex", "typst") ||
            (is.null(page) && target == "docx")
    ) {
        return(NULL)
    }
    page <- page %||% pub_page()
    size <- .page_size(page$size, page$orientation)
    turn <- page$orientation == "landscape"
    c(
        list(paper = page$size, width = size[[1L]], height = size[[2L]]),
        as.list(page$margins),
        list(turn = turn)
    )
}

#' Figure devices per target
#' @noRd
.target_devices <- list(
    html = c("png", "svg"),
    docx = "png",
    latex = c("png", "pdf"),
    typst = c("png", "svg"),
    md = c("png", "svg")
)

#' Default device settings of figures, the same for every format and the viewer, so that
#' they share the rendered figures in the cache
#' @noRd
.figure_default <- list(device = "png", res = 200)

#' Figure settings of a target: the spec's over the default
#' @param figure the spec's `figure` field or `NULL`.
#' @param target the target.
#' @param format output format of the spec.
#' @param call the environment of the caller, for the error message.
#' @return `list(device, res)`.
#' @noRd
.settings_figure <- function(figure, target, format, call) {
    settings <- utils::modifyList(.figure_default, figure %||% list())
    devices <- .target_devices[[target]]
    if (!settings$device %in% devices) {
        output <- if (format == "pdf") paste("PDF via", target) else format
        rlang::cnd_signal(.render_error(
            sprintf(
                "Figures of %s output can't use the device \"%s\" (%s).",
                output,
                settings$device,
                paste0("\"", devices, "\"", collapse = " or ")
            ),
            format = format,
            call = call
        ))
    }
    settings
}

#' Path of a file in inst/templates
#' @param name file name, e.g. `"reference.docx"`.
#' @noRd
.template_file <- function(name) {
    system.file("templates", name, package = "pubflow", mustWork = TRUE)
}


# ======================================================================================
# Front matter and table of contents
# ======================================================================================

# ------------
# Front matter
# ------------
#' Nodes of the front matter: of the spec's `front_matter` function, else the
#' document's (`NULL` if neither has one)
#' @param settings settings of the target (`.render_settings()`).
#' @param doc the `pub_doc` (with the render-time metadata).
#' @param call the environment of the caller, for the error message.
#' @noRd
.front_nodes <- function(settings, doc, call = rlang::caller_env()) {
    fun <- settings$front_matter
    if (is.null(fun)) {
        return(doc$front_matter)
    }
    tryCatch(
        {
            front <- fun(doc, settings$format)
            if (!is.null(front)) .as_children(list(front))
        },
        error = function(e) {
            rlang::cnd_signal(.render_error(
                "`front_matter` failed.",
                format = settings$format,
                parent = e,
                call = call
            ))
        }
    )
}


# -----------------
# Table of contents
# -----------------
#' Whether the spec adds a table of contents: the document has sections and no table of
#' contents is placed (Markdown has none)
#' @param settings settings of the target (`.render_settings()`).
#' @param doc the `pub_doc`.
#' @param front nodes of the front matter or `NULL`.
#' @noRd
.wants_toc <- function(settings, doc, front) {
    settings$toc &&
        settings$target != "md" &&
        any(vapply(doc$children, inherits, logical(1), "pub_section")) &&
        !.has_toc(c(front, doc$children))
}

#' Whether nodes place a table of contents (a list of figures or tables is none)
#' @param nodes list of nodes (sections are searched recursively).
#' @noRd
.has_toc <- function(nodes) {
    any(vapply(
        nodes,
        \(x) {
            if (inherits(x, "pub_section")) {
                .has_toc(x$children)
            } else {
                x$type == "toc" && x$object$what == "sections"
            }
        },
        logical(1)
    ))
}
