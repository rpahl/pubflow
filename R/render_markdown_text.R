# Text on the Pandoc path. pubflow writes CommonMark that pandoc reads with a few
# extensions for its own markup (raw blocks, custom styles, math, image widths). Texts
# carry user input, so they are escaped to mean in pandoc what they mean in the HTML:
# raw HTML is escaped, and the extension syntax (`{` of attributes, raw attributes and
# spans; `:::` fences of divs) is backslash-escaped where commonmark's parser sees text.
# Math and placeholders are protected first, as for HTML. Strings that pubflow writes
# itself (titles, captions, error messages) are escaped as literal text.

# ------------
# Pandoc input
# ------------
#' Pandoc reader of the Markdown written by `pub_markdown()`
#'
#' LaTeX and Typst read images with a caption as figures (Word gets its captions as
#' styled paragraphs).
#' @param target `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @return `character(1)` pandoc's `--from` format.
#' @noRd
.pandoc_reader <- function(target = "docx") {
    paste0(
        "commonmark+raw_attribute+tex_math_dollars+bracketed_spans",
        "+fenced_divs+attributes",
        if (target %in% c("latex", "typst")) "+implicit_figures"
    )
}

#' Markdown text for a Pandoc target
#'
#' @param text `character(1)` Markdown (pubflow's subset).
#' @param target `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @param color placeholder colour (hex without `#`) for LaTeX and Typst.
#' @param ref converter of cross-references (`.ref_converter()`) or `NULL` (they stay
#'   text).
#' @return `character(1)` Markdown: raw HTML and extension syntax escaped, placeholders
#'   and references in the target's form.
#' @noRd
.markdown_pandoc <- function(text, target, color = "0083C0", ref = NULL) {
    store <- .token_store()
    convert <- c(.pandoc_converters(target, color), list(ref = ref))
    chunks <- .split_fenced_code(text)
    context <- .prose_context(chunks)
    for (i in seq_along(chunks)) {
        chunks[[i]] <- if (attr(chunks[[i]], "code")) {
            .drop_fence_attributes(chunks[[i]])
        } else {
            .protect_markdown(chunks[[i]], store, convert, context)
        }
    }
    markdown <- .escape_raw_html(paste(unlist(chunks), collapse = "\n"))
    .restore_tokens(.escape_extensions(markdown), store)
}

#' Converters of the protected parts: math stays as-is (pandoc reads `$`),
#' placeholders get the target's form (LaTeX and Typst: the escaped text between raw
#' opening and closing markup)
#' @param target `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @param color placeholder colour (hex without `#`) for LaTeX and Typst.
#' @return list of converters as `.protect_markdown()` takes them.
#' @noRd
.pandoc_converters <- function(target, color = "0083C0") {
    around <- function(open, close, format) {
        \(m) {
            paste0(
                .md_raw_inline(open, format),
                .escape_inline(.placeholder_text(m)),
                .md_raw_inline(close, format)
            )
        }
    }
    placeholder <- switch(
        target,
        docx = \(m) {
            sprintf(
                "[%s]{custom-style=\"Placeholder\"}",
                .escape_inline(.placeholder_text(m))
            )
        },
        latex = around(sprintf("\\textcolor[HTML]{%s}{", toupper(color)), "}", "latex"),
        typst = around(
            sprintf("#text(fill: rgb(\"#%s\"))[", tolower(color)),
            "]",
            "typst"
        ),
        identity
    )
    list(display_math = identity, inline_math = identity, placeholder = placeholder)
}

#' Keep only the language of a fenced code block's info string
#'
#' Pandoc reads `{=latex}` (raw content) and `{.class}` there.
#' @param chunk `character(1)` fenced code block (fences included).
#' @noRd
.drop_fence_attributes <- function(chunk) {
    sub(
        "^( {0,3}(`{3,}|~{3,}))[ \t]*([A-Za-z0-9_+.-]*)[^\n]*",
        "\\1\\3",
        chunk,
        perl = TRUE
    )
}


# --------
# Escaping
# --------
#' Backslash-escape extension syntax in the text of Markdown
#'
#' Finds the text nodes with commonmark's parser and escapes every opening brace in
#' them that isn't escaped yet and a `:::` at their start, so pandoc reads no
#' attributes, raw attributes, spans or divs there (code, links' targets and autolinks
#' are left alone). A backslash before a brace or a colon makes it a literal character
#' in CommonMark.
#' @param text `character(1)` Markdown without raw HTML.
#' @return `character(1)` the escaped Markdown.
#' @noRd
.escape_extensions <- function(text) {
    if (
        !grepl("{", text, fixed = TRUE) &&
            !grepl(":::", text, fixed = TRUE)
    ) {
        return(text)
    }
    nums <- .markdown_text_nodes(text)
    if (is.null(nums)) {
        return(text)
    }
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    for (i in unique(nums[, 1L])) {
        ranges <- nums[nums[, 1L] == i & nums[, 3L] == i, c(2L, 4L), drop = FALSE]
        lines[[i]] <- .escape_in_ranges(lines[[i]], ranges)
    }
    # strsplit() drops the last newline
    paste0(paste(lines, collapse = "\n"), if (endsWith(text, "\n")) "\n")
}

