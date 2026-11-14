cells <- function(ht) {
    res <- as.matrix(as.data.frame(ht))
    dimnames(res) <- NULL
    res
}

border <- function(ht, side) {
    fun <- getExportedValue("huxtable", paste0(side, "_border"))
    unname(huxtable::brdr_thickness(fun(ht)))
}


# ======================================================================================
# Building tables
# ======================================================================================

# ------
# Tables
# ------

describe("pub_table()", {
    df <- data.frame(
        batch = c("A", "B"),
        slope = c(0.12345, NA),
        n = 1:2,
        grade = factor(c("x", NA))
    )

    it("returns a plain huxtable whose cells are huxtable's text", {
        ht <- pub_table(df)

        expect_identical(class(ht), c("huxtable", "data.frame"))
        expect_true(all(vapply(ht, is.character, logical(1))))
        expect_identical(
            cells(ht),
            rbind(
                c("batch", "slope", "n", "grade"),
                c("A", "0.12345", "1", "x"),
                c("B", NA, "2", NA)
            )
        )
        expect_identical(cells(ht), cells(huxtable::as_hux(df)))
        expect_identical(
            unname(huxtable::header_rows(ht)),
            c(TRUE, FALSE, FALSE)
        )
        expect_true(all(huxtable::bold(ht)[1, ]))
        expect_false(any(huxtable::bold(ht)[-1, ]))
        expect_identical(huxtable::caption(ht), NA_character_)
        expect_null(attr(ht, "pubflow"))
    })

    it("stores numbers with 15 significant digits, as huxtable does", {
        x <- data.frame(x = c(1 / 3, 0.1 + 0.2, 1e6, 123456789012))

        ht <- pub_table(x)

        expect_identical(
            cells(ht)[-1, 1],
            c("0.333333333333333", "0.3", "1e+06", "123456789012")
        )
        expect_identical(
            cell_text(ht)[-1, 1],
            c("0.3333", "0.3000", "1000000.0000", "123456789012.0000")
        )
    })

    it("formats numeric columns by digits, else 4 or 0 decimal places", {
        ht <- pub_table(df, digits = c(slope = 2))
        fmt <- huxtable::number_format(ht)

        expect_identical(unname(fmt[2:3, 2]), list(2L, 2L))
        expect_identical(unname(fmt[2:3, 3]), list(0L, 0L))
        expect_true(all(is.na(unlist(fmt[, c(1, 4)]))))
        expect_true(all(is.na(unlist(fmt[1, ]))))
        expect_identical(cell_text(pub_table(df))[2, 2:3], c("0.1235", "1"))
        expect_identical(
            cell_text(pub_table(df, digits = c(n = 1)))[2, 3],
            "1.0"
        )
    })

    it("applies labels, digits, NA text and caption", {
        ht <- pub_table(
            df,
            caption = "Slopes",
            labels = c(batch = "Batch", slope = "Slope"),
            digits = c(slope = 2, n = 1),
            na = "-"
        )

        expect_identical(
            cell_text(ht),
            rbind(
                c("Batch", "Slope", "n", "grade"),
                c("A", "0.12", "1.0", "x"),
                c("B", "-", "2.0", "-")
            )
        )
        expect_identical(huxtable::caption(ht), "Slopes")
        expect_identical(pub_meta(ht, "caption"), "Slopes")
        expect_identical(huxtable::caption_pos(ht), "top")
    })

    it("aligns numeric columns right and others left by default", {
        ht <- pub_table(df, align = c(grade = "center"))

        align <- huxtable::align(ht)
        expect_true(all(align[, 1] == "left"))
        expect_true(all(align[, 2] == "right"))
        expect_true(all(align[, 3] == "right"))
        expect_true(all(align[, 4] == "center"))
    })

    it("adds a spanner row and merges consecutive equal spanners", {
        ht <- pub_table(
            data.frame(a = 1, b = 2, c = 3, d = 4, e = 5),
            header = c(b = "Model", c = "Model", d = "Other", e = "Model")
        )

        expect_identical(cells(ht)[1, ], c("", "Model", "Model", "Other", "Model"))
        expect_identical(unname(huxtable::header_rows(ht)), c(TRUE, TRUE, FALSE))
        expect_identical(unname(huxtable::colspan(ht)[1, ]), c(1, 2, 1, 1, 1))
        expect_true(all(huxtable::align(ht)[1, ] == "center"))
        expect_true(all(huxtable::bold(ht)[1:2, ]))
        expect_identical(border(ht, "bottom")[1, ], c(0, 0.4, 0.4, 0.4, 0.4))
        expect_identical(border(ht, "top")[1, ], rep(0.8, 5))
    })

    it("numbers footnotes in the labels and lists them below the body", {
        ht <- pub_table(
            df,
            labels = c(batch = "Batch"),
            footnotes = c(batch = "Lot.", n = "Count.", grade = "Lot.")
        )

        expect_identical(
            cell_text(ht)[c(1, 4, 5), 1],
            c("Batch\u00b9", "\u00b9 Lot.", "\u00b2 Count.")
        )
        expect_identical(cell_text(ht)[1, 3:4], c("n\u00b2", "grade\u00b9"))
        expect_identical(unname(huxtable::colspan(ht)[4:5, 1]), c(4, 4))
        expect_true(all(huxtable::align(ht)[4:5, ] == "left"))
        expect_false(any(huxtable::header_rows(ht)[4:5]))
        expect_true(all(huxtable::wrap(ht)[4:5, 1]))
        expect_true(all(huxtable::font_size(ht)[4:5, ] == 9))
        expect_true(all(border(ht, "bottom")[3, ] == 0.8))
        expect_true(all(border(ht, "bottom")[4:5, ] == 0))
        expect_identical(huxtable::na_string(ht)[4, 1], "")
    })

    it("uses multi-digit superscripts beyond nine footnotes", {
        notes <- rlang::set_names(paste("Note", 1:10), paste0("x", 1:10))
        data <- as.data.frame(as.list(rlang::set_names(1:10, names(notes))))

        ht <- pub_table(data, footnotes = notes)

        expect_identical(cell_text(ht)[1, 10], "x10\u00b9\u2070")
        expect_identical(cell_text(ht)[12, 1], "\u00b9\u2070 Note 10")
    })

    it("merges runs of equal body cells vertically", {
        ht <- pub_table(
            data.frame(g = c("a", "a", "b", "a", NA, NA), x = 1:6),
            merge = "g"
        )

        expect_identical(unname(huxtable::rowspan(ht)[, 1]), c(1, 2, 1, 1, 1, 1, 1))
        expect_identical(cells(ht)[, 2], c("x", as.character(1:6)))
        expect_error(pub_table(df, merge = "nope"), "unknown columns: nope")
        expect_error(pub_table(df, merge = 1), "character vector")
    })

    it("stores widths in huxtable's col_width", {
        rel <- pub_table(df, widths = list(slope = 2, n = 0.5))
        mixed <- pub_table(df, widths = c(batch = "2.5cm", slope = 2, grade = "auto"))

        expect_identical(unname(huxtable::col_width(rel)), c(NA, 2, 0.5, NA))
        expect_identical(
            unname(huxtable::col_width(mixed)),
            c("2.5cm", "2", NA, "auto")
        )
        expect_identical(unname(huxtable::col_width(pub_table(df))), rep(NA_real_, 4))
        expect_error(pub_table(df, widths = c(n = 0)), "`widths` must be")
        expect_error(pub_table(df, widths = c(n = "2in")), "`widths` must be")
        expect_error(pub_table(df, widths = list(n = TRUE)), "`widths` must")
        expect_error(pub_table(df, widths = c(n = Inf)), "`widths` must be")
    })

    it("sets the font size from the argument or the theme", {
        expect_true(all(huxtable::font_size(pub_table(df)) == 9))
        expect_true(all(huxtable::font_size(pub_table(df, font_size = 8)) == 8))
        theme <- pub_table_theme(font_size = 11)
        expect_true(all(huxtable::font_size(pub_table(df, theme = theme)) == 11))
    })

    it("draws booktabs rules or a grid", {
        booktabs <- pub_table(df)
        grid <- pub_table(df, theme = pub_table_theme(borders = "grid"))

        expect_identical(border(booktabs, "top")[, 1], c(0.8, 0.4, 0))
        expect_identical(border(booktabs, "bottom")[, 1], c(0.4, 0, 0.8))
        expect_true(all(border(booktabs, "left") == 0))
        for (side in c("top", "bottom", "left", "right")) {
            expect_true(all(border(grid, side) == 0.4))
        }
    })

    it("colours the borders and sets their width from the theme", {
        theme <- pub_table_theme(border_color = "#D9E2F3", border_width = 0.5)

        booktabs <- pub_table(df, theme = theme)
        grid <- pub_table(
            df,
            theme = pub_table_theme(
                borders = "grid",
                border_width = 1
            )
        )

        expect_identical(border(booktabs, "top")[, 1], c(0.5, 0.5, 0))
        expect_identical(border(booktabs, "bottom")[, 1], c(0.5, 0, 0.5))
        expect_true(all(huxtable::top_border_color(booktabs) == "#D9E2F3"))
        expect_true(all(huxtable::right_border_color(booktabs) == "#D9E2F3"))
        for (side in c("top", "bottom", "left", "right")) {
            expect_true(all(border(grid, side) == 1))
        }
        expect_true(all(is.na(huxtable::top_border_color(grid))))
    })

    it("calls the theme's style function last, with the row roles", {
        seen <- NULL
        theme <- pub_table_theme(style = function(ht, rows) {
            seen <<- rows
            huxtable::align(ht)[rows$header, ] <- "center"
            huxtable::bold(ht)[rows$body, ] <- TRUE
            ht
        })

        ht <- pub_table(
            df,
            header = c(n = "Spanner"),
            footnotes = c(n = "A note."),
            theme = theme
        )

        expect_identical(
            seen,
            list(header = 1:2, spanner = 1L, body = 3:4, footnote = 5L)
        )
        expect_true(all(huxtable::align(ht)[1:2, ] == "center"))
        expect_true(all(huxtable::bold(ht)[3:4, ]))
        expect_false(any(huxtable::bold(ht)[5, ]))
    })

    it("styles a finished table again with the theme's style function", {
        theme <- pub_table_theme(style = function(ht, rows) {
            huxtable::background_color(ht)[rows$header, ] <- "grey90"
            ht
        })
        parts <- pub_table(df, theme = theme)

        ht <- pub_table(rbind(parts, parts[-1, ]), theme = theme)

        expect_identical(
            unname(huxtable::background_color(ht)[, 1]),
            c("grey90", NA, NA, NA, NA)
        )
    })

    it("fails if the theme's style function doesn't return the table", {
        bad <- list(\(ht, rows) NULL, \(ht, rows) ht[, 1], \(ht, rows) "x")
        for (style in bad) {
            expect_error(
                pub_table(df, theme = pub_table_theme(style = style)),
                "same rows and columns"
            )
        }
    })

    it("keeps metadata and row roles if the theme's style function rebuilds it", {
        rebuild <- \(ht, rows) huxtable::as_hux(as.matrix(ht), add_colnames = FALSE)
        theme <- pub_table_theme(style = rebuild)
        parts <- pub_table(df, caption = "Slopes", footnotes = c(n = "A note."))
        parts <- pub_set_meta(parts, id = "slopes")

        ht <- pub_table(parts, theme = theme)

        expect_identical(pub_meta(ht), list(id = "slopes", caption = "Slopes"))
        expect_identical(
            unname(huxtable::header_rows(ht)),
            c(TRUE, FALSE, FALSE, FALSE)
        )
        expect_identical(pub_table_rows(ht)$footnote, 4L)
        expect_identical(pub_table_rows(pub_table(ht, theme = theme))$footnote, 4L)
    })

    it("lets `...` override the colour of single border sides", {
        theme <- pub_table_theme(border_color = "red", top_border_color = "blue")

        expect_identical(theme$properties$top_border_color, "blue")
        expect_identical(theme$properties$left_border_color, "red")
    })

    it("applies further cell properties of the theme", {
        theme <- pub_table_theme(font = "Arial", top_padding = 2)

        ht <- pub_table(df, theme = theme)

        expect_true(all(huxtable::font(ht) == "Arial"))
        expect_true(all(huxtable::top_padding(ht) == 2))
    })

    it("takes the default theme from the option pubflow.table_theme", {
        withr::local_options(
            pubflow.table_theme = pub_table_theme(font_size = 7)
        )

        expect_true(all(huxtable::font_size(pub_table(df)) == 7))
    })

    it("stores factors, dates and times (in UTC) as text", {
        withr::local_timezone("Asia/Tokyo")
        x <- data.frame(
            f = factor("b", levels = c("a", "b")),
            d = as.Date("2024-01-02"),
            t = as.POSIXct("2024-01-02 23:30:00", tz = "America/New_York"),
            ok = TRUE
        )

        expect_identical(
            cells(pub_table(x))[2, ],
            c("b", "2024-01-02", "2024-01-03 04:30:00 UTC", "TRUE")
        )
    })

    it("accepts matrices and data without rows", {
        m <- matrix(c(1, 2, 3, 4), 2, dimnames = list(NULL, c("a", "b")))

        expect_identical(
            cell_text(pub_table(m)),
            rbind(c("a", "b"), c("1.0000", "3.0000"), c("2.0000", "4.0000"))
        )
        expect_identical(
            cell_text(pub_table(data.frame(a = character(0), b = numeric(0)))),
            rbind(c("a", "b"))
        )
    })

    it("frames a header-only table and finishes a huxtable without rows", {
        ht <- pub_table(data.frame(a = character(0)), footnotes = c(a = "N."))
        hx <- huxtable::as_hux(data.frame(a = character(0)), add_colnames = FALSE)

        empty <- pub_table(hx, caption = "Empty")

        expect_identical(cell_text(ht)[, 1], c("a\u00b9", "\u00b9 N."))
        expect_identical(border(ht, "top")[1, 1], 0.8)
        expect_identical(border(ht, "bottom")[, 1], c(0.8, 0))
        expect_identical(dim(empty), c(0L, 1L))
        expect_identical(huxtable::caption(empty), "Empty")
    })

    it("marks footnotes and sets labels in the label row below a spanner", {
        ht <- pub_table(
            data.frame(a = 1, b = 2),
            header = c(b = "S"),
            footnotes = c(b = "N.")
        )

        relabelled <- pub_table(ht[1:3, ], labels = c(a = "A"))

        expect_identical(cell_text(ht)[1:2, 2], c("S", "b\u00b9"))
        expect_identical(
            cell_text(relabelled)[1:2, ],
            rbind(c("", "S"), c("A", "b\u00b9"))
        )
    })

    it("keeps its text when huxtable merges cells", {
        ht <- pub_table(data.frame(a = c("x", "x"), b = c(1 / 3, 2)))

        merged <- huxtable::merge_cells(ht, 2:3, 1)

        expect_identical(cells(merged), cells(ht))
        expect_identical(cell_text(merged), cell_text(ht))
    })

    it("finishes a huxtable", {
        hx <- huxtable::as_hux(data.frame(g = c("a", "a"), x = c(0.125, 2)))

        ht <- pub_table(
            hx,
            caption = "Finished",
            labels = c(x = "X"),
            digits = c(x = 2),
            merge = "g",
            align = c(g = "center"),
            footnotes = c(x = "Note.")
        )

        expect_identical(class(ht), c("huxtable", "data.frame"))
        expect_identical(
            cell_text(ht),
            rbind(
                c("g", "X\u00b9"),
                c("a", "0.13"),
                c("a", "2.00"),
                c("\u00b9 Note.", "\u00b9 Note.")
            )
        )
        expect_identical(huxtable::caption(ht), "Finished")
        expect_identical(unname(huxtable::rowspan(ht)[2, 1]), 2)
        expect_true(all(huxtable::align(ht)[1:3, 1] == "center"))
        expect_identical(
            unname(huxtable::header_rows(ht)),
            c(TRUE, FALSE, FALSE, FALSE)
        )
    })

    it("finishes a table combined with huxtable's rbind()", {
        a <- pub_table(data.frame(batch = "A", y = 1.5), digits = c(y = 1))
        b <- pub_table(data.frame(batch = "B", y = 2.25), digits = c(y = 1))
        stacked <- rbind(a, b[!huxtable::header_rows(b), ])
        expect_identical(border(stacked, "bottom")[, 1], c(0.4, 0.8, 0.8))

        ht <- pub_table(stacked, footnotes = c(batch = "Lots."))

        expect_identical(cell_text(ht)[, 1], c("batch\u00b9", "A", "B", "\u00b9 Lots."))
        expect_identical(cell_text(ht)[2:3, 2], c("1.5", "2.3"))
        expect_identical(border(ht, "bottom")[, 1], c(0.4, 0, 0.8, 0))
        expect_identical(border(ht, "top")[1, 1], 0.8)
    })

    it("converts typed columns of a huxtable to huxtable's text", {
        hx <- huxtable::as_hux(
            data.frame(x = 1 / 3, d = as.Date("2024-05-06")),
            add_colnames = FALSE
        )

        ht <- pub_table(hx, digits = c(x = 3), merge = "x")

        expect_true(all(vapply(ht, is.character, logical(1))))
        expect_identical(cells(ht)[1, ], c("0.333333333333333", "2024-05-06"))
        expect_identical(cell_text(ht)[1, ], c("0.333", "2024-05-06"))
    })

    it("keeps labels of typed columns as text when finishing a huxtable", {
        hx <- huxtable::hux(
            f = factor("001"),
            d = as.Date("2024-05-06"),
            add_colnames = FALSE,
            autoformat = FALSE
        )
        expect_identical(huxtable::number_format(hx)[[1, 1]], "%.3g")

        ht <- pub_table(hx)

        expect_identical(cell_text(ht)[1, ], c("001", "2024-05-06"))
        expect_true(all(is.na(unlist(huxtable::number_format(ht)))))
    })

    it("keeps numeric columns of a huxtable without number format numeric", {
        hx <- huxtable::as_hux(data.frame(x = c(1 / 3, NA)), add_colnames = FALSE)
        huxtable::number_format(hx) <- NA

        ht <- pub_table(hx, na = "-")

        expect_identical(cells(ht)[, 1], c("0.333333333333333", NA))
        expect_identical(cell_text(ht)[, 1], c("0.333333333333333", "-"))
        expect_identical(unname(huxtable::align(ht)[, 1]), c("right", "right"))
    })

    it("validates its input", {
        hx <- huxtable::as_hux(df)
        expect_error(pub_table(1:3), "data.frame or matrix")
        expect_error(pub_table(data.frame()), "data.frame or matrix")
        expect_error(pub_table(df, caption = 1), "`caption` must be")
        expect_error(pub_table(df, na = NA), "`na` must be")
        expect_error(pub_table(df, labels = c("A")), "named by column")
        expect_error(
            pub_table(df, labels = c(foo = "A")),
            "unknown columns: foo"
        )
        expect_error(pub_table(df, labels = c(n = 1)), "`labels` must be")
        expect_error(pub_table(df, header = c(n = NA)), "`header` must be")
        expect_error(pub_table(df, footnotes = c(n = 1)), "`footnotes` must")
        expect_error(pub_table(df, footnotes = c(n = " ")), "must not be blank")
        expect_error(
            pub_table(df, labels = c(n = "A", n = "B")),
            "`labels` names columns more than once: n."
        )
        expect_error(pub_table(df, digits = c(n = 1, n = 2)), "more than once")
        expect_error(pub_table(df, digits = c(n = -1)), "whole numbers")
        expect_error(pub_table(df, digits = c(n = "2")), "whole numbers")
        expect_error(pub_table(df, digits = c(n = 1.5)), "whole numbers")
        expect_error(pub_table(df, digits = c(n = Inf)), "whole numbers")
        expect_error(pub_table(hx, digits = c(n = Inf)), "whole numbers")
        expect_error(pub_table(df, digits = c(n = 325)), "from 0 to 324")
        expect_error(pub_table(df, align = c(n = "top")), "\"left\", \"right\"")
        expect_error(pub_table(df, font_size = 0), "`font_size` must")
        expect_error(pub_table(df, font_size = NA_real_), "`font_size` must")
        expect_error(pub_table(df, font_size = c(8, 9)), "`font_size` must")
        expect_error(pub_table(df, caption = NA_character_), "`caption` must")
        expect_error(pub_table(df, merge = NA_character_), "character vector")
        expect_error(pub_table(df, align = c(n = NA)), "\"left\", \"right\"")
        expect_error(pub_table(df, theme = list()), "pub_table_theme")
        expect_error(
            pub_table(data.frame(a = 1, a = 2, check.names = FALSE)),
            "unique, non-empty names"
        )
        expect_error(
            pub_table(rlang::set_names(data.frame(1), NA_character_)),
            "unique, non-empty names"
        )
        expect_error(pub_table(data.frame(a = I(list(1)))), "List columns")
        listCol <- huxtable::as_hux(data.frame(a = 1), add_colnames = FALSE)
        listCol[[1]] <- list(1)
        expect_error(pub_table(listCol), "List columns")
        expect_error(pub_table(hx, header = c(n = "x")), "needs a data.frame")
        headerless <- huxtable::as_hux(df, add_colnames = FALSE)
        expect_error(pub_table(headerless, labels = c(n = "N")), "header row")
        expect_error(pub_table(headerless, footnotes = c(n = "x")), "header row")
    })
})


