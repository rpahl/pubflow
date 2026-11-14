# Native Word table writer: a huxtable to a WordprocessingML table (`<w:tbl>`) built
# from huxtable's exported getters and the cell text of pubflow's common formatter. The
# XML goes into the DOCX as a raw openxml block of the Pandoc Markdown, so DOCX tables
# need neither flextable nor officer (~200 ms per table). Cells use direct formatting
# only (no style ids, which differ between reference documents). Without widths Word
# sizes the columns itself (autofit).

# ======================================================================================
# Word tables
# ======================================================================================

# ------
# Tables
# ------
#' Word XML of a table
#'
#' Why a native writer instead of huxtable -> flextable -> Word:
#'
#' - Speed: `huxtable::as_flextable()` (120-160 ms) plus `officer::to_wml()` (~80 ms)
#'   cost ~200 ms per table, i.e. ~12 s for a report with 60 tables; a real-world Word
#'   report spends 3.3 s converting to flextable and 4.2 s writing Word XML (35 s in
#'   total). This writer takes ~8 ms for a 40x8 table (`inst/bench/wml.R`). Its XML goes
#'   into the Pandoc Markdown as a raw openxml block, so the DOCX is assembled in one
#'   pandoc call (0.8 s for 60 tables, 100 images, 60 equations) instead of by officer,
#'   whose inserts get slower with every table (3.7-4 s for 40).
#' - Identical cell text in every format (GMP): the cells are the strings of the common
#'   formatter, written as they are; no second formatting layer (flextable's) can change
#'   them.
#' - No flextable dependency (it masks huxtable's `to_html()` and `set_caption()` when
#'   both are attached).
#'
#' The price: pubflow maintains this writer, and it supports only the huxtable
#' properties mapped here; Markdown cells may only use strong, emphasis and
#' strikethrough (other Markdown is an error).
#'
#' @param ht a huxtable.
#' @param font_size font size (pt) for all cells, or `NULL` (the table's).
#' @param text_width width of the text area in twips (1/20 pt; A4 with 2.5 cm margins:
#'   16 cm = 9071), for tables with widths.
#' @return `character(1)` `<w:tbl>` element (prefix `w`, namespace declared by the
#'   document).
#' @noRd
.huxtable_to_wml <- function(ht, font_size = NULL, text_width = 9071L) {
    if (!is.null(font_size)) {
        huxtable::font_size(ht) <- font_size
    }
    text <- .format_cells(ht)
    props <- .wml_props(ht)
    widths <- .wml_widths(ht, text_width)
    content <- .wml_contents(text, props)
    spans <- .wml_spans(ht)
    header <- cumprod(unname(huxtable::header_rows(ht))) == 1L
    rows <- .wml_rows(spans, props, content, widths, header)
    paste0(
        "<w:tbl>",
        .wml_table_props(ht, widths),
        "<w:tblGrid>",
        paste0("<w:gridCol w:w=\"", widths$grid, "\"/>", collapse = ""),
        "</w:tblGrid>",
        paste(rows, collapse = ""),
        "</w:tbl>"
    )
}


# ======================================================================================
# Cells
# ======================================================================================

# ---------------
# Cell properties
# ---------------
#' Cell properties as matrices, ready for the XML
#'
#' @return list of character matrices (XML fragments or values) and logical matrices,
#'   one element per cell.
#' @param ht a huxtable.
#' @noRd
.wml_props <- function(ht) {
    font <- huxtable::font(ht)
    size <- huxtable::font_size(ht)
    color <- .wml_colors(huxtable::text_color(ht))
    fill <- .wml_colors(huxtable::background_color(ht))
    list(
        font = .wml_if(
            !is.na(font),
            sprintf(
                "<w:rFonts w:ascii=\"%1$s\" w:hAnsi=\"%1$s\" w:cs=\"%1$s\"/>",
                .xml_attr(font)
            )
        ),
        bold = .true(huxtable::bold(ht)),
        italic = .true(huxtable::italic(ht)),
        color = .wml_if(!is.na(color), sprintf("<w:color w:val=\"%s\"/>", color)),
        size = .wml_if(
            !is.na(size),
            sprintf(
                "<w:sz w:val=\"%1$d\"/><w:szCs w:val=\"%1$d\"/>",
                as.integer(round(size * 2))
            )
        ),
        markdown = .true(huxtable::markdown(ht)),
        jc = .wml_jc(huxtable::align(ht)),
        valign = .wml_valign(huxtable::valign(ht)),
        fill = .wml_if(
            !is.na(fill),
            sprintf(
                "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"%s\"/>",
                fill
            )
        ),
        nowrap = .wml_if(!.true(huxtable::wrap(ht), na = TRUE), "<w:noWrap/>"),
        margins = .wml_margins(ht),
        borders = .wml_border_sides(ht)
    )
}

