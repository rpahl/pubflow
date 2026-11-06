# ======================================================================================
# Exported API
# ======================================================================================

# -----------------------
# Rounding and formatting
# -----------------------

describe("pub_round() and pub_format_num()", {
    it("round ties half away from zero", {
        x <- c(0.125, 2.675, 1.005, 0.285, -2.675, -0.001)

        expect_identical(
            pub_format_num(x, 2),
            c("0.13", "2.68", "1.01", "0.29", "-2.68", "0.00")
        )
        expect_identical(
            pub_format_num(c(0.5, 2.5, -0.5, -2.5), 0),
            c("1", "3", "-1", "-3")
        )
        # sprintf() rounds the binary value, exact ties to even
        expect_identical(
            sprintf("%.2f", x),
            c("0.12", "2.67", "1.00", "0.28", "-2.67", "-0.00")
        )
        expect_identical(
            sprintf("%.0f", c(0.5, 2.5, -0.5, -2.5)),
            c("0", "2", "-0", "-2")
        )
    })

    it("carry into a new digit", {
        expect_identical(pub_format_num(c(9.995, -99.995), 2), c("10.00", "-100.00"))
        expect_identical(pub_format_num(c(9.5, 99.5), 0), c("10", "100"))
        expect_identical(pub_format_num(999.5, "%.3g"), "1e+03")
        expect_identical(pub_format_num(9.995, "%.2e"), "1.00e+01")
    })

    it("give no negative zero", {
        expect_identical(pub_format_num(c(-0.001, -0.0049, -0), 2), rep("0.00", 3L))
        expect_identical(pub_format_num(-0.4, 0), "0")
        expect_identical(pub_format_num(-0, "%.2e"), "0.00e+00")
        expect_identical(pub_format_num(-0, "%.3g"), "0")
        expect_identical(1 / pub_round(c(-0.001, -0), 2), c(Inf, Inf))
        expect_identical(
            sprintf(c("%.2f", "%.2e", "%.3g"), -0),
            c("-0.00", "-0.00e+00", "-0")
        )
    })

    it("round near-ties as their 15-digit text", {
        x <- c(mean(c(2.67, 2.68)), 1.015 - 0.01)

        expect_identical(
            sprintf("%.17g", x),
            c("2.6749999999999998", "1.0049999999999999")
        )
        expect_identical(as.character(x), c("2.675", "1.005"))
        expect_identical(pub_format_num(x, 2), c("2.68", "1.01"))
        expect_identical(pub_round(x, 2), c(2.68, 1.01))
        expect_identical(sprintf("%.2f", x), c("2.67", "1.00"))
    })

    it("handle small and large magnitudes", {
        expect_identical(
            pub_format_num(c(1e-20, 123456789.125, 1e5), 2),
            c("0.00", "123456789.13", "100000.00")
        )
        expect_identical(pub_format_num(1e-20, "%.2e"), "1.00e-20")
        expect_identical(pub_format_num(2^60, 0), "1152921504606846976")
        expect_identical(pub_round(2^60), 2^60)
    })

    it("keep finite numbers finite near the largest double", {
        # the 15-digit text of the largest double is above the double range
        big <- c(.Machine$double.xmax, -.Machine$double.xmax)
        expect_identical(pub_round(big, 2), big)
        expect_identical(pub_format_num(big, 0), formatC(big, format = "f", digits = 0))
        expect_identical(pub_format_num(big, "%.2f"), sprintf("%.2f", big))
        expect_identical(pub_format_num(big, "%.3e"), c("1.798e+308", "-1.798e+308"))
        expect_identical(
            pub_format_num(big, "%.14e"),
            c("1.79769313486232e+308", "-1.79769313486232e+308")
        )
        # rounding up beyond the largest double, also at ties
        expect_identical(
            pub_format_num(c(big, 1.795e308), "%.2e"),
            c("1.80e+308", "-1.80e+308", "1.80e+308")
        )
        expect_identical(pub_format_num(1.75e308, "Max: %.1g %%"), "Max: 2e+308 %")
        expect_identical(pub_format_num(1.5e308, "%.0e"), "2e+308")
    })

    it("lay out sprintf() formats with other text", {
        expect_identical(pub_format_num(12.25, "%.1f %%"), "12.3 %")
        expect_identical(pub_format_num(12.25, "%%%.1f"), "%12.3")
        expect_identical(
            pub_format_num(c(12250, 2.5), "%.2e"),
            c("1.23e+04", "2.50e+00")
        )
        expect_identical(pub_format_num(2.5, "%.0e"), "3e+00")
        expect_identical(pub_format_num(c(0.125, 1225), "%.2g"), c("0.13", "1.2e+03"))
        expect_identical(pub_format_num(2.5, "%.0g"), "3")
        formats <- c("%.2e", "%.0e", "%.2g", "%.0g")
        expect_identical(
            sprintf(formats, c(12250, 2.5, 0.125, 2.5)),
            c("1.22e+04", "2e+00", "0.12", "2")
        )
    })

    it("agree with sprintf() except at ties and negative zeros", {
        withr::local_seed(20261010)
        x <- exp(stats::rnorm(5000L, 0, 6)) * sample(c(-1, 1), 5000L, TRUE)
        x <- x[abs(x) < 1e9]

        for (f in c("%.0f", "%.2f", "%.0e", "%.3e", "%.1g", "%.3g", "%.6g")) {
            expected <- sub("^-(0(\\.0+)?)$", "\\1", sprintf(f, x))
            expect_identical(pub_format_num(x, f), expected, info = f)
        }
    })

    it("return the rounded numbers as doubles", {
        x <- c(0.125, 2.675, -2.675, 9.995, -0.001)

        expect_identical(pub_round(x, 2), c(0.13, 2.68, -2.68, 10, 0))
        expect_identical(pub_round(x, 2), as.numeric(pub_format_num(x, 2)))
        expect_identical(pub_round(c(0.5, 2.5, -0.5, -2.5)), c(1, 3, -1, -3))
        expect_identical(pub_round(c(a = 1L, b = NA), 2), c(a = 1, b = NA))
        # round() rounds the binary value, exact ties to even
        expect_identical(round(c(0.125, 2.675), 2), c(0.12, 2.67))
    })

    it("round integers and subnormal numbers, also to many decimal places", {
        expect_identical(pub_round(c(2L, NA, .Machine$integer.max)), c(2, NA, 2^31 - 1))
        expect_identical(pub_round(c(123456.5, -0.5, 0.49), 0L), c(123457, -1, 0))
        expect_identical(pub_round(c(1e22, -1e22), 2), c(1e22, -1e22))
        expect_identical(pub_round(c(5e-324, -5e-324), 2), c(0, 0))
        # beyond the decimal places of the 15-digit text nothing changes
        x <- c(0.1, -5e-324, 1.23456789e-300)
        for (digits in c(338, 400, 1e10, 1e15)) {
            expect_no_warning(res <- pub_round(x, digits))
            expect_identical(res, x, info = format(digits))
        }
        # formatC() lays out the binary value beyond the 15 digits
        x <- c(0.285, 1.005)
        expect_identical(pub_format_num(x, 20), sprintf("%.20f", x))
    })

    it("keep the class and other attributes", {
        x <- structure(c(1.25, -2.5), class = "my_numbers", unit = "%")

        expect_identical(
            pub_round(x, 1),
            structure(c(1.3, -2.5), class = "my_numbers", unit = "%")
        )
        expect_identical(pub_format_num(x, 0), c("1", "-3"))
    })

    it("keep NA, NaN, infinite values, names and dimensions", {
        x <- c(a = 0.125, b = NA, c = NaN, d = Inf, e = -Inf)
        m <- matrix(c(0.5, 2.5, -1, 1), 2L, dimnames = list(c("r1", "r2"), c("a", "b")))

        expect_identical(
            pub_round(x, 2),
            c(a = 0.13, b = NA, c = NaN, d = Inf, e = -Inf)
        )
        expect_identical(
            pub_format_num(x, 2),
            c(a = "0.13", b = NA, c = NA, d = "Inf", e = "-Inf")
        )
        expect_identical(pub_format_num(x[4:5], "%.1f"), c(d = "Inf", e = "-Inf"))
        expect_identical(
            pub_round(m),
            matrix(c(1, 3, -1, 1), 2L, dimnames = dimnames(m))
        )
        expect_identical(
            pub_format_num(m, 0),
            matrix(c("1", "3", "-1", "1"), 2L, dimnames = dimnames(m))
        )
        expect_identical(pub_format_num(c(5L, -3L), 1), c("5.0", "-3.0"))
        expect_identical(pub_round(numeric(0)), numeric(0))
        expect_identical(pub_format_num(numeric(0), "%.2f"), character(0))
    })

    it("signal errors for invalid arguments", {
        for (digits in list(-1, 1.5, c(1, 2), NA, Inf, "2", TRUE)) {
            expect_error(
                pub_round(1, digits),
                "`digits` must be a single whole number >= 0"
            )
        }
        for (x in list("1", TRUE, NULL, 1i)) {
            expect_error(pub_round(x), "`x` must be a numeric vector")
        }
        expect_error(pub_format_num(factor("1"), 2), "`x` must be a numeric vector")
        formats <- c("%d", "%5.2f", "%+.2f", "%.2f %.1f", "%f", "%s", "%.1%%f", "100%%")
        for (f in formats) {
            expect_error(pub_format_num(1, f), "`format` must be", info = f)
        }
        for (f in list(-1, 1.5, 325, 1e10, Inf, NA, c(1, 2), \(x) "x")) {
            expect_error(pub_format_num(1, f), "`format` must be")
        }
    })
})