# ======================================================================================
# Styling tables
# ======================================================================================

# ----
# Rows
# ----

describe("pub_table_rows()", {
    df <- data.frame(batch = c("A", "B"), slope = c(0.5, 1.5))
    note <- c(slope = "Per month.")

    it("gives the rows by role, as the theme's style function gets them", {
        seen <- NULL
        theme <- pub_table_theme(style = function(ht, rows) {
            seen <<- rows
            ht
        })

        ht <- pub_table(
            df,
            header = c(slope = "Model"),
            footnotes = note,
            theme = theme
        )

        expected <- list(header = 1:2, spanner = 1L, body = 3:4, footnote = 5L)
        expect_identical(pub_table_rows(ht), expected)
        expect_identical(seen, expected)
        expect_identical(
            pub_table_rows(pub_table(df[0, ])),
            list(
                header = 1L,
                spanner = integer(0),
                body = integer(0),
                footnote = integer(0)
            )
        )
    })

    it("survives styling with huxtable and pubflow's functions", {
        ht <- pub_table(df, footnotes = note) |>
            huxtable::set_bold(2, 1) |>
            pub_strikeout(3, 2) |>
            pub_set_meta(id = "slopes")

        expect_identical(pub_table_rows(ht)$footnote, 4L)
    })

    it("fails after binding or subsetting until the table is finished again", {
        ht <- pub_table(df, footnotes = note)
        changed <- list(
            rbind(ht, ht[2, ]),
            ht[1:3, ],
            cbind(ht, ht),
            huxtable::add_footnote(ht, "More."),
            huxtable::set_header_rows(ht, 2, TRUE)
        )
        for (x in changed) {
            expect_error(pub_table_rows(x), "finish it with `pub_table\\(\\)`")
        }

        both <- pub_table(rbind(ht[1:3, ], ht[2:3, ]))

        expect_identical(pub_table_rows(both)$body, 2:5)
    })

    it("keeps footnotes as footnotes when a table is finished again", {
        theme <- pub_table_theme(style = function(ht, rows) {
            huxtable::italic(ht)[rows$footnote, ] <- TRUE
            ht
        })
        ht <- pub_table(df, footnotes = note, theme = theme)

        again <- pub_table(
            ht,
            labels = c(batch = "Batch", slope = "Slope"),
            digits = c(slope = 2),
            theme = theme
        )

        expect_identical(pub_table_rows(again), pub_table_rows(ht))
        expect_identical(cell_text(again)[1, ], c("Batch", "Slope\u00b9"))
        expect_identical(cell_text(again)[2:3, 2], c("0.50", "1.50"))
        expect_identical(
            huxtable::number_format(again)[4, ],
            huxtable::number_format(ht)[4, ]
        )
        expect_identical(border(again, "bottom")[, 1], c(0.4, 0, 0.8, 0))
        expect_true(all(huxtable::italic(again)[4, ]))
        expect_error(
            pub_table(ht, footnotes = c(batch = "Lots.")),
            "give all footnotes in one"
        )
    })

    it("keeps only the footnote markers it set when labels change", {
        area <- data.frame(a = 1, b = 2)
        ht <- pub_table(
            area,
            labels = c(a = "Area m\u00b2", b = "R\u00b2"),
            footnotes = c(b = "Adjusted.")
        )
        expect_identical(cell_text(ht)[1, ], c("Area m\u00b2", "R\u00b2\u00b9"))

        again <- pub_table(ht, labels = c(a = "Area", b = "R"))

        expect_identical(cell_text(again)[1, ], c("Area", "R\u00b9"))
    })

    it("validates its input", {
        expect_error(pub_table_rows(df), "huxtable")
        expect_error(pub_table_rows(huxtable::hux(df)), "unknown")
    })
})