#' Matrix of `yes` where `cond` holds, else `""` (keeps dimensions)
#' @param cond logical matrix.
#' @param yes `character`: the values where `cond` is `TRUE` (recycled).
#' @return character matrix with the dimensions of `cond`.
#' @noRd
.wml_if <- function(cond, yes) {
    res <- ifelse(cond, yes, "")
    res[is.na(res)] <- ""
    dim(res) <- dim(cond)
    res
}

#' Logical matrix with `NA` replaced
#' @param x logical matrix.
#' @param na the value for `NA`.
#' @noRd
.true <- function(x, na = FALSE) {
    res <- x
    res[is.na(res)] <- na
    res == TRUE
}

#' Colours as RRGGBB (`NA` for no colour or transparent)
#' @param x character matrix of R colours.
#' @return character matrix with the dimensions of `x`.
#' @noRd
.wml_colors <- function(x) {
    values <- unique(x[!is.na(x)])
    if (length(values) == 0L) {
        return(array(NA_character_, dim(x)))
    }
    rgba <- tryCatch(
        grDevices::col2rgb(values, alpha = TRUE),
        error = \(e) {
            rlang::abort(
                sprintf("Can't convert table colours to Word: %s", conditionMessage(e)),
                call = NULL
            )
        }
    )
    hex <- sprintf("%02X%02X%02X", rgba[1L, ], rgba[2L, ], rgba[3L, ])
    hex[rgba[4L, ] == 0] <- NA_character_
    res <- hex[match(x, values)]
    dim(res) <- dim(x)
    res
}

#' Paragraph alignment (decimal alignment shows right-aligned)
#' @param align character matrix of huxtable alignments.
#' @noRd
.wml_jc <- function(align) {
    res <- ifelse(align %in% c("left", "center", "right"), align, "right")
    res[is.na(align)] <- "left"
    dim(res) <- dim(align)
    res
}

#' Vertical alignment of the cells
#' @param valign character matrix of huxtable vertical alignments.
#' @noRd
.wml_valign <- function(valign) {
    res <- ifelse(valign %in% c("middle", "bottom"), valign, "top")
    res[res == "middle"] <- "center"
    dim(res) <- dim(valign)
    res
}

#' Cell margins (huxtable padding, pt) as `<w:tcMar>`
#' @param ht a huxtable.
#' @return character matrix.
#' @noRd
.wml_margins <- function(ht) {
    twips <- \(p) {
        p <- suppressWarnings(as.numeric(p))
        p[is.na(p)] <- 0
        as.integer(round(p * 20))
    }
    res <- sprintf(
        paste0(
            "<w:tcMar><w:top w:w=\"%d\" w:type=\"dxa\"/>",
            "<w:left w:w=\"%d\" w:type=\"dxa\"/>",
            "<w:bottom w:w=\"%d\" w:type=\"dxa\"/>",
            "<w:right w:w=\"%d\" w:type=\"dxa\"/></w:tcMar>"
        ),
        twips(huxtable::top_padding(ht)),
        twips(huxtable::left_padding(ht)),
        twips(huxtable::bottom_padding(ht)),
        twips(huxtable::right_padding(ht))
    )
    dim(res) <- dim(ht)
    res
}

