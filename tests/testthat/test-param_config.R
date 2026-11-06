# -------
# Configs
# -------

describe("param_config()", {
    orders <- function(cfg) {
        vapply(cfg, param_attr, integer(1), which = "order")
    }

    it("creates a config from named params", {
        a <- param(1, label = "A")
        b <- param("x", label = "B")
        cfg <- param_config(a = a, b = b)

        expect_equal(class(cfg), c("param_config", "list"))
        expect_true(is.list(cfg))
        expect_equal(names(cfg), c("a", "b"))
        expect_equal(param_attr(cfg$a, "label"), "A")
        expect_identical(param_value(cfg$b), "x")
    })

    it("stamps the position as attribute 'order'", {
        cfg <- param_config(b = param(1), a = param(2), c = param(3))

        expect_identical(orders(cfg), c(b = 1L, a = 2L, c = 3L))
    })

    it("flattens lists and configs of params", {
        cfg1 <- param_config(a = param(1), b = param(2))
        cfg <- param_config(
            cfg1,
            list(c = param(3), d = choice_param("yes", c("yes", "no"))),
            e = param(5)
        )

        expect_equal(names(cfg), c("a", "b", "c", "d", "e"))
        expect_identical(orders(cfg), c(a = 1L, b = 2L, c = 3L, d = 4L, e = 5L))
        expect_true(all(vapply(cfg, is_param, logical(1))))
    })

    it("ignores the names of list arguments", {
        cfg <- param_config(
            prep = list(a = param(1)),
            stats = list(b = param(2))
        )
        expect_equal(names(cfg), c("a", "b"))
    })

    it("keeps param groups as one param", {
        group <- param_group(list(lower = param(1), upper = param(2)))
        cfg <- param_config(limits = group, list(other = group))

        expect_equal(names(cfg), c("limits", "other"))
        expect_equal(class(cfg$limits), c("param_group", "param", "list"))
        expect_equal(names(cfg$limits), c("lower", "upper"))
        expect_equal(param_attr(cfg$other, "order"), 2L)
    })

    it("ignores NULL arguments", {
        cfg <- param_config(a = param(1), NULL, if (FALSE) list(b = param(2)))
        expect_equal(names(cfg), "a")
    })

    it("creates an empty config", {
        cfg <- param_config()

        expect_equal(class(cfg), c("param_config", "list"))
        expect_length(cfg, 0)
        expect_length(param_config(list()), 0)
    })

    it("signals duplicate names by default", {
        expect_error(
            param_config(a = param(1), list(a = param(2), b = param(3))),
            "Duplicate param names: a."
        )
        expect_error(
            param_config(
                a = param(1),
                a = param(2),
                b = param(3),
                b = param(4)
            ),
            "Duplicate param names: a, b."
        )
    })

    it("keeps the first definition with .duplicates = 'first'", {
        cfg <- param_config(
            list(a = param(1), b = param(2)),
            list(c = param(3), a = param(10), b = param(20)),
            .duplicates = "first"
        )

        expect_equal(names(cfg), c("a", "b", "c"))
        expect_identical(param_value(cfg$a), 1)
        expect_identical(param_value(cfg$b), 2)
        expect_identical(orders(cfg), c(a = 1L, b = 2L, c = 3L))
    })

    it("signals elements that are no params", {
        expect_error(
            param_config(list(a = param(1), b = 2, c = "x")),
            "all elements must be params, not: b, c"
        )
        expect_error(param_config(a = 1), "must be params or lists of params")
        expect_error(
            param_config(data.frame(a = 1)),
            "must be params or lists of params"
        )
    })

    it("signals unnamed params", {
        expect_error(param_config(param(1)), "must be named")
        expect_error(param_config(list(param(1))), "all params must be named")
        expect_error(
            param_config(list(a = param(1), param(2))),
            "all params must be named"
        )
    })

    it("signals NA names and does not flatten nested lists", {
        nms <- c("a", NA)
        expect_error(
            param_config(stats::setNames(list(param(1), param(2)), nms)),
            "all params must be named"
        )
        expect_error(
            param_config(list(list(a = param(1)))),
            "all params must be named"
        )
    })

    it("names a duplicate only once", {
        expect_error(
            param_config(a = param(1), a = param(2), a = param(3)),
            "Duplicate param names: a.",
            fixed = TRUE
        )
    })

    it("reports errors as calls of param_config()", {
        err <- tryCatch(param_config(a = 1), error = identity)
        expect_identical(conditionCall(err), quote(param_config(a = 1)))
    })

    it("signals an invalid .duplicates argument", {
        expect_error(
            param_config(a = param(1), .duplicates = "last"),
            "`.duplicates` must be one of"
        )
    })

    it("can be the children of a param group", {
        cfg <- param_config(a = param(1), b = param("x"))
        pg <- param_group(cfg)

        expect_equal(class(pg), c("param_group", "param", "list"))
        expect_equal(param_value(pg), list(a = 1, b = "x"))
    })

    it("re-stamps the order of a config", {
        cfg <- param_config(a = param(1), b = param(2), c = param(3))
        cfg2 <- param_config(cfg[c("c", "a")])

        expect_identical(orders(cfg2), c(c = 1L, a = 2L))
        expect_identical(param_config(cfg), cfg)
    })
})

