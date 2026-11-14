# ======================================================================================
# LaTeX and Typst tables
# ======================================================================================

# -----
# LaTeX
# -----

describe(".table_latex()", {
    portrait <- .latex_text_width(default_settings("latex")$page)[[
        "portrait"
    ]]
    latex <- function(ht, caption = "Caption", width = portrait) {
        .table_latex(ht, caption, NULL, text_width = width, unit_width = portrait)
    }

    it("writes a breakable longtable with the header rows repeated", {
        res <- latex(report_data_table())

        expect_match(res, "^\\\\begingroup\n")
        expect_match(res, "\\begin{longtable}[c]", fixed = TRUE)
        expect_match(res, "\\\\endfirsthead[\\s\\S]*\\\\endhead", perl = TRUE)
        expect_false(grepl("\\begin{table}", res, fixed = TRUE))
        expect_match(res, "\\\\endgroup$")
    })

    it("writes the caption escaped, tables without one don't count", {
        res <- latex(pub_table(data.frame(x = 1)), "50% \"of\" a_b & {c}")

        expect_match(
            res,
            paste0(
                "\\caption{50\\% \\textquotedbl{}of\\textquotedbl{} a\\_b \\& ",
                "\\{c\\}}"
            ),
            fixed = TRUE
        )
        expect_false(grepl("LTcaptype", res, fixed = TRUE))
        expect_match(
            latex(pub_table(data.frame(x = 1)), NULL),
            "^\\\\begingroup\n\\\\def\\\\LTcaptype\\{none\\}\n"
        )
    })

    it("writes the cell text literally", {
        ht <- pub_table(data.frame(x = c("\"a\" -- b's", "~5 ,, $x$ \\n")))

        res <- latex(ht)

        expect_match(
            res,
            paste0(
                "\\selectfont \\textquotedbl{}a\\textquotedbl{} -{}- ",
                "b\\textquotesingle{}s}"
            ),
            fixed = TRUE
        )
        expect_match(
            res,
            paste0(
                "\\selectfont \\textasciitilde{}5 ,{}, \\$x\\$ ",
                "\\textbackslash{}n}"
            ),
            fixed = TRUE
        )
    })

    it("puts the text of merged body cells into their first row", {
        ht <- report_summary_table()

        res <- latex(ht)

        expect_false(grepl("\\multirow", res, fixed = TRUE))
        cells <- regmatches(res, gregexpr("selectfont [A-C]}", res))[[1L]]
        expect_identical(cells, sprintf("selectfont %s}", c("A", "B", "C")))
    })

    it("aligns wrapping cells at the top", {
        ht <- pub_table(data.frame(
            id = "B01",
            text = paste(rep("Long text that wraps.", 30), collapse = " ")
        ))

        res <- latex(ht)

        expect_match(res, "\\parbox[t]", fixed = TRUE)
        expect_false(grepl("\\parbox[b]", res, fixed = TRUE))
    })

    it("applies the font size and keeps Unicode and escapes in cells", {
        ht <- pub_table(data.frame(x = c("\u00b5g \u2264 5 \u00b0C", "#1_a & 5%")))

        res <- .table_latex(ht, NULL, 7, text_width = portrait, portrait)

        expect_match(res, "\\fontsize{7pt}", fixed = TRUE)
        expect_false(grepl("\\fontsize{9pt}", res, fixed = TRUE))
        expect_match(res, "selectfont \u00b5g \u2264 5 \u00b0C}", fixed = TRUE)
        expect_match(res, "selectfont \\#1\\_a \\& 5\\%}", fixed = TRUE)
    })

    it("writes a caption with line breaks on one line", {
        res <- latex(pub_table(data.frame(x = 1)), "a\nb")

        expect_match(res, "\\caption{a b}", fixed = TRUE)
    })
})

