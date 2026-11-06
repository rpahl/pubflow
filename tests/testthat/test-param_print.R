print_text <- function(x) {
    paste(capture.output(print(x)), collapse = "\n")
}

describe("print.param()", {
    it("prints the value representation by param type", {
        expect_match(
            print_text(param("hello", label = "char")),
            "param<character>: hello"
        )
        expect_match(
            print_text(param(1.23, label = "num")),
            "param<numeric>: 1.23"
        )
        expect_match(
            print_text(param(1:3, label = "int")),
            "param<numeric>: 1, 2, 3"
        )
        expect_match(
            print_text(param(TRUE, label = "flag")),
            "param<logical>: TRUE"
        )

        txtFac <- print_text(
            param(factor("yes", levels = c("yes", "no")), label = "choice")
        )
        expect_match(txtFac, "param<factor>: <factor\\[1\\]: yes>")
        expect_false(grepl("param<factor>: 1", txtFac, fixed = TRUE))
        expect_match(txtFac, "levels: yes, no\n")

        txtChrLevels <- print_text(
            param("yes", levels = c("yes", "no"), label = "chr")
        )
        expect_match(txtChrLevels, "param<character>: yes")
        expect_match(txtChrLevels, "levels: yes, no")

        expect_match(
            print_text(param(data.frame(a = 1:2, b = c("x", "y")))),
            "param<data.frame>: <data.frame 2 x 2>"
        )
        expect_match(
            print_text(param(list(a = 1, b = "x"), label = "lst")),
            "param<list>: <list\\[2\\]: a=1, b=x>"
        )
        expect_match(
            print_text(param(as.Date("2026-10-04"))),
            "param<Date>: 2026-10-04"
        )
    })

    it("dispatches for all param types without base-class methods", {
        params <- list(
            param("a"),
            numeric_param(1),
            numeral_param("1.0"),
            choice_param("a", c("a", "b")),
            param(TRUE),
            param(data.frame(a = 1)),
            param(list(a = 1)),
            param_group(list(a = param(1)))
        )
        for (p in params) {
            out <- capture.output(res <- withVisible(print(p)))
            expect_match(out[[1]], "^param<")
            expect_false(res$visible)
            expect_identical(res$value, p)
            expect_identical(capture.output(p), out)
        }
    })

    it("prints date-times in UTC", {
        withr::local_timezone("Asia/Tokyo")
        time <- as.POSIXct("2024-01-02 23:30:00", tz = "America/New_York")

        expect_match(
            print_text(param(time, label = "When")),
            "2024-01-03 04:30:00 UTC",
            fixed = TRUE
        )
        expect_match(
            print_text(param(as.POSIXlt(time), label = "When")),
            "2024-01-03 04:30:00 UTC",
            fixed = TRUE
        )
    })

    it("abbreviates long values", {
        expect_match(
            print_text(param(factor(letters))),
            "<factor\\[26\\]: a, b, c, d, e, ...>"
        )
        expect_match(
            print_text(param(list(a = 1, b = 2, c = 3, d = 4))),
            "<list\\[4\\]: a=1, b=2, c=3, ...>"
        )
        expect_match(
            print_text(param(list(1, "x"))),
            "<list\\[2\\]: \\[\\[1\\]\\]=1, \\[\\[2\\]\\]=x>"
        )
        txt <- print_text(param(1:100))
        expect_match(txt, "\\.\\.\\.\n")
        expect_false(grepl("100", txt, fixed = TRUE))
    })

    it("prints attributes that are not values in short form", {
        txt <- print_text(param(1, ui_widget = mean, ui_args = list(a = 1)))
        expect_match(txt, "ui_widget: <function>")
        expect_match(txt, "ui_args: <list\\[1\\]: a=1>")
    })

    it("prints the attributes and counts the validity functions", {
        p <- numeral_param("1.1", label = "bla", min = 0, max = 10, foo = "bar")
        txt <- print_text(p)

        expect_match(txt, "param<character>: 1.1")
        expect_match(txt, "label: bla")
        expect_match(txt, "min: 0")
        expect_match(txt, "max: 10")
        expect_match(txt, "foo: bar")
        expect_match(txt, "\n  validity: <function>$")
        expect_false(grepl("coercible", txt, fixed = TRUE))
    })

    it("counts chained validity functions", {
        p <- param(1) |>
            add_validity(list(\(x) "", \(x) ""))

        expect_match(print_text(p), "validity: <3 functions>$")
    })

    it("omits the validity line if there are no validity functions", {
        txt <- print_text(param(1, validity = NULL))
        expect_false(grepl("validity", txt, fixed = TRUE))
    })

    it("prints the description only if it differs from the label", {
        expect_false(grepl("description", print_text(param(1)), fixed = TRUE))
        expect_match(
            print_text(param(1, label = "a", description = "b")),
            "label: a\n  description: b"
        )
    })

    it("prints param_group recursively with full child details", {
        pg <- param_group(
            list(
                p1 = param("a", validity = \(x) if (x == "") "empty" else ""),
                p2 = numeric_param(2, min = 0, max = 3)
            ),
            validity = \(x) if (length(x) == 0) "group invalid" else ""
        )

        txt <- print_text(pg)

        expect_match(txt, "param<list>: <list\\[2\\]: p1=a, p2=2>")
        expect_match(txt, "\n  children:\n")
        expect_match(txt, "\n    p1:\n    param<character>: a")
        expect_match(txt, "\n    p2:\n    param<numeric>: 2")
        expect_match(txt, "\n      validity: <function>\n    p2:")
    })

    it("prints children of a group that are no params", {
        pg <- param_group(list(a = param(1)))
        pg$b <- 2

        expect_match(print_text(pg), "\n    b: 2")
    })

    it("indents nested param groups by level", {
        pg <- param_group(list(g = param_group(list(x = param(1)))))

        txt <- print_text(pg)

        expect_match(txt, "\n    g:\n    param<list>: <list\\[1\\]: x=1>")
        expect_match(txt, "\n      children:\n        x:\n        param<numeric>: 1")
    })

    it("omits the children line of a group without children", {
        pg <- param_group(list(a = param(1)))
        pg$a <- NULL

        txt <- print_text(pg)

        expect_match(txt, "param<list>: <list\\[0\\]: >")
        expect_false(grepl("children", txt, fixed = TRUE))
    })

    it("prints no trailing whitespace", {
        g <- param_group(list(a = param(character()), b = param("")))
        p <- param(character(), note = character(), validity = list(\(x) "", \(x) ""))

        for (x in list(g, p)) {
            out <- capture.output(print(x))
            expect_false(any(grepl("[[:space:]]$", out)), info = toString(out))
        }
        expect_identical(
            capture.output(print(param(character())))[[1L]],
            "param<character>:"
        )
    })
})

