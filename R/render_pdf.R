# PDF files: pub_markdown() writes the Markdown and the figures into the work directory,
# then pandoc makes the PDF with xelatex (pandoc's LaTeX template, pubflow's header and
# the header and footer lines of the document), or pandoc writes Typst (pubflow's
# template) and typst makes the PDF. Math is TeX in LaTeX output, so formulas are
# checked with pandoc's math parser before they reach TeX.

# ======================================================================================
# PDF files
# ======================================================================================

# ------
# Render
# ------
#' Render a document to PDF in a work directory
#' @param doc a `pub_doc`.
#' @param settings settings of the target `"latex"` (xelatex) or `"typst"`
#'   (`.render_settings()`).
#' @param cache a `pub_cache` or `NULL`.
#' @param work path of the work directory.
#' @param quiet `TRUE` to hide pandoc's messages.
#' @param front nodes of the front matter or `NULL`.
#' @param call the call that errors name.
#' @return path of the PDF file.
#' @noRd
.render_pdf <- function(doc, settings, cache, work, quiet, front, call) {
    target <- settings$target
    input <- file.path(work, "document.md")
    md <- .markdown_doc(doc, settings, file.path(work, "document_files"), cache, front)
    writeLines(enc2utf8(md), input, useBytes = TRUE)
    output <- file.path(work, "document.pdf")
    if (target == "latex") {
        options <- .latex_options(doc$meta, settings, work, front)
    } else {
        # pandoc's own typst run refers to images by absolute paths, which typst looks
        # for inside its root directory
        typst <- file.path(work, "document.typ")
        options <- c(.typst_options(doc$meta, settings, work, front), standalone = TRUE)
    }
    .run_pandoc(
        c(
            list(
                from = .pandoc_reader(target),
                to = target,
                `input-files` = input,
                `output-file` = if (target == "latex") output else typst,
                `resource-path` = work
            ),
            options
        ),
        work,
        format = "pdf",
        quiet = quiet,
        call = call,
        args = settings$pandoc_args
    )
    if (target == "typst") {
        .run_typst(typst, output, work, call = call)
    }
    output
}

#' Compile a Typst file to PDF (typst may read files below `root` only)
#' @param input path of the Typst file.
#' @param output path of the PDF file.
#' @param root directory below which typst may read files.
#' @param call the call that errors name.
#' @return typst's output lines, invisibly.
#' @noRd
.run_typst <- function(input, output, root, call) {
    typst <- .find_typst(call = call)
    out <- suppressWarnings(system2(
        typst,
        c("compile", "--root", shQuote(root), shQuote(input), shQuote(output)),
        stdout = TRUE,
        stderr = TRUE
    ))
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        rlang::cnd_signal(.render_error(
            c(
                sprintf("typst failed (exit status %d):", status),
                rlang::set_names(out, rep("x", length(out)))
            ),
            format = "pdf",
            call = call
        ))
    }
    invisible(out)
}


# -----
# LaTeX
# -----
#' pandoc's options for PDF via xelatex
#'
#' The header lines of pubflow's header file come first, then those of the spec's
#' header, then the document's header and footer lines and the caption labels (written
#' into the work directory). Front matter replaces the title block: the title and author
#' then go into the PDF's properties only (`title-meta`, `author-meta`).
#' @param meta metadata of the document.
#' @param settings settings of the target `"latex"` (`.render_settings()`).
#' @param work path of the work directory.
#' @param front nodes of the front matter or `NULL`.
#' @return list of pandoc's options.
#' @noRd
.latex_options <- function(meta, settings, work, front) {
    headFoot <- file.path(work, "pubflow-head-foot.tex")
    writeLines(
        enc2utf8(.latex_head_foot(meta, settings$labels)),
        headFoot,
        useBytes = TRUE
    )
    page <- settings$page
    margins <- unlist(page[c("top", "bottom", "left", "right")])
    variables <- list(
        papersize = page$paper,
        geometry = c(
            sprintf("%s=%gcm", names(margins), margins),
            "headheight=14pt",
            if (page$turn) "landscape"
        ),
        `block-headings` = TRUE
    )
    if (!is.null(front)) {
        variables[["title-meta"]] <- .latex_meta_text(meta[["title"]])
        variables[["author-meta"]] <- .latex_meta_text(meta[["author"]])
    }
    list(
        `pdf-engine` = "xelatex",
        `number-sections` = settings$number_sections,
        `include-in-header` = c(settings$latex_preamble, headFoot),
        variables = variables,
        metadata = if (is.null(front)) .pandoc_metadata(meta)
    )
}

