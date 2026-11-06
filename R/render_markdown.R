# Pandoc Markdown of documents: one Markdown file plus figure files per document, which
# pandoc turns into DOCX or PDF (LaTeX, Typst) in one call, or which is the result
# itself (target "md"). The walk is shared; the markup of each node depends on the
# target. A render context collects the blocks and keeps the numbering, the page
# orientation and pending page breaks: page and section breaks are written lazily before
# the next content, so a landscape part directly after a page break or after another
# landscape part doesn't make an empty page.

# ======================================================================================
# Markdown documents
# ======================================================================================

# ------
# Render
# ------
#' Render a document to Pandoc Markdown
#'
#' Writes a document (see [pub_doc()]) as Markdown for pandoc, and its figures as image
#' files. [pub_render()] uses it for DOCX, PDF and Markdown files. It can also be used
#' to see or post-process the Markdown that pandoc gets.
#'
#' @details
#' ## Targets
#'
#' * `"docx"`: Markdown for pandoc's Word writer. Tables become native Word tables,
#'   and caption numbers and the table of contents Word fields. Landscape parts get
#'   their own sections and, if the spec locks, tables and figures are locked.
#' * `"latex"`, `"typst"`: Markdown for a PDF via xelatex or Typst. Tables are written
#'   as LaTeX or Typst code that breaks across pages and repeats the header rows.
#'   Figures are PNG images unless the spec's `figure` asks for `"pdf"` (LaTeX) or
#'   `"svg"` (Typst).
#' * `"md"`: a plain Markdown document with a YAML front matter that holds the header,
#'   numbered headings, tables as Pandoc multiline tables and images. Page breaks,
#'   landscape parts and tables of contents are left out.
#'
#' The document header (title, subtitle, author, time) of DOCX is not part of the
#' Markdown. [pub_render()] passes it to pandoc as metadata.
#'
#' ## Texts, widgets and errors
#'
#' * Texts are CommonMark (see [pub_text()]). Raw HTML and pandoc's own syntax in them
#'   show as text, as in HTML.
#' * Widgets are replaced by their `fallback` figure (see [pub_meta()]) or skipped with
#'   a warning.
#' * Error items (failed steps) are written as marked paragraphs. [pub_render()] refuses
#'   them unless the spec shows them.
#' * Cross-references in texts (see [pub_text()]) become Word cross-reference fields,
#'   LaTeX or Typst references or, for `"md"`, the label and number.
#'
#' ## Math in PDFs
#'
#' LaTeX runs TeX commands, so for the `"latex"` target pandoc's math parser checks
#' every formula first. A formula it can't read, or one that defines macros, is an
#' error.
#'
#' ## Report spec
#'
#' The report spec (see [pub_report_spec()]) adds the front matter, table of contents,
#' section numbers, caption labels, figure devices and page. [pub_render()] calls
#' `pub_markdown()` with its spec. The document's metadata is used as-is (no
#' render-time metadata), so the Markdown of a document is always the same.
#'
#' @param doc A `pub_doc`.
#' @param target `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @param assets_dir Directory for the figure files (created if needed). The Markdown
#'   refers to them as `<basename(assets_dir)>/figure-<n>.<ext>`, so the Markdown file
#'   belongs in the parent of `assets_dir`.
#' @param cache A [pub_cache()] or `NULL` (render every figure). Figures are cached
#'   as in [pub_html()].
#' @param spec A [pub_report_spec()] of the target's format (`"pdf"` for LaTeX and
#'   Typst), or `NULL` (the default spec of the format).
#' @return `character(1)` Markdown.
#' @seealso [pub_render()], [pub_html()], [pub_report_spec()]
#' @examples
#' doc <- pub_doc(
#'     pub_section(
#'         "Results",
#'         pub_text("The slope is **negative** ($b < 0$)."),
#'         pub_table(data.frame(batch = c("A", "B"), slope = c(-0.26, -0.25)),
#'                   caption = "Slopes", digits = c(slope = 2L))
#'     ),
#'     title = "Demo"
#' )
#' cat(pub_markdown(doc, "md", assets_dir = tempfile()))
#' @export
pub_markdown <- function(
    doc,
    target = c("docx", "latex", "typst", "md"),
    assets_dir,
    cache = NULL,
    spec = NULL
) {
    .check_doc(doc)
    target <- rlang::arg_match(target)
    if (!rlang::is_string(assets_dir) || !nzchar(assets_dir)) {
        rlang::abort("`assets_dir` must be a directory path (a string).")
    }
    .check_cache(cache)
    format <- .target_format(target)
    spec <- spec %||% pub_report_spec(format)
    spec <- .check_report_spec(spec, format)
    .markdown_doc(doc, .render_settings(spec, target), assets_dir, cache)
}

