# Markdown text to HTML: CommonMark via commonmark, plus what CommonMark lacks: math
# (`$...$`, `$$...$$`, restored as `\(...\)` and `\[...\]` for MathJax) and placeholder
# spans (`[text]{.placeholder}`). Both are replaced by tokens before the conversion and
# restored after it (code spans and fenced code blocks are left alone, found by a simple
# scanner). Raw HTML is not part of pubflow's Markdown subset and is escaped, because
# texts carry user input (param values) and commonmark passes raw HTML through: the raw
# HTML nodes are found by commonmark's own parser, so escaping follows CommonMark
# exactly.

# ----------
# Conversion
# ----------
#' Character that delimits tokens (Unicode private use area: never part of real text,
#' kept by commonmark)
#' @noRd
.token_mark <- function() {
    intToUtf8(0xE000L)
}

#' Convert Markdown text to HTML
#'
#' @param text `character(1)` Markdown.
#' @param ref converter of cross-references (`.ref_converter()`) or `NULL` (they stay
#'   text).
#' @return `list(html = <character(1)>, math = <TRUE if math was found>)`.
#' @noRd
.markdown_html <- function(text, ref = NULL) {
    store <- .token_store()
    chunks <- .split_fenced_code(text)
    context <- .prose_context(chunks)
    for (i in seq_along(chunks)) {
        if (!attr(chunks[[i]], "code")) {
            chunks[[i]] <- .protect_markdown(
                chunks[[i]],
                store,
                c(.html_converters(), list(ref = ref)),
                context
            )
        }
    }
    markdown <- .escape_raw_html(paste(unlist(chunks), collapse = "\n"))
    html <- .restore_tokens(commonmark::markdown_html(markdown), store)
    list(html = html, math = any(names(store$tokens) == "math"))
}

#' Store for tokens (`tokens`, named by kind), their replacements (`html`) and the
#' source text they replace (`source`)
#' @noRd
.token_store <- function() {
    store <- new.env(parent = emptyenv())
    store$tokens <- character()
    store$html <- character()
    store$source <- character()
    store
}

#' Replace the tokens of a store by their replacements
#' @param text `character` with tokens.
#' @param store environment with `tokens`, `html` and `source` (see `.token_store()`).
#' @param field `"html"` (the replacements) or `"source"` (the source text).
#' @return `text` with the replacements.
#' @noRd
.restore_tokens <- function(text, store, field = "html") {
    for (i in seq_along(store$tokens)) {
        text <- sub(store$tokens[[i]], store[[field]][[i]], text, fixed = TRUE)
    }
    text
}

#' Converters of the protected parts to HTML
#' @noRd
.html_converters <- function() {
    list(
        display_math = \(m) .math_html(m, display = TRUE),
        inline_math = \(m) .math_html(m, display = FALSE),
        placeholder = .placeholder_html
    )
}


# -----------
# Fenced code
# -----------
#' Split Markdown into fenced code blocks and other text
#'
#' @param text `character(1)` Markdown.
#' @return `list` of `character(1)` chunks with attribute `code` (`TRUE` for a fenced
#'   code block, fences included).
#' @noRd
.split_fenced_code <- function(text) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    chunks <- list()
    current <- character()
    fence <- NULL
    for (line in lines) {
        # the info string of a backtick fence has no backticks (CommonMark)
        opening <- regmatches(
            line,
            regexpr("^ {0,3}(`{3,}(?=[^`]*$)|~{3,})", line, perl = TRUE)
        )
        if (is.null(fence) && length(opening) == 1L) {
            chunks <- .add_chunk(chunks, current, code = FALSE)
            fence <- trimws(opening)
            current <- line
        } else if (!is.null(fence)) {
            current <- c(current, line)
            closing <- paste0(
                "^ {0,3}",
                substr(fence, 1L, 1L),
                "{",
                nchar(fence),
                ",}\\s*$"
            )
            if (grepl(closing, line)) {
                chunks <- .add_chunk(chunks, current, code = TRUE)
                current <- character()
                fence <- NULL
            }
        } else {
            current <- c(current, line)
        }
    }
    .add_chunk(chunks, current, code = !is.null(fence))
}

