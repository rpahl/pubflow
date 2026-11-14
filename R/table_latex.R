# LaTeX and Typst tables: huxtable's to_latex() and to_typst() of the display table
# (cell text from the common formatter). Every table may break across pages between rows
# and repeats its header rows (huxtable's breakable(): a LaTeX longtable, a breakable
# Typst figure), so a long table neither floats away from its place nor loses rows at
# the bottom of a page. Typst sizes `auto` columns by their content; LaTeX has no
# automatic table layout (huxtable writes `l` columns without a table width, and wide
# tables run off the page), so pubflow sizes the columns from the cell texts the way a
# browser does and passes the widths to huxtable, whose columns then wrap (`p{}`).

# ======================================================================================
# LaTeX and Typst tables
# ======================================================================================

# -----
# LaTeX
# -----
#' LaTeX of a table
#'
#' @param x a huxtable.
#' @param caption `character(1)` caption or `NULL`.
#' @param font_size font size (pt) for all cells, or `NULL` (the table's).
#' @param text_width width (pt) of the text on the pages the table goes on.
#' @param unit_width width (pt) of LaTeX's `\textwidth`: the portrait text width, which
#'   pdflscape keeps on landscape pages.
#' @param label `\label` of a captioned table (target of cross-references) or `NULL`.
#' @return `character(1)` LaTeX.
#' @noRd
.table_latex <- function(
    x,
    caption,
    font_size,
    text_width,
    unit_width,
    label = NULL
) {
    ht <- .pdf_huxtable(x, font_size)
    ht <- .latex_widths(ht, text_width, unit_width)
    ht <- .unmerge_rows(.escape_cells(ht, .latex_text))
    # huxtable's top and bottom are the other way round in wrapping cells (\parbox[b]
    # for top); merged cells (\multirow) are right
    valign <- huxtable::valign(ht)
    single <- huxtable::rowspan(ht) == 1L
    valign[single] <- c(top = "bottom", bottom = "top", middle = "middle")[valign[
        single
    ]]
    huxtable::valign(ht) <- valign
    if (!is.null(caption)) {
        # huxtable writes the caption as-is
        huxtable::caption(ht) <- .latex_text(.one_line(caption))
    }
    if (!is.null(label)) {
        huxtable::label(ht) <- label
    }
    # huxtable sets \tabcolsep for the rest of the document, and a longtable counts as a
    # table even without caption
    paste0(
        "\\begingroup\n",
        if (is.null(caption)) "\\def\\LTcaptype{none}\n",
        huxtable::to_latex(ht),
        "\n\\endgroup"
    )
}

#' Merged body cells of a LaTeX table as their first row
#'
#' huxtable draws the text of a cell merged across rows from its last row upwards
#' (`\multirow{-n}`), so after a page break inside it the text would cover the repeated
#' header rows. As in Word, the text goes into the first row instead and the other rows
#' stay empty (same background, no borders between them), so a page break leaves it
#' where the cell starts. Merged cells in the leading header rows (repeated on every
#' page, never broken) stay merged.
#' @param ht a huxtable with escaped cell text.
#' @return `ht` without body cells merged across rows.
#' @noRd
.unmerge_rows <- function(ht) {
    rowspan <- huxtable::rowspan(ht)
    colspan <- huxtable::colspan(ht)
    n <- nrow(ht)
    nHeader <- sum(cumprod(unname(huxtable::header_rows(ht))))
    for (k in which(rowspan > 1L)) {
        i <- (k - 1L) %% n + 1L
        if (i <= nHeader) {
            next
        }
        j <- (k - 1L) %/% n + 1L
        rows <- i + seq_len(rowspan[[k]] - 1L)
        cols <- j - 1L + seq_len(colspan[[k]])
        huxtable::rowspan(ht)[i, j] <- 1L
        huxtable::colspan(ht)[rows, j] <- colspan[[k]]
        for (col in cols) {
            ht[[col]][rows] <- ""
        }
        huxtable::background_color(ht)[rows, cols] <-
            huxtable::background_color(ht)[i, j]
        huxtable::top_border(ht)[rows, cols] <- 0
        huxtable::bottom_border(ht)[c(i, rows)[-length(rows) - 1L], cols] <- 0
    }
    ht
}