# ======================================================================================
# Strikeout
# ======================================================================================

# ------------
# Struck cells
# ------------

describe("pub_strikeout()", {
    criteria <- data.frame(name = c("R*2_adj", "", "Ratio"), min = c(0.8, NA, 2.705))
    table <- function() {
        pub_table(criteria, digits = c(min = 2), na = "-")
    }

    it("strikes the display text through as huxtable Markdown", {
        ht <- pub_strikeout(table(), 2:4)

        expect_identical(
            cell_text(ht)[-1, ],
            rbind(
                c("~~R\\*2\\_adj~~", "~~0.80~~"),
                c("", "~~-~~"),
                c("~~Ratio~~", "~~2.71~~")
            )
        )
        expect_true(all(huxtable::markdown(ht)[-1, ]))
        expect_false(any(huxtable::markdown(ht)[1, ]))
        expect_true(all(is.na(unlist(huxtable::number_format(ht)[-1, ]))))
        expect_identical(cell_text(ht)[1, ], c("name", "min"))
    })

    it("escapes the syntax of pubflow's Markdown, not only CommonMark's", {
        ht <- pub_table(data.frame(a = c("$5 and $6", "x^2^ @fig:x {.c}")))

        expect_identical(
            cell_text(pub_strikeout(ht, 2:3))[-1, 1],
            c("~~\\$5 and \\$6~~", "~~x\\^2\\^ \\@fig:x \\{.c\\}~~")
        )
    })

    it("strikes each line of a text cell through", {
        ht <- pub_table(data.frame(a = "- a\n\n b\n"))

        expect_identical(cell_text(pub_strikeout(ht, 2))[2, 1], "~~- a~~  \n~~b~~")
    })

    it("selects cells like huxtable's setters", {
        ht <- table()

        expect_identical(
            cell_text(pub_strikeout(ht, 2, "min"))[2, ],
            c("R*2_adj", "~~0.80~~")
        )
        expect_identical(
            cell_text(pub_strikeout(ht, huxtable::final(1), huxtable::everywhere))[4, ],
            c("~~Ratio~~", "~~2.71~~")
        )
        expect_identical(cell_text(pub_strikeout(ht))[1, ], c("~~name~~", "~~min~~"))
    })

    it("leaves struck cells alone and keeps Markdown cells unescaped", {
        ht <- pub_strikeout(table(), 4)
        md <- huxtable::set_contents(table(), 2, 1, "**bold**") |>
            huxtable::set_markdown(2, 1)

        expect_identical(
            cell_text(pub_strikeout(ht, 4))[4, ],
            c("~~Ratio~~", "~~2.71~~")
        )
        expect_identical(cell_text(pub_strikeout(md, 2, 1))[2, 1], "~~**bold**~~")
    })

    it("strikes partly struck Markdown cells through as a whole", {
        md <- huxtable::set_contents(table(), 2, 1, "~~A~~ and ~~B~~") |>
            huxtable::set_markdown(2, 1)

        ht <- pub_strikeout(md, 2, 1)

        expect_identical(cell_text(ht)[2, 1], "~~A and B~~")
        expect_identical(cell_text(pub_strikeout(ht, 2, 1))[2, 1], "~~A and B~~")
    })

    it("strikes each line of Markdown cells after its block markers", {
        strike <- \(text) {
            md <- huxtable::set_contents(table(), 2, 1, text) |>
                huxtable::set_markdown(2, 1)
            cell_text(pub_strikeout(md, 2, 1))[2, 1]
        }

        expect_identical(strike("~~a~~\n\n~~b~~"), "~~a~~\n\n~~b~~")
        expect_identical(strike("a\n\nb"), "~~a~~\n\n~~b~~")
        expect_identical(strike("# ~~h~~"), "# ~~h~~")
        expect_identical(strike("## h ~~x~~"), "## ~~h x~~")
        expect_identical(strike("- a\n- **b**"), "- ~~a~~\n- ~~**b**~~")
        expect_identical(strike("> 1. a"), "> 1. ~~a~~")
        expect_identical(strike("-1 and #2"), "~~-1 and #2~~")
        # hard line breaks stay after the strikeout
        expect_identical(strike("a  \nb"), "~~a~~  \n~~b~~")
        expect_identical(strike("a\\\nb"), "~~a~~\\\n~~b~~")
        expect_identical(strike("a\\\\\nb"), "~~a\\\\~~\n~~b~~")
        expect_identical(strike("a \nb"), "~~a~~\n~~b~~")
    })

    it("strikes through only the selected cells", {
        ht <- table()

        expect_identical(pub_strikeout(ht, integer(0)), ht)
        expect_identical(
            cell_text(pub_strikeout(pub_table(data.frame(a = " x ")), 2))[2, 1],
            "~~x~~"
        )
    })

    it("treats Markdown that is not one struck paragraph as not struck", {
        expect_true(.is_struck("~~A~~"))
        expect_false(.is_struck("~~A~~ and B"))
        expect_false(.is_struck("# ~~A~~"))
        expect_false(.is_struck("~~A~~\n\n~~B~~"))
    })

    it("survives huxtable's rbind(), cbind() and [", {
        ht <- pub_strikeout(table(), 3)

        stacked <- rbind(ht, ht[-1, ])
        side <- cbind(ht, ht)
        sub <- ht[c(1, 3), ]

        expect_identical(
            unname(huxtable::markdown(stacked)[, 2]),
            c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE)
        )
        expect_identical(cell_text(side)[3, ], rep(c("", "~~-~~"), 2))
        expect_identical(cell_text(sub)[2, 2], "~~-~~")
        expect_true(huxtable::markdown(sub)[2, 2])
    })

    it("shows the cells struck through in every huxtable writer", {
        out <- .display_huxtable(pub_strikeout(table(), 4, "min"))

        expect_match(huxtable::to_html(out), "<del>2.71</del>", fixed = TRUE)
        expect_match(huxtable::to_latex(out), "\\sout{2.71}", fixed = TRUE)
        expect_match(huxtable::to_typst(out), "#strike[2.71]", fixed = TRUE)
        expect_match(huxtable::to_md(out), "~~2.71~~", fixed = TRUE)
    })

    it("validates its input", {
        expect_error(pub_strikeout(data.frame(a = 1)), "must be a huxtable")
        expect_error(pub_strikeout(NULL), "must be a huxtable")
    })
})