#' The text of the chunks outside fenced code blocks, if there is fenced code
#'
#' Link reference definitions apply to the whole text, so a chunk is parsed with this
#' context after it.
#' @param chunks chunks from `.split_fenced_code()`.
#' @return `character(1)` or `NULL` (one chunk only).
#' @noRd
.prose_context <- function(chunks) {
    if (length(chunks) > 1L) {
        code <- vapply(chunks, attr, logical(1), "code")
        paste(unlist(chunks[!code]), collapse = "\n\n")
    }
}

#' Append lines as one chunk (nothing for no lines)
#' @param chunks `list` of chunks so far.
#' @param lines `character` lines of the new chunk.
#' @param code `TRUE` if the lines are a fenced code block.
#' @return `chunks`, extended.
#' @noRd
.add_chunk <- function(chunks, lines, code) {
    if (length(lines) == 0L) {
        return(chunks)
    }
    c(chunks, list(structure(paste(lines, collapse = "\n"), code = code)))
}


# ---------------
# Protected parts
# ---------------
#' Replace math, placeholders and cross-references by tokens, outside code spans
#' @param text `character(1)` Markdown without fenced code blocks.
#' @param store environment collecting the tokens and their replacements (see
#'   `.token_store()`).
#' @param convert `list` of functions `display_math`, `inline_math`, `placeholder` and
#'   (optional) `ref` giving the replacement of a match; without `ref` references stay
#'   text.
#' @param context `character(1)` the text around `text` without fenced code (its link
#'   reference definitions apply to `text`), or `NULL`.
#' @return `text` ready for commonmark.
#' @noRd
.protect_markdown <- function(text, store, convert, context = NULL) {
    code <- .token_store()
    # code spans: a run of backticks up to the next run of the same length
    text <- .tokenize(
        text,
        "(?<!`)(`+)(?!`)[\\s\\S]*?(?<!`)\\1(?!`)",
        "code",
        code,
        identity
    )
    # parts nested in a match (code in math, math or code in a placeholder) stay literal
    inner <- list(code, store)
    text <- .tokenize(
        text,
        "\\$\\$([\\s\\S]+?)\\$\\$",
        "math",
        store,
        convert$display_math,
        inner
    )
    # inline math as in Pandoc: no space after the opening and before the closing `$`,
    # which is not followed by a digit; `\$` is a dollar sign
    inlineMath <- paste0(
        "(?<![\\\\$])\\$(?![\\s$])", # opening `$`, not `\\$` or `$$`
        "((?:\\\\.|[^$\\\\\\n])+?)", # content, `\\$` allowed
        "(?<!\\s)\\$(?![$0-9])" # closing `$`
    )
    text <- .tokenize(text, inlineMath, "math", store, convert$inline_math, inner)
    text <- .tokenize(
        text,
        "\\[([^\\]\\n]*)\\]\\{\\.placeholder\\}",
        "placeholder",
        store,
        convert$placeholder,
        inner
    )
    text <- .protect_refs(text, store, convert$ref, context)
    .restore_tokens(text, code)
}

#' Replace the matches of a regular expression by tokens
#'
#' @param text `character(1)` Markdown.
#' @param pattern Perl regular expression.
#' @param kind name of the tokens (`"math"`, ...).
#' @param store environment with `tokens` (named by kind) and `html`.
#' @param convert `function(match)` returning the replacement of a token.
#' @param inner `list` of stores whose tokens in a match are put back to their source
#'   before `convert` sees it.
#' @return `text` with tokens.
#' @noRd
.tokenize <- function(text, pattern, kind, store, convert, inner = list()) {
    matches <- gregexpr(pattern, text, perl = TRUE)
    found <- regmatches(text, matches)[[1L]]
    if (length(found) == 0L) {
        return(text)
    }
    for (s in inner) {
        found <- .restore_tokens(found, s, "source")
    }
    ids <- length(store$tokens) + seq_along(found)
    tokens <- paste0(.token_mark(), kind, ids, .token_mark())
    store$tokens <- c(store$tokens, rlang::set_names(tokens, kind))
    store$html <- c(store$html, vapply(found, convert, character(1), USE.NAMES = FALSE))
    store$source <- c(store$source, found)
    regmatches(text, matches) <- list(tokens)
    text
}