# -----
# Typst
# -----
#' Typst of a table
#'
#' huxtable writes every table as a figure, which Typst numbers; a table without caption
#' gets no number. The caption is pubflow's: huxtable puts its caption into a block (a
#' line break after "Table 1:") and leaves quotes and dots unescaped. It writes the
#' figure's caption after the table, so the last `caption: none` is the figure's (a cell
#' may contain the same text).
#' @param x a huxtable.
#' @param caption `character(1)` caption or `NULL`.
#' @param font_size font size (pt) for all cells, or `NULL` (the table's).
#' @param label label of a captioned table (target of cross-references) or `NULL`.
#' @return `character(1)` Typst.
#' @noRd
.table_typst <- function(x, caption, font_size, label = NULL) {
    ht <- .pdf_huxtable(x, font_size)
    if (!is.null(label)) {
        huxtable::label(ht) <- label
    }
    huxtable::col_width(ht) <- .typst_widths(huxtable::col_width(ht))
    ht <- .typst_markdown_cells(.escape_cells(ht, .typst_text))
    typst <- huxtable::to_typst(ht)
    if (is.null(caption)) {
        return(paste("#[", "#set figure(numbering: none)", typst, "]", sep = "\n"))
    }
    none <- "caption: none"
    at <- max(gregexpr(none, typst, fixed = TRUE)[[1L]])
    paste0(
        substr(typst, 1L, at - 1L),
        "caption: [",
        .typst_text(.one_line(caption)),
        "]",
        substr(typst, at + nchar(none), nchar(typst))
    )
}


# -----
# Cells
# -----
#' Display table for LaTeX and Typst: breakable, without caption
#'
#' Breakable tables can't have a fixed height or text wrapped around them.
#' @param x a huxtable.
#' @param font_size font size (pt) for all cells, or `NULL` (the table's).
#' @return huxtable with the cell text as displayed.
#' @noRd
.pdf_huxtable <- function(x, font_size) {
    ht <- .display_huxtable(x)
    huxtable::caption(ht) <- NA
    if (!is.null(font_size)) {
        huxtable::font_size(ht) <- font_size
    }
    huxtable::height(ht) <- NA_real_
    position <- huxtable::position(ht)
    if (position %in% c("wrapleft", "wrapright")) {
        huxtable::position(ht) <- sub("^wrap", "", position)
    }
    huxtable::breakable(ht) <- TRUE
    ht
}

#' Escape the text cells of a table for a target (huxtable leaves characters that the
#' target shows differently, e.g. quotes)
#' @param ht a huxtable.
#' @param escape function escaping strings.
#' @return `ht` with its non-markdown cells escaped and `escape_contents()` off.
#' @noRd
.escape_cells <- function(ht, escape) {
    plain <- !huxtable::markdown(ht)
    for (j in seq_len(ncol(ht))) {
        rows <- plain[, j]
        ht[[j]][rows] <- escape(ht[[j]][rows])
    }
    huxtable::escape_contents(ht) <- FALSE
    ht
}

#' LaTeX for literal text
#'
#' Besides TeX's special characters, the characters that xelatex's fonts turn into other
#' ones (TeX ligatures: `"` and `'` become curly quotes, `--` a dash, `,,` a low quote)
#' are written so that they show as they are, as in Word and HTML. Line breaks become
#' `\newline`.
#' @param x character vector.
#' @return `x` escaped.
#' @noRd
.latex_text <- function(x) {
    mark <- intToUtf8(0xE001L)
    x <- gsub("\\", mark, x, fixed = TRUE)
    special <- c(
        "{" = "\\{",
        "}" = "\\}",
        "$" = "\\$",
        "&" = "\\&",
        "%" = "\\%",
        "#" = "\\#",
        "_" = "\\_",
        "^" = "\\textasciicircum{}",
        "~" = "\\textasciitilde{}",
        "<" = "\\textless{}",
        ">" = "\\textgreater{}",
        "|" = "\\textbar{}",
        "\"" = "\\textquotedbl{}",
        "'" = "\\textquotesingle{}",
        "`" = "\\textasciigrave{}",
        "\n" = "\\newline "
    )
    for (char in names(special)) {
        x <- gsub(char, special[[char]], x, fixed = TRUE)
    }
    x <- gsub(mark, "\\textbackslash{}", x, fixed = TRUE)
    x <- gsub("([-,])(?=\\1)", "\\1{}", x, perl = TRUE)
    gsub("([!?])(?=\\\\textasciigrave)", "\\1{}", x, perl = TRUE)
}

