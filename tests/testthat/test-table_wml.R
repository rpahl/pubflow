# The WML of a table in a minimal document, parsed
wml_doc <- function(ht, ...) {
    xml2::read_xml(paste0(
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/",
        "wordprocessingml/2006/main\"><w:body>",
        .huxtable_to_wml(ht, ...),
        "</w:body></w:document>"
    ))
}

wml_find <- function(x, xpath) {
    xml2::xml_find_all(x, xpath, xml2::xml_ns(x))
}

# Text of the cells of each row (merged cells once, continuations "")
wml_row_text <- function(doc) {
    lapply(wml_find(doc, "//w:tr"), \(tr) {
        vapply(
            wml_find(tr, "./w:tc"),
            \(tc) {
                paste(xml2::xml_text(wml_find(tc, ".//w:t")), collapse = "")
            },
            character(1)
        )
    })
}

# The same as a matrix (tables without column spans)
wml_cell_text <- function(doc) {
    do.call(rbind, wml_row_text(doc))
}

wml_val <- function(doc, xpath) {
    xml2::xml_attr(wml_find(doc, xpath), "val")
}

describe(".huxtable_to_wml()", {
    it("writes well-formed XML for the report tables", {
        tables <- list(
            report_data_table(),
            report_summary_table(),
            report_trend_by_site()[[1L]],
            report_pvalue_table(),
            report_wrapped_table(),
            report_footnote_table(),
            slopes_summary_table(panel = c("1", "1", "3")),
            slopes_criteria_table(),
            edge_case_table()
        )
        for (ht in tables) {
            doc <- wml_doc(ht)
            expect_length(wml_find(doc, "//w:tbl"), 1L)
            expect_length(wml_find(doc, "//w:tr"), nrow(ht))
            expect_length(wml_find(doc, "//w:gridCol"), ncol(ht))
        }
    })

    it("shows the formatter's text in every cell", {
        doc <- wml_doc(edge_case_table())
        expect_identical(unname(wml_cell_text(doc)), unname(edge_case_text()))
        struck <- wml_find(doc, "//w:r[w:rPr/w:strike]/w:t")
        expect_identical(xml2::xml_text(struck), edge_case_text()[edge_case_struck()])
    })

    it("merges cells across columns and rows", {
        doc <- wml_doc(report_data_table())
        expect_identical(wml_val(doc, "//w:gridSpan"), "3")
        expect_identical(wml_row_text(doc)[[1L]], c("", "Time [months]"))
        summary <- wml_doc(report_summary_table())
        expect_identical(wml_val(summary, "//w:vMerge[@w:val]"), rep("restart", 3L))
        expect_length(wml_find(summary, "//w:vMerge[not(@w:val)]"), 3L)
        site <- wml_cell_text(summary)[, 1L]
        expect_identical(site[-1L], c("A", "", "B", "", "C", ""))
    })

    it("repeats the header rows on every page", {
        doc <- wml_doc(report_data_table())
        header <- vapply(
            wml_find(doc, "//w:tr"),
            \(tr) {
                length(wml_find(tr, "./w:trPr/w:tblHeader")) == 1L
            },
            logical(1)
        )
        expect_identical(header, c(TRUE, TRUE, FALSE, FALSE, FALSE))
        expect_length(wml_find(doc, "//w:trPr/w:cantSplit"), 5L)
    })

    it("writes text colours, bold, italic, fonts and backgrounds", {
        ht <- report_data_table() |>
            huxtable::set_background_color(3L, 1L, "lightgrey") |>
            huxtable::set_italic(4L, 1L) |>
            huxtable::set_font(5L, 1L, "Arial")
        doc <- wml_doc(ht)
        expect_setequal(wml_val(doc, "//w:color"), c("000000", "0000FF", "00B050"))
        expect_identical(xml2::xml_attr(wml_find(doc, "//w:shd"), "fill"), "D3D3D3")
        bold <- wml_find(doc, "//w:r[w:rPr/w:b]/w:t")
        bold <- xml2::xml_text(bold)
        expect_identical(
            bold[nzchar(bold)],
            c("Time [months]", "Site ID", "0", "3", "6")
        )
        expect_identical(
            xml2::xml_text(wml_find(doc, "//w:r[w:rPr/w:i]/w:t")),
            "B"
        )
        fonts <- wml_find(doc, "//w:rFonts")
        expect_identical(xml2::xml_attr(fonts, "ascii"), "Arial")
        expect_identical(unique(wml_val(doc, "//w:r/w:rPr/w:sz")), "18")
    })

    it("writes borders by side, width and style", {
        doc <- wml_doc(report_footnote_table())
        top <- wml_find(doc, "//w:tr[1]/w:tc/w:tcPr/w:tcBorders/w:top")
        expect_identical(xml2::xml_attr(top, "sz"), c("6", "6"))
        expect_identical(xml2::xml_attr(top, "val"), c("single", "single"))
        expect_length(wml_find(doc, "//w:tcBorders/w:left"), 0L)
        grid <- pub_table(
            data.frame(a = 1:2, b = 3:4),
            theme = pub_table_theme(borders = "grid")
        )
        grid <- huxtable::set_bottom_border_style(grid, 3L, 1L, "dashed")
        doc <- wml_doc(grid)
        expect_length(wml_find(doc, "//w:tcBorders/w:left"), 6L)
        expect_identical(unique(wml_val(doc, "//w:tcBorders/*")), c("single", "dashed"))
        expect_identical(
            unique(xml2::xml_attr(wml_find(doc, "//w:tcBorders/*"), "sz")),
            "3"
        )
    })

    it("writes footnote rows spanning all columns", {
        doc <- wml_doc(report_footnote_table())
        text <- wml_row_text(doc)
        expect_identical(text[[length(text)]], "¹ Site IDs: A, B, C")
        last <- wml_find(doc, "//w:tr[last()]/w:tc")
        expect_length(last, 1L)
        expect_identical(wml_val(last[[1L]], ".//w:gridSpan"), "2")
    })

    it("writes alignment, vertical alignment, wrapping and padding", {
        ht <- pub_table(data.frame(a = "x", b = 1.5), align = c(a = "center")) |>
            huxtable::set_valign(2L, 1L, "middle") |>
            huxtable::set_wrap(2L, 2L, FALSE) |>
            huxtable::set_left_padding(2L, 2L, 2) |>
            huxtable::set_position("left")
        doc <- wml_doc(ht)
        expect_identical(
            wml_val(doc, "//w:tc/w:p/w:pPr/w:jc"),
            c("center", "right", "center", "right")
        )
        expect_identical(wml_val(doc, "//w:vAlign"), c("top", "top", "center", "top"))
        expect_length(wml_find(doc, "//w:noWrap"), 1L)
        margin <- wml_find(doc, "//w:tr[2]/w:tc[2]//w:tcMar/w:left")
        expect_identical(xml2::xml_attr(margin, "w"), "40")
        expect_identical(wml_val(doc, "//w:tblPr/w:jc"), "left")
    })

    it("writes Markdown cells as runs with bold, italic and strikethrough", {
        ht <- huxtable::hux(
            a = c("**b** *i* ~~s~~ and ***both***", "x"),
            add_colnames = FALSE
        )
        huxtable::markdown(ht)[1L, 1L] <- TRUE
        doc <- wml_doc(ht)
        runs <- wml_find(doc, "//w:tr[1]//w:r")
        expect_identical(
            xml2::xml_text(runs),
            c("b", " ", "i", " ", "s", " and ", "both")
        )
        flags <- vapply(
            runs,
            \(r) {
                paste(xml2::xml_name(wml_find(r, "./w:rPr/*")), collapse = " ")
            },
            character(1)
        )
        expect_identical(
            flags,
            c("b bCs", "", "i iCs", "", "strike", "", "b bCs i iCs")
        )
        struck <- wml_doc(slopes_criteria_table())
        expect_identical(
            xml2::xml_text(wml_find(struck, "//w:r[w:rPr/w:strike]/w:t")),
            c("R²", "0.95", "Linearity", "0.05")
        )
    })

    it("writes an empty paragraph for an empty Markdown cell", {
        ht <- huxtable::hux(a = c("", "x"), add_colnames = FALSE)
        huxtable::markdown(ht)[1L, 1L] <- TRUE
        doc <- wml_doc(ht)
        p <- wml_find(doc, "//w:tr[1]/w:tc/w:p")
        expect_length(p, 1L)
        expect_length(wml_find(p[[1L]], "./w:r"), 0L)
        expect_identical(wml_cell_text(doc)[, 1L], c("", "x"))
    })

    it("signals an error for other Markdown in cells", {
        ht <- huxtable::hux(a = "see [link](https://x.org)", add_colnames = FALSE)
        huxtable::markdown(ht) <- TRUE
        expect_error(.huxtable_to_wml(ht), class = "pubflow_render_error")
        expect_snapshot(.huxtable_to_wml(ht), error = TRUE)
        huxtable::contents(ht)[1L, 1L] <- "- item"
        expect_error(.huxtable_to_wml(ht), "found list", class = "pubflow_render_error")
    })

    it("escapes text and keeps line breaks", {
        ht <- huxtable::hux(
            a = c("a < b & c > d", "line 1\nline 2\001"),
            add_colnames = FALSE
        )
        doc <- wml_doc(ht)
        expect_identical(wml_cell_text(doc)[, 1L], c("a < b & c > d", "line 1line 2"))
        expect_length(wml_find(doc, "//w:tr[2]//w:br"), 1L)
    })

    it("lets Word fit columns without widths", {
        doc <- wml_doc(report_footnote_table())
        layout <- xml2::xml_attr(wml_find(doc, "//w:tblLayout"), "type")
        expect_identical(layout, "autofit")
        expect_identical(xml2::xml_attr(wml_find(doc, "//w:tblW"), "type"), "auto")
        expect_identical(
            unique(xml2::xml_attr(wml_find(doc, "//w:tcW"), "type")),
            "auto"
        )
    })

    it("divides the table width by relative widths", {
        ht <- pub_table(
            data.frame(a = 1, b = 2, c = 3),
            widths = c(a = 1, b = 1, c = 2)
        )
        doc <- wml_doc(ht, text_width = 8000L)
        expect_identical(
            xml2::xml_attr(wml_find(doc, "//w:tblLayout"), "type"),
            "fixed"
        )
        grid <- xml2::xml_attr(wml_find(doc, "//w:gridCol"), "w")
        expect_identical(grid, c("2000", "2000", "4000"))
        expect_identical(xml2::xml_attr(wml_find(doc, "//w:tblW"), "w"), "8000")
        huxtable::width(ht) <- 0.5
        grid <- xml2::xml_attr(
            wml_find(wml_doc(ht, text_width = 8000L), "//w:gridCol"),
            "w"
        )
        expect_identical(grid, c("1000", "1000", "2000"))
    })

    it("fixes cm widths and shares the rest", {
        doc <- wml_doc(report_wrapped_table(), text_width = 9071L)
        expect_identical(
            xml2::xml_attr(wml_find(doc, "//w:tblLayout"), "type"),
            "autofit"
        )
        grid <- as.integer(xml2::xml_attr(wml_find(doc, "//w:gridCol"), "w"))
        expect_identical(grid[[1L]], 1417L)
        expect_true(all(abs(grid[-1L] - (9071 - 1417) / 3) <= 1))
        tcW <- wml_find(doc, "//w:tr[1]/w:tc/w:tcPr/w:tcW")
        expect_identical(xml2::xml_attr(tcW, "type"), c("dxa", "auto", "auto", "dxa"))
    })

    it("treats invalid widths set with huxtable as automatic", {
        ht <- pub_table(data.frame(a = 1, b = 2, c = 3))
        huxtable::col_width(ht) <- c(Inf, 1, 3)
        doc <- wml_doc(ht, text_width = 8000L)
        grid <- xml2::xml_attr(wml_find(doc, "//w:gridCol"), "w")
        expect_identical(grid, c("1600", "1600", "4800"))
        tcW <- wml_find(doc, "//w:tr[1]/w:tc/w:tcPr/w:tcW")
        expect_identical(xml2::xml_attr(tcW, "type"), c("auto", "dxa", "dxa"))
        huxtable::col_width(ht) <- c(".cm", "1cm", "auto")
        grid <- xml2::xml_attr(wml_find(wml_doc(ht), "//w:gridCol"), "w")
        expect_false(anyNA(as.integer(grid)))
    })

    it("applies a font size", {
        doc <- wml_doc(report_footnote_table(), font_size = 7)
        expect_identical(unique(wml_val(doc, "//w:r/w:rPr/w:sz")), "14")
    })

    it("signals an error for colours Word can't use", {
        ht <- huxtable::set_text_color(report_footnote_table(), 2L, 1L, "nocolour")
        expect_error(.huxtable_to_wml(ht), "nocolour")
    })

    it("writes the XML of a small table", {
        ht <- pub_table(
            data.frame(site = c("A", "B"), value = c(1.5, NA)),
            digits = c(value = 1L),
            na = "-",
            header = c(value = "Results")
        )
        xml <- xml2::read_xml(paste0(
            "<w:document xmlns:w=\"http://schemas.openxmlformats.org/",
            "wordprocessingml/2006/main\">",
            .huxtable_to_wml(ht),
            "</w:document>"
        ))
        expect_snapshot(cat(as.character(xml, options = "format")))
    })
})

