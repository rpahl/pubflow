# ======================================================================================
# Param objects
# ======================================================================================

# ------------
# Constructors
# ------------

describe("param()", {
    it("creates a param object with the expected attributes", {
        p <- param("my value", label = "my string")
        expect_equal(param_value(p), "my value")
        expect_equal(attr(p, "label"), "my string")
        expect_equal(attr(p, "description"), "my string")
        expect_equal(attr(p, "validity"), list(default_param_validity))
    })

    it("puts the param class first", {
        expect_equal(class(param(1.1)), c("param", "numeric"))
        expect_equal(class(param(1L)), c("param", "integer"))
        expect_equal(class(param("a")), c("param", "character"))
        expect_equal(class(param(TRUE)), c("param", "logical"))
        expect_equal(class(param(list(a = 1))), c("param", "list"))
        expect_equal(class(param(factor("a"))), c("param", "factor"))
        expect_equal(
            class(param(data.frame(a = 1:3))),
            c("param", "data.frame")
        )
        expect_equal(class(param(Sys.Date())), c("param", "Date"))
        expect_equal(
            class(param_group(list(a = param(1)))),
            c("param_group", "param", "list")
        )
    })

    it("does not duplicate the param class when re-wrapping a param", {
        p <- param(param(1, source = "user"), label = "new")

        expect_equal(class(p), c("param", "numeric"))
        expect_equal(param_attr(p, "label"), "new")
        expect_equal(param_attr(p, "source"), "user")
    })

    it("can set a custom description", {
        p <- param(
            "my value",
            label = "my string",
            description = "This is a nice string."
        )
        expect_equal(attr(p, "description"), "This is a nice string.")
    })

    it("can set additional attributes", {
        p <- param(
            "my value",
            label = "my string",
            advanced = TRUE,
            source = "user",
            ui_args = list(width = "10ch")
        )
        expect_equal(attr(p, "advanced"), TRUE)
        expect_equal(attr(p, "source"), "user")
        expect_equal(attr(p, "ui_args"), list(width = "10ch"))
    })

    it("accepts a list of validity functions or NULL", {
        f1 <- \(x) ""
        f2 <- \(x) "bad"
        expect_equal(attr(param(1, validity = list(f1, f2)), "validity"), list(f1, f2))
        expect_equal(attr(param(1, validity = NULL), "validity"), list())
    })

    it("signals bad arguments", {
        expect_error(param(NULL), "Parameter value cannot be NULL")
        expect_error(param(1, label = 1), "label must be a single string")
        expect_error(
            param(1, label = c("a", "b")),
            "label must be a single string"
        )
        expect_error(
            param(1, description = NA_character_),
            "description must be a single string"
        )
        expect_error(param(1, "lbl", "desc", NULL, "user"), "must be named")
        expect_error(
            param(1, validity = "not a function"),
            "validity must be a function or list of functions"
        )
        expect_error(
            param(1, validity = list(\(x) "", 1)),
            "validity must be a function or list of functions"
        )
    })
})

describe("base behaviour of param objects", {
    num <- param(c(1.5, 2), label = "num")
    int <- param(1:3, label = "int")
    chr <- param("abc", label = "chr")
    lgl <- param(TRUE, label = "lgl")
    fct <- param(factor(c("b", "a"), levels = c("a", "b")), label = "fct")
    df <- param(data.frame(a = 1:2), label = "df")

    it("supports arithmetic and comparison (Ops) on numeric params", {
        expect_equal(param_value(num + 1), c(2.5, 3))
        expect_equal(param_value(2 * num), c(3, 4))
        expect_equal(param_value(int - 1L), 0:2)
        expect_identical(num == 1.5, c(TRUE, FALSE))
        expect_identical(num > 1.7, c(FALSE, TRUE))
        expect_identical(int <= 2L, c(TRUE, TRUE, FALSE))
        expect_identical(sum(num), 3.5)
        expect_identical(max(int), 3L)
    })

    it("compares factor params by their labels (Ops.factor)", {
        expect_identical(fct == "a", c(FALSE, TRUE))
        expect_identical(fct != "a", c(TRUE, FALSE))
        expect_identical(choice_param("no", c("yes", "no")) == "no", TRUE)
    })

    it("keeps as.character(), levels() and switch() on factor params", {
        expect_identical(as.character(fct), c("b", "a"))
        expect_identical(levels(fct), c("a", "b"))
        expect_identical(as.integer(fct), c(2L, 1L))
        trans <- choice_param("exp", choices = c("none", "log", "exp"))
        res <- switch(as.character(trans), none = 1, log = 2, exp = 3)
        expect_equal(res, 3)
    })

    it("keeps the is.*() functions and inherits()", {
        expect_true(is.numeric(num))
        expect_true(is.numeric(int))
        expect_false(is.numeric(fct))
        expect_true(is.character(chr))
        expect_false(is.character(fct))
        expect_true(is.factor(fct))
        expect_true(is.logical(lgl))
        expect_true(is.data.frame(df))
        expect_true(is.list(param_group(list(a = num))))
        expect_true(inherits(num, "numeric"))
        expect_true(inherits(fct, "factor"))
        expect_true(inherits(fct, "param"))
        expect_true(inherits(df, "data.frame"))
        expect_true(if (lgl) TRUE else FALSE)
    })

    it("keeps subsetting with [ and length()", {
        expect_identical(num[2], 2)
        expect_identical(int[2:3], 2:3)
        expect_identical(chr[1], "abc")
        expect_identical(as.character(fct[1]), "b")
        expect_identical(levels(fct[1]), c("a", "b"))
        expect_identical(df[["a"]], 1:2)
        expect_identical(nrow(df), 2L)
        expect_identical(length(num), 2L)
        expect_identical(length(fct), 2L)
        expect_identical(length(df), 1L)
    })

    it("keeps format() and toString()", {
        expect_identical(format(num), c("1.5", "2.0"))
        expect_identical(format(fct), c("b", "a"))
        expect_identical(format(chr), "abc")
        expect_identical(toString(num), "1.5, 2")
        expect_identical(toString(fct), "b, a")
        expect_identical(toString(lgl), "TRUE")
        expect_identical(paste(fct), c("b", "a"))
        expect_identical(sprintf("%s", fct), c("b", "a"))
    })

    it("does not change how base classes are printed", {
        expect_identical(
            capture.output(print(factor(c("a", "b")))),
            c("[1] a b", "Levels: a b")
        )
        expect_identical(
            capture.output(print(data.frame(a = 1L))),
            c("  a", "1 1")
        )
    })

    it("registers S3 methods only for pubflow classes", {
        methods <- getNamespaceInfo("pubflow", "S3methods")
        classes <- methods[, 2]

        ownGeneric <- methods[, 1] == "as_pub_output"
        # pipeflow's output hook stamps figures
        outputHook <- methods[, 1] == "pip_output_value" &
            classes %in% c("ggplot", "recordedplot", "list")
        expect_true(all(
            classes %in%
                c("param", "param_config") |
                startsWith(classes, "pub_") |
                startsWith(classes, "pubflow_") |
                ownGeneric |
                outputHook
        ))
        isBasePrint <- methods[, 1] == "print" &
            classes %in% c("factor", "data.frame")
        expect_false(any(isBasePrint))
    })

    it("loads without 'S3 methods overwritten' messages", {
        skip_on_cran()
        rscript <- file.path(R.home("bin"), "Rscript")
        code <- "loadNamespace('pubflow'); cat('pubflow loaded')"
        # R_TESTS (set by R CMD check) would make the child source a startup file that
        # does not exist in its working directory.
        env <- c(
            R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
            R_TESTS = NA
        )
        out <- withr::with_envvar(
            env,
            suppressWarnings(system2(
                rscript,
                c("--vanilla", "-e", shQuote(code)),
                stdout = TRUE,
                stderr = TRUE
            ))
        )
        skip_if_not(
            any(grepl("pubflow loaded", out, fixed = TRUE)),
            "pubflow is not installed"
        )
        expect_false(any(grepl("overwritten", out, fixed = TRUE)))
    })
})