#' Markdown of a checked document
#'
#' The front matter (unnumbered), the table of contents of the spec and the body share
#' one context, so caption numbers count through all. Cross-references get their numbers
#' after the walk (DOCX, md); a problem with them is an error.
#' @param doc a checked `pub_doc`.
#' @param spec settings of the target (`.render_settings()`).
#' @param assets_dir directory for the figure files.
#' @param cache a `pub_cache` or `NULL`.
#' @param front nodes of the front matter or `NULL`.
#' @return `character(1)` Markdown.
#' @noRd
.markdown_doc <- function(
    doc,
    spec,
    assets_dir,
    cache,
    front = .front_nodes(spec, doc)
) {
    ctx <- .markdown_context(doc, spec, assets_dir, cache, front)
    .md_nodes(front, ctx, level = 1L, number = integer(), numbered = FALSE)
    if (.wants_toc(spec, doc, front)) {
        .md_item(.new_item("toc", pub_toc(spec$toc_depth)), ctx)
    }
    .md_nodes(
        doc$children,
        ctx,
        level = 1L,
        number = integer(),
        numbered = spec$number_sections
    )
    if (ctx$landscape && ctx$target != "typst") {
        # Word: the last section is landscape (pub_render() moves it to the end); LaTeX:
        # the landscape environment ends
        ctx$blocks <- c(ctx$blocks, .md_section_break(ctx, landscape = TRUE))
    }
    blocks <- c(
        if (spec$target == "md" && is.null(front)) {
            .md_front_matter(doc$meta)
        },
        ctx$blocks
    )
    .ref_signal(ctx$refs, "error", format = spec$target)
    md <- .insert_refs(
        paste0(paste(blocks, collapse = "\n\n"), "\n"),
        ctx$refs,
        spec$target
    )
    if (spec$target == "latex") {
        .check_latex_math(md)
    }
    md
}

#' Render context: settings, counters, the blocks written so far and the page state
#' @param doc a checked `pub_doc`.
#' @param spec settings of the target (`.render_settings()`).
#' @param assets_dir directory for the figure files.
#' @param cache a `pub_cache` or `NULL`.
#' @param front nodes of the front matter or `NULL`.
#' @return an environment.
#' @noRd
.markdown_context <- function(doc, spec, assets_dir, cache, front = NULL) {
    ctx <- new.env(parent = emptyenv())
    ctx$spec <- spec
    ctx$target <- spec$target
    ctx$cache <- cache
    ctx$assets_dir <- assets_dir
    ctx$tables <- 0L
    ctx$figures <- 0L
    ctx$files <- 0L
    ctx$refs <- .ref_state(c(front, doc$children), spec$labels)
    ctx$blocks <- character()
    ctx$text_width <- switch(
        spec$target,
        docx = .docx_text_width(spec$reference_docx, spec$page),
        latex = .latex_text_width(spec$page)
    )
    ctx$text_area <- if (spec$target %in% c("latex", "typst")) {
        .pdf_text_area(spec$page, spec$target)
    }
    # orientation of the current part and of the next content; a turned (landscape)
    # document has no landscape parts
    ctx$landscape <- FALSE
    ctx$want_landscape <- FALSE
    ctx$turn <- isTRUE(spec$page$turn)
    ctx$pending_break <- FALSE
    # TRUE while nothing is on the first page (pandoc's title block counts; front matter
    # replaces it)
    ctx$empty <- !is.null(front) || !.has_title_block(doc$meta)
    ctx
}

#' Whether a document gets a title block: a title, subtitle or author (a time alone
#' doesn't make one)
#' @param meta named `list` of document metadata.
#' @return `TRUE` or `FALSE`.
#' @noRd
.has_title_block <- function(meta) {
    any(c("title", "subtitle", "author") %in% names(meta))
}

#' Add content blocks, preceded by a pending page break or a section break if the
#' orientation changes
#'
#' Nothing breaks the page before the first content; a change to landscape is marked
#' there too, except in Word, where a section break ends the part before it.
#' @param ctx the render context.
#' @param blocks `character` Markdown blocks (empty strings are dropped).
#' @return `ctx`, invisibly.
#' @noRd
.md_emit <- function(ctx, blocks) {
    blocks <- blocks[nzchar(blocks)]
    if (length(blocks) == 0L) {
        return(invisible(ctx))
    }
    pending <- if (ctx$landscape != ctx$want_landscape) {
        if (!ctx$empty || ctx$target != "docx") {
            .md_section_break(ctx, landscape = ctx$landscape)
        }
    } else if (ctx$pending_break && !ctx$empty) {
        .md_page_break(ctx)
    }
    ctx$landscape <- ctx$want_landscape
    ctx$pending_break <- FALSE
    ctx$empty <- FALSE
    ctx$blocks <- c(ctx$blocks, pending, blocks)
    invisible(ctx)
}


# ------------
# Front matter
# ------------
#' YAML front matter of the Markdown target (only with a title, subtitle or author, as
#' the title block of the other targets)
#' @param meta named `list` of document metadata.
#' @return `character(1)` front matter or `NULL`.
#' @noRd
.md_front_matter <- function(meta) {
    if (!.has_title_block(meta)) {
        return(NULL)
    }
    time <- meta[["time"]]
    fields <- c(
        title = meta[["title"]],
        subtitle = meta[["subtitle"]],
        author = meta[["author"]],
        date = if (!is.null(time)) .format_utc(time)
    )
    paste(
        c("---", sprintf("%s: %s", names(fields), .yaml_string(fields)), "---"),
        collapse = "\n"
    )
}