describe(".unmerge_rows()", {
    table <- function() {
        ht <- huxtable::hux(
            a = c("H", "H", "x", "x"),
            b = c("h", "h2", "x", "y"),
            c = c("g", "g2", "1", "2"),
            add_colnames = FALSE
        )
        huxtable::header_rows(ht)[1:2] <- TRUE
        ht <- huxtable::merge_cells(ht, 1:2, 1)
        huxtable::background_color(ht)[3, 1:2] <- "#EEEEEE"
        huxtable::bottom_border(ht) <- 1
        huxtable::merge_cells(ht, 3:4, 1:2)
    }
    bottom <- function(ht) {
        unname(huxtable::brdr_thickness(huxtable::bottom_border(ht)))
    }

    it("keeps cells merged across the leading header rows", {
        res <- .unmerge_rows(table())

        expect_equal(huxtable::rowspan(res)[[1L, 1L]], 2)
        expect_identical(res[[1L]][1:2], c("H", "H"))
    })

    it("empties the other rows of a body cell spanning rows and columns", {
        res <- .unmerge_rows(table())

        expect_equal(unname(huxtable::rowspan(res)[3:4, 1L]), c(1, 1))
        expect_equal(unname(huxtable::colspan(res)[3:4, 1L]), c(2, 2))
        expect_identical(res[[1L]][3:4], c("x", ""))
        expect_identical(res[[2L]][[4L]], "")
        expect_identical(res[[3L]][3:4], c("1", "2"))
        expect_identical(
            unname(huxtable::background_color(res)[4L, 1:2]),
            c("#EEEEEE", "#EEEEEE")
        )
        # no border inside the cell, its bottom border stays
        expect_identical(bottom(res)[3L, 1:2], c(0, 0))
        expect_identical(bottom(res)[4L, 1:2], c(1, 1))
        expect_identical(bottom(res)[3L, 3L], 1)
    })
})


# -----
# Typst
# -----

describe(".table_typst()", {
    it("writes a breakable figure with pubflow's caption", {
        res <- .table_typst(pub_table(data.frame(x = 1)), "A \"b\" ...", NULL)

        expect_match(res, "#show figure: set block(breakable: true)", fixed = TRUE)
        expect_match(res, "caption: [A \\\"b\\\" \\.\\.\\.]", fixed = TRUE)
        expect_false(grepl("figure.caption", res, fixed = TRUE))
    })

    it("sets the figure's caption, not cell text that looks like it", {
        ht <- pub_table(data.frame(x = "caption: none"))

        res <- .table_typst(ht, "Cap", NULL)

        expect_match(res, "[caption: none]", fixed = TRUE)
        expect_match(res, "caption: [Cap]\n)", fixed = TRUE)
    })

    it("gives tables without caption no number", {
        res <- .table_typst(pub_table(data.frame(x = 1)), NULL, NULL)

        expect_match(res, "^#\\[\n#set figure\\(numbering: none\\)\n")
        expect_match(res, "caption: none", fixed = TRUE)
    })

    it("translates widths and escapes the cell text", {
        ht <- pub_table(
            data.frame(a = "x...", b = "-1", c = "z"),
            widths = c(a = "2cm", b = 2)
        )

        res <- .table_typst(ht, NULL, NULL)

        expect_match(res, "columns: (2cm, 2fr, 1fr)", fixed = TRUE)
        expect_match(res, "[x\\.\\.\\.]", fixed = TRUE)
        expect_match(res, "[\\-1]", fixed = TRUE)
    })
})


# -----
# Cells
# -----

describe(".pdf_huxtable()", {
    it("sets the font size and drops caption, height and text wrapping", {
        ht <- pub_table(data.frame(x = 1), caption = "Cap", font_size = 12)
        huxtable::height(ht) <- 0.5
        huxtable::position(ht) <- "wrapright"

        res <- .pdf_huxtable(ht, 7)

        expect_identical(unique(as.vector(huxtable::font_size(res))), 7)
        expect_true(is.na(huxtable::caption(res)))
        expect_true(is.na(huxtable::height(res)))
        expect_identical(huxtable::position(res), "right")
        expect_true(huxtable::breakable(res))
    })

    it("keeps the font size without one and positions without wrapping", {
        ht <- pub_table(data.frame(x = 1), font_size = 12)
        huxtable::position(ht) <- "left"

        res <- .pdf_huxtable(ht, NULL)

        expect_identical(unique(as.vector(huxtable::font_size(res))), 12)
        expect_identical(huxtable::position(res), "left")
    })
})

describe(".escape_cells()", {
    it("escapes plain cells only and switches off huxtable's escaping", {
        ht <- huxtable::hux(a = c("*a_b*", "a_b"), add_colnames = FALSE)
        huxtable::markdown(ht)[1L, 1L] <- TRUE

        res <- .escape_cells(ht, .latex_text)

        expect_identical(res[[1L]], c("*a_b*", "a\\_b"))
        expect_false(any(huxtable::escape_contents(res)))
    })
})