describe(".wml_colors()", {
    it("writes no colour for NA and transparent colours", {
        x <- matrix(c("transparent", "#FF000000", "#FF000080", NA, "red", "red"), 2L)
        expect_identical(
            .wml_colors(x),
            matrix(c(NA, NA, "FF0000", NA, "FF0000", "FF0000"), 2L)
        )
        expect_identical(
            .wml_colors(matrix(NA_character_, 2L, 3L)),
            matrix(NA_character_, 2L, 3L)
        )
    })
})

describe(".wml_border_sides()", {
    it("writes double and dotted borders, clamps widths and keeps colours", {
        ht <- huxtable::hux(a = 1:2, b = 3:4, add_colnames = FALSE) |>
            huxtable::set_top_border(1L, 1L, 0.1) |>
            huxtable::set_top_border_style(1L, 1L, "double") |>
            huxtable::set_top_border(1L, 2L, 20) |>
            huxtable::set_top_border_style(1L, 2L, "dotted") |>
            huxtable::set_top_border_color(1L, 2L, "red")
        top <- .wml_border_sides(ht)$top
        expect_identical(
            top[1L, ],
            c(
                "<w:top w:val=\"double\" w:sz=\"2\" w:space=\"0\" w:color=\"auto\"/>",
                "<w:top w:val=\"dotted\" w:sz=\"96\" w:space=\"0\" w:color=\"FF0000\"/>"
            )
        )
        expect_identical(top[2L, ], c("", ""))
    })
})