# ======================================================================================
# Themes and parameter tables
# ======================================================================================

# -----------
# Table theme
# -----------

describe("pub_table_theme()", {
    it("has defaults: 9 pt, booktabs, 4 decimal places", {
        theme <- pub_table_theme()

        expect_s3_class(theme, "pub_table_theme")
        expect_identical(theme$font_size, 9)
        expect_identical(theme$borders, "booktabs")
        expect_identical(theme$number_format, 4L)
        expect_identical(theme$properties, list())
        expect_null(theme$border_width)
        expect_null(theme$style)
    })

    it("accepts every supported number format", {
        formats <- list(2L, "%.1f", "%.2e", "%.3g", "Mean: %.1f %%", \(x) "x", NA)
        for (fmt in formats) {
            expect_identical(pub_table_theme(number_format = fmt)$number_format, fmt)
        }
        expect_identical(
            cell_text(pub_table(
                data.frame(x = 1.25),
                theme = pub_table_theme(number_format = 1)
            ))[2],
            "1.3"
        )
    })

    it("validates its input", {
        expect_error(pub_table_theme(font_size = -1), "`font_size`")
        expect_error(pub_table_theme(font_size = "9"), "`font_size`")
        expect_error(pub_table_theme(font_size = c(8, 9)), "`font_size`")
        expect_error(pub_table_theme(borders = "none"), "must be one of")
        expect_error(pub_table_theme(number_format = -1), "`number_format`")
        expect_error(pub_table_theme(number_format = list()), "`number_format`")
        expect_error(
            pub_table_theme(number_format = "%d"),
            "one %.nf, %.ne or %.ng conversion",
            fixed = TRUE
        )
        expect_error(pub_table_theme(number_format = "%5.2f"), "`number_format`")
        expect_error(pub_table_theme("Arial"), "must be named")
        expect_error(pub_table_theme(na_string = "-"), "pubflow manages")
        expect_error(pub_table_theme(top_border = 1), "pubflow manages")
        expect_error(pub_table_theme(colour = "red"), "Unrecognized")
        expect_error(pub_table_theme(border_color = 1), "`border_color`")
        expect_error(pub_table_theme(border_color = ""), "`border_color`")
        expect_error(pub_table_theme(border_color = c("a", "b")), "`border_color`")
        expect_error(pub_table_theme(border_width = 0), "`border_width`")
        expect_error(pub_table_theme(border_width = c(1, 2)), "`border_width`")
        expect_error(pub_table_theme(style = "bold"), "`style` must be a function")
    })
})


