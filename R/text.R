# Text: character outputs are Markdown in a supported subset, without headings (document
# structure comes from sections).

# -----------
# Text output
# -----------
#' Text output
#'
#' Joins lines into one Markdown text and checks that it has no headings (use sections
#' for structure). Steps may also return plain character vectors, which the document
#' builder checks in the same way.
#'
#' @details
#' ## Supported Markdown
#'
#' The same in HTML, DOCX and PDF:
#'
#' | Markdown | Result |
#' |---|---|
#' | blank line | new paragraph |
#' | `*italic*`, `**bold**`, `` `code` `` | emphasis and code |
#' | `[link](url)` | link |
#' | `- item`, `1. item` | bullet and numbered lists |
#' | backslash at the end of a line | line break |
#' | `$...$`, `$$...$$` (on its own lines) | inline and display math |
#' | fenced code block | code block |
#' | `[<insert value>]{.placeholder}` | highlighted text to fill in |
#'
#' A placeholder marks a gap that someone fills in by hand later, e.g. in the Word
#' report. It is highlighted in every format, so it is not overlooked.
#'
#' ## Cross-references
#'
#' `@fig:<id>` and `@tab:<id>` refer to the figure or table with that `id` (see
#' [pub_meta()] and [pub_figure()]) and become a link "Figure 1" or "Table 2". The word
#' is set by `labels` in the report spec. In Word they are cross-reference fields.
#'
#' * The figure or table needs a caption (only captions are numbered) and its `id` must
#'   be unique in the document.
#' * References in code, math, placeholders, links and image descriptions stay text, as
#'   do `\@fig:x` and `a@fig:x`.
#' * A reference that can't be resolved is an error in [pub_render()] and
#'   [pub_markdown()]. [pub_html()] and the viewer warn and mark it, so a draft still
#'   displays.
#'
#' @param x Character vector of lines.
#' @param title `character(1)` heading line shown above the text (not a section) or
#'   `NULL` (as is a blank string).
#' @return `character(1)` with metadata (see [pub_meta()]).
#' @seealso [pub_md_escape()] for data in the text, [pub_meta()], [pub_type()]
#' @examples
#' txt <- pub_text(
#'     c(
#'         "The mean difference is **2.5 units** ($p = 0.03$).",
#'         "",
#'         "- group A",
#'         "- group B",
#'         "",
#'         "See [<insert link>]{.placeholder} and @fig:trend."
#'     ),
#'     title = "Summary"
#' )
#' writeLines(txt)
#' pub_meta(txt)
#'
#' # Display math, numbered list and code block
#' writeLines(pub_text(c(
#'     "The fitted model is",
#'     "",
#'     "$$",
#'     "y = a + b x",
#'     "$$",
#'     "",
#'     "1. fit the model",
#'     "2. check the residuals",
#'     "",
#'     "```",
#'     "lm(y ~ x)",
#'     "```"
#' )))
#'
#' try(pub_text(c("# Results", "Text")))
#' @export
pub_text <- function(x, title = NULL) {
    if (!is.character(x) || anyNA(x)) {
        rlang::abort("`x` must be a character vector without `NA`.")
    }
    if (!is.null(title) && !rlang::is_string(title)) {
        rlang::abort("`title` must be a single string or `NULL`.")
    }
    meta <- pub_meta(x)
    text <- .join_lines(x)
    .check_markdown(text)
    if (!is.null(title) && !grepl("[^[:space:]]", title)) {
        title <- NULL
    }
    meta[["title"]] <- title %||% meta[["title"]]
    pub_meta(text) <- meta
    text
}

#' Check Markdown text: no headings
#'
#' Uses the CommonMark parser, so lines in code blocks are ignored and setext headings
#' (text underlined with `===` or `---`) are found as well.
#' @param text `character(1)`.
#' @param what description of the text for the message.
#' @param call the environment shown as the caller in the error.
#' @return `text`, invisibly; signals an error for headings.
#' @noRd
.check_markdown <- function(text, what = "Text", call = rlang::caller_env()) {
    xml <- xml2::read_xml(commonmark::markdown_xml(text, sourcepos = TRUE))
    headings <- xml2::xml_find_all(xml, "//d1:heading", xml2::xml_ns(xml))
    if (length(headings) == 0L) {
        return(invisible(text))
    }
    pos <- xml2::xml_attr(headings, "sourcepos")
    lineNo <- as.integer(sub(":.*", "", pos))
    # the line endings of CommonMark
    lines <- strsplit(text, "\r\n|\r|\n")[[1L]]
    rlang::abort(
        c(
            sprintf("%s must not contain headings (use sections):", what),
            rlang::set_names(
                sprintf("line %d: \"%s\"", lineNo, lines[lineNo]),
                "x"
            )
        ),
        call = call
    )
}

# --------
# Escaping
# --------
#' Escape text for Markdown
#'
#' Escapes text so that it shows as it is in a [pub_text()] or a Markdown table cell,
#' e.g. a name, a label or a model formula from data. Without escaping, a label
#' `*new*` would come out in italics, the formula `airquality$Ozone ~ airquality$Temp`
#' partly as math, and a line starting with `1.` as a numbered list.
#'
#' Every character with a meaning in pubflow's Markdown gets a backslash: the inline
#' syntax (emphasis, code, links, math, superscript, cross-references, raw HTML) and
#' what starts a block at the beginning of a line (lists, quotes). The text comes out
#' on one line: line breaks and other runs of whitespace become one space. For several
#' lines, escape each line and join them with `"  \n"` (a line break) or `"\n\n"` (a
#' new paragraph).
#'
#' @param x Character vector or factor of plain text.
#' @return `x` as Markdown, a character vector of the same length; `NA` stays `NA`.
#' @seealso [pub_text()]
#' @examples
#' model <- "airquality$Ozone ~ airquality$Temp"
#' txt <- pub_text(paste("The model", pub_md_escape(model), "fits the data well."))
#' writeLines(txt)
#'
#' # several lines: escape each, then join
#' address <- c("1. Main Street", "<Building B>")
#' writeLines(paste(pub_md_escape(address), collapse = "  \n"))
#' @export
pub_md_escape <- function(x) {
    if (!is.character(x) && !is.factor(x)) {
        rlang::abort("`x` must be a character vector or a factor.")
    }
    x <- .escape_inline(gsub("[[:space:]]+", " ", x, perl = TRUE))
    # block starts: quotes and `:::` always; list markers before a space or the end;
    # `---` and `===` (thematic breaks, setext underlines)
    x <- sub("^( ?)([>:]|([-+=])(?=\\s|$|\\3))", "\\1\\\\\\2", x, perl = TRUE)
    sub("^( ?[0-9]+)([.)])(?=\\s|$)", "\\1\\\\\\2", x, perl = TRUE)
}