describe("numeric_param()", {
    it("creates a numeric_param object with the expected attributes", {
        p <- numeric_param(1.1, label = "bla", min = 0, max = 10, foo = "bar")
        expect_equal(param_value(p), 1.1)
        expect_equal(class(p), c("param", "numeric"))
        expect_equal(attr(p, "label"), "bla")
        expect_equal(attr(p, "description"), "bla")
        expect_equal(attr(p, "min"), 0)
        expect_equal(attr(p, "max"), 10)
        expect_true(is.list(attr(p, "validity")))
        expect_true(all(sapply(attr(p, "validity"), is.function)))
        expect_equal(attr(p, "validity")[[1]](1.1), "")
        expect_equal(attr(p, "foo"), "bar")
    })

    it("signals bad arguments", {
        expect_error(
            numeric_param(11, min = 10, max = 0),
            "min (10) is not less than max (0)",
            fixed = TRUE
        )
        expect_error(numeric_param("1"), "x must be numeric")
    })

    it("signals equal bounds and bounds that are not numbers", {
        expect_error(
            numeric_param(1, min = 1, max = 1),
            "min (1) is not less than max (1)",
            fixed = TRUE
        )
        msg <- "min and max must be non-empty numeric vectors without NA"
        expect_error(numeric_param(1, min = NA), msg)
        expect_error(numeric_param(1, max = NA_real_), msg)
        expect_error(numeric_param(1, min = "0"), msg)
        expect_error(numeric_param(1, max = numeric()), msg)
    })

    it("signals undefined and empty values", {
        p <- numeric_param(c(2, NA), min = 1, max = 3)
        expect_equal(param_validity(p), "value cannot be NA")
        expect_equal(
            param_validity(p, value = numeric()),
            "value cannot be empty"
        )
    })

    it("signals if initial value is out of bounds", {
        p <- numeric_param(4, min = 1, max = 3)
        expect_equal(
            param_validity(p),
            "value must be less than or equal to max (3)"
        )
        param_value(p) <- 0
        expect_equal(
            param_validity(p),
            "value must be greater than or equal to min (1)"
        )
    })

    it("can customize the validity function", {
        p <- numeric_param(5, label = "my number", min = 0, max = 10, validity = \(x) {
            if (x %% 1 == 0) "" else "need an integer"
        })
        expect_equal(param_validity(p, value = 5), "")
        expect_equal(param_validity(p, value = 5.5), "need an integer")
    })

    it("replaces the default rule in a wrapper constructor", {
        pos_integer_param <- function(x, max = 10L, ...) {
            numeric_param(
                x,
                min = 1,
                max = max,
                validity = \(x) {
                    if (any(x != round(x))) "whole number needed" else ""
                },
                ...
            )
        }
        p <- pos_integer_param(3L)
        expect_equal(param_validity(p), "")
        expect_equal(param_validity(p, value = 2.5), "whole number needed")
        # the default bounds rule is gone
        expect_equal(param_validity(p, value = 99), "")
        expect_equal(param_attr(p, "min"), 1)
    })

    it("works with numeric vectors", {
        p <- numeric_param(1:3, min = 0, max = 4)
        expect_equal(param_validity(p), "")
        expect_equal(
            param_validity(p, 5),
            "value must be less than or equal to max (4)"
        )
        expect_equal(
            param_validity(p, 3:8),
            "value must be less than or equal to max (4)"
        )
        p[2] <- 5
        expect_equal(
            param_validity(p),
            "value must be less than or equal to max (4)"
        )
    })
})