describe(".xml_text() and .xml_attr()", {
    it("escapes markup characters and keeps quotes in text", {
        expect_identical(
            .xml_text(c("a & <b> \"c\" 'd'", NA)),
            c("a &amp; &lt;b&gt; \"c\" 'd'", "")
        )
        expect_identical(.xml_attr("A \"B\" & C"), "A &quot;B&quot; &amp; C")
    })

    it("drops control characters but keeps tabs and line breaks", {
        expect_identical(.xml_text("a\001\010\013\014\016\037b\t\n\r"), "ab\t\n\r")
    })

    it("escapes font names and cell text in the document", {
        ht <- huxtable::hux(a = "x \" ' & \t y", add_colnames = FALSE)
        huxtable::font(ht) <- "A&B \"C\" <D>"
        doc <- wml_doc(ht)
        fonts <- wml_find(doc, "//w:rFonts")
        expect_identical(xml2::xml_attr(fonts, "ascii"), "A&B \"C\" <D>")
        expect_identical(xml2::xml_attr(fonts, "cs"), "A&B \"C\" <D>")
        expect_identical(wml_cell_text(doc)[1L, 1L], "x \" ' & \t y")
    })
})

describe(".wml_markdown_runs()", {
    md_table <- function(x) {
        ht <- huxtable::hux(a = x, add_colnames = FALSE)
        huxtable::markdown(ht) <- TRUE
        ht
    }

    it("writes soft breaks as spaces and hard breaks as line breaks", {
        doc <- wml_doc(md_table("a\nb"))
        expect_identical(xml2::xml_text(wml_find(doc, "//w:r")), c("a", " ", "b"))
        expect_length(wml_find(doc, "//w:br"), 0L)
        doc <- wml_doc(md_table("a  \nb"))
        expect_length(wml_find(doc, "//w:r/w:br"), 1L)
        expect_identical(wml_cell_text(doc)[1L, 1L], "ab")
    })

    it("writes a paragraph per Markdown paragraph", {
        doc <- wml_doc(md_table("p1\n\np2"))
        p <- wml_find(doc, "//w:tc/w:p")
        expect_identical(xml2::xml_text(p), c("p1", "p2"))
        expect_length(wml_find(doc, "//w:tc/w:p/w:pPr/w:jc"), 2L)
    })

    it("escapes text and drops control characters in Markdown cells", {
        doc <- wml_doc(md_table("x \001& **y \"q\"**"))
        expect_identical(wml_cell_text(doc)[1L, 1L], "x & y \"q\"")
    })

    it("names the row and column of the failing cell", {
        ht <- huxtable::hux(a = c("1", "2"), b = c("3", "`c`"), add_colnames = FALSE)
        huxtable::markdown(ht) <- TRUE
        expect_error(
            .huxtable_to_wml(ht),
            "cell \\[2, 2\\].*found code",
            class = "pubflow_render_error"
        )
    })
})