describe(".latex_text() and .typst_text()", {
    it("escape every special character", {
        expect_identical(
            .latex_text("\\ { } $ & % # _ ^ ~ < > | \" ' ` -- ,, !` \n"),
            paste0(
                "\\textbackslash{} \\{ \\} \\$ \\& \\% \\# \\_ ",
                "\\textasciicircum{} \\textasciitilde{} \\textless{} ",
                "\\textgreater{} \\textbar{} \\textquotedbl{} ",
                "\\textquotesingle{} \\textasciigrave{} -{}- ,{}, ",
                "!{}\\textasciigrave{} \\newline "
            )
        )
        expect_identical(
            .typst_text("a-b... \"c\" ~ #d [e] 1. *f*"),
            paste0("a\\-b\\.\\.\\. \\\"c\\\" \\~ \\#d \\[e\\] ", "1\\. \\*f\\*")
        )
    })

    it("handle empty, missing and Unicode text", {
        uni <- "\u00b5g \u2264 5 \u00b0C \u2013 \u03b1"

        expect_identical(.latex_text(character()), character())
        expect_identical(.latex_text(c("", NA, uni)), c("", NA, uni))
        expect_identical(.typst_text(c("", NA, uni)), c("", NA, uni))
    })

    it("break up every pair in runs of ligature characters", {
        expect_identical(
            .latex_text(c("---", ",,,", "?`", "\\{")),
            c("-{}-{}-", ",{},{},", "?{}\\textasciigrave{}", "\\textbackslash{}\\{")
        )
    })
})


# ======================================================================================
# Column widths
# ======================================================================================

describe(".typst_widths()", {
    it("keeps cm, makes positive numbers shares and the rest one share each", {
        res <- .typst_widths(c("1.5cm", "0.5", "2", "0", "-1", NA, "abc", "2 cm"))

        expect_identical(
            res,
            c("1.5cm", "0.5fr", "2fr", "1fr", "1fr", "1fr", "1fr", "1fr")
        )
        expect_identical(.typst_widths(c("2cm", NA)), c("2cm", "1fr"))
        expect_identical(.typst_widths(c(NA_real_, NA_real_)), c("auto", "auto"))
    })
})


# -----
# LaTeX
# -----

describe(".latex_widths()", {
    widths <- function(ht, width = 455) {
        res <- .latex_widths(.pdf_huxtable(ht, NULL), width, unit_width = 455)
        list(
            table = huxtable::width(res),
            cols = huxtable::col_width(res) * huxtable::width(res) * 455,
            size = huxtable::font_size(res)
        )
    }
    long <- "Sample stored at the wrong temperature for two days."

    it("keeps the natural width of a table that fits", {
        res <- widths(pub_table(data.frame(a = "x", b = 1.5)))

        expect_true(is.na(res$table))
        expect_true(all(is.na(res$cols)))
    })

    it("wraps a wide table, giving each column at least its longest word", {
        ht <- pub_table(data.frame(
            id = "B01",
            a = paste(rep(long, 4), collapse = " "),
            b = long
        ))

        res <- widths(ht)
        ext <- .column_extents(.pdf_huxtable(ht, NULL))

        expect_equal(sum(res$cols), 455, tolerance = 1e-5)
        expect_true(all(res$cols >= ext$min * (1 - 1e-5)))
        # the longer column gets more of the extra width
        expect_gt(res$cols[[2L]], res$cols[[3L]])
        expect_identical(unique(as.vector(res$size)), 9)
    })

    it("shrinks a table whose longest words don't fit", {
        words <- as.data.frame(matrix("Antidisestablishmentarianism", 1, 12))

        res <- widths(pub_table(words))

        expect_equal(sum(res$cols), 455, tolerance = 1e-5)
        expect_lt(max(res$size), 9)
    })

    it("keeps given widths: cm fixed, shares of the rest", {
        ht <- pub_table(
            data.frame(a = "x", b = "y", c = "z", d = "w"),
            widths = c(a = "2.54cm", b = 1, c = 3)
        )

        res <- widths(ht)

        expect_equal(res$cols[[1L]], 72, tolerance = 1e-5)
        # the automatic column counts as one share
        expect_equal(
            unname(res$cols[-1L]),
            (455 - 72) * c(1, 3, 1) / 5,
            tolerance = 1e-5
        )
    })

    it("gives the other columns 1 cm if the cm widths leave too little", {
        ht <- pub_table(
            data.frame(a = "x", b = "y", c = "z"),
            widths = c(a = "16cm", b = 1)
        )

        expect_warning(
            res <- widths(ht),
            "less than 1 cm",
            class = "pubflow_render_warning"
        )

        expect_equal(unname(res$cols[-1L]), rep(72 / 2.54, 2L), tolerance = 1e-5)
    })

    it("lets a cell spanning columns widen them", {
        ht <- huxtable::hux(
            a = c("a much longer spanning header", "x"),
            b = c("", "y"),
            add_colnames = FALSE
        )
        huxtable::colspan(ht)[1, 1] <- 2

        ext <- .column_extents(ht)

        single <- .cell_extents(ht)
        expect_gt(sum(ext$max), max(single$max[2L, ]) * 2)
        expect_equal(sum(ext$max), single$max[1L, 1L])
    })

    it("takes the table width from huxtable::width()", {
        ht <- pub_table(data.frame(a = "x", b = "y"), widths = c(a = 1, b = 3))
        huxtable::width(ht) <- 0.5

        res <- widths(ht, width = 400)

        expect_equal(res$table, 200 / 455, tolerance = 1e-5)
        expect_equal(unname(res$cols), c(50, 150), tolerance = 1e-5)
    })
})