describe("print.param_config()", {
    it("prints a table with one row per param in the config order", {
        cfg <- param_config(
            alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1),
            unit = param("%", label = "Unit of y"),
            pick = choice_param("a", choices = c("a", "b"), label = "Pick")
        )

        expect_snapshot(print(cfg))
    })

    it("lists group children indented below their group and shortens values", {
        grp <- param_group(
            list(a = param(1, label = "A"), g = param_group(list(x = param(2)))),
            label = "Group"
        )
        grp$b <- 2 # a child that is no param
        cfg <- param_config(grp = grp, long = param(strrep("x", 50)))

        expect_snapshot(print(cfg))
    })

    it("joins the lines of a multi-line value", {
        txt <- print_text(param_config(e = param("a\n  b", label = "Text")))
        expect_match(txt, "e    character a b   Text", fixed = TRUE)
    })

    it("prints the number of params of an empty config", {
        expect_identical(print_text(param_config()), "<param_config: 0 params>")
        expect_match(print_text(param_config(a = param(1))), "^<param_config: 1 param>")
    })

    it("returns the config invisibly", {
        cfg <- param_config(a = param(1))

        capture.output(res <- expect_invisible(print(cfg)))
        expect_identical(res, cfg)
    })
})

describe(".format_param_value()", {
    it("formats empty values", {
        expect_identical(.format_param_value(character(0)), "")
        expect_identical(.format_param_value(list()), "<list[0]: >")
        expect_identical(.format_param_value(factor(character(0))), "<factor[0]: >")
        expect_identical(.format_param_value(NULL), "<NULL>")
    })

    it("formats missing values as NA", {
        expect_identical(.format_param_value(c(1, NA)), "1, NA")
        expect_identical(.format_param_value(NA_character_), "NA")
        expect_identical(.format_param_value(as.POSIXct(NA)), "NA")
    })

    it("abbreviates only beyond the limits", {
        expect_identical(.format_param_value(strrep("a", 80)), strrep("a", 80))
        expect_identical(
            .format_param_value(strrep("a", 81)),
            paste0(strrep("a", 77), "...")
        )
        expect_identical(
            .format_param_value(factor(letters[1:5])),
            "<factor[5]: a, b, c, d, e>"
        )
        expect_identical(
            .format_param_value(list(a = 1, b = 2, c = 3)),
            "<list[3]: a=1, b=2, c=3>"
        )
    })

    it("formats atomic vectors without names or dimensions", {
        expect_identical(.format_param_value(c(a = 1, b = 2)), "1, 2")
        expect_identical(.format_param_value(matrix(1:4, 2)), "1, 2, 3, 4")
    })

    it("formats lists recursively with partial names", {
        expect_identical(
            .format_param_value(list(a = 1, 2)),
            "<list[2]: a=1, [[2]]=2>"
        )
        expect_identical(
            .format_param_value(list(a = list(b = 1))),
            "<list[1]: a=<list[1]: b=1>>"
        )
    })

    it("formats date-times in lists in UTC", {
        withr::local_timezone("Asia/Tokyo")
        time <- as.POSIXlt("2024-01-02 23:30:00", tz = "America/New_York")

        expect_identical(
            .format_param_value(list(t = time)),
            "<list[1]: t=2024-01-03 04:30:00 UTC>"
        )
    })

    it("formats other objects by their class", {
        expect_identical(.format_param_value(new.env()), "<environment>")
        expect_identical(.format_param_value(quote(x)), "<name>")
    })
})