describe("numeral_param()", {
    it("creates a numeral_param object with the expected attributes", {
        p <- numeral_param("1.1", label = "bla", min = 0, max = 10, foo = "bar")
        expect_equal(param_value(p), "1.1")
        expect_equal(class(p), c("param", "character"))
        expect_equal(attr(p, "label"), "bla")
        expect_equal(attr(p, "description"), "bla")
        expect_equal(attr(p, "min"), 0)
        expect_equal(attr(p, "max"), 10)
        expect_equal(attr(p, "foo"), "bar")
        expect_true(is.list(attr(p, "validity")))
        expect_true(all(sapply(attr(p, "validity"), is.function)))
        expect_equal(attr(p, "validity")[[1]]("1.1"), "")
        expect_equal(
            attr(p, "validity")[[1]]("11"),
            "value must be less than or equal to max (10)"
        )
    })

    it("signals bad arguments", {
        expect_error(
            numeral_param("11", min = 10, max = 0),
            "min (10) is not less than max (0)",
            fixed = TRUE
        )
        expect_error(numeral_param(1), "x must be a character vector")
        expect_error(
            numeral_param("1", min = NA),
            "min and max must be non-empty numeric vectors without NA"
        )
    })

    it("signals undefined, empty and non-coercible values (without warning)", {
        p <- numeral_param(c("2", NA), min = 1, max = 3)
        expect_equal(param_validity(p), "value cannot be NA")
        expect_equal(
            param_validity(p, value = character()),
            "value cannot be empty"
        )

        expect_no_warning(info <- param_validity(p, value = "abc"))
        expect_equal(info, "value was not coercible to numeric")
    })

    it("signals if initial value is out of bounds", {
        p <- numeral_param("4", min = 1, max = 3)
        expect_equal(
            param_validity(p),
            "value must be less than or equal to max (3)"
        )
        param_value(p) <- "0"
        expect_equal(
            param_validity(p),
            "value must be greater than or equal to min (1)"
        )
    })

    it("can customize the validity function", {
        p <- numeral_param(
            "1.1",
            label = "my number",
            min = 0,
            max = 10,
            validity = \(x) if (grepl("\\.", x)) "" else "need decimal point"
        )
        expect_equal(param_validity(p, value = "1.23"), "")
        expect_equal(param_validity(p, value = "4"), "need decimal point")
    })

    it("works with numeric vectors", {
        p <- numeral_param(c("1", "2", "3"), min = 0, max = 4)
        expect_equal(param_validity(p), "")
        expect_equal(
            param_validity(p, value = "5"),
            "value must be less than or equal to max (4)"
        )
        expect_equal(
            param_validity(p, value = c("3", "8")),
            "value must be less than or equal to max (4)"
        )
        p[2] <- "5"
        expect_equal(
            param_validity(p),
            "value must be less than or equal to max (4)"
        )
    })

    it("keeps the decimal places of the value", {
        p <- numeral_param("1.20")
        param_value(p) <- "0.900"
        expect_identical(param_value(p), "0.900")
    })
})

describe("choice_param()", {
    it("creates a factor param whose levels are the choices", {
        p <- choice_param(
            "log",
            choices = c("none", "log", "sqrt"),
            label = "Transformation",
            source = "user"
        )

        expect_equal(class(p), c("param", "factor"))
        expect_identical(
            param_value(p),
            factor("log", levels = c("none", "log", "sqrt"))
        )
        expect_equal(param_attr(p, "label"), "Transformation")
        expect_equal(param_attr(p, "description"), "Transformation")
        expect_equal(param_attr(p, "source"), "user")
        expect_equal(param_validity(p), "")
    })

    it("reports values outside the choices", {
        p <- choice_param("a", choices = c("a", "b"))

        expect_equal(param_validity(p, value = "b"), "")
        expect_equal(
            param_validity(p, value = "c"),
            "value must be one of: a, b"
        )
        expect_equal(
            param_validity(p, value = NA),
            "value must be one of: a, b"
        )
        expect_equal(
            param_validity(p, value = character()),
            "value cannot be empty"
        )
    })

    it("accepts several values, NA and non-character choices", {
        p <- choice_param(c("b", "a"), choices = c("a", "b"))
        expect_equal(as.character(p), c("b", "a"))
        expect_equal(param_validity(p), "")

        p <- choice_param(NA, choices = c("a", "b"))
        expect_equal(param_validity(p), "value must be one of: a, b")

        p <- choice_param(2, choices = c(1, 2, 5))
        expect_equal(levels(p), c("1", "2", "5"))
        expect_equal(as.character(p), "2")
    })

    it("accepts a factor value", {
        p <- choice_param(factor("b"), choices = c("a", "b"))
        expect_identical(param_value(p), factor("b", levels = c("a", "b")))
    })

    it("can customize the validity function", {
        p <- choice_param(
            "a",
            choices = c("a", "b"),
            validity = \(x) if (x == "a") "" else "only a"
        )
        expect_equal(param_validity(p, value = "b"), "only a")
    })

    it("signals bad arguments", {
        expect_error(
            choice_param(NULL, choices = c("a", "b")),
            "Parameter value cannot be NULL"
        )
        expect_error(
            choice_param("c", choices = c("a", "b")),
            "x must be one of the choices (a, b), not: c",
            fixed = TRUE
        )
        expect_error(choice_param("a", choices = character()), "non-empty")
        expect_error(choice_param("a", choices = c("a", NA)), "without NA")
        expect_error(choice_param("a", choices = list("a")), "non-empty")
        expect_error(choice_param("a", choices = c("a", "a")), "unique")
    })
})