#' Source positions of the text nodes of Markdown (not those of autolinks)
#' @param text `character(1)` Markdown.
#' @return integer matrix with a row per node: first line and byte column, last line
#'   and byte column, and `1` if the node is in a link's text or an image's
#'   description (`0` otherwise); `NULL` without text nodes.
#' @noRd
.markdown_text_nodes <- function(text) {
    xml <- xml2::read_xml(commonmark::markdown_xml(text, sourcepos = TRUE))
    ns <- xml2::xml_ns(xml)
    nodes <- xml2::xml_find_all(
        xml,
        "//d1:text[not(ancestor::d1:link[starts-with(@destination, .)])]",
        ns
    )
    pos <- xml2::xml_attr(nodes, "sourcepos")
    nums <- regmatches(pos, regexec("^(\\d+):(\\d+)-(\\d+):(\\d+)$", pos))
    nums <- do.call(rbind, lapply(nums, \(m) as.integer(m[-1L])))
    if (is.null(nums)) {
        return(NULL)
    }
    inside <- function(parent) {
        query <- sprintf("boolean(ancestor::d1:%s)", parent)
        as.integer(xml2::xml_find_lgl(nodes, query, ns))
    }
    cbind(nums, link = inside("link"), image = inside("image"))
}

#' Insert backslashes before unescaped opening braces and a leading `:::` in byte
#' ranges of a line
#' @param line `character(1)` a line of Markdown.
#' @param ranges integer matrix of (first, last) byte columns.
#' @noRd
.escape_in_ranges <- function(line, ranges) {
    bytes <- charToRaw(line)
    at <- integer()
    for (k in seq_len(nrow(ranges))) {
        cols <- seq(ranges[k, 1L], min(ranges[k, 2L], length(bytes)))
        start <- ranges[k, 1L]
        braces <- cols[bytes[cols] == charToRaw("{")]
        escaped <- vapply(braces, \(i) .is_escaped(bytes, start, i), logical(1L))
        at <- c(at, braces[!escaped])
        fence <- start + 0:2
        if (
            all(fence <= length(bytes)) &&
                all(bytes[fence] == charToRaw(":"))
        ) {
            at <- c(at, start)
        }
    }
    if (length(at) == 0L) {
        return(line)
    }
    at <- sort(unique(at))
    pieces <- split(bytes, findInterval(seq_along(bytes), at))
    keys <- as.integer(names(pieces))
    out <- unlist(lapply(seq_along(pieces), \(k) {
        if (keys[[k]] > 0L) c(charToRaw("\\"), pieces[[k]]) else pieces[[k]]
    }))
    res <- rawToChar(out)
    Encoding(res) <- "UTF-8"
    res
}

#' Whether an odd number of backslashes (in the text from byte `start`) precedes byte
#' `i`, which makes it a literal character
#' @param bytes raw bytes of the line.
#' @param start first byte of the text.
#' @param i byte to check.
#' @noRd
.is_escaped <- function(bytes, start, i) {
    n <- 0L
    while (i - n - 1L >= start && bytes[[i - n - 1L]] == charToRaw("\\")) {
        n <- n + 1L
    }
    n %% 2L == 1L
}

#' Escape inline Markdown syntax (also Pandoc's: math, superscript, citations,
#' attributes)
#' @param x `character` text.
#' @noRd
.escape_inline <- function(x) {
    gsub("([][\\\\`*_<>&~#|$^@{}])", "\\\\\\1", x, perl = TRUE)
}

#' Markdown for a literal string on one line (titles, captions, messages)
#'
#' Whitespace runs (also line breaks) become one space; besides inline syntax, what
#' would start a block at the beginning of a line is escaped (list markers, block
#' quotes, setext underlines, `:::`).
#' @param x `character` literal strings.
#' @noRd
.escape_literal <- function(x) {
    x <- .escape_inline(.one_line(x))
    x <- sub("^([-+=>:])", "\\\\\\1", x, perl = TRUE)
    sub("^([0-9]+)([.)])", "\\1\\\\\\2", x, perl = TRUE)
}

#' A string on one line: whitespace runs (also line breaks) become one space
#' @param x `character` strings.
#' @noRd
.one_line <- function(x) {
    trimws(gsub("[[:space:]]+", " ", x, perl = TRUE))
}