describe(".wml_rows()", {
    it("merges a block of cells across rows and columns", {
        ht <- huxtable::hux(a = 1:3, b = 4:6, c = 7:9, add_colnames = FALSE) |>
            huxtable::set_rowspan(1L, 1L, 2L) |>
            huxtable::set_colspan(1L, 1L, 2L) |>
            huxtable::set_bottom_border(2L, 1L, 1)
        huxtable::col_width(ht) <- c("1cm", "2cm", "1cm")
        doc <- wml_doc(ht)
        expect_identical(
            wml_row_text(doc),
            list(c("1", "7"), c("", "8"), c("3", "6", "9"))
        )
        expect_identical(wml_val(doc, "//w:gridSpan"), c("2", "2"))
        expect_identical(wml_val(doc, "//w:vMerge[@w:val]"), "restart")
        expect_length(wml_find(doc, "//w:tr[2]/w:tc[1]/w:tcPr/w:vMerge"), 1L)
        # the bottom border shows in the last row of the merged cell only
        expect_length(wml_find(doc, "//w:tr[1]//w:tcBorders/w:bottom"), 0L)
        expect_length(wml_find(doc, "//w:tr[2]/w:tc[1]//w:tcBorders/w:bottom"), 1L)
        tcW <- wml_find(doc, "//w:tr[1]/w:tc/w:tcPr/w:tcW")
        expect_identical(xml2::xml_attr(tcW, "w"), c("1701", "567"))
    })

    it("repeats only header rows at the top of the table", {
        ht <- huxtable::hux(a = 1:3, add_colnames = FALSE)
        huxtable::header_rows(ht) <- c(FALSE, TRUE, FALSE)
        expect_length(wml_find(wml_doc(ht), "//w:tblHeader"), 0L)
        huxtable::header_rows(ht) <- c(TRUE, FALSE, TRUE)
        header <- wml_find(wml_doc(ht), "//w:tr[w:trPr/w:tblHeader]")
        expect_length(header, 1L)
        expect_identical(xml2::xml_text(header), "1")
    })
})