#' Text of a PDF property (hyperref's `pdftitle`), escaped, on one line
#' @param x `character` text or `NULL`.
#' @return `character` LaTeX text or `NULL`.
#' @noRd
.latex_meta_text <- function(x) {
    if (is.null(x)) NULL else .latex_text(.one_line(x))
}

#' fancyhdr lines for the header and footer of the document (`header`, `footer` in its
#' metadata; `{trace}` expanded), escaped, and the caption labels
#'
#' pubflow's header file sets the default: the page number ("Page x / N") at the right
#' of the footer. The labels are set at the start of the document, after babel or
#' polyglossia have set theirs.
#' @param meta metadata of the document.
#' @param labels `list(table, figure)` words of the captions.
#' @noRd
.latex_head_foot <- function(meta, labels) {
    lines <- character()
    for (part in c("header", "footer")) {
        values <- .expand_trace(meta[[part]], meta, format = "pdf")
        command <- if (part == "header") "fancyhead" else "fancyfoot"
        where <- c(left = "L", center = "C", right = "R")[names(values)]
        lines <- c(
            lines,
            sprintf("\\%s[%s]{%s}", command, where, .latex_text(.one_line(values)))
        )
    }
    c(
        "% header and footer of the document",
        lines,
        "% caption labels",
        sprintf(
            paste0(
                "\\AtBeginDocument{\\renewcommand{\\tablename}{%s}",
                "\\renewcommand{\\figurename}{%s}}"
            ),
            .latex_text(labels$table),
            .latex_text(labels$figure)
        )
    )
}


# -----
# Typst
# -----
#' pandoc's options for Typst
#'
#' A header file written into the work directory turns a landscape document and sets the
#' caption labels. Front matter replaces the title block (variable `title-block`); the
#' title and author stay in the PDF's properties.
#' @param meta metadata of the document.
#' @param settings settings of the target `"typst"` (`.render_settings()`).
#' @param work path of the work directory.
#' @param front nodes of the front matter or `NULL`.
#' @return list of pandoc's options.
#' @noRd
.typst_options <- function(meta, settings, work, front) {
    page <- settings$page
    margins <- page[c("top", "bottom", "left", "right")]
    head <- file.path(work, "pubflow-head.typ")
    writeLines(enc2utf8(.typst_head(settings)), head, useBytes = TRUE)
    list(
        template = settings$typst_template,
        `include-in-header` = head,
        variables = list(
            papersize = if (page$paper == "letter") {
                "us-letter"
            } else {
                page$paper
            },
            margin = lapply(margins, \(x) sprintf("%gcm", x)),
            `title-block` = is.null(front)
        ),
        metadata = c(.pandoc_metadata(meta), .typst_head_foot(meta))
    )
}

#' Typst lines before the document: page orientation and caption labels (supplements of
#' table and image figures)
#' @param settings settings of the target `"typst"` (`.render_settings()`).
#' @noRd
.typst_head <- function(settings) {
    supplement <- "#show figure.where(kind: %s): set figure(supplement: [%s])"
    c(
        "// pubflow: page orientation and caption labels",
        if (settings$page$turn) "#set page(flipped: true)",
        sprintf(supplement, "table", .typst_text(settings$labels$table)),
        sprintf(supplement, "image", .typst_text(settings$labels$figure))
    )
}

#' Header and footer of the document as metadata of pubflow's Typst template
#' (`header-left`, ..., `footer-right`; pandoc escapes them; `{trace}` expanded)
#'
#' pandoc's templates treat an empty string as unset, so an empty part is also passed as
#' `<part>-<side>-empty = TRUE`: an empty right footer removes the page number, as in
#' LaTeX and DOCX.
#' @param meta metadata of the document.
#' @return named list of metadata fields.
#' @noRd
.typst_head_foot <- function(meta) {
    fields <- list()
    for (part in intersect(c("header", "footer"), names(meta))) {
        values <- .expand_trace(meta[[part]], meta, format = "pdf")
        values <- rlang::set_names(
            .one_line(values),
            paste(part, names(values), sep = "-")
        )
        empty <- values[!nzchar(values)]
        fields <- c(
            fields,
            as.list(values),
            rlang::set_names(
                as.list(rep(TRUE, length(empty))),
                paste0(names(empty), "-empty")
            )
        )
    }
    fields
}