# ======================================================================================
# Formatting
# ======================================================================================

# --------------
# Number formats
# --------------

describe(".format_decimal()", {
    it("reads every number text that tables accept", {
        text <- c(
            "1e-05",
            "1.23456789012346e+17",
            "1152921504606846976",
            ".5",
            "5.",
            "+1E2",
            "-0",
            " -2.675 ",
            "Inf",
            "-Inf",
            "0e+2000000000",
            "1e+2000000000"
        )

        expect_true(all(.is_number_text(text)))
        expect_identical(
            .format_decimal(text, 2L, "digits", as.numeric(text)),
            c(
                "0.00",
                "123456789012346000.00",
                "1152921504606846976.00",
                "0.50",
                "5.00",
                "100.00",
                "0.00",
                "-2.68",
                "Inf",
                "-Inf",
                "0.00",
                "Inf"
            )
        )
    })
})

describe(".sprintf_spec()", {
    it("accepts one %.nf, %.ne or %.ng conversion and other text", {
        expect_identical(
            .sprintf_spec("%.2f"),
            list(type = "f", precision = 2L, from = 1L, to = 4L)
        )
        expect_identical(
            .sprintf_spec("Mean: %.10e %%"),
            list(type = "e", precision = 10L, from = 7L, to = 11L)
        )
        expect_identical(
            .sprintf_spec("%%%.0g"),
            list(type = "g", precision = 0L, from = 3L, to = 6L)
        )
        rejected <- c(
            "%d",
            "%f",
            "%5.2f",
            "%-.2f",
            "%.2f%.1f",
            "%.1%%f",
            "100%%",
            "%.2E",
            "%"
        )
        for (f in rejected) {
            expect_null(.sprintf_spec(f), info = f)
        }
    })
})