#' Border of every cell side as `<w:top .../>` etc. (`""`: none)
#' @param ht a huxtable.
#' @return list of character matrices `top`, `left`, `bottom`, `right`.
#' @noRd
.wml_border_sides <- function(ht) {
    side <- \(name, border, style, color) {
        width <- huxtable::brdr_thickness(border(ht))
        colors <- .wml_colors(color(ht))
        colors[is.na(colors)] <- "auto"
        styles <- c(
            solid = "single",
            double = "double",
            dashed = "dashed",
            dotted = "dotted"
        )[style(ht)]
        styles[is.na(styles)] <- "single"
        size <- pmin(pmax(as.integer(round(width * 8)), 2L), 96L)
        .wml_if(
            !is.na(width) & width > 0,
            sprintf(
                "<w:%s w:val=\"%s\" w:sz=\"%d\" w:space=\"0\" w:color=\"%s\"/>",
                name,
                styles,
                size,
                colors
            )
        )
    }
    list(
        top = side(
            "top",
            huxtable::top_border,
            huxtable::top_border_style,
            huxtable::top_border_color
        ),
        left = side(
            "left",
            huxtable::left_border,
            huxtable::left_border_style,
            huxtable::left_border_color
        ),
        bottom = side(
            "bottom",
            huxtable::bottom_border,
            huxtable::bottom_border_style,
            huxtable::bottom_border_color
        ),
        right = side(
            "right",
            huxtable::right_border,
            huxtable::right_border_style,
            huxtable::right_border_color
        )
    )
}

#' Escape text for an XML attribute in double quotes
#' @param x `character`.
#' @noRd
.xml_attr <- function(x) {
    gsub("\"", "&quot;", .xml_text(x), fixed = TRUE)
}


# -------------
# Cell contents
# -------------
#' Paragraphs of every cell
#'
#' Plain cells get one run per paragraph (`\n` becomes a line break); Markdown cells get
#' runs with bold, italic and strikethrough.
#' @param text character matrix: the cell text of `.format_cells()`.
#' @param props cell properties from `.wml_props()`.
#' @return character matrix of `<w:p>` elements.
#' @noRd
.wml_contents <- function(text, props) {
    plain <- .wml_run(text, .wml_rpr(props))
    pPr <- paste0(
        "<w:pPr><w:spacing w:before=\"0\" w:after=\"0\" w:line=\"240\" ",
        "w:lineRule=\"auto\"/><w:jc w:val=\"",
        props$jc,
        "\"/>",
        ifelse(nzchar(props$size), paste0("<w:rPr>", props$size, "</w:rPr>"), ""),
        "</w:pPr>"
    )
    res <- paste0("<w:p>", pPr, plain, "</w:p>")
    for (k in which(props$markdown)) {
        paragraphs <- .wml_markdown_runs(text[[k]], props, k)
        res[[k]] <- paste0("<w:p>", pPr[[k]], paragraphs, "</w:p>", collapse = "")
    }
    dim(res) <- dim(text)
    res
}

#' Run properties of every cell, or of cell `k` with extra formatting
#' @param props cell properties from `.wml_props()`.
#' @param k index of the cell (column-major), or `NULL` for all cells.
#' @param bold,italic,strike add this format (Markdown).
#' @return `character`: `<w:rPr>` elements or `""`.
#' @noRd
.wml_rpr <- function(props, k = NULL, bold = FALSE, italic = FALSE, strike = FALSE) {
    pick <- \(x) if (is.null(k)) x else x[[k]]
    rPr <- paste0(
        pick(props$font),
        ifelse(pick(props$bold) | bold, "<w:b/><w:bCs/>", ""),
        ifelse(pick(props$italic) | italic, "<w:i/><w:iCs/>", ""),
        if (strike) "<w:strike/>" else "",
        pick(props$color),
        pick(props$size)
    )
    ifelse(nzchar(rPr), paste0("<w:rPr>", rPr, "</w:rPr>"), "")
}

#' Runs of text (lines separated by `<w:br/>`)
#' @param text `character` (not yet escaped).
#' @param rPr `character`: run properties from `.wml_rpr()`.
#' @noRd
.wml_run <- function(text, rPr) {
    t <- gsub(
        "\n",
        "</w:t><w:br/><w:t xml:space=\"preserve\">",
        .xml_text(text),
        fixed = TRUE
    )
    paste0("<w:r>", rPr, "<w:t xml:space=\"preserve\">", t, "</w:t></w:r>")
}