#' Typst markup for literal text
#'
#' Escapes what Typst's markup reads as syntax or shorthand: also quotes (made curly),
#' `~` (a non-breaking space), `--` (a dash) and dots (`...` is an ellipsis, `1.` at the
#' start of a line a list).
#' @param x character vector.
#' @return `x` escaped.
#' @noRd
.typst_text <- function(x) {
    gsub("([\\\\#*$_`<>=@+/~\"'.\\[\\]-])", "\\\\\\1", x, perl = TRUE)
}

#' Markdown cells as Typst markup
#'
#' huxtable's Typst writer leaves the text of Markdown cells unescaped, so `$` or `#`
#' in it break the document. pubflow writes these cells itself, with the Markdown the
#' Word writer supports (see `.cell_markdown_blocks()`).
#' @param ht a huxtable with `escape_contents()` off.
#' @return `ht` with Typst markup in its Markdown cells, which are no longer Markdown.
#' @noRd
.typst_markdown_cells <- function(ht) {
    isMarkdown <- huxtable::markdown(ht)
    for (j in which(colSums(isMarkdown) > 0L)) {
        rows <- which(isMarkdown[, j])
        ht[[j]][rows] <- mapply(
            \(text, i) .typst_markdown(text, c(i, j)),
            ht[[j]][rows],
            rows,
            USE.NAMES = FALSE
        )
    }
    huxtable::markdown(ht) <- FALSE
    ht
}

#' Typst markup of the Markdown of one cell
#' @param text `character(1)`: the Markdown of the cell.
#' @param cell `integer(2)`: row and column of the cell, for errors.
#' @noRd
.typst_markdown <- function(text, cell) {
    if (is.na(text)) {
        return(text)
    }
    paras <- vapply(
        .cell_markdown_blocks(text, cell, "typst"),
        \(block) .typst_inlines(block, cell),
        character(1)
    )
    paste(paras, collapse = "\n\n")
}

#' Typst markup of the inline nodes below `node`
#'
#' Functions end with `;`, so that the text after them doesn't continue the call.
#' @param node a commonmark XML node.
#' @param cell `integer(2)`: row and column of the cell, for errors.
#' @noRd
.typst_inlines <- function(node, cell) {
    parts <- lapply(xml2::xml_children(node), \(x) {
        name <- xml2::xml_name(x)
        fun <- c(strong = "strong", emph = "emph", strikethrough = "strike")[name]
        if (!is.na(fun)) {
            return(sprintf("#%s[%s];", fun, .typst_inlines(x, cell)))
        }
        switch(
            name,
            text = .typst_text(xml2::xml_text(x)),
            softbreak = " ",
            linebreak = "#linebreak();",
            .cell_markdown_error(name, cell, "typst")
        )
    })
    paste(unlist(parts), collapse = "")
}


# ======================================================================================
# Column widths
# ======================================================================================

# -----
# Typst
# -----
#' Column widths for Typst: `"<n>cm"` as is, numbers as shares (`fr`) of the rest, other
#' columns one share each (as in DOCX); without widths all columns `auto` (sized by
#' their content)
#' @param value `huxtable::col_width()` of a table.
#' @return character vector of Typst column widths.
#' @noRd
.typst_widths <- function(value) {
    w <- .width_kinds(value)
    if (all(w$auto)) {
        return(rep("auto", length(w$value)))
    }
    ifelse(w$cm, w$value, paste0(w$share, "fr"))
}