#' MathJax markup for `$...$` or `$$...$$`
#'
#' In a span of class `pubflow-math`: the viewer hides it while MathJax typesets
#' (inst/www/pubflow-viewer.css).
#' @param match the math, delimiters included.
#' @param display `TRUE` for display math (`$$...$$`).
#' @return `character(1)` HTML.
#' @noRd
.math_html <- function(match, display) {
    delim <- if (display) 2L else 1L
    tex <- substr(match, delim + 1L, nchar(match) - delim)
    tex <- htmltools::htmlEscape(trimws(tex))
    if (display) {
        sprintf(
            paste0(
                "<span class=\"pubflow-math pubflow-math-display\">",
                "\\[%s\\]</span>"
            ),
            tex
        )
    } else {
        sprintf("<span class=\"pubflow-math\">\\(%s\\)</span>", tex)
    }
}

#' HTML span for `[text]{.placeholder}`
#' @param match the placeholder span.
#' @return `character(1)` HTML.
#' @noRd
.placeholder_html <- function(match) {
    sprintf(
        "<span class=\"pubflow-placeholder\">%s</span>",
        htmltools::htmlEscape(.placeholder_text(match))
    )
}

#' The text of a placeholder span `[text]{.placeholder}`
#' @param match the placeholder span.
#' @return `character(1)`, not escaped.
#' @noRd
.placeholder_text <- function(match) {
    # by position: a nested code span may hold `]`
    substr(match, 2L, nchar(match) - nchar("]{.placeholder}"))
}


# --------
# Raw HTML
# --------
#' Escape raw HTML as CommonMark sees it
#'
#' Replaces the `<` that starts each raw HTML node (inline HTML, HTML block) found by
#' commonmark's parser with `&lt;`, and parses again until none is left: the rest of an
#' escaped node may hold further HTML (e.g. `<a title="<b>">`). Code is never touched.
#' @param text `character(1)` Markdown.
#' @return `text` without raw HTML.
#' @noRd
.escape_raw_html <- function(text) {
    for (i in seq_len(lengths(gregexpr("<", text, fixed = TRUE)))) {
        if (!grepl("<", text, fixed = TRUE)) {
            break
        }
        starts <- .raw_html_starts(text)
        escaped <- .escape_starts(text, starts)
        if (nrow(starts) == 0L || identical(escaped, text)) {
            break
        }
        text <- escaped
    }
    text
}

#' Source positions (line, byte column) where raw HTML nodes start
#' @param text `character(1)` Markdown.
#' @return `data.frame(line, col)`.
#' @noRd
.raw_html_starts <- function(text) {
    xml <- xml2::read_xml(commonmark::markdown_xml(text, sourcepos = TRUE))
    nodes <- xml2::xml_find_all(
        xml,
        "//d1:html_inline | //d1:html_block",
        xml2::xml_ns(xml)
    )
    # "line:col-line:col"; only the start is reliable for the last block
    pos <- xml2::xml_attr(nodes, "sourcepos")
    data.frame(
        line = as.integer(sub(":.*", "", pos)),
        col = as.integer(sub("^[0-9]+:([0-9]+)-.*", "\\1", pos))
    )
}

#' Replace the first `<` at or after each start position by `&lt;`
#' @param text `character(1)` Markdown.
#' @param starts `data.frame(line, col)` from `.raw_html_starts()`.
#' @return `text`, escaped.
#' @noRd
.escape_starts <- function(text, starts) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    starts <- starts[order(starts$line, -starts$col), , drop = FALSE]
    for (k in seq_len(nrow(starts))) {
        i <- starts$line[[k]]
        bytes <- charToRaw(lines[[i]])
        hit <- which(bytes == charToRaw("<"))
        hit <- hit[hit >= starts$col[[k]]][1L]
        if (!is.na(hit)) {
            bytes <- c(
                bytes[seq_len(hit - 1L)],
                charToRaw("&lt;"),
                bytes[-seq_len(hit)]
            )
            lines[[i]] <- rawToChar(bytes)
            Encoding(lines[[i]]) <- "UTF-8"
        }
    }
    paste(lines, collapse = "\n")
}
