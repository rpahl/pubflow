# A one-column pubflow table of numbers with the given number format
num_table <- function(x, fmt) {
    ht <- pub_table(data.frame(x = x))
    huxtable::number_format(ht)[-1, 1] <- list(fmt)
    ht
}

body_text <- function(ht) {
    pub_cell_text(ht)[-1, , drop = FALSE]
}


# ---------
# Cell text
# ---------

describe("pub_cell_text() / .format_cells()", {
    it("formats numbers with a whole number of decimal places", {
        ht <- num_table(c(1, 2.5, -3.14159), 2)

        expect_identical(body_text(ht)[, 1], c("1.00", "2.50", "-3.14"))
    })

    it("formats numbers with a sprintf() format", {
        ht <- num_table(c(1, 0.000123, 12345.678), "%.3g")

        expect_identical(body_text(ht)[, 1], c("1", "0.000123", "1.23e+04"))
    })

    it("formats numbers with a function returning one string", {
        ht <- num_table(c(0.5, 0.25), \(x) sprintf("%d%%", round(100 * x)))

        expect_identical(body_text(ht)[, 1], c("50%", "25%"))
    })

    it("shows numbers with as.character() for an NA format", {
        x <- c(1 / 3, 1e5, 0.1 + 0.2)
        typed <- huxtable::as_hux(data.frame(x = x), add_colnames = FALSE)
        huxtable::number_format(typed) <- NA
        theme <- pub_table_theme(number_format = NA)

        expect_identical(cell_text(typed)[, 1], as.character(x))
        expect_identical(
            body_text(pub_table(data.frame(x = x), theme = theme))[, 1],
            as.character(x)
        )
        for (na in list(NA_character_, NA_real_, NA_integer_)) {
            huxtable::number_format(typed) <- na
            expect_identical(cell_text(typed)[, 1], as.character(x))
            expect_s3_class(pub_table_theme(number_format = na), "pub_table_theme")
        }
    })

    it("shows text cells with an NA format as stored", {
        ht <- num_table(c(1 / 3, 2), NA)

        expect_identical(body_text(ht)[, 1], c("0.333333333333333", "2"))
    })

    it("shows the cell's na_string for NA and NaN", {
        ht <- pub_table(data.frame(x = c(1, NA, NaN), y = c("a", NA, "b")), na = "-")
        huxtable::na_string(ht)[3, 2] <- "missing"

        expect_identical(
            body_text(ht),
            rbind(c("1.0000", "a"), c("-", "missing"), c("-", "b"))
        )
    })

    it("shows factors by their labels", {
        f <- factor(c("low", "high", NA), levels = c("low", "high"))
        typed <- huxtable::as_hux(data.frame(f = f), add_colnames = FALSE)

        expect_identical(cell_text(typed)[, 1], c("low", "high", ""))
        expect_identical(
            body_text(pub_table(data.frame(f = f), na = "-"))[, 1],
            c("low", "high", "-")
        )
    })

    it("shows dates and date-times in UTC", {
        d <- as.Date(c("2024-01-02", NA))
        t <- as.POSIXct(c("2024-01-02 10:00:05", NA), tz = "Europe/Berlin")
        typed <- huxtable::as_hux(data.frame(d = d, t = t), add_colnames = FALSE)
        expected <- rbind(
            c("2024-01-02", "2024-01-02 09:00:05 UTC"),
            c("", "")
        )

        expect_identical(cell_text(typed), expected)
        expect_identical(
            body_text(pub_table(data.frame(d = d, t = t))),
            expected
        )
    })

    it("shows logical cells as TRUE/FALSE", {
        ht <- pub_table(data.frame(pass = c(TRUE, FALSE, NA)), na = "-")

        expect_identical(body_text(ht)[, 1], c("TRUE", "FALSE", "-"))
    })

    it("never changes text cells, also not numbers inside text", {
        ht <- pub_table(data.frame(x = c("12.3456 mg", "0.125", "<1e-04")))

        expect_identical(body_text(ht)[, 1], c("12.3456 mg", "0.125", "<1e-04"))
    })

    it("formats a text cell with a number format only if it is a number", {
        ht <- pub_table(data.frame(x = c("12.3456 mg", "0.125", "1e-3")))
        huxtable::number_format(ht)[-1, 1] <- 2

        expect_identical(body_text(ht)[, 1], c("12.3456 mg", "0.13", "0.00"))
    })

    it("recognizes numbers in text cells by their decimal notation", {
        x <- c(" 1 ", "+1", ".5", "5.", "1E3", "-Inf", "1e-400", "1e400")
        nonNumbers <- c("1e", "0x10", "Infinity", "inf", "NA", "", "1,5", "1 2")

        expect_identical(
            body_text(num_table(x, 2))[, 1],
            c("1.00", "1.00", "0.50", "5.00", "1000.00", "-Inf", "0.00", "Inf")
        )
        expect_identical(body_text(num_table(nonNumbers, 2))[, 1], nonNumbers)
    })

    it("shows the na_string for NaN in text cells with a number format", {
        ht <- num_table(c("NaN", "-NaN", "NaN"), 2)
        huxtable::number_format(ht)[4, 1] <- NA
        huxtable::na_string(ht) <- "-"

        expect_identical(body_text(ht)[, 1], c("-", "-", "NaN"))
    })

    it("formats integer columns by their number format", {
        ht <- pub_table(data.frame(n = c(1L, -2L, NA)), na = "-")
        huxtable::number_format(ht)[-1, 1] <- 1

        expect_identical(body_text(ht)[, 1], c("1.0", "-2.0", "-"))
    })

    it("handles tables without body rows", {
        empty <- huxtable::as_hux(data.frame(x = numeric(0)), add_colnames = FALSE)

        expect_identical(pub_cell_text(empty), matrix(character(0), 0, 1))
        expect_identical(dim(.display_huxtable(empty)), c(0L, 1L))
        expect_identical(
            pub_cell_text(pub_table(data.frame(x = numeric(0), y = character(0)))),
            matrix(c("x", "y"), 1, 2)
        )
    })

    it("rounds half away from zero, not as formatC() or round()", {
        x <- c(0.125, 2.675, 2.705, 0.065, 0.285, -2.675, -0.001, 9.995)

        expect_identical(
            body_text(num_table(x, 2))[, 1],
            c("0.13", "2.68", "2.71", "0.07", "0.29", "-2.68", "0.00", "10.00")
        )
        # formatC() rounds the binary value, ties to even; round() differs from it for
        # 2.705 and 0.065 (R >= 4.0.0)
        expect_identical(
            formatC(x, format = "f", digits = 2),
            c("0.12", "2.67", "2.71", "0.07", "0.28", "-2.67", "-0.00", "9.99")
        )
        expect_identical(
            formatC(round(c(2.705, 0.065), 2), format = "f", digits = 2),
            c("2.70", "0.06")
        )
    })

    it("rounds ties away from zero with 0 decimal places", {
        ht <- num_table(c(0.5, 1.5, 2.5, -0.5, -2.5), 0)

        expect_identical(body_text(ht)[, 1], c("1", "2", "3", "-1", "-3"))
    })

    it("rounds sprintf() formats half away from zero", {
        ht <- num_table(c(12.25, -0.04, 1225), "%.1f %%")

        expect_identical(body_text(ht)[, 1], c("12.3 %", "0.0 %", "1225.0 %"))
        expect_identical(body_text(num_table(1225, "%.3g"))[, 1], "1.23e+03")
        # sprintf() rounds the binary value, ties to even
        expect_identical(sprintf("%.1f %%", c(12.25, -0.04)), c("12.2 %", "-0.0 %"))
        expect_identical(sprintf("%.3g", 1225), "1.22e+03")
    })

    it("shows infinite values as Inf and -Inf", {
        ht <- pub_table(data.frame(x = c(Inf, -Inf, 1)), digits = c(x = 2))

        expect_identical(body_text(ht)[, 1], c("Inf", "-Inf", "1.00"))
    })

    it("treats Markdown cells as text, whatever their number format", {
        ht <- huxtable::set_contents(num_table(1, 2), 2, 1, "00123") |>
            huxtable::set_markdown(2, 1)

        expect_identical(body_text(ht)[, 1], "00123")
        expect_identical(body_text(pub_strikeout(ht, 2, 1))[, 1], "~~00123~~")
    })

    it("formats the edge-case table as expected", {
        text <- cell_text(edge_case_table())
        struck <- edge_case_struck()

        expect_identical(text[struck], paste0("~~", edge_case_text()[struck], "~~"))
        text[struck] <- edge_case_text()[struck]
        expect_identical(text, edge_case_text())
    })

    it("rounds numbers as their 15-digit text", {
        x <- 1.015 - 0.01

        ht <- num_table(x, 2)

        expect_identical(as.character(x), "1.005")
        expect_identical(sprintf("%.2f", x), "1.00")
        expect_identical(body_text(ht)[, 1], "1.01")
    })

    it("formats typed numeric columns of plain huxtables", {
        typed <- huxtable::as_hux(
            data.frame(x = c(0.125, 2), n = 1:2),
            add_colnames = FALSE
        )

        expect_identical(cell_text(typed), rbind(c("0.125", "1"), c("2", "2")))
        huxtable::number_format(typed)[, 1] <- 2
        expect_identical(cell_text(typed)[, 1], c("0.13", "2.00"))
    })

    it("formats numbers of huxtables built with column names", {
        ht <- huxtable::as_hux(data.frame(x = c(0.12345, 2)))

        expect_identical(cell_text(ht)[, 1], c("x", "0.123", "2"))
    })

    it("signals an error naming the cell for unsupported formats", {
        expect_error(
            pub_cell_text(num_table(c(1, 2), -1)),
            "table cell \\[2, 1\\]: unsupported number format"
        )
        expect_error(
            pub_cell_text(num_table(1, 1.5)),
            "cell \\[2, 1\\]"
        )
        expect_error(
            pub_cell_text(num_table(1, 325)),
            "unsupported number format \\(use a whole number from 0 to 324"
        )
        expect_identical(
            pub_cell_text(num_table(1, 324))[2L, 1L],
            formatC(1, 324, format = "f")
        )
        expect_error(
            pub_cell_text(num_table(1, c(1, 2))),
            "unsupported number format"
        )
        expect_error(
            pub_cell_text(num_table(c(1, 2), \(x) c("a", "b"))),
            "cell \\[2, 1\\]: number format function must return one string"
        )
        for (f in c("%d", "%5.2f", "%+.2f", "%.2f and %.1f", "%f")) {
            expect_error(
                pub_cell_text(num_table(1.5, f)),
                "cell \\[2, 1\\]: unsupported number format",
                info = f
            )
        }
        expect_error(
            pub_cell_text(num_table(1.5, Inf)),
            "one %.nf, %.ne or %.ng conversion",
            fixed = TRUE
        )
    })

    it("rejects list columns and non-huxtables", {
        ht <- huxtable::as_hux(data.frame(a = I(list(1, "x"))), add_colnames = FALSE)

        expect_error(pub_cell_text(ht), "list columns")
        expect_error(pub_cell_text(data.frame(a = 1)), "must be a huxtable")
    })
})