#' Time of a document as shown in its header
#' @param time `POSIXct` time.
#' @return `character` time in UTC.
#' @noRd
.format_utc <- function(time) {
    format(time, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
}

#' YAML double-quoted strings
#' @param x `character` strings.
#' @return `character` quoted and escaped strings.
#' @noRd
.yaml_string <- function(x) {
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub("\"", "\\\"", x, fixed = TRUE)
    x <- gsub("\n", "\\n", x, fixed = TRUE)
    x <- gsub("\r", "\\r", x, fixed = TRUE)
    x <- gsub("\t", "\\t", x, fixed = TRUE)
    paste0("\"", x, "\"")
}


# ======================================================================================
# Nodes
# ======================================================================================

# --------
# Sections
# --------
#' Markdown of a list of nodes (sections and items)
#'
#' @param nodes `list` of sections and items.
#' @param ctx the render context.
#' @param level `integer(1)` section level of the nodes (1 = top).
#' @param number `integer` section number of the parent (empty at the top).
#' @param numbered `TRUE` if the parent is numbered.
#' @noRd
.md_nodes <- function(nodes, ctx, level, number, numbered) {
    nNumbered <- 0L
    for (node in nodes) {
        if (inherits(node, "pub_item")) {
            .md_item(node, ctx)
            next
        }
        isNumbered <- numbered && node$numbered
        if (isNumbered) {
            nNumbered <- nNumbered + 1L
        }
        .md_section(
            node,
            ctx,
            level = level,
            number = if (isNumbered) c(number, nNumbered)
        )
    }
    invisible(ctx)
}

#' Markdown of a section: its heading, then its children
#' @param x a `pub_section`.
#' @param ctx the render context.
#' @param level `integer(1)` section level (1 = top).
#' @param number `integer` section number, `NULL` if unnumbered.
#' @noRd
.md_section <- function(x, ctx, level, number) {
    if (isTRUE(x$page_break %||% (level == 1L))) {
        ctx$pending_break <- TRUE
    }
    outer <- ctx$want_landscape
    ctx$want_landscape <- outer || (x$landscape && !ctx$turn)
    .md_emit(ctx, .md_heading(x$title, level, number, ctx))
    .md_nodes(
        x$children,
        ctx,
        level = level + 1L,
        number = number %||% integer(),
        numbered = !is.null(number)
    )
    ctx$want_landscape <- outer
    invisible(ctx)
}

#' Heading line: Word numbers headings by style (unnumbered ones get the "Heading n
#' Unnumbered" styles, levels beyond 5 the level-5 styles); pandoc numbers LaTeX and
#' Typst headings unless they are `.unnumbered` (up to level 5); the Markdown target
#' shows the number as text
#' @param title `character(1)` section title.
#' @param level `integer(1)` section level.
#' @param number `integer` section number, `NULL` if unnumbered.
#' @param ctx the render context.
#' @return `character(1)` heading block.
#' @noRd
.md_heading <- function(title, level, number, ctx) {
    text <- .escape_literal(title)
    if (ctx$target == "docx") {
        level <- min(level, 5L)
        if (is.null(number)) {
            return(.md_div(sprintf("Heading %d Unnumbered", level), text))
        }
        return(paste(strrep("#", level), text))
    }
    if (ctx$target %in% c("latex", "typst")) {
        return(paste(
            c(strrep("#", min(level, 5L)), text, if (is.null(number)) "{.unnumbered}"),
            collapse = " "
        ))
    }
    number <- if (!is.null(number)) paste(number, collapse = ".")
    paste(c(strrep("#", min(level, 6L)), number, text), collapse = " ")
}


# -----
# Items
# -----
#' An item: optional title line and the content, on landscape pages if its metadata says
#' so
#' @param x a `pub_item`.
#' @param ctx the render context.
#' @noRd
.md_item <- function(x, ctx) {
    if (x$type == "pagebreak") {
        ctx$pending_break <- TRUE
        return(invisible(ctx))
    }
    outer <- ctx$want_landscape
    ctx$want_landscape <- outer ||
        (isTRUE(x$meta[["landscape"]]) && !ctx$turn)
    content <- switch(
        x$type,
        text = .markdown_pandoc(
            x$object,
            ctx$target,
            ctx$spec$placeholder_color,
            ref = .ref_converter(ctx$refs, ctx$target)
        ),
        table = .md_table(x$object, x$meta, ctx),
        figure = .md_figure(x$object, x$meta, ctx),
        widget = .md_widget(x, ctx),
        raw = .md_raw(x$object, ctx),
        toc = .md_toc(x$object, ctx),
        error = .md_error(x$object, ctx),
        NULL
    )
    if (length(content) > 0L) {
        .md_emit(ctx, c(.md_item_title(x$meta[["title"]], ctx), content))
    }
    ctx$want_landscape <- outer
    invisible(ctx)
}

#' Title line of an item (none for a missing or blank title)
#' @param title `character(1)` title or `NULL`.
#' @param ctx the render context.
#' @return `character(1)` block or `NULL`.
#' @noRd
.md_item_title <- function(title, ctx) {
    if (is.null(title) || !nzchar(trimws(title))) {
        return(NULL)
    }
    text <- .escape_literal(title)
    switch(ctx$target, docx = .md_div("Item Title", text), paste0("**", text, "**"))
}

#' Raw content of the target, if any (not empty)
#' @param x a `pub_raw`.
#' @param ctx the render context.
#' @return `character(1)` block or `NULL`.
#' @noRd
.md_raw <- function(x, ctx) {
    content <- x[[ctx$target]]
    if (is.null(content) || !any(nzchar(content))) {
        return(NULL)
    }
    if (ctx$target == "md") {
        return(content)
    }
    .md_raw_block(content, .raw_format(ctx$target))
}

#' Pandoc's name of the raw format of a target
#' @param target `"docx"`, `"latex"` or `"typst"`.
#' @noRd
.raw_format <- function(target) {
    if (target == "docx") "openxml" else target
}

#' Table of contents: a Word TOC field, updated by Word (headings and paragraphs with
#' outline levels up to `depth`); LaTeX's and Typst's table of contents. Lists of
#' figures and tables are the engines' lists of the captions (Word's of the `SEQ`
#' fields).
#' @param x a `pub_toc`.
#' @param ctx the render context.
#' @return `character(1)` raw block or `NULL` (Markdown target).
#' @noRd
.md_toc <- function(x, ctx) {
    if (x$what != "sections") {
        return(.md_toc_list(x$what, ctx))
    }
    if (ctx$target == "latex") {
        return(.md_raw_block(
            c(
                sprintf("\\setcounter{tocdepth}{%d}", min(x$depth, 5L)),
                "\\tableofcontents"
            ),
            "latex"
        ))
    }
    if (ctx$target == "typst") {
        return(.md_raw_block(sprintf("#outline(depth: %d)", x$depth), "typst"))
    }
    if (ctx$target != "docx") {
        return(NULL)
    }
    .md_toc_field(sprintf("TOC \\o \"1-%d\" \\h \\z \\u", x$depth), "table of contents")
}

#' List of figures or tables
#' @param what `"figures"` or `"tables"`.
#' @param ctx the render context.
#' @return `character(1)` raw block or `NULL` (Markdown target).
#' @noRd
.md_toc_list <- function(what, ctx) {
    figures <- what == "figures"
    switch(
        ctx$target,
        latex = .md_raw_block(sprintf("\\listof%s", what), "latex"),
        typst = .md_raw_block(
            sprintf(
                "#outline(title: [List of %s], target: figure.where(kind: %s))",
                if (figures) "Figures" else "Tables",
                if (figures) "image" else "table"
            ),
            "typst"
        ),
        docx = .md_toc_field(
            sprintf("TOC \\h \\z \\c \"%s\"", if (figures) "Figure" else "Table"),
            paste("list of", what)
        ),
        NULL
    )
}

#' Word TOC field, filled in when Word updates the fields
#' @param instr `character(1)` field instruction.
#' @param what `character(1)` what the field shows, for its placeholder text.
#' @return `character(1)` raw OpenXML block.
#' @noRd
.md_toc_field <- function(instr, what) {
    .md_raw_block(
        sprintf(
            paste0(
                "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" w:dirty=\"true\"/>",
                "</w:r><w:r><w:instrText xml:space=\"preserve\"> %s </w:instrText>",
                "</w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>",
                "Update the field to show the %s.</w:t></w:r><w:r><w:fldChar ",
                "w:fldCharType=\"end\"/></w:r></w:p>"
            ),
            instr,
            what
        ),
        "openxml"
    )
}

#' Error item: the failed step and its message, marked
#' @param x a `pub_error`.
#' @param ctx the render context.
#' @return `character` blocks.
#' @noRd
.md_error <- function(x, ctx) {
    lines <- c(
        paste0(
            "**",
            .escape_literal(sprintf("Step %s failed", .failed_label(x))),
            "**"
        ),
        .escape_literal(Filter(
            \(l) nzchar(trimws(l)),
            strsplit(x$message, "\n", fixed = TRUE)[[1L]]
        )),
        if (!identical(x$step, x$failed_step)) {
            .escape_literal(sprintf("Step '%s' was not run.", x$step))
        }
    )
    text <- paste(lines, collapse = "\\\n")
    switch(
        ctx$target,
        docx = .md_div("Error", text),
        latex = c(
            .md_raw_block("\\begin{pubflowerror}", "latex"),
            text,
            .md_raw_block("\\end{pubflowerror}", "latex")
        ),
        typst = c(
            .md_raw_block(
                paste0(
                    "#block(stroke: 0.75pt + rgb(\"#c00000\"), inset: 6pt, ",
                    "width: 100%)["
                ),
                "typst"
            ),
            text,
            .md_raw_block("]", "typst")
        ),
        paste0("> ", gsub("\n", "\n> ", text, fixed = TRUE))
    )
}


# ------
# Tables
# ------
#' Table: numbered caption before it; DOCX: the native Word table, in a locked content
#' control if locked; Markdown: huxtable's Markdown of the display table; LaTeX and
#' Typst: huxtable's table with caption (numbered by the engine)
#' @param x a huxtable.
#' @param meta named `list` of the item's metadata.
#' @param ctx the render context.
#' @return `character` blocks.
#' @noRd
.md_table <- function(x, meta, ctx) {
    caption <- meta[["caption"]]
    if (ctx$target == "latex") {
        latex <- .table_latex(
            x,
            caption,
            meta[["font_size"]],
            text_width = .md_text_width(ctx),
            unit_width = ctx$text_width[["portrait"]],
            label = .ref_label(ctx, meta, "table")
        )
        return(.md_raw_block(latex, "latex"))
    }
    if (ctx$target == "typst") {
        typst <- .table_typst(
            x,
            caption,
            meta[["font_size"]],
            label = .ref_label(ctx, meta, "table")
        )
        return(.md_raw_block(typst, "typst"))
    }
    if (!is.null(caption)) {
        ctx$tables <- ctx$tables + 1L
        .ref_number(ctx$refs, meta, "table", ctx$tables)
        caption <- .md_caption("table", ctx$tables, caption, ctx, meta)
    }
    if (ctx$target == "md") {
        return(c(caption, .md_table_markdown(x)))
    }
    wml <- .huxtable_to_wml(
        x,
        font_size = meta[["font_size"]],
        text_width = .md_text_width(ctx)
    )
    if (.md_locked(meta, ctx)) {
        sdt <- .md_locked_sdt("locked-table")
        wml <- c(sdt[["open"]], wml, sdt[["close"]])
    }
    c(caption, .md_raw_block(wml, "openxml"))
}

#' Whether a table or figure is locked (DOCX only): `lock = TRUE` locks every item that
#' isn't `locked = FALSE`, `lock = NULL` the items with `locked = TRUE`
#' @param meta named `list` of the item's metadata.
#' @param ctx the render context.
#' @noRd
.md_locked <- function(meta, ctx) {
    !isFALSE(ctx$spec$lock) && isTRUE(meta[["locked"]] %||% ctx$spec$lock)
}

#' Start and end of a locked content control around a table or figure: Word lets
#' users neither edit nor delete its content
#'
#' Without a `w:id` (optional; Word adds one when it saves), so it can't clash with
#' the id of a control in raw content or in a reference document's header.
#' @param tag tag of the content control (`locked-table` or `locked-figure`).
#' @return `character(2)` openxml, named `open` and `close`.
#' @noRd
.md_locked_sdt <- function(tag) {
    c(
        open = paste0(
            sprintf("<w:sdt><w:sdtPr><w:tag w:val=\"%s\"/>", tag),
            "<w:lock w:val=\"sdtContentLocked\"/></w:sdtPr><w:sdtContent>"
        ),
        close = "</w:sdtContent></w:sdt>"
    )
}

#' huxtable's Markdown of the display table, without caption; text cells escaped
#' (huxtable writes them as they are), lines not wrapped
#' @param x a huxtable.
#' @return `character(1)` Markdown table.
#' @noRd
.md_table_markdown <- function(x) {
    ht <- .display_huxtable(x)
    huxtable::caption(ht) <- NA
    plain <- !huxtable::markdown(ht)
    for (j in seq_len(ncol(ht))) {
        rows <- plain[, j]
        ht[[j]][rows] <- .escape_inline(ht[[j]][rows])
    }
    md <- withCallingHandlers(
        huxtable::to_md(ht, max_width = Inf),
        warning = function(w) {
            # spans keep their content in the first cell; columns are aligned like their
            # first row
            known <- c("colspan/rowspan", "vary column alignment")
            if (
                any(vapply(known, grepl, logical(1), conditionMessage(w), fixed = TRUE))
            ) {
                invokeRestart("muffleWarning")
            }
        }
    )
    sub("\n+$", "", md)
}

#' Numbered caption: Word gets a `SEQ` field with the number as its result (correct
#' before the fields are updated), inside a bookmark if the item is the target of
#' cross-references
#' @param kind `"table"` or `"figure"`.
#' @param number `integer(1)` number of the table or figure.
#' @param caption `character(1)` caption text.
#' @param ctx the render context.
#' @param meta the item's metadata (its `id`).
#' @noRd
.md_caption <- function(kind, number, caption, ctx, meta = list()) {
    label <- .escape_literal(ctx$spec$labels[[kind]])
    text <- .escape_literal(caption)
    if (ctx$target == "md") {
        return(sprintf("%s %d: %s", label, number, text))
    }
    id <- switch(kind, table = "Table", figure = "Figure")
    field <- sprintf(
        paste0(
            "<w:fldSimple w:instr=\" SEQ %s \\* ARABIC \"><w:r><w:t>%d</w:t>",
            "</w:r></w:fldSimple>"
        ),
        id,
        number
    )
    style <- switch(kind, table = "Table Caption", figure = "Image Caption")
    number <- .ref_bookmarked(
        .ref_anchor(ctx$refs, meta, kind),
        paste(label, .md_raw_inline(field, "openxml"))
    )
    .md_div(style, sprintf("%s: %s", number, text))
}


# -------
# Figures
# -------
#' Figure: image file in the assets directory, numbered caption after it
#'
#' DOCX: the "Figure" paragraph, in a locked content control if locked. LaTeX and
#' Typst: a figure with caption (pandoc's implicit figure, which the engine numbers), a
#' centred image without.
#' @param x a figure (plot object or image file path).
#' @param meta named `list` of the item's metadata.
#' @param ctx the render context.
#' @return `character` blocks.
#' @noRd
.md_figure <- function(x, meta, ctx) {
    path <- gsub("([\\<>])", "\\\\\\1", .md_figure_asset(x, meta, ctx))
    caption <- meta[["caption"]]
    if (ctx$target %in% c("latex", "typst")) {
        width <- .md_pdf_figure_width(x, meta, ctx)
        alt <- if (!is.null(caption)) .escape_literal(caption) else ""
        label <- .ref_label(ctx, meta, "figure")
        id <- if (!is.null(label)) paste0("#", label, " ") else ""
        image <- sprintf("![%s](<%s>){%swidth=%s}", alt, path, id, width)
        return(if (is.null(caption)) .md_centered(image, ctx) else image)
    }
    alt <- .escape_literal(caption %||% meta[["title"]] %||% "Figure")
    image <- sprintf("![%s](<%s>)", alt, path)
    if (!is.null(caption)) {
        ctx$figures <- ctx$figures + 1L
        .ref_number(ctx$refs, meta, "figure", ctx$figures)
        caption <- .md_caption("figure", ctx$figures, caption, ctx, meta)
    }
    if (ctx$target == "md") {
        return(c(image, caption))
    }
    width <- .md_figure_width(meta[["out_width"]], ctx)
    figure <- .md_div("Figure", sprintf("%s{width=%s}", image, width))
    if (.md_locked(meta, ctx)) {
        # the control is split around the paragraph that pandoc writes for the image
        sdt <- .md_locked_sdt("locked-figure")
        figure <- c(
            .md_raw_block(sdt[["open"]], "openxml"),
            figure,
            .md_raw_block(sdt[["close"]], "openxml")
        )
    }
    c(figure, caption)
}

#' Width of a figure in Word: `out_width` of the text width of the page (portrait or
#' landscape) in inches
#'
#' pandoc computes percentages from the portrait width of the reference document and
#' never scales an image beyond its natural size.
#' @param out_width percentage string or `NULL` (`"90%"`).
#' @param ctx the render context.
#' @return `character(1)` width such as `"5.67in"`.
#' @noRd
.md_figure_width <- function(out_width, ctx) {
    percent <- as.numeric(sub("%", "", out_width %||% "90%", fixed = TRUE))
    sprintf("%.2fin", .md_text_width(ctx) * percent / 100 / 1440)
}

#' Width of a figure in LaTeX and Typst: `out_width` of the text width of the page, but
#' at most as wide as keeps the figure within 85% of the text height (room for the
#' caption)
#'
#' pandoc limits images to the text height, so a figure on a landscape page would fill
#' it completely and move on to the next page. Image files have an aspect ratio only if
#' their metadata gives width and height.
#' @param x a figure (plot object or image file path).
#' @param meta named `list` of the item's metadata.
#' @param ctx the render context.
#' @return `character(1)` width such as `"5.67in"`.
#' @noRd
.md_pdf_figure_width <- function(x, meta, ctx) {
    percent <- as.numeric(sub(
        "%",
        "",
        meta[["out_width"]] %||% "90%",
        fixed = TRUE
    ))
    orientation <- if (ctx$want_landscape) "landscape" else "portrait"
    area <- ctx$text_area[[orientation]]
    width <- area[["width"]] * percent / 100
    size <- c(meta[["width"]], meta[["height"]])
    if (!is.character(x)) {
        size <- c(
            meta[["width"]] %||% 8,
            meta[["height"]] %||% 6
        )
    }
    if (length(size) == 2L) {
        width <- min(width, 0.85 * area[["height"]] * size[[1L]] / size[[2L]])
    }
    sprintf("%.2fin", width / 72)
}

#' Text width (twips) of the pages the next content goes on
#' @param ctx the render context.
#' @noRd
.md_text_width <- function(ctx) {
    ctx$text_width[[if (ctx$want_landscape) "landscape" else "portrait"]]
}

#' Copy the figure's image file into the assets directory
#' @param x a figure (plot object or image file path).
#' @param meta named `list` of the item's metadata.
#' @param ctx the render context.
#' @return `character(1)` its path relative to the parent of the assets directory.
#' @noRd
.md_figure_asset <- function(x, meta, ctx) {
    res <- .figure_file(
        x,
        meta,
        ctx$spec$figure,
        ctx$cache,
        devices = .target_devices[[ctx$target]]
    )
    if (res$temporary) {
        on.exit(unlink(res$file), add = TRUE)
    }
    ctx$files <- ctx$files + 1L
    name <- sprintf("figure-%d.%s", ctx$files, tolower(tools::file_ext(res$file)))
    dest <- file.path(ctx$assets_dir, name)
    dir.create(ctx$assets_dir, recursive = TRUE, showWarnings = FALSE)
    # the figure files written there could overwrite an image file in the assets
    # directory, also one that a later figure reads
    if (
        is.character(x) &&
            identical(normalizePath(dirname(res$file)), normalizePath(ctx$assets_dir))
    ) {
        rlang::cnd_signal(.render_error(
            c(
                sprintf("Can't use the image file '%s'.", res$file),
                i = "`assets_dir` must not hold the image files of figures."
            ),
            format = ctx$target
        ))
    }
    copied <- .file_op(file.copy(res$file, dest, overwrite = TRUE))
    if (!copied$ok) {
        rlang::cnd_signal(.render_error(
            c(sprintf("Can't write the figure file '%s'.", dest), i = copied$reason),
            format = ctx$target
        ))
    }
    paste(basename(ctx$assets_dir), name, sep = "/")
}

#' Widget: its `fallback` figure, else nothing (with a warning)
#' @param x a `pub_item` of type `"widget"`.
#' @param ctx the render context.
#' @return `character` blocks or `NULL`.
#' @noRd
.md_widget <- function(x, ctx) {
    fallback <- x$meta[["fallback"]]
    label <- x$meta[["caption"]] %||% x$meta[["title"]]
    what <- if (is.null(label)) "A widget" else sprintf("Widget '%s'", label)
    if (is.null(fallback)) {
        rlang::warn(
            c(
                sprintf("%s has no `fallback` figure and is left out.", what),
                i = "Set its metadata `fallback` to a figure (`pub_meta()`)."
            ),
            class = "pubflow_render_warning"
        )
        return(NULL)
    }
    if (pub_type(fallback) != "figure") {
        rlang::cnd_signal(.render_error(
            sprintf(
                "%s: the `fallback` must be a figure, not <%s>.",
                what,
                paste(class(fallback), collapse = "/")
            ),
            format = ctx$target
        ))
    }
    meta <- x$meta[setdiff(names(x$meta), "fallback")]
    meta <- utils::modifyList(pub_meta(fallback), meta)
    # a widget is no target of cross-references
    meta[["id"]] <- NULL
    .md_figure(fallback, meta, ctx)
}

#' Content between raw lines of the target that centre it
#' @param content `character` blocks.
#' @param ctx the render context (LaTeX or Typst target).
#' @noRd
.md_centered <- function(content, ctx) {
    switch(
        ctx$target,
        latex = c(
            .md_raw_block("\\begingroup\\centering", "latex"),
            content,
            .md_raw_block("\\par\\endgroup", "latex")
        ),
        typst = c(
            .md_raw_block("#align(center)[", "typst"),
            content,
            .md_raw_block("]", "typst")
        )
    )
}


# ======================================================================================
# Markup
# ======================================================================================

# ------
# Breaks
# ------
#' Page break (Word, LaTeX, Typst; a weak one in Typst: none on an empty page)
#' @param ctx the render context.
#' @return `character(1)` raw block or `NULL` (Markdown target).
#' @noRd
.md_page_break <- function(ctx) {
    switch(
        ctx$target,
        docx = .md_raw_block(
            "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>",
            "openxml"
        ),
        latex = .md_raw_block("\\clearpage", "latex"),
        typst = .md_raw_block("#pagebreak(weak: true)", "typst")
    )
}

#' Break ending a part of the given orientation
#'
#' Word: a section break, whose page size, margins, header and footer are copied from
#' the reference document after pandoc (`.docx_complete_sections()`); LaTeX: the start
#' or end of a landscape environment (pdflscape); Typst: a page set rule.
#' @param ctx the render context.
#' @param landscape `TRUE` if the part that ends is landscape.
#' @return `character(1)` raw block or `NULL` (Markdown target).
#' @noRd
.md_section_break <- function(ctx, landscape) {
    switch(
        ctx$target,
        docx = {
            orient <- if (landscape) "<w:pgSz w:orient=\"landscape\"/>" else ""
            .md_raw_block(
                sprintf(
                    "<w:p><w:pPr><w:sectPr>%s</w:sectPr></w:pPr></w:p>",
                    orient
                ),
                "openxml"
            )
        },
        latex = .md_raw_block(
            if (landscape) "\\end{landscape}" else "\\begin{landscape}",
            "latex"
        ),
        typst = .md_raw_block(
            sprintf("#set page(flipped: %s)", if (landscape) "false" else "true"),
            "typst"
        )
    )
}


# --------------------
# Divs and raw content
# --------------------
#' Div with a Word style (pandoc resolves the name to the style's id)
#' @param style `character(1)` name of the Word style.
#' @param content `character(1)` Markdown content.
#' @noRd
.md_div <- function(style, content) {
    sprintf("::: {custom-style=\"%s\"}\n%s\n:::", style, content)
}

#' Raw block of a format: a fenced code block longer than any backtick run in the
#' content
#' @param content `character` lines.
#' @param format pandoc's raw format (e.g. `"openxml"`).
#' @noRd
.md_raw_block <- function(content, format) {
    fence <- strrep("`", max(3L, .longest_backtick_run(content) + 1L))
    paste(c(sprintf("%s{=%s}", fence, format), content, fence), collapse = "\n")
}

#' Raw inline content of a format
#' @param content `character(1)` content.
#' @param format pandoc's raw format (e.g. `"openxml"`).
#' @noRd
.md_raw_inline <- function(content, format) {
    ticks <- strrep("`", .longest_backtick_run(content) + 1L)
    sprintf("%s%s%s{=%s}", ticks, content, ticks, format)
}

#' Length of the longest run of backticks
#' @param x `character` strings.
#' @return `integer(1)`, 0 without backticks.
#' @noRd
.longest_backtick_run <- function(x) {
    runs <- unlist(regmatches(x, gregexpr("`+", x)))
    if (length(runs) == 0L) 0L else max(nchar(runs))
}


# ======================================================================================
# Pandoc runs
# ======================================================================================

# --------------
# Markdown files
# --------------
#' Render a document to Markdown in a work directory
#' @param doc a checked `pub_doc`.
#' @param settings settings of the target (`.render_settings()`).
#' @param cache a `pub_cache` or `NULL`.
#' @param work the work directory.
#' @param stem file name of the result without extension (figures go to
#'   `<stem>_files/`).
#' @param front nodes of the front matter or `NULL`.
#' @return path of the Markdown file.
#' @noRd
.render_md <- function(doc, settings, cache, work, stem, front) {
    output <- file.path(work, paste0(stem, ".md"))
    md <- .markdown_doc(
        doc,
        settings,
        file.path(work, paste0(stem, "_files")),
        cache,
        front
    )
    writeLines(enc2utf8(md), output, useBytes = TRUE)
    output
}


# ------
# pandoc
# ------
#' Document header as pandoc metadata (title block of the writers): only with a title,
#' subtitle or author
#' @param meta named `list` of document metadata.
#' @return named `list` of strings (empty without a title block).
#' @noRd
.pandoc_metadata <- function(meta) {
    if (!.has_title_block(meta)) {
        return(list())
    }
    time <- meta[["time"]]
    fields <- list(
        title = meta[["title"]],
        subtitle = meta[["subtitle"]],
        author = meta[["author"]],
        date = if (!is.null(time)) .format_utc(time)
    )
    fields[!vapply(fields, is.null, logical(1))]
}

#' Run pandoc with a defaults file
#'
#' @param defaults named list of pandoc options (strings, character vectors for lists, a
#'   named list for `metadata`; `NULL` entries are left out).
#' @param work the work directory (gets the defaults file).
#' @param format output format, for the error.
#' @param quiet `FALSE` to show pandoc's warnings as R warnings.
#' @param call the environment of the caller, for the error message.
#' @param args `character` further arguments (a spec's `pandoc_args`); they follow the
#'   defaults file, so they override it.
#' @return pandoc's messages, invisibly. A failure is a `pubflow_render_error` with
#'   pandoc's messages; with `quiet = FALSE` its warnings become R warnings.
#' @noRd
.run_pandoc <- function(defaults, work, format, quiet, call, args = character()) {
    pandoc <- .find_pandoc(call = call)
    file <- file.path(work, "pandoc-defaults.yaml")
    defaults <- defaults[!vapply(defaults, is.null, logical(1))]
    writeLines(enc2utf8(.yaml_lines(defaults)), file, useBytes = TRUE)
    out <- suppressWarnings(system2(
        pandoc,
        c("--defaults", shQuote(file), shQuote(args)),
        stdout = TRUE,
        stderr = TRUE
    ))
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        rlang::cnd_signal(.render_error(
            c(
                sprintf("pandoc failed (exit status %d):", status),
                rlang::set_names(out, rep("x", length(out)))
            ),
            format = format,
            call = call
        ))
    }
    if (!quiet && length(out) > 0L) {
        messages <- rlang::set_names(out, rep("!", length(out)))
        rlang::warn(c("pandoc reported:", messages), class = "pubflow_render_warning")
    }
    invisible(out)
}

#' YAML lines of a pandoc defaults file
#'
#' Options that pandoc reads as lists are written as lists; logical values are YAML
#' booleans.
#' @param x named `list` of options.
#' @param indent `character(1)` indent of nested options.
#' @return `character` lines.
#' @noRd
.yaml_lines <- function(x, indent = "") {
    lists <- c("input-files", "resource-path", "include-in-header")
    unlist(
        lapply(names(x), \(key) {
            value <- x[[key]]
            if (is.list(value)) {
                return(c(
                    paste0(indent, key, ":"),
                    .yaml_lines(value, paste0(indent, "  "))
                ))
            }
            if (rlang::is_bool(value)) {
                return(sprintf("%s%s: %s", indent, key, tolower(value)))
            }
            if (length(value) == 1L && !key %in% lists) {
                return(sprintf("%s%s: %s", indent, key, .yaml_string(value)))
            }
            c(paste0(indent, key, ":"), sprintf("%s- %s", indent, .yaml_string(value)))
        }),
        use.names = FALSE
    )
}