# ======================================================================================
# Page and math
# ======================================================================================

# ----------
# Text width
# ----------
#' Text width (pt) of portrait and landscape pages in LaTeX
#' @param page page settings (`width`, `height` and margins in cm).
#' @return `c(portrait, landscape)` widths.
#' @noRd
.latex_text_width <- function(page) {
    vapply(.pdf_text_area(page, "latex"), \(x) x[["width"]], numeric(1))
}

#' Text area (pt) of portrait and landscape pages
#'
#' LaTeX's pdflscape turns the portrait text area; Typst turns the page and keeps its
#' margins.
#' @param page page settings (`width`, `height` and margins in cm).
#' @param target `"latex"` or `"typst"`.
#' @return `list(portrait, landscape)` of `c(width, height)`.
#' @noRd
.pdf_text_area <- function(page, target) {
    pt <- 72 / 2.54
    width <- (page$width - page$left - page$right) * pt
    height <- (page$height - page$top - page$bottom) * pt
    landscape <- if (target == "latex") {
        c(width = height, height = width)
    } else {
        c(
            width = (page$height - page$left - page$right) * pt,
            height = (page$width - page$top - page$bottom) * pt
        )
    }
    list(portrait = c(width = width, height = height), landscape = landscape)
}


# ----
# Math
# ----
#' Check the math of Markdown for LaTeX output
#'
#' Math becomes TeX in LaTeX, and TeX commands can read files on the server (`\input`).
#' pandoc's math parser (texmath, which also makes the Word equations) must read every
#' formula; it rejects commands it doesn't know, also in arguments (colours, dimensions,
#' labels), so only math commands reach TeX. Macro definitions, which it accepts and
#' expands but TeX would run, and TeX's `^^` notation are refused as well. One pandoc
#' run reads the Markdown as the PDF run does and writes HTML with MathML: formulas it
#' can't parse are left as text there.
#' @param md `character(1)` Markdown for the LaTeX target.
#' @return `md`, invisibly; a `pubflow_render_error` naming the formulas.
#' @noRd
.check_latex_math <- function(md) {
    if (!grepl("$", md, fixed = TRUE)) {
        return(invisible(md))
    }
    work <- tempfile("pubflow-math-")
    dir.create(work)
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    input <- file.path(work, "math.md")
    output <- file.path(work, "math.html")
    writeLines(enc2utf8(md), input, useBytes = TRUE)
    .run_pandoc(
        list(
            from = .pandoc_reader("latex"),
            to = "html",
            `input-files` = input,
            `output-file` = output,
            `html-math-method` = list(method = "mathml")
        ),
        work,
        format = "latex",
        quiet = TRUE,
        call = NULL
    )
    html <- xml2::read_html(output, encoding = "UTF-8")
    failed <- xml2::xml_text(xml2::xml_find_all(
        html,
        "//span[contains(concat(' ', @class, ' '), ' math ')]"
    ))
    parsed <- xml2::xml_text(xml2::xml_find_all(
        html,
        paste0(
            "//*[local-name() = 'annotation']",
            "[@encoding = 'application/x-tex']"
        )
    ))
    defines <- parsed[grepl(.tex_definitions, parsed, perl = TRUE)]
    bad <- .one_line(c(failed, defines))
    if (length(bad) == 0L) {
        return(invisible(md))
    }
    bad <- ifelse(nchar(bad) > 60L, paste0(substr(bad, 1L, 57L), "..."), bad)
    rlang::cnd_signal(.render_error(
        c(
            "Can't use this math in PDF output via LaTeX:",
            rlang::set_names(bad, rep("x", length(bad))),
            i = paste(
                "Formulas must be math that pandoc can read (as for Word)",
                "and must not define macros."
            )
        ),
        format = "latex"
    ))
}

#' TeX that defines macros, or uses TeX's `^^` notation
#' @noRd
.tex_definitions <- paste0(
    "\\^\\^|\\\\(?:(?:re)?newcommand|providecommand|(?:re)?newenvironment|",
    "DeclareMathOperator|[gex]?def|let|futurelet|csname)(?![A-Za-z])"
)