# -----
# LaTeX
# -----
#' Column widths of a LaTeX table
#'
#' Given widths stay: `"<n>cm"` is fixed, numbers are shares of the rest of the table
#' width (`huxtable::width()`, else the text width), and automatic columns among them
#' count as one share each (as in Word). A table without widths is laid out like an
#' automatic table in a browser: it keeps its natural width (huxtable's columns without
#' width) if every cell fits on one line; otherwise each column gets at least its
#' longest word and a part of the rest in proportion to how much more its content needs,
#' and the text wraps. If even the longest words don't fit, the columns keep those
#' proportions and the table is shrunk to the width: its font size and padding are
#' scaled down (a longtable can't be scaled as a box).
#' @param ht a huxtable with the cell text as displayed.
#' @param text_width width (pt) of the text on the pages the table goes on.
#' @param unit_width width (pt) of LaTeX's `\textwidth`.
#' @return `ht` with `width()` (a fraction of `\textwidth`) and `col_width()`
#'   (proportions), or without widths (natural width).
#' @noRd
.latex_widths <- function(ht, text_width, unit_width) {
    w <- .width_kinds(huxtable::col_width(ht))
    total <- .table_width(huxtable::width(ht), text_width, per_cm = 72 / 2.54)
    if (all(w$auto)) {
        ext <- .column_extents(ht)
        if (sum(ext$max) <= total) {
            huxtable::width(ht) <- NA_real_
            huxtable::col_width(ht) <- NA_real_
            return(ht)
        }
        if (sum(ext$min) > total) {
            ht <- .shrink_table(ht, total / sum(ext$min))
            widths <- ext$min
        } else {
            extra <- ext$max - ext$min
            widths <- ext$min + (total - sum(ext$min)) * extra / sum(extra)
        }
        widths <- widths * total / sum(widths)
    } else {
        widths <- numeric(length(w$value))
        widths[w$cm] <- w$size[w$cm] * 72 / 2.54
        widths <- .share_widths(widths, w$share, w$cm, total, per_cm = 72 / 2.54)
    }
    huxtable::width(ht) <- signif(sum(widths) / unit_width, 6)
    huxtable::col_width(ht) <- signif(widths / sum(widths), 6)
    ht
}

#' Scale the font size and padding of a table
#' @param ht a huxtable.
#' @param scale factor (< 1 to shrink).
#' @return `ht` with font sizes and paddings scaled.
#' @noRd
.shrink_table <- function(ht, scale) {
    size <- huxtable::font_size(ht)
    size[is.na(size)] <- .latex_font_size
    huxtable::font_size(ht) <- signif(size * scale, 4)
    huxtable::left_padding(ht) <- .padding(huxtable::left_padding(ht)) * scale
    huxtable::right_padding(ht) <-
        .padding(huxtable::right_padding(ht)) * scale
    huxtable::top_padding(ht) <- .padding(huxtable::top_padding(ht)) * scale
    huxtable::bottom_padding(ht) <-
        .padding(huxtable::bottom_padding(ht)) * scale
    ht
}

#' Font size (pt) of cells without one (pandoc's LaTeX documents: 10pt)
#' @noRd
.latex_font_size <- 10

#' Padding in pt (huxtable's default for other values)
#' @param x matrix of paddings (e.g. `huxtable::left_padding()`).
#' @return numeric matrix of the same shape.
#' @noRd
.padding <- function(x) {
    res <- suppressWarnings(as.numeric(x))
    res[!is.finite(res)] <- 6
    matrix(res, nrow(x), ncol(x))
}


# ------------
# Text extents
# ------------
#' Narrowest and natural width (pt) of each column, from the cell texts
#'
#' A cell needs at least its longest word and at most its longest line, plus its
#' padding. A cell spanning columns adds what the columns lack in equal parts.
#' @param ht a huxtable.
#' @return `list(min, max)`: numeric per column.
#' @noRd
.column_extents <- function(ht) {
    cells <- .cell_extents(ht)
    spans <- .wml_spans(ht)
    m <- ncol(ht)
    col <- col(spans$origin)
    span <- spans$colspan
    isOrigin <- spans$origin == seq_along(spans$origin)
    single <- which(isOrigin & span == 1L)
    column <- factor(col[single], levels = seq_len(m))
    minW <- tapply(cells$min[single], column, max, default = 0)
    maxW <- tapply(cells$max[single], column, max, default = 0)
    multi <- which(isOrigin & span > 1L)
    for (k in multi[order(span[multi])]) {
        cols <- col[[k]] - 1L + seq_len(span[[k]])
        minW[cols] <- minW[cols] +
            max(cells$min[[k]] - sum(minW[cols]), 0) /
                span[[k]]
        maxW[cols] <- maxW[cols] +
            max(cells$max[[k]] - sum(maxW[cols]), 0) /
                span[[k]]
    }
    list(min = as.vector(minW), max = pmax(as.vector(maxW), as.vector(minW)))
}