describe("param_group()", {
    it("creates a param group object with the expected attributes", {
        x <- list(
            p1 = param("value1", label = "Parameter 1"),
            p2 = param(42, label = "Parameter 2")
        )
        pg <- param_group(x, label = "My Group", area = "criteria")
        expect_equal(class(pg), c("param_group", "param", "list"))
        expect_true(is.list(pg))
        expect_equal(names(pg), c("p1", "p2"))

        expect_equal(attr(pg, "label"), "My Group")
        expect_equal(attr(pg, "description"), "My Group")
        expect_equal(attr(pg, "area"), "criteria")
        expect_identical(pg$p1, x$p1)
        expect_identical(pg[["p2"]], x$p2)
    })

    it("signals bad input args", {
        expect_error(param_group("not a list"), "x must be a list")
        expect_error(param_group(data.frame(a = 1)), "x must be a list")
        expect_error(
            param_group(list(a = "not a param object")),
            "all elements of x must be 'param' objects"
        )
    })

    it("signals if passed list is not named", {
        expect_error(
            param_group(list(param("value1"), param(42))),
            "param_group input list must be named"
        )
        expect_error(
            param_group(list(a = param("value1"), param(42))),
            "param_group input list must be named"
        )
    })

    it("signals duplicate names", {
        expect_error(
            param_group(list(a = param(1), a = param(2))),
            "param_group input list must have unique names"
        )
    })

    it("signals if one of the names is 'group'", {
        expect_error(
            param_group(list(v = param("value1"), group = param(42))),
            "param_group input list cannot contain an element named 'group'"
        )
    })

    it("param validity checks overall validity and then all contained params", {
        p1 <- param(1, validity = \(x) if (x > 0) "" else "must be > 0")
        p2 <- param(2, validity = \(x) if (x > 1) "" else "must be > 1")
        pg <- param_group(
            list(p1 = p1, p2 = p2),
            validity = \(x) {
                if (x$p1 > x$p2) {
                    return("p2 must be greater than p1")
                }
                ""
            }
        )

        expect_equal(param_validity(pg), c(group = "", p1 = "", p2 = ""))
        expect_equal(
            param_validity(pg, list(p1 = 3, p2 = 0)),
            c(group = "p2 must be greater than p1", p1 = "", p2 = "must be > 1")
        )
        expect_equal(
            param_validity(pg, list(p1 = -1, p2 = 0)),
            c(group = "", p1 = "must be > 0", p2 = "must be > 1")
        )

        expect_error(
            param_validity_assert(pg, list(p1 = -1, p2 = 0)),
            "p1: must be > 0, p2: must be > 1"
        )
    })

    it("supports list-based validity for group and children", {
        p1 <- param(
            2,
            validity = list(
                \(x) if (x > 0) "" else "p1 must be > 0",
                \(x) if (x %% 2 == 0) "" else "p1 must be even"
            )
        )
        p2 <- param(
            3,
            validity = list(
                \(x) if (x > 1) "" else "p2 must be > 1",
                \(x) if (x < 5) "" else "p2 must be < 5"
            )
        )

        pg <- param_group(
            list(p1 = p1, p2 = p2),
            validity = list(
                \(x) if (x$p1 <= x$p2) "" else "group: p1 must be <= p2",
                \(x) {
                    if ((x$p1 + x$p2) < 10) "" else "group: sum must be < 10"
                }
            )
        )

        expect_equal(param_validity(pg), c(group = "", p1 = "", p2 = ""))

        expect_equal(
            param_validity(pg, list(p1 = -1, p2 = 7)),
            c(
                group = "",
                p1 = "p1 must be > 0, p1 must be even",
                p2 = "p2 must be < 5"
            )
        )

        expect_equal(
            param_validity(pg, list(p1 = 9, p2 = 2)),
            c(
                group = "group: p1 must be <= p2, group: sum must be < 10",
                p1 = "p1 must be even",
                p2 = ""
            )
        )

        expect_error(
            param_validity_assert(pg, list(p1 = 9, p2 = 2)),
            paste(
                "group: group: p1 must be <= p2, group: sum must be < 10,",
                "p1: p1 must be even"
            )
        )
    })
})


# --------------
# Type and class
# --------------

describe("param_type()", {
    it("returns the type of the value", {
        expect_equal(param_type(param("a")), "character")
        expect_equal(param_type(param(factor("a"))), "factor")
        expect_equal(param_type(param(TRUE)), "logical")
        expect_equal(param_type(param(1.5)), "numeric")
        expect_equal(param_type(param(1L)), "numeric")
        expect_equal(param_type(param(list(a = 1))), "list")
        expect_equal(param_type(param(data.frame(a = 1))), "data.frame")
        expect_equal(param_type(param_group(list(a = param(1)))), "list")
    })

    it("treats ordered factors as factors", {
        p <- param(factor("lo", levels = c("lo", "hi"), ordered = TRUE))
        expect_equal(param_type(p), "factor")
    })

    it("returns the first non-param class for other values", {
        expect_equal(param_type(param(Sys.Date())), "Date")
        expect_equal(param_type(param(matrix(1:4, 2))), "matrix")
        expect_equal(param_type(param(mean)), "function")
    })

    it("works for the types of the param constructors", {
        expect_equal(param_type(numeric_param(1)), "numeric")
        expect_equal(param_type(numeral_param("1.0")), "character")
        expect_equal(param_type(choice_param("a", c("a", "b"))), "factor")
    })

    it("also accepts plain values", {
        expect_equal(param_type("a"), "character")
        expect_equal(param_type(1L), "numeric")
        expect_equal(param_type(factor("a")), "factor")
    })

    it("uses the implicit class of a value with only the param class", {
        p <- structure(1, class = "param")
        expect_equal(param_type(p), "numeric")
        expect_identical(param_value(p), 1)
        expect_equal(param_type(structure(1L, class = "param")), "numeric")
    })
})

describe("is_param()", {
    it("tests for the param class", {
        expect_true(is_param(param(1)))
        expect_true(is_param(choice_param("yes", c("yes", "no"))))
        expect_true(is_param(param_group(list(a = param(1)))))
        expect_false(is_param(1))
        expect_false(is_param(factor("a")))
        expect_false(is_param(list(param(1))))
        expect_false(is_param(NULL))
    })
})