describe(".table_width()", {
    it("reads fractions, percentages and cm widths", {
        expect_identical(.table_width(0.5, 1000), 500)
        expect_identical(.table_width("50%", 1000), 500)
        expect_identical(.table_width("2.54cm", 1000), 1440)
        expect_identical(.table_width("2.54cm", 1000, per_cm = 10), 25.4)
    })

    it("caps relative widths at the text width", {
        expect_identical(.table_width(2, 1000), 1000)
        expect_identical(.table_width("150%", 1000), 1000)
    })

    it("uses the text width for missing or invalid widths", {
        for (width in list(NA, NA_real_, NA_character_, 0, -1, "x", "%", "cm")) {
            expect_identical(.table_width(width, 1000), 1000)
        }
    })

    it("sets the width of a table with relative widths", {
        ht <- pub_table(data.frame(a = 1, b = 2), widths = c(a = 1, b = 3))
        huxtable::width(ht) <- "5cm"
        doc <- wml_doc(ht)
        expect_identical(xml2::xml_attr(wml_find(doc, "//w:tblW"), "w"), "2835")
        grid <- xml2::xml_attr(wml_find(doc, "//w:gridCol"), "w")
        expect_identical(grid, c("709", "2126"))
    })
})

describe(".share_widths()", {
    it("shares the rest by shares, else gives 1 cm per column with a warning", {
        cm <- c(TRUE, FALSE, FALSE)
        expect_identical(
            .share_widths(c(10, 0, 0), c(NA, 1, 3), cm, 50, 1),
            c(10, 10, 30)
        )
        expect_warning(
            res <- .share_widths(c(10, 0, 0), c(NA, 1, 3), cm, 11, per_cm = 1),
            "leave less than 1 cm for each other column of a 11.0 cm wide table",
            class = "pubflow_render_warning"
        )
        expect_identical(res, c(10, 1, 1))
        expect_no_warning(.share_widths(c(10, 0, 0), c(NA, 1, 1), cm, 12, per_cm = 1))
    })
})

describe(".wml_table_props()", {
    it("aligns the table by its position", {
        ht <- huxtable::hux(a = 1, add_colnames = FALSE)
        jc <- vapply(
            c("left", "wrapleft", "center", "right", "wrapright"),
            \(position) {
                huxtable::position(ht) <- position
                wml_val(wml_doc(ht), "//w:tblPr/w:jc")
            },
            character(1)
        )
        expect_identical(unname(jc), c("left", "left", "center", "right", "right"))
    })
})