# --------------
# Number formats
# --------------

describe(".format_numbers() / .apply_number_format()", {
    it("formats each cell by its own format within a column", {
        ht <- num_table(rep(1.25, 5), 1)
        huxtable::number_format(ht)[3, 1] <- "%.2e"
        huxtable::number_format(ht)[4, 1] <- list(\(x) "fun")
        huxtable::number_format(ht)[5, 1] <- 2L
        huxtable::number_format(ht)[6, 1] <- NA

        expect_identical(
            body_text(ht)[, 1],
            c("1.3", "1.25e+00", "fun", "1.25", "1.25")
        )
    })

    it("calls a function format once per value, not for missing values", {
        seen <- numeric(0)
        f <- function(x) {
            seen <<- c(seen, x)
            "v"
        }
        ht <- pub_table(data.frame(x = c(1, NA, Inf, NaN)), na = "-")
        huxtable::number_format(ht)[-1, 1] <- list(f)

        expect_identical(body_text(ht)[, 1], c("v", "-", "v", "-"))
        expect_identical(seen, c(1, Inf))
    })

    it("names the cell when a function format fails", {
        err <- expect_error(
            pub_cell_text(num_table(c(1, 2), \(x) {
                if (x > 1) stop("too big") else "ok"
            })),
            "cell \\[3, 1\\]: number format function failed"
        )
        expect_identical(conditionMessage(err$parent), "too big")
    })

    it("shows the na_string for a function format that returns NA", {
        ht <- num_table(c(1.5, 2), \(x) if (x > 1.8) NA_character_ else "ok")
        huxtable::na_string(ht) <- "n/a"
        expect_identical(pub_cell_text(ht)[-1L, 1L], c("ok", "n/a"))
        expect_error(
            pub_cell_text(num_table(1.5, \(x) NA)),
            "cell \\[2, 1\\]: number format function must return one string"
        )
    })

    it("names the first cell (column by column) with an unsupported format", {
        ht <- pub_table(data.frame(a = 1:2, b = c(1.5, 2), c = 3:4))
        huxtable::number_format(ht)[3, 2] <- "%d"
        huxtable::number_format(ht)[2, 3] <- -1

        expect_error(pub_cell_text(ht), "cell \\[3, 2\\]: unsupported number format")
    })
})


# --------------
# Display tables
# --------------

describe(".display_huxtable()", {
    ht <- pub_table(
        data.frame(x = c(2.705, 0.065, NA), y = c("a", "b", "c")),
        digits = c(x = 2),
        na = "-"
    )

    it("holds the display strings without number formatting", {
        res <- .display_huxtable(ht)

        expect_identical(as.matrix(as.data.frame(res)) |> unname(), cell_text(ht))
        expect_true(all(is.na(unlist(huxtable::number_format(res)))))
        expect_identical(pub_meta(res), pub_meta(ht))
    })

    it("makes every huxtable writer show the formatter's text", {
        res <- .display_huxtable(ht)
        outputs <- list(
            html = huxtable::to_html(res),
            md = huxtable::to_md(res),
            latex = huxtable::to_latex(res),
            typst = huxtable::to_typst(res)
        )

        for (out in outputs) {
            expect_match(out, "2.71", fixed = TRUE)
            expect_match(out, "0.07", fixed = TRUE)
            expect_no_match(out, "2.70", fixed = TRUE)
        }
        # huxtable's own number formatting would round with round()
        expect_match(huxtable::to_md(ht), "2.70", fixed = TRUE)
    })
})