# ======================================================================================
# Attributes and values
# ======================================================================================

# ----------
# Attributes
# ----------

describe("param_attr()", {
    it("retrieves the specified attribute from a param object", {
        p <- param("value", label = "my label", description = "my description")
        expect_equal(param_attr(p, "label"), "my label")
        expect_equal(param_attr(p, "description"), "my description")
    })

    it("returns the default if the specified attribute is not set", {
        p <- param("value")
        expect_null(param_attr(p, "non-existent"))
        expect_equal(param_attr(p, "source", default = "user"), "user")
    })

    it("does no partial matching of attribute names", {
        p <- param("value", label = "my label")
        expect_null(param_attr(p, "lab"))
    })
})


# ------
# Values
# ------

describe("param_value()", {
    it("returns the value without param class and attributes", {
        p <- param("abc", label = "lbl", source = "user")
        v <- param_value(p)

        expect_identical(v, "abc")
        expect_false(is_param(v))
    })

    it("keeps non-param classes and value attributes", {
        v <- param_value(choice_param("yes", c("yes", "no"), label = "Question"))
        expect_identical(v, factor("yes", levels = c("yes", "no")))

        expect_identical(param_value(param(c(a = 1, b = 2))), c(a = 1, b = 2))
        expect_identical(
            param_value(param(data.frame(a = 1:2, b = c("x", "y")))),
            data.frame(a = 1:2, b = c("x", "y"))
        )
        mat <- matrix(1:4, 2, dimnames = list(NULL, c("a", "b")))
        expect_identical(param_value(param(mat)), mat)
        date <- as.Date("2026-10-04")
        expect_identical(param_value(param(date)), date)
        ord <- factor("lo", levels = c("lo", "hi"), ordered = TRUE)
        expect_identical(param_value(param(ord)), ord)
    })

    it("keeps the attributes that the class of the value needs", {
        time <- as.POSIXct("2024-01-02 03:04:05", tz = "America/New_York")
        values <- list(
            time = time,
            local = as.POSIXlt(time),
            span = as.difftime(90, units = "mins"),
            series = stats::ts(1:4, start = 2020)
        )

        for (v in values) {
            expect_identical(param_value(param(v)), v)
        }
        expect_identical(param_value(param(1, units = "mg")), 1)
    })

    it("returns plain values of all types", {
        values <- list(
            "a",
            1.5,
            2L,
            TRUE,
            list(a = 1),
            factor("a"),
            data.frame(a = 1)
        )
        for (value in values) {
            expect_identical(param_value(param(value, label = "x")), value)
        }
    })

    it("unwraps param groups recursively", {
        inner <- param_group(list(
            lower = numeral_param("1.0"),
            upper = numeral_param("2.0")
        ))
        outer <- param_group(list(
            limits = inner,
            show = choice_param("no", c("yes", "no")),
            n = numeric_param(3L)
        ))

        res <- param_value(outer)
        expect_identical(
            res,
            list(
                limits = list(lower = "1.0", upper = "2.0"),
                show = factor("no", levels = c("yes", "no")),
                n = 3L
            )
        )
        isParam <- rapply(res, is_param, how = "unlist")
        expect_false(any(isParam))
    })

    it("signals an error for non-param input", {
        expect_error(param_value("abc"), "x must be a 'param' object")
    })
})