# ----------------
# Parameter tables
# ----------------

describe("pub_params_table()", {
    params <- param_config(
        alpha = numeric_param(0.05, label = "Alpha", description = "Level"),
        trans = choice_param(
            "log",
            c("none", "log"),
            label = "Transformation",
            area = "analysis"
        ),
        limits = param_group(
            list(
                lower = numeral_param("1", label = "Lower"),
                upper = numeral_param("2", label = "Upper")
            ),
            label = "Limits"
        )
    )

    it("lists labels, values and descriptions by default", {
        ht <- pub_params_table(params, caption = "Parameters")

        expect_identical(
            cells(ht),
            rbind(
                c("Parameter", "Value", "Description"),
                c("Alpha", "0.05", "Level"),
                c("Transformation", "log", "Transformation"),
                c("Limits", "Lower: 1, Upper: 2", "Limits")
            )
        )
        expect_identical(huxtable::caption(ht), "Parameters")
    })

    it("shows the requested fields, incl. names and other attributes", {
        ht <- pub_params_table(
            params[1:2],
            columns = c(name = "Name", value = "Value", area = "Area")
        )

        expect_identical(
            cells(ht),
            rbind(
                c("Name", "Value", "Area"),
                c("alpha", "0.05", ""),
                c("trans", "log", "analysis")
            )
        )
    })

    it("shows date-times in UTC", {
        withr::local_timezone("Asia/Tokyo")
        time <- as.POSIXct("2024-01-02 23:30:00", tz = "America/New_York")

        ht <- pub_params_table(list(when = param(time, label = "When")))

        expect_identical(cells(ht)[2, 1:2], c("When", "2024-01-03 04:30:00 UTC"))
    })

    it("lists the members of a group that have a value", {
        group <- \(lower, upper) {
            param_group(list(
                lower = numeral_param(lower, label = "Lower"),
                upper = param(upper, label = "Upper")
            ))
        }
        ht <- pub_params_table(list(
            both = group("1", "x"),
            one = group("", "x"),
            none = group(NA_character_, " ")
        ))

        expect_identical(
            pub_cell_text(ht)[-1, 2],
            c("Lower: 1, Upper: x", "Upper: x", "")
        )
    })

    it("shows empty values (not empty attributes) as `na`", {
        ht <- pub_params_table(
            list(
                a = NULL,
                b = NA,
                c = c("", " "),
                d = list(NA, NA),
                e = c(1, NA),
                f = param("x", description = "")
            ),
            na = "-"
        )

        expect_identical(
            pub_cell_text(ht)[-1, 2],
            c("-", "-", "-", "-", "1, NA", "x")
        )
        expect_identical(pub_cell_text(ht)[-1, 3], rep("", 6))
    })

    it("shows plain values with their name as label", {
        ht <- pub_params_table(list(n = 3, empty = NULL))

        expect_identical(
            pub_cell_text(ht),
            rbind(
                c("Parameter", "Value", "Description"),
                c("n", "3", ""),
                c("empty", "", "")
            )
        )
    })

    it("works for the params of a pipeline", {
        p <- demo_pipeline()

        ht <- pub_params_table(pub_get_params(p, source = "user"))

        expect_identical(nrow(ht), 11L)
        expect_identical(
            cells(ht)[2, ],
            c("Report title", "Quality demo", "Report title")
        )
    })

    it("shows each of several values of the same name", {
        ht <- pub_params_table(list(a = 1, a = 2))

        expect_identical(cells(ht)[-1, 1:2], rbind(c("a", "1"), c("a", "2")))
    })

    it("shows an empty text for attributes a field does not have", {
        ht <- pub_params_table(params[1], columns = c(unit = "Unit"))

        expect_identical(cells(ht), rbind("Unit", ""))
    })

    it("returns a header-only table for no params", {
        ht <- pub_params_table(list())

        expect_identical(
            cells(ht),
            rbind(c("Parameter", "Value", "Description"))
        )
    })

    it("validates its input", {
        expect_error(pub_params_table(list(1)), "named list")
        expect_error(pub_params_table("a"), "named list")
        expect_error(pub_params_table(params, columns = "x"), "named character")
        expect_error(pub_params_table(params, columns = character(0)), "named char")
        expect_error(pub_params_table(params, columns = c(a = 1)), "named character")
        expect_error(pub_params_table(NULL), "named list")
        expect_error(pub_params_table(params, na = NA), "`na` must be a single string")
        expect_error(pub_params_table(params, caption = 1), "`caption` must")
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# ------------------
# Report-like tables
# ------------------

describe("report tables", {
    it("show every table feature of a report", {
        # status font colours, bold, spanner row, footnote, vertical merge, auto-width
        # and centred column
        data <- data.frame(
            batch = c("A", "A"),
            test = c("Assay", "pH"),
            value = c(99.123, 7.05),
            status = c("validated", "recorded"),
            note = c("A long comment that wraps.", "-")
        )
        ht <- pub_table(
            data,
            labels = c(batch = "Batch number"),
            digits = c(value = 1),
            header = c(value = "Result", status = "Result"),
            footnotes = c(batch = "Batch footnote."),
            merge = "batch",
            widths = c(note = "auto"),
            align = c(test = "center")
        )
        rows <- pub_table_rows(ht)$body[1:2]
        ht <- ht |>
            huxtable::set_text_color(rows, "value", c("black", "#00B050")) |>
            huxtable::set_bold(rows[[2L]], "status")

        text <- cell_text(ht)
        expect_identical(text[2, 1], "Batch number\u00b9")
        expect_identical(text[1, 3:4], c("Result", "Result"))
        expect_identical(unname(huxtable::colspan(ht)[1, 3]), 2)
        expect_identical(unname(huxtable::rowspan(ht)[3, 1]), 2)
        expect_identical(
            unname(huxtable::text_color(ht)[3:4, 3]),
            c("black", "#00B050")
        )
        expect_identical(unname(huxtable::bold(ht)[3:4, 4]), c(FALSE, TRUE))
        expect_identical(text[3:4, 3], c("99.1", "7.1"))
        expect_true(all(huxtable::align(ht)[2:4, 2] == "center"))
        expect_identical(unname(huxtable::col_width(ht))[[5]], "auto")
        expect_identical(text[5, 1], "\u00b9 Batch footnote.")
    })

    it("build the batch summary from the stacked per-batch data", {
        ht <- report_summary_table()

        expect_identical(
            cell_text(ht)[, 1:3],
            rbind(
                c("Batch number", "Parameter", "Estimate"),
                c("A", "Intercept", "100.123"),
                c("A", "Slope", "-0.251"),
                c("B", "Intercept", "100.123"),
                c("B", "Slope", "-0.300"),
                c("C", "Intercept", "100.123"),
                c("C", "Slope", "-0.126")
            )
        )
        expect_identical(cell_text(ht)[3, 4:6], c("0.054", "10", "0.0123"))
        expect_identical(unname(huxtable::rowspan(ht)[, 1]), c(1, 2, 1, 2, 1, 2, 1))
        expect_identical(
            unname(huxtable::text_color(ht)[c(2, 4, 6), 1]),
            c("#1B9E77", "#D95F02", "#7570B3")
        )
        expect_match(pub_meta(ht, "caption"), "^Summary of linear regression")
    })

    it("split the trend assessment combined across tests by batch", {
        tables <- report_trend_by_batch()

        expect_named(tables, c("A", "B"))
        expect_identical(
            cell_text(tables$B),
            rbind(
                c("Batch", "Test", "Estimated trend (months)"),
                c("B", "Assay", "36"),
                c("B", "Impurity A", "24")
            )
        )
        expect_identical(
            pub_meta(tables$A, "caption"),
            "Current trend assessment of batch A"
        )
        expect_true(all(huxtable::align(tables$A)[, 2] == "center"))
    })

    it("show test-status colours under a time spanner", {
        ht <- report_data_table()

        expect_identical(
            cell_text(ht)[1:3, ],
            rbind(
                c("", rep("Time [months]", 3)),
                c("Batch number", "0", "3", "6"),
                c("A", "100.0", "99.1", "98.4")
            )
        )
        expect_identical(cell_text(ht)[4, 4], "-")
        expect_identical(
            unname(huxtable::text_color(ht)[3:5, 2]),
            c("black", "blue", "#00B050")
        )
        expect_identical(unname(huxtable::text_color(ht)[4, 4]), "black")
    })

    it("show the p-value in bold and coloured", {
        ht <- report_pvalue_table(pInteraction = 0.31)

        expect_identical(unname(huxtable::text_color(ht)[4, 4]), "#006400")
        expect_true(huxtable::bold(ht)[4, 4])
        expect_identical(sum(huxtable::bold(ht)[-1, ]), 1L)
        expect_identical(
            unname(huxtable::text_color(report_pvalue_table(0.1))[4, 4]),
            "#8B0000"
        )
        expect_identical(cell_text(ht)[4:5, 3], c("1.300", ""))
    })

    it("give the deviation table wrapping columns and a small font", {
        ht <- report_wrapped_table()

        expect_identical(
            unname(huxtable::col_width(ht)),
            c("2.5cm", "auto", "auto", "1")
        )
        expect_true(all(huxtable::font_size(ht) == 8))
    })

    it("put the batch numbers into a footnote", {
        ht <- report_footnote_table()

        expect_identical(
            cell_text(ht)[c(1, 4), 1],
            c("Parameter\u00b9", "\u00b9 Batch numbers: A, B, C")
        )
    })
})

describe("slope summary tables", {
    it("show separate and common slope fits under their spanners", {
        ht <- slopes_summary_table()

        expect_identical(
            cell_text(ht)[1:3, ],
            rbind(
                c("", rep("Separate slope", 4), rep("Common slope", 3)),
                c(
                    "Sample",
                    "Intercept",
                    "Slope",
                    "R\u00b2",
                    "Slope Ratio",
                    "Slope",
                    "R\u00b2",
                    "Rel. Potency [%]"
                ),
                c("Ref", "1.235", "0.988", "0.99", "", "", "", "")
            )
        )
        expect_identical(unname(huxtable::colspan(ht)[1, ]), c(1, 4, 1, 1, 1, 3, 1, 1))
        expect_identical(cell_text(ht)[5, 6:8], c("0.991", "0.98", "98"))
        expect_identical(
            pub_meta(ht, "caption"),
            "Overall summary of separate and common slope fits."
        )
    })

    it("add a merged serotype column", {
        ht <- slopes_summary_table(serotype = "6B")

        expect_identical(
            cell_text(ht)[1:3, 1:2],
            rbind(c("", ""), c("Serotype", "Sample"), c("6B", "Ref"))
        )
        expect_identical(unname(huxtable::rowspan(ht)[, 1]), c(1, 1, 3, 1, 1))
        expect_identical(
            unname(huxtable::colspan(ht)[1, ]),
            c(1, 1, 4, 1, 1, 1, 3, 1, 1)
        )
    })

    it("show deactivated criteria grey and struck through", {
        ht <- slopes_criteria_table()
        grey <- "#d3c8c8"

        expect_identical(
            cell_text(ht)[2:3, ],
            rbind(c("Slope ratio", "0.80", "1.25"), c("~~R\u00b2~~", "~~0.95~~", ""))
        )
        expect_identical(cell_text(ht)[5, ], c("~~Parallelism~~", "", "~~0.05~~"))
        expect_identical(
            unname(huxtable::text_color(ht)[, 3]),
            c(NA, NA, grey, NA, grey)
        )
    })
})


# ------------------
# huxtable behaviour
# ------------------

# A failure here means huxtable changed
describe("huxtable 6.0.2 behaviour pubflow relies on", {
    part <- function(batch, color) {
        ht <- pub_table(
            data.frame(batch = batch, y = c(0.125, NA, 1)),
            caption = paste("Batch", batch),
            digits = c(y = 2),
            na = "-",
            merge = "batch"
        )
        ht <- huxtable::set_text_color(ht, 2:4, "y", color)
        pub_set_meta(pub_strikeout(ht, 4, "y"), title = batch)
    }

    it("rbind(), cbind() and [ keep cell properties", {
        a <- part("A", "red")
        b <- part("B", "blue")

        stacked <- rbind(a, b[!huxtable::header_rows(b), ])
        side <- cbind(a, b)
        sub <- stacked[c(1, 5:7), ]

        expect_identical(
            cell_text(stacked)[, 2],
            c("y", rep(c("0.13", "-", "~~1.00~~"), 2))
        )
        expect_identical(
            unname(huxtable::text_color(stacked)[, 2]),
            c(NA, rep(c("red", "blue"), each = 3))
        )
        expect_identical(
            unname(huxtable::rowspan(stacked)[, 1]),
            c(1, 3, 1, 1, 3, 1, 1)
        )
        expect_identical(unname(huxtable::header_rows(stacked)), c(TRUE, rep(FALSE, 6)))
        expect_identical(
            cell_text(side)[, c(2, 4)],
            cbind(c("y", "0.13", "-", "~~1.00~~"), c("y", "0.13", "-", "~~1.00~~"))
        )
        expect_identical(unname(huxtable::rowspan(side)[2, c(1, 3)]), c(3, 3))
        expect_identical(cell_text(sub), cell_text(b))
        expect_identical(unname(huxtable::rowspan(sub)[, 1]), c(1, 3, 1, 1))
    })

    it("rbind() keeps the first caption and metadata, [ and cbind() not", {
        a <- part("A", "red")
        b <- part("B", "blue")

        expect_identical(huxtable::caption(rbind(a, b)), "Batch A")
        expect_identical(huxtable::caption(cbind(a, b)), "Batch A")
        expect_identical(pub_meta(rbind(a, b), "title"), "A")
        expect_null(pub_meta(cbind(a, b), "title"))
        expect_null(pub_meta(a[1:2, ], "title"))
    })

    it("binds by position and keeps each part's borders", {
        a <- pub_table(data.frame(x = 1, y = 2))
        b <- pub_table(data.frame(y = 3, x = 4))

        stacked <- rbind(a, b[-1, ])

        expect_identical(cells(stacked)[3, ], c("3", "4"))
        expect_identical(border(stacked, "bottom")[, 1], c(0.4, 0.8, 0.8))
        spanned <- pub_table(data.frame(z = 1), header = c(z = "S"))
        expect_error(cbind(a, spanned))
    })

    it("keeps character widths, but not numeric widths with NA", {
        ht <- pub_table(data.frame(a = 1, b = 2), widths = c(a = "2cm", b = "auto"))
        rel <- pub_table(data.frame(a = 1, b = 2), widths = c(a = 2))

        expect_identical(unname(huxtable::col_width(ht[2, ])), c("2cm", "auto"))
        expect_identical(
            unname(huxtable::col_width(cbind(ht, ht))),
            rep(c("2cm", "auto"), 2)
        )
        expect_identical(unname(huxtable::col_width(rel[2, ])), c(NA_real_, NA))
    })

    it("maps cell text as numbers and recycles short logical rows", {
        ht <- pub_table(data.frame(p = c(0.01, 0.2)), footnotes = c(p = "N."))

        mapped <- huxtable::map_text_color(
            ht,
            2:3,
            "p",
            huxtable::by_ranges(0.05, c("darkgreen", "darkred"))
        )
        bold <- huxtable::set_bold(ht, c(FALSE, TRUE), 1)

        expect_identical(
            unname(huxtable::text_color(mapped)[2:3, 1]),
            c("darkgreen", "darkred")
        )
        expect_identical(unname(huxtable::bold(bold)[, 1]), c(TRUE, TRUE, FALSE, TRUE))
    })
})