#' Escape text for XML; drops characters XML 1.0 does not allow
#' @param x `character` (`NA` becomes `""`).
#' @noRd
.xml_text <- function(x) {
    x[is.na(x)] <- ""
    x <- .strip_control(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}


# --------------
# Markdown cells
# --------------
#' Runs of the paragraphs of a Markdown cell
#'
#' Only the Markdown of `.cell_markdown_blocks()` is supported.
#' @param text `character(1)`: the Markdown of the cell.
#' @param props cell properties from `.wml_props()`.
#' @param k index of the cell (column-major).
#' @return `character`: the runs of each paragraph.
#' @noRd
.wml_markdown_runs <- function(text, props, k) {
    vapply(
        .cell_markdown_blocks(text, .wml_cell(props, k), "docx"),
        \(block) paste(.wml_inlines(block, props, k, list()), collapse = ""),
        character(1)
    )
}

#' Runs of the inline nodes below `node`
#' @param node a commonmark XML node.
#' @param props cell properties from `.wml_props()`.
#' @param k index of the cell (column-major).
#' @param flags `list` of the active formats (`bold`, `italic`, `strike`).
#' @noRd
.wml_inlines <- function(node, props, k, flags) {
    unlist(lapply(xml2::xml_children(node), \(x) {
        name <- xml2::xml_name(x)
        format <- c(strong = "bold", emph = "italic", strikethrough = "strike")[name]
        if (!is.na(format)) {
            flags[[format]] <- TRUE
            return(.wml_inlines(x, props, k, flags))
        }
        rPr <- do.call(.wml_rpr, c(list(props, k), flags))
        switch(
            name,
            text = .wml_run(xml2::xml_text(x), rPr),
            softbreak = .wml_run(" ", rPr),
            linebreak = "<w:r><w:br/></w:r>",
            .cell_markdown_error(name, .wml_cell(props, k), "docx")
        )
    }))
}

#' Row and column of cell `k`
#' @param props cell properties from `.wml_props()`.
#' @param k index of the cell (column-major).
#' @return `integer(2)`.
#' @noRd
.wml_cell <- function(props, k) {
    n <- nrow(props$jc)
    c((k - 1L) %% n + 1L, (k - 1L) %/% n + 1L)
}


# ======================================================================================
# Table layout
# ======================================================================================

# ------------
# Merged cells
# ------------
#' Merged cells
#'
#' @return list: `origin` (integer matrix: the column-major index of the top-left cell
#'   covering each cell), `rowspan`, `colspan`.
#' @param ht a huxtable.
#' @noRd
.wml_spans <- function(ht) {
    rowspan <- huxtable::rowspan(ht)
    colspan <- huxtable::colspan(ht)
    n <- nrow(ht)
    origin <- matrix(NA_integer_, n, ncol(ht))
    for (j in seq_len(ncol(ht))) {
        for (i in seq_len(n)) {
            if (is.na(origin[i, j])) {
                rows <- i - 1L + seq_len(rowspan[i, j])
                cols <- j - 1L + seq_len(colspan[i, j])
                origin[rows, cols] <- (j - 1L) * n + i
            }
        }
    }
    list(origin = origin, rowspan = rowspan, colspan = colspan)
}


# ------
# Widths
# ------
#' Column widths
#'
#' Without widths (`NA` or `"auto"` everywhere) the table is autofit: Word sizes the
#' columns by their content and wraps text to fit the margins. Otherwise `"<n>cm"`
#' columns are fixed and numbers are shares of the rest of the table width
#' (`huxtable::width()` as a fraction of the text width, else the text width); with
#' automatic columns among them the table stays autofit (they count as one share each
#' for the grid), else its layout is fixed.
#' @return list: `layout` ("autofit" or "fixed"), `table` (table width in twips or `NA`
#'   for automatic), `grid` (integer twips per column) and `auto` (logical: automatic
#'   column).
#' @param ht a huxtable.
#' @param text_width width of the text area in twips.
#' @noRd
.wml_widths <- function(ht, text_width) {
    w <- .width_kinds(huxtable::col_width(ht))
    m <- length(w$value)
    if (all(w$auto)) {
        return(list(
            layout = "autofit",
            table = NA_real_,
            grid = rep(as.integer(text_width %/% m), m),
            auto = w$auto
        ))
    }
    total <- .table_width(huxtable::width(ht), text_width)
    twips <- numeric(m)
    twips[w$cm] <- w$size[w$cm] * 1440 / 2.54
    twips <- .share_widths(twips, w$share, w$cm, total)
    list(
        layout = if (any(w$auto)) "autofit" else "fixed",
        table = if (any(w$auto)) total else sum(twips),
        grid = as.integer(round(twips)),
        auto = w$auto
    )
}

#' An absolute width such as `"2.5cm"`
#' @noRd
.cm_pattern <- "^([0-9]*\\.)?[0-9]+cm$"

#' Kinds of column widths, the same in every format
#' @param value `huxtable::col_width()` of a table.
#' @return list: `value` (character), `cm` (absolute `"<n>cm"`), `auto` (automatic:
#'   anything but `"<n>cm"` and positive numbers, e.g. values set with huxtable
#'   directly), `share` (the numbers, 1 for automatic columns) and `size` (cm of the
#'   absolute columns, else `NA`).
#' @noRd
.width_kinds <- function(value) {
    value <- as.character(value)
    cm <- grepl(.cm_pattern, value)
    share <- suppressWarnings(as.numeric(value))
    auto <- !cm & !(is.finite(share) & share > 0)
    share[auto] <- 1
    size <- rep(NA_real_, length(value))
    size[cm] <- as.numeric(sub("cm$", "", value[cm]))
    list(value = value, cm = cm, auto = auto, share = share, size = size)
}

#' Table width from `huxtable::width()` (a fraction of the text width, or `"<n>%"` /
#' `"<n>cm"`), in the unit of `text_width`
#' @param width the value of `huxtable::width()`; others give `text_width`.
#' @param text_width width of the text area.
#' @param per_cm units per cm (default: twips).
#' @noRd
.table_width <- function(width, text_width, per_cm = 1440 / 2.54) {
    if (is.numeric(width) && !is.na(width) && width > 0) {
        return(text_width * min(width, 1))
    }
    width <- as.character(width)
    if (grepl("^([0-9]*\\.)?[0-9]+%$", width)) {
        return(text_width * min(as.numeric(sub("%$", "", width)) / 100, 1))
    }
    if (grepl(.cm_pattern, width)) {
        return(as.numeric(sub("cm$", "", width)) * per_cm)
    }
    text_width
}

#' Widths of the share and automatic columns: the table width that the absolute
#' columns leave, by share
#'
#' If that is less than 1 cm per column, each gets 1 cm (with a warning), and the table
#' is wider than its width.
#' @param widths column widths, those of the absolute columns set, in the unit of
#'   `total`.
#' @param share shares of the other columns (1 for automatic ones).
#' @param cm logical: absolute column.
#' @param total table width.
#' @param per_cm units per cm (default: twips).
#' @return `widths` with the other columns filled in.
#' @noRd
.share_widths <- function(widths, share, cm, total, per_cm = 1440 / 2.54) {
    rest <- total - sum(widths[cm])
    if (rest >= sum(!cm) * per_cm) {
        widths[!cm] <- rest * share[!cm] / sum(share[!cm])
        return(widths)
    }
    rlang::warn(
        c(
            sprintf(
                "The absolute column widths (%.1f cm) leave less than 1 cm for each %s",
                sum(widths[cm]) / per_cm,
                sprintf("other column of a %.1f cm wide table.", total / per_cm)
            ),
            i = "These columns get 1 cm, so the table is wider."
        ),
        class = "pubflow_render_warning"
    )
    widths[!cm] <- per_cm
    widths
}


# -------------------------
# Table properties and rows
# -------------------------
#' Table properties
#' @param ht a huxtable.
#' @param widths column widths from `.wml_widths()`.
#' @return `character(1)` `<w:tblPr>` element.
#' @noRd
.wml_table_props <- function(ht, widths) {
    position <- huxtable::position(ht)
    jc <- if (position %in% c("left", "wrapleft")) {
        "left"
    } else if (position %in% c("right", "wrapright")) {
        "right"
    } else {
        "center"
    }
    tblW <- if (is.na(widths$table)) {
        "<w:tblW w:w=\"0\" w:type=\"auto\"/>"
    } else {
        sprintf("<w:tblW w:w=\"%d\" w:type=\"dxa\"/>", as.integer(round(widths$table)))
    }
    paste0(
        "<w:tblPr>",
        tblW,
        "<w:jc w:val=\"",
        jc,
        "\"/>",
        "<w:tblLayout w:type=\"",
        widths$layout,
        "\"/>",
        "<w:tblCellMar><w:top w:w=\"0\" w:type=\"dxa\"/>",
        "<w:left w:w=\"0\" w:type=\"dxa\"/>",
        "<w:bottom w:w=\"0\" w:type=\"dxa\"/>",
        "<w:right w:w=\"0\" w:type=\"dxa\"/></w:tblCellMar>",
        "<w:tblLook w:val=\"0000\"/></w:tblPr>"
    )
}

#' Table rows
#'
#' One `<w:tc>` per visible cell, built for all cells at once. A cell merged across rows
#' writes its content in its first row and an empty continuation cell (`w:vMerge`) in
#' the others.
#' @param spans merged cells from `.wml_spans()`.
#' @param props cell properties from `.wml_props()`.
#' @param content character matrix of the cell paragraphs from `.wml_contents()`.
#' @param widths column widths from `.wml_widths()`.
#' @param header logical per row: repeat the row on every page.
#' @return `character` `<w:tr>` elements.
#' @noRd
.wml_rows <- function(spans, props, content, widths, header) {
    origin <- spans$origin
    n <- nrow(origin)
    # a part is the piece of a (merged) cell in one row
    part <- which((origin - 1L) %/% n + 1L == col(origin))
    part <- part[order(row(origin)[part], col(origin)[part])]
    i <- row(origin)[part]
    j <- col(origin)[part]
    k <- origin[part]
    i0 <- (k - 1L) %% n + 1L
    span <- spans$colspan[k]
    last <- i0 + spans$rowspan[k] - 1L
    first <- i == i0
    # every row of a row-merged cell takes its right border from the merged cell's first
    # row, while the neighbour's left border comes from its own row: they differ only if
    # hidden cells of the merged cell have their own borders
    borders <- paste0(
        ifelse(first, props$borders$top[k], ""),
        props$borders$left[k],
        ifelse(i == last, props$borders$bottom[(j - 1L) * n + last], ""),
        props$borders$right[(j + span - 2L) * n + i0]
    )
    tcPr <- paste0(
        .wml_cell_widths(widths, j, span),
        ifelse(span > 1L, sprintf("<w:gridSpan w:val=\"%d\"/>", span), ""),
        ifelse(
            spans$rowspan[k] == 1L,
            "",
            ifelse(first, "<w:vMerge w:val=\"restart\"/>", "<w:vMerge/>")
        ),
        ifelse(nzchar(borders), paste0("<w:tcBorders>", borders, "</w:tcBorders>"), ""),
        props$fill[k],
        props$nowrap[k],
        props$margins[k],
        "<w:vAlign w:val=\"",
        props$valign[k],
        "\"/>"
    )
    cells <- paste0(
        "<w:tc><w:tcPr>",
        tcPr,
        "</w:tcPr>",
        ifelse(first, content[k], "<w:p/>"),
        "</w:tc>"
    )
    rows <- vapply(
        split(cells, factor(i, seq_len(n))),
        paste,
        character(1),
        collapse = ""
    )
    paste0(
        "<w:tr><w:trPr><w:cantSplit/>",
        ifelse(header, "<w:tblHeader/>", ""),
        "</w:trPr>",
        rows,
        "</w:tr>"
    )
}

#' Preferred widths of cells starting in column `j` and spanning `span` columns
#' @param widths column widths from `.wml_widths()`.
#' @param j,span `integer`: the first column and the number of columns of each cell.
#' @return `character`: `<w:tcW>` elements.
#' @noRd
.wml_cell_widths <- function(widths, j, span) {
    grid <- c(0, cumsum(widths$grid))
    auto <- c(0L, cumsum(widths$auto))
    isAuto <- widths$layout == "autofit" & auto[j + span] - auto[j] > 0L
    ifelse(
        isAuto,
        "<w:tcW w:w=\"0\" w:type=\"auto\"/>",
        sprintf(
            "<w:tcW w:w=\"%d\" w:type=\"dxa\"/>",
            as.integer(grid[j + span] - grid[j])
        )
    )
}