describe("param_value<-", {
    it("updates the value while preserving attributes", {
        p <- param("a", label = "my label", source = "user")
        param_value(p) <- "b"

        expect_equal(param_value(p), "b")
        expect_equal(param_attr(p, "label"), "my label")
        expect_equal(param_attr(p, "source"), "user")
        expect_equal(class(p), c("param", "character"))
    })

    it("preserves factor levels", {
        p <- choice_param("yes", c("yes", "no"))
        param_value(p) <- "no"

        expect_equal(as.character(p), "no")
        expect_equal(levels(p), c("yes", "no"))
        expect_equal(class(p), c("param", "factor"))
    })

    it("works with params containing empty values", {
        p <- param(character(), label = "empty char")
        param_value(p) <- "a"
        expect_true(is_param(p))
        expect_equal(param_value(p), "a")
        expect_equal(param_attr(p, "label"), "empty char")

        p <- param(numeric(), label = "empty num")
        param_value(p) <- 1.23
        expect_true(is_param(p))
        expect_equal(param_value(p), 1.23)
        expect_equal(param_attr(p, "label"), "empty num")

        p <- param(logical(), label = "empty log")
        param_value(p) <- TRUE
        expect_true(is_param(p))
        expect_equal(param_value(p), TRUE)
        expect_equal(param_attr(p, "label"), "empty log")

        p <- param(
            factor(character(), levels = c("yes", "no")),
            label = "empty factor"
        )
        param_value(p) <- "no"
        expect_true(is_param(p))
        expect_identical(
            param_value(p),
            factor("no", levels = c("yes", "no"))
        )
        expect_equal(param_attr(p, "label"), "empty factor")

        p <- param(data.frame(), label = "empty df")
        param_value(p) <- data.frame(a = 2)
        expect_true(is_param(p))
        expect_equal(param_value(p), data.frame(a = 2))
        expect_equal(param_attr(p, "label"), "empty df")

        p <- param(list(), label = "empty list")
        param_value(p) <- list(a = 2, b = "y")
        expect_true(is_param(p))
        expect_equal(param_value(p), list(a = 2, b = "y"))
        expect_equal(param_attr(p, "label"), "empty list")
    })

    it("works with param_group objects", {
        x <- list(
            p1 = param(factor("a", levels = c("a", "b")), label = "Param 1"),
            p2 = param(42, label = "Parameter 2")
        )
        pg <- param_group(x, label = "My Group")
        param_value(pg) <- list(p2 = 100, p1 = "b", extra = "ignored")

        expect_equal(class(pg), c("param_group", "param", "list"))
        expect_equal(param_attr(pg, "label"), "My Group")
        expect_equal(param_value(pg$p1), factor("b", levels = c("a", "b")))
        expect_equal(param_value(pg$p2), 100)
        expect_equal(param_attr(pg$p2, "label"), "Parameter 2")
    })

    it("signals an error for invalid param_group replacement input", {
        pg <- param_group(list(
            p1 = param("a"),
            p2 = param(1)
        ))

        expect_error(
            param_value(pg) <- "not a list",
            "value for param_group must be a named list with names: p1, p2"
        )
        expect_error(
            param_value(pg) <- list(p1 = "b"),
            "value for param_group must be a named list with names"
        )
    })

    it("can replace values with a different length", {
        p <- param("a", label = "char")
        param_value(p) <- c("a", "b", "c")
        expect_true(is_param(p))
        expect_equal(param_value(p), c("a", "b", "c"))
        expect_equal(param_attr(p, "label"), "char")

        p <- param(1, label = "num")
        param_value(p) <- c(1, 2, 3)
        expect_equal(param_value(p), c(1, 2, 3))
        expect_equal(param_attr(p, "label"), "num")

        p <- param(TRUE, label = "log")
        param_value(p) <- c(TRUE, FALSE, TRUE)
        expect_equal(param_value(p), c(TRUE, FALSE, TRUE))

        p <- choice_param("yes", c("yes", "no"), label = "fac")
        param_value(p) <- c("no", "yes")
        expect_identical(
            param_value(p),
            factor(c("no", "yes"), levels = c("yes", "no"))
        )
        expect_equal(param_attr(p, "label"), "fac")

        p <- param(data.frame(a = 1), label = "df")
        param_value(p) <- data.frame(a = c(1, 2), b = c("x", "y"))
        expect_identical(
            param_value(p),
            data.frame(a = c(1, 2), b = c("x", "y"))
        )
        expect_equal(param_attr(p, "label"), "df")

        p <- param(list(a = 1), label = "lst")
        param_value(p) <- list(a = 1, b = 2)
        expect_equal(param_value(p), list(a = 1, b = 2))
        expect_equal(param_attr(p, "label"), "lst")
    })

    it("prefers replacement value attributes over existing ones", {
        p <- param(c(a = 1), label = "num")
        attr(p, "units") <- "old"

        v <- c(x = 2, y = 3)
        attr(v, "units") <- "new"

        param_value(p) <- v

        expect_equal(param_value(p), c(x = 2, y = 3))
        expect_equal(attr(p, "units", exact = TRUE), "new")
        expect_equal(param_attr(p, "label"), "num")
        expect_true(is_param(p))
    })

    it("keeps the names of the current value for an unnamed value", {
        p <- numeric_param(c(lower = 1, upper = 2))
        param_value(p) <- c(3, 4)
        expect_identical(param_value(p), c(lower = 3, upper = 4))
    })

    it("converts the value to the class of the current value", {
        p <- param(1.5)
        param_value(p) <- "2.5"
        expect_identical(param_value(p), 2.5)

        p <- param(1L)
        param_value(p) <- 2
        expect_identical(param_value(p), 2L)

        p <- param("a")
        param_value(p) <- 1
        expect_identical(param_value(p), "1")

        p <- param(as.Date("2026-01-01"))
        param_value(p) <- "2026-10-04"
        expect_identical(param_value(p), as.Date("2026-10-04"))

        p <- param(data.frame(a = 1))
        param_value(p) <- list(a = 1:2)
        expect_identical(param_value(p), data.frame(a = 1:2))
    })

    it("signals an error if the value can't be converted", {
        p <- param(structure(list(), class = "my_class"))
        expect_error(
            param_value(p) <- 1,
            "Can't convert the value to class 'my_class'"
        )
    })

    it("sets factor values outside the levels to NA without warning", {
        p <- choice_param("a", choices = c("a", "b"), label = "Choice")
        expect_no_warning(param_value(p) <- "z")

        expect_identical(
            param_value(p),
            factor(NA_character_, levels = c("a", "b"))
        )
        expect_equal(param_validity(p), "value must be one of: a, b")
    })

    it("takes the levels of a factor value", {
        p <- choice_param("yes", c("yes", "no"))
        param_value(p) <- factor("maybe", levels = c("yes", "no", "maybe"))

        expect_equal(levels(p), c("yes", "no", "maybe"))
        expect_equal(as.character(p), "maybe")
    })

    it("keeps ordered factors ordered", {
        p <- param(factor("lo", levels = c("lo", "hi"), ordered = TRUE))
        param_value(p) <- "hi"
        expect_identical(
            param_value(p),
            factor("hi", levels = c("lo", "hi"), ordered = TRUE)
        )
    })

    it("reads date-time strings in the time zone of the param", {
        withr::local_timezone("Europe/Berlin")
        time <- as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
        p <- param(time)

        param_value(p) <- "2026-01-01 10:00:00"
        expect_identical(param_value(p), time)

        local <- param(as.POSIXlt(time))
        param_value(local) <- "2026-01-01 10:00:00"
        expect_identical(param_value(local), as.POSIXlt(time))
    })

    it("reads ISO 8601 date-time strings with T and Z", {
        withr::local_timezone("Europe/Berlin")
        p <- param(as.POSIXct("2026-01-01 10:00:00", tz = "America/New_York"))

        param_value(p) <- "2026-01-01T15:00:00Z"
        expect_identical(
            param_value(p),
            as.POSIXct("2026-01-01 10:00:00", tz = "America/New_York")
        )
        param_value(p) <- c("2026-01-01T15:00:00.5Z", "2026-01-01T10:00:00")
        expect_equal(
            unclass(param_value(p)),
            unclass(as.POSIXct(
                c("2026-01-01 15:00:00.5", "2026-01-01 15:00:00"),
                tz = "UTC"
            )),
            ignore_attr = TRUE
        )
        expect_identical(attr(param_value(p), "tzone"), "America/New_York")
    })

    it("takes the plain value of a param value", {
        p <- param(1, label = "one")
        param_value(p) <- param(2, label = "two")

        expect_equal(param_value(p), 2)
        expect_equal(param_attr(p, "label"), "one")

        pg <- param_group(list(a = param(1), b = param("x")))
        param_value(pg) <- param_group(list(a = param(2), b = param("y")))
        expect_equal(param_value(pg), list(a = 2, b = "y"))
    })

    it("yields an identical object when setting the current value", {
        params <- list(
            param("a", source = "user"),
            numeric_param(1.5, min = 0, max = 2),
            numeric_param(2L),
            numeral_param("1.20"),
            choice_param("b", choices = c("a", "b")),
            choice_param("no", c("yes", "no")),
            param(TRUE),
            param(list(a = 1)),
            param(data.frame(a = 1:2)),
            param(as.Date("2026-10-04")),
            param(as.POSIXct("2026-01-01 10:00:00", tz = "UTC")),
            param_group(list(a = param(1), b = choice_param("on", c("on", "off"))))
        )
        for (p in params) {
            q <- p
            param_value(q) <- param_value(p)
            expect_identical(q, p)
        }
    })

    it("signals an error for non-param input", {
        x <- "abc"
        expect_error(param_value(x) <- "def", "x must be a 'param' object")
    })
})