describe(".shrink_table() and .padding()", {
    it("scale font sizes, the default one included, and paddings", {
        ht <- huxtable::hux(a = c("x", "y"), add_colnames = FALSE)
        huxtable::font_size(ht)[1L, 1L] <- 12
        huxtable::left_padding(ht) <- 4

        res <- .shrink_table(ht, 0.5)

        expect_identical(as.vector(huxtable::font_size(res)), c(6, 5))
        expect_identical(as.vector(huxtable::left_padding(res)), c(2, 2))
    })

    it("give paddings that aren't numbers huxtable's default", {
        res <- .padding(matrix(c("4", NA, "abc", "2"), 2L))

        expect_identical(res, matrix(c(4, 6, 6, 2), 2L))
    })
})


# ------------
# Text extents
# ------------

describe(".cell_extents()", {
    it("measures the longest word and line; empty cells only need padding", {
        ht <- huxtable::hux(
            a = c("one two\nthree", NA, ""),
            add_colnames = FALSE
        )
        huxtable::font_size(ht) <- 10

        res <- .cell_extents(ht)
        em <- .string_widths(c("three", "one two"), c(1L, 1L)) * 10

        expect_equal(res$min[[1L]], em[[1L]] + 12)
        expect_equal(res$max[[1L]], em[[2L]] + 12)
        expect_identical(as.vector(res$min[2:3, 1L]), c(12, 12))
        expect_identical(as.vector(res$max[2:3, 1L]), c(12, 12))
    })

    it("measures markdown cells without their markup", {
        ht <- huxtable::hux(a = c("**bold**", "bold"), add_colnames = FALSE)
        huxtable::markdown(ht)[1L, 1L] <- TRUE

        res <- .cell_extents(ht)

        expect_identical(res$max[[1L]], res$max[[2L]])
    })

    it("measures escaped characters without their backslash", {
        ht <- huxtable::hux(
            a = c("~~a\\*b\\$~~", "a*b$", "~~C:\\\\~~", "C:\\"),
            add_colnames = FALSE
        )
        huxtable::markdown(ht)[c(1L, 3L), 1L] <- TRUE

        res <- .cell_extents(ht)

        expect_identical(res$max[[1L]], res$max[[2L]])
        expect_identical(res$max[[3L]], res$max[[4L]])
    })
})

describe(".string_widths()", {
    it("measures text in em, bold wider than plain", {
        plain <- .string_widths(c("M", "MM", "Batch"), c(1L, 1L, 1L))
        bold <- .string_widths("Batch", 2L)

        expect_equal(plain[[2L]], 2 * plain[[1L]])
        expect_gt(bold, plain[[3L]])
        expect_identical(.string_widths(character(), integer()), numeric())
    })

    it("measures characters without metrics by stand-ins", {
        res <- expect_silent(.string_widths(c("a\u2264b", "a<b", "{}"), c(1L, 1L, 1L)))

        expect_true(all(res > 0))
    })

    it("leaves the current graphics device alone", {
        grDevices::pdf(NULL)
        dev <- grDevices::dev.cur()
        withr::defer(grDevices::dev.off(dev))

        .string_widths("x", 1L)

        expect_identical(grDevices::dev.cur(), dev)
    })
})