describe("c.param_config()", {
    it("combines configs and re-stamps the order", {
        cfg1 <- param_config(a = param(1), b = param(2))
        cfg2 <- param_config(c = param(3), d = param(4))
        cfg <- c(cfg2, cfg1)

        expect_equal(class(cfg), c("param_config", "list"))
        expect_equal(names(cfg), c("c", "d", "a", "b"))
        expect_equal(
            vapply(cfg, param_attr, integer(1), which = "order"),
            c(c = 1L, d = 2L, a = 3L, b = 4L)
        )
    })

    it("adds params and lists of params", {
        cfg <- c(
            param_config(a = param(1)),
            b = param(2),
            list(c = param(3))
        )
        expect_equal(names(cfg), c("a", "b", "c"))
    })

    it("handles duplicates like param_config()", {
        cfg1 <- param_config(a = param(1), b = param(2))
        cfg2 <- param_config(b = param(20), c = param(3))

        err <- expect_error(c(cfg1, cfg2), "Duplicate param names: b.")
        expect_identical(err$call[[1L]], quote(c))
        err <- expect_error(c(cfg1, 1), "must be")
        expect_identical(err$call[[1L]], quote(c))

        cfg <- c(cfg1, cfg2, .duplicates = "first")
        expect_equal(names(cfg), c("a", "b", "c"))
        expect_identical(param_value(cfg$b), 2)
    })

    it("returns a single config unchanged and ignores NULL", {
        cfg <- param_config(a = param(1), b = param(2))

        expect_identical(c(cfg), cfg)
        expect_identical(c(cfg, NULL), cfg)
    })

    it("signals an invalid .duplicates argument", {
        cfg <- param_config(a = param(1))
        expect_error(
            c(cfg, cfg, .duplicates = "last"),
            "`.duplicates` must be one of"
        )
    })
})

describe("[.param_config", {
    cfg <- param_config(a = param(1), b = param(2), c = param(3))

    it("keeps the class and the order stamps", {
        sub <- cfg[c("c", "a")]

        expect_equal(class(sub), c("param_config", "list"))
        expect_equal(names(sub), c("c", "a"))
        expect_equal(param_attr(sub$c, "order"), 3L)
        expect_identical(sub$a, cfg$a)
    })

    it("supports numeric, logical and empty indices", {
        expect_equal(names(cfg[2:3]), c("b", "c"))
        expect_equal(names(cfg[c(TRUE, FALSE, TRUE)]), c("a", "c"))
        expect_equal(names(cfg[-1]), c("b", "c"))
        expect_identical(cfg[], cfg)
        expect_length(cfg[0], 0)
        expect_equal(class(cfg[0]), c("param_config", "list"))
    })

    it("signals unknown names and indices", {
        expect_error(cfg[c("a", "zz", "yy")], "Unknown params: zz, yy.", fixed = TRUE)
        expect_error(cfg[4], "beyond the end")
        expect_error(cfg[NA_character_], "Unknown params: NA.", fixed = TRUE)
        expect_error(cfg[c(TRUE, NA)], "by `NA`")
    })

    it("returns single params with [[ and $", {
        expect_equal(class(cfg[["b"]]), c("param", "numeric"))
        expect_identical(cfg$b, cfg[["b"]])
    })
})


# ------------------
# Saving and reading
# ------------------

describe("saveRDS()/readRDS() of configs", {
    it("keeps the config, its params and their order", {
        cfg <- param_config(
            alpha = numeric_param(0.05, min = 0, max = 1),
            trans = choice_param("log", choices = c("none", "log")),
            limits = param_group(list(
                lower = numeral_param("1.0"),
                upper = numeral_param("2.0")
            ))
        )
        file <- withr::local_tempfile(fileext = ".rds")
        saveRDS(cfg, file)
        restored <- readRDS(file)

        expect_equal(restored, cfg)
        expect_equal(class(restored), c("param_config", "list"))
        expect_identical(
            lapply(restored, param_attr, "order"),
            lapply(cfg, param_attr, "order")
        )
        expect_equal(
            param_validity(restored$trans, value = "exp"),
            "value must be one of: none, log"
        )
    })
})