# ======================================================================================
# Validity
# ======================================================================================

# ---------------
# Validity checks
# ---------------

describe("param_validity()", {
    it("returns an empty string for a valid value", {
        p <- param("value")
        expect_equal(param_validity(p), "")
    })

    it("returns character(0) if no validity function is set", {
        p <- param("value", validity = NULL)
        expect_identical(param_validity(p), character(0))
    })

    it("uses default validity to signal empty and NA values", {
        p <- param(character())
        expect_equal(param_validity(p), "value cannot be empty")

        p <- param(NA_character_)
        expect_equal(param_validity(p), "value cannot be NA")
    })

    it("evaluates the validity function on the parameter value", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_equal(param_validity(p), "")

        p <- param(-3, validity = \(x) if (x > 0) "" else "invalid")
        expect_equal(param_validity(p), "invalid")
    })

    it("can evaluate a chain of validity functions", {
        p <- param(
            5,
            validity = list(
                \(x) if (x > 0) "" else "must be positive",
                \(x) if (x %% 2 == 0) "" else "must be even"
            )
        )

        expect_equal(param_validity(p), c("", "must be even"))
        expect_equal(param_validity(p, value = 6), c("", ""))
        expect_equal(
            param_validity(p, value = -2),
            c("must be positive", "")
        )
    })

    it("always tries to cast the validity result to a string", {
        p <- param(5, validity = \(x) if (x > 0) 1 else 0)
        expect_equal(param_validity(p), "1")

        p <- param(-3, validity = \(x) if (x > 0) 1 else 0)
        expect_equal(param_validity(p), "0")

        p <- param(2, validity = \(x) if (x > 0) c("o", "k"))
        expect_equal(param_validity(p, 2), "o, k")
        expect_equal(param_validity(p, -2), "")

        pg <- param_group(
            list(
                p1 = param(5, validity = \(x) if (x > 0) 1 else 0),
                p2 = param(-3, validity = \(x) if (x > 0) 1 else 0)
            ),
            validity = \(x) if (x$p1 > x$p2) 1 else 0
        )
        expect_equal(param_validity(pg), c(group = "1", p1 = "1", p2 = "0"))
    })

    it("can evaluate the validity function on a different value", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_equal(param_validity(p, value = 10), "")
        expect_equal(param_validity(p, value = -2), "invalid")
    })

    it("can handle errors in the validity function itself", {
        p <- param(5, validity = \(x) stop("something went wrong"))
        expect_equal(
            param_validity(p),
            "validity check failed: something went wrong"
        )
    })

    it("passes plain values to the validity functions", {
        seen <- NULL
        check <- \(x) {
            seen <<- x
            ""
        }
        p <- param(factor("b", levels = c("a", "b")), validity = check)

        param_validity(p)
        expect_identical(seen, factor("b", levels = c("a", "b")))

        param_validity(p, value = param("a", label = "other"))
        expect_identical(seen, "a")

        seenByGroup <- NULL
        checkGroup <- \(x) {
            seenByGroup <<- x
            ""
        }
        pg <- param_group(list(a = param(1), b = p), validity = checkGroup)
        param_validity(pg)
        expect_identical(
            seenByGroup,
            list(a = 1, b = factor("b", levels = c("a", "b")))
        )
        expect_identical(seen, factor("b", levels = c("a", "b")))
    })

    it("matches the values of group children by name", {
        pg <- param_group(list(
            lower = numeric_param(1, max = 5),
            upper = numeric_param(2, min = 3)
        ))

        expect_equal(
            param_validity(pg, value = list(upper = 4, lower = 6)),
            c(
                group = "",
                lower = "value must be less than or equal to max (5)",
                upper = ""
            )
        )
        expect_equal(
            param_validity(pg, value = list(lower = 1))[["upper"]],
            "value cannot be empty"
        )
        expect_equal(
            param_validity(pg, value = c(lower = 1, upper = 4)),
            c(group = "", lower = "", upper = "")
        )
        expect_equal(
            param_validity(pg, value = "not a list"),
            c(
                group = "",
                lower = "value cannot be empty",
                upper = "value cannot be empty"
            )
        )
    })

    it("collapses the messages of nested groups", {
        inner <- param_group(list(
            a = param(1, validity = \(x) "a bad"),
            b = param(2, validity = \(x) "b bad")
        ))
        outer <- param_group(list(inner = inner, c = param(3)))

        expect_equal(
            param_validity(outer),
            c(group = "", inner = "a bad, b bad", c = "")
        )
    })
})