#' Narrowest (longest word) and natural (longest line) width of each cell in pt, padding
#' included
#' @param ht a huxtable.
#' @return `list(min, max)`: numeric matrices.
#' @noRd
.cell_extents <- function(ht) {
    n <- nrow(ht)
    text <- matrix(
        unlist(lapply(seq_len(ncol(ht)), \(j) {
            as.character(ht[[j]])
        })),
        n
    )
    text[is.na(text)] <- ""
    isMarkdown <- huxtable::markdown(ht)
    # markup (not escaped: after an even number of backslashes) and backslash escapes
    # take no width
    text[isMarkdown] <- gsub(
        "(?<!\\\\)((?:\\\\\\\\)*)(?:~~|\\*\\*|__|[*_])",
        "\\1",
        text[isMarkdown],
        perl = TRUE
    )
    text[isMarkdown] <- gsub("\\\\([[:punct:]])", "\\1", text[isMarkdown])
    face <- 1L + .true(huxtable::bold(ht)) + 2L * .true(huxtable::italic(ht))
    lines <- strsplit(text, "\n", fixed = TRUE)
    words <- lapply(lines, \(l) unlist(strsplit(l, "[[:space:]]+")))
    # one measurement of all words and lines
    parts <- c(words, lines)
    em <- .string_widths(unlist(parts), rep(c(face, face), lengths(parts)))
    cell <- factor(rep(seq_along(parts), lengths(parts)), levels = seq_along(parts))
    longest <- as.vector(tapply(em, cell, max, default = 0))
    size <- huxtable::font_size(ht)
    size[is.na(size)] <- .latex_font_size
    pad <- .padding(huxtable::left_padding(ht)) +
        .padding(huxtable::right_padding(ht))
    k <- length(text)
    list(
        min = matrix(longest[seq_len(k)], n) * size + pad,
        max = matrix(longest[k + seq_len(k)], n) * size + pad
    )
}

#' Widths of strings in em, by font face (1 plain, 2 bold, 3 italic, 4 bold italic)
#'
#' Measured with the Computer Modern metrics that R ships for its PDF device: the same
#' on every machine and close to Latin Modern, LaTeX's default font, plus 5% for its
#' optical sizes and kerning. Characters without metrics there are measured by stand-ins
#' of similar width.
#' @param x character vector.
#' @param face integer font face per string of `x`.
#' @return numeric widths in em.
#' @noRd
.string_widths <- function(x, face) {
    if (length(x) == 0L) {
        return(numeric())
    }
    x <- chartr("-<>|", "(mml", x)
    x <- gsub("[^ !#-;=?-\\[\\]`a-z]", "0", x, perl = TRUE)
    old <- grDevices::dev.cur()
    grDevices::pdf(NULL, family = .cm_metrics())
    on.exit(
        {
            grDevices::dev.off()
            if (old > 1L) grDevices::dev.set(old)
        },
        add = TRUE
    )
    res <- numeric(length(x))
    for (f in unique(face)) {
        hit <- face == f
        res[hit] <- graphics::strwidth(x[hit], units = "inches", font = f)
    }
    res * 72 / graphics::par("ps") * 1.05
}

#' Computer Modern font metrics shipped with R (not registered)
#' @return a `Type1Font` for `grDevices::pdf()`.
#' @noRd
.cm_metrics <- function() {
    grDevices::Type1Font(
        "pubflowCM",
        c(
            "CM_regular_10.afm",
            "CM_boldx_10.afm",
            "CM_italic_10.afm",
            "CM_boldx_italic_10.afm",
            "CM_symbol_10.afm"
        )
    )
}