describe("add_validity()", {
    it("appends validity functions and keeps default checks", {
        p <- param(5)
        p <- add_validity(p, \(x) if (x %% 2 == 0) "" else "must be even")

        expect_equal(param_validity(p), c("", "must be even"))
        expect_equal(param_validity(p, value = 6), c("", ""))

        info <- param_validity(p, value = NA_real_)
        expect_equal(info[[1]], "value cannot be NA")
        expect_match(info[[2]], "validity check failed")
    })

    it("accepts a list of validity functions", {
        p <- param(1)
        p <- add_validity(
            p,
            list(
                \(x) if (x > 0) "" else "must be positive",
                \(x) if (x < 10) "" else "must be less than 10"
            )
        )

        expect_equal(param_validity(p), c("", "", ""))
        expect_equal(
            param_validity(p, value = -1),
            c("", "must be positive", "")
        )
        expect_equal(
            param_validity(p, value = 12),
            c("", "", "must be less than 10")
        )
    })

    it("adds a cross-field rule to a param group", {
        limits <- param_group(list(
            lower = numeral_param("1.0"),
            upper = numeral_param("2.0")
        )) |>
            add_validity(\(x) {
                if (as.numeric(x$lower) < as.numeric(x$upper)) {
                    ""
                } else {
                    "lower must be below upper"
                }
            })

        expect_equal(param_validity(limits)[["group"]], "")
        expect_equal(
            param_validity(limits, list(lower = "3", upper = "2")),
            c(group = "lower must be below upper", lower = "", upper = "")
        )
    })

    it("adds to a param without validity functions; NULL adds nothing", {
        f <- \(x) if (x > 0) "" else "must be positive"
        p <- add_validity(param(1, validity = NULL), f)
        expect_equal(attr(p, "validity"), list(f))
        expect_equal(param_validity(p, value = -1), "must be positive")

        expect_identical(add_validity(p, NULL), p)
    })

    it("signals bad arguments", {
        expect_error(add_validity(1, \(x) ""), "x must be a 'param' object")
        expect_error(
            add_validity(param(1), "f"),
            "validity must be a function or list of functions"
        )
    })
})

describe("param_validity_assert()", {
    it("does not signal an error if the parameter value is valid", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_silent(param_validity_assert(p))
    })

    it("returns the parameter object invisibly if the value is valid", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_invisible(param_validity_assert(p))
        expect_equal(param_validity_assert(p), p)
    })

    it("returns the value invisibly if the value is valid", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_equal(param_validity_assert(p, value = 10), 10)
    })

    it("signals an error if the parameter value is invalid", {
        p <- param(-3, validity = \(x) if (x > 0) "" else "invalid")
        expect_error(param_validity_assert(p), "invalid")
    })

    it("can check the validity of a different value", {
        p <- param(5, validity = \(x) if (x > 0) "" else "invalid")
        expect_silent(param_validity_assert(p, value = 10))
        expect_error(param_validity_assert(p, value = -2), "invalid")
    })
})

describe("default_param_validity()", {
    it("signals empty and NA values", {
        expect_equal(default_param_validity(1), "")
        expect_equal(default_param_validity(list(a = 1)), "")
        expect_equal(default_param_validity(NULL), "value cannot be empty")
        expect_equal(
            default_param_validity(character()),
            "value cannot be empty"
        )
        expect_equal(default_param_validity(c(1, NA)), "value cannot be NA")
        expect_equal(
            default_param_validity(data.frame(a = c(1, NA))),
            "value cannot be NA"
        )
    })

    it("accepts formulas without a warning", {
        expect_no_warning(expect_equal(default_param_validity(y ~ x), ""))
        expect_equal(default_param_validity(~a), "")
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# ------------------
# Saving and reading
# ------------------

describe("saveRDS()/readRDS() of params", {
    # A function frame as environment of the group's validity closure, which (unlike the
    # test's environment) does not change after saving.
    make_params <- function() {
        list(
            chr = param("a", label = "chr", source = "user"),
            num = numeric_param(0.5, min = 0, max = 1, area = "analysis"),
            int = numeric_param(3L, step = 1),
            numeral = numeral_param("1.20"),
            choice = choice_param("b", choices = c("a", "b")),
            yesNo = choice_param("no", c("yes", "no")),
            onOff = choice_param("off", c("on", "off"), ui_widget = "radio"),
            lgl = param(TRUE, advanced = TRUE),
            df = param(data.frame(a = 1:2)),
            lst = param(list(a = 1, b = "x")),
            group = param_group(list(
                lower = numeric_param(1),
                upper = numeric_param(2)
            )) |>
                add_validity(\(x) if (x$lower < x$upper) "" else "bad")
        )
    }

    it("keeps params of all types including their validity checks", {
        params <- make_params()
        file <- withr::local_tempfile(fileext = ".rds")
        saveRDS(params, file)
        restored <- readRDS(file)

        expect_equal(restored, params, ignore_function_env = TRUE)
        for (name in names(params)) {
            expect_identical(
                param_value(restored[[name]]),
                param_value(params[[name]])
            )
            expect_identical(class(restored[[name]]), class(params[[name]]))
            expect_identical(
                param_validity(restored[[name]]),
                param_validity(params[[name]])
            )
        }
        expect_equal(
            param_validity(restored$num, value = 2),
            "value must be less than or equal to max (1)"
        )
        expect_equal(
            param_validity(restored$choice, value = "c"),
            "value must be one of: a, b"
        )
        expect_equal(
            param_validity(restored$group, list(lower = 3, upper = 2)),
            c(group = "bad", lower = "", upper = "")
        )
    })
})
