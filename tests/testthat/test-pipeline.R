empty_list <- function() rlang::set_names(list(), character(0))

# Param object or value stored for `name` in each step that has it
stored <- function(x, name) {
    params <- Filter(\(p) name %in% names(p), x[["params"]])
    lapply(params, \(p) p[[name]])
}

# Deparsed formals of a function, or elements of a list (e.g. step params)
as_text <- function(x) {
    if (is.function(x)) {
        x <- as.list(formals(x))
    }
    vapply(x, deparse1, character(1))
}

simple_pipeline <- function() {
    p <- pipeflow::pip_new("simple") |>
        pipeflow::pip_add(
            "s1",
            \(x = "", n = 1, choice = factor("a", c("a", "b")), y = 3) {
                list(x = x, n = n, choice = choice, y = y)
            }
        ) |>
        pipeflow::pip_add("s2", \(x = "", s1 = ~s1) x)
    pipeflow::pip_set_params(
        p,
        param_config(
            x = param("x", label = "x-label", source = "user"),
            n = numeric_param(1, min = 0, max = 10, label = "number"),
            choice = choice_param("a", choices = c("a", "b"), label = "Choice")
        ),
        unknown = "error"
    )
}


# ======================================================================================
# Params in pipelines
# ======================================================================================

# ----------------
# Values for steps
# ----------------

describe("steps of pipelines with params", {
    it("stores param objects, but the step receives plain values", {
        p <- simple_pipeline()

        expect_true(is_param(p[["s1", "params"]]$x))
        run_quietly(p)

        expect_identical(
            p[["s1", "out"]],
            list(x = "x", n = 1, choice = factor("a", c("a", "b")), y = 3)
        )
    })

    it("hands plain values of groups and `...` params to the step", {
        # pubflow's pip_param_value() method
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add(
                "s",
                \(x = "", n = 1, limits = list(), ...) {
                    list(x = x, n = n, limits = limits, dots = list(...))
                },
                params = list(extra = "")
            )
        pipeflow::pip_set_params(
            p,
            param_config(
                x = param("x", label = "x-label"),
                n = numeric_param(2, min = 0),
                limits = param_group(list(
                    lower = numeral_param("1"),
                    inner = param_group(list(v = numeric_param(3)))
                )),
                extra = param("e")
            ),
            unknown = "error"
        )

        run_quietly(p)

        expect_identical(
            p[["s", "out"]],
            list(
                x = "x",
                n = 2,
                limits = list(lower = "1", inner = list(v = 3)),
                dots = list(extra = "e")
            )
        )
        expect_true(is_param(p[["s", "params"]]$limits))
    })

    it("lets params override the defaults of fun", {
        # pipeflow >= 0.5.0.9009
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("a", \() 1) |>
            pipeflow::pip_add("s", \(x = 1, y = 2) x + y, params = list(x = 5, y = ~a))

        run_quietly(p)

        expect_identical(p[["s", "out"]], 6)
        expect_identical(p[["s", "depends"]], c(y = "a"))
    })

    it("keeps param attributes out of the results", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s", \(batches = "b1", ylab = "y") {
                cbind(data.frame(Batch = batches), data.frame(Test = ylab))
            })
        pipeflow::pip_set_params(
            p,
            list(
                batches = c("b1", "b2", "b3"),
                ylab = param("Response", label = "y-axis label")
            )
        )

        run_quietly(p)

        expect_identical(p[["s", "out"]]$Test, rep("Response", 3L))
    })

    it("passes failures to the ~try() references of a layout step", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("data", \(n = 3) seq_len(n)) |>
            pipeflow::pip_add("check", \(data = ~data) stop("no limits")) |>
            pipeflow::pip_add("doc", \(data = ~ try(data), check = ~ try(check)) {
                list(data, check)
            }) |>
            pipeflow::pip_add("sum", \(check = ~check) sum(check))

        expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )
        doc <- p[["doc", "out"]]
        expect_identical(doc[[1]], 1:3)
        expect_s3_class(doc[[2]], "pipeflow_failure")
        expect_identical(doc[[2]]$failed_step, "check")
        expect_identical(p[["sum", "state"]], "new")
    })

    it("takes the params of a replaced step from the new function's formals", {
        p <- simple_pipeline()
        pipeflow::pip_set_params(p, list(x = "user"))
        fun <- \(x = "x", z = 0) toupper(x)

        expect_warning(
            pipeflow::pip_replace(p, "s1", fun),
            class = "pipeflow_param_conflict"
        )
        run_quietly(p)

        expect_identical(p[["s1", "params"]]$x, "x")
        expect_true(is_param(p[["s2", "params"]]$x))
        expect_identical(p[["s1", "out"]], "X")
    })

    it("keeps no stored value for a param the replacement binds", {
        p <- simple_pipeline()
        pipeflow::pip_set_params(p, list(x = "user"))
        pipeflow::pip_replace(p, "s2", \(x = ~s1) x$n, keep_params = TRUE)
        run_quietly(p)

        expect_identical(p[["s2", "depends"]], c(x = "s1"))
        expect_identical(p[["s2", "out"]], 1)
    })

    it("keeps the param objects with keep_params = TRUE", {
        p <- simple_pipeline()
        pipeflow::pip_set_params(p, list(x = "user"))
        fun <- \(x = "x", z = 0) toupper(x)

        expect_no_warning(pipeflow::pip_replace(p, "s1", fun, keep_params = TRUE))
        run_quietly(p)

        expect_true(is_param(p[["s1", "params"]]$x))
        expect_identical(p[["s1", "params"]]$x, p[["s2", "params"]]$x)
        expect_identical(p[["s1", "params"]]$z, 0)
        expect_identical(p[["s1", "out"]], "USER")
    })

    it("keeps the pipeline out of reach of a step's outputs", {
        # the output keeps the step frame alive; `unused` stays a promise
        fun <- function(x = 1, unused = 2) function() x
        environment(fun) <- globalenv()
        dots <- function(x = 1, ...) function() x
        environment(dots) <- globalenv()
        self <- function(x = 1) {
            name <- .self[["name"]]
            function() c(x, name)
        }
        environment(self) <- globalenv()
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s", fun) |>
            pipeflow::pip_add("d", dots, params = list(extra = 5)) |>
            pipeflow::pip_add("self", self)

        run_quietly(p)

        expect_false(reaches_pipeline(p[["s", "out"]]))
        expect_false(reaches_pipeline(p[["d", "out"]]))
        expect_false(reaches_pipeline(p[["self", "out"]]))
        expect_identical(p[["s", "out"]](), 1)
        expect_identical(p[["self", "out"]](), c("1", "p"))
        expect_true(reaches_pipeline(p))
    })
})

describe("step errors (pipeflow)", {
    it("name the running step, also after renaming", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("data", \(fail = FALSE) {
                if (fail) stop("boom") else 1
            })
        q <- rbind(p, p)
        pipeflow::pip_set_params(
            pipeflow::pip_view(q, step = "data2"),
            list(fail = TRUE),
            scope = "view"
        )

        err <- expect_error(
            run_quietly(q),
            "^step 'data2': boom$",
            class = "pipeflow_step_error"
        )
        expect_identical(err$step, "data2")
        expect_identical(conditionMessage(err$parent), "boom")
    })

    it("name the step and the key of a failed partition", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("split", \(x = 1) list(a = 1, b = 2), exec = "split") |>
            pipeflow::pip_add("calc", \(v = ~split) {
                if (v > 1) stop("too big") else v
            })

        err <- expect_error(
            run_quietly(p),
            "step 'calc': key 'b': too big",
            class = "pipeflow_step_error"
        )
        expect_s3_class(err$parent, "pipeflow_key_error")
    })

    it("keep the class of the step's own error", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("fit", \(x = 1) {
                rlang::abort("no fit", class = "my_error")
            })

        err <- expect_error(run_quietly(p), class = "pipeflow_step_error")
        expect_s3_class(err$parent, "my_error")
    })
})

describe("setting params (pubflow's setter)", {
    it("binds a param whose value is a one-sided formula", {
        # pipeflow >= 0.5.0.9010 binds one-sided formulas; formula values are given as
        # strings, two-sided ones are values
        new_p <- \() {
            pipeflow::pip_new("p") |>
                pipeflow::pip_add("a", \() 1) |>
                pipeflow::pip_add("b", \(f = NULL) f)
        }
        p <- new_p()

        pipeflow::pip_set_params(p, list(f = param(~a)))

        expect_identical(p[["b", "depends"]], c(f = "a"))

        p <- new_p()
        pipeflow::pip_set_params(p, list(f = param(y ~ x)))
        run_quietly(p)

        expect_length(p[["b", "depends"]], 0)
        expect_identical(deparse(p[["b", "out"]]), "y ~ x")
    })

    it("merges plain values into the stored param objects", {
        p <- simple_pipeline()

        pipeflow::pip_set_params(p, list(x = "new", n = 5, choice = "b"))
        params <- pub_get_params(p)

        expect_identical(param_value(params$x), "new")
        expect_identical(param_attr(params$x, "label"), "x-label")
        expect_identical(param_attr(params$x, "source"), "user")
        expect_identical(param_value(params$n), 5)
        expect_identical(param_attr(params$n, "max"), 10)
        expect_identical(as.character(params$choice), "b")
        expect_identical(levels(params$choice), c("a", "b"))
        expect_identical(param_attr(params$choice, "label"), "Choice")
    })

    it("merges per step into the value stored there", {
        p <- simple_pipeline()

        pipeflow::pip_set_params(p, list(x = "new"))

        expect_identical(stored(p, "x")$s1, stored(p, "x")$s2)
        expect_identical(param_value(stored(p, "x")$s2), "new")

        # a step holding a plain value gets the plain value
        p <- demo_pipeline()

        pipeflow::pip_set_params(p, list(yUnit = "mg"))

        yUnit <- stored(p, "yUnit")
        expect_identical(yUnit$data, "mg")
        expect_identical(param_value(yUnit$plot), "mg")
        expect_identical(param_attr(yUnit$plot, "label"), "Unit of y")
    })

    it("sets param objects as they are and plain-only names as values", {
        p <- simple_pipeline()
        x <- param("replaced", label = "other")

        pipeflow::pip_set_params(p, list(y = 10, x = x))

        expect_identical(stored(p, "y")$s1, 10)
        expect_identical(stored(p, "x"), list(s1 = x, s2 = x))
    })

    it("validates all values and sets nothing if any is invalid", {
        p <- demo_pipeline()
        before <- p[["params"]]

        err <- expect_error(
            pipeflow::pip_set_params(
                p,
                list(
                    alpha = 2,
                    xTrans = "exp",
                    ylab = "fine",
                    title = NA
                )
            ),
            class = "pipeflow_set_params_error"
        )

        # one entry per step and param, in pipeline order
        first <- !duplicated(err$errors$name)
        invalid <- err$errors[first, ]
        expect_setequal(invalid$name, c("alpha", "xTrans", "title"))
        message <- rlang::set_names(invalid$message, invalid$name)
        expect_match(message[["alpha"]], "less than or equal to max")
        expect_match(message[["xTrans"]], "must be one of: none")
        expect_true(all(vapply(
            err$parents,
            inherits,
            logical(1),
            "pubflow_invalid_param"
        )))
        labels <- vapply(err$parents[first], `[[`, "", "label")
        expect_identical(
            labels[invalid$name == "alpha"],
            "Significance level"
        )
        expect_identical(p[["params"]], before)
    })

    it("validates param objects given as values", {
        p <- simple_pipeline()

        err <- expect_error(
            pipeflow::pip_set_params(p, list(n = numeric_param(-1, min = 0))),
            class = "pipeflow_set_params_error"
        )
        expect_s3_class(err$parents[[1]], "pubflow_invalid_param")
    })

    it("validates param groups with their cross-field rule", {
        p <- demo_pipeline()

        err <- expect_error(
            pipeflow::pip_set_params(
                p,
                list(limits = list(lower = "110", upper = "x"))
            ),
            class = "pipeflow_set_params_error"
        )

        expect_identical(err$parents[[1]]$label, "Specification limits")
        expect_identical(
            unique(err$errors$message),
            paste(
                "lower limit must be below upper limit,",
                "upper: value was not coercible to numeric"
            )
        )
    })

    it("reports values that can't be merged as invalid", {
        p <- demo_pipeline()

        err <- expect_error(
            pipeflow::pip_set_params(
                p,
                list(limits = list(lower = "1"), alpha = 0.1),
                validate = FALSE
            ),
            class = "pipeflow_set_params_error"
        )

        expect_identical(unique(err$errors$name), "limits")
        expect_match(err$errors$message[[1]], "named list with names")
        expect_identical(param_value(pub_get_params(p)$alpha), 0.05)
    })

    it("sets invalid values with validate = FALSE", {
        p <- simple_pipeline()

        pipeflow::pip_set_params(p, list(n = 20), validate = FALSE)

        expect_identical(param_value(pub_get_params(p)$n), 20)
    })

    it("leaves steps done if the values are identical", {
        p <- demo_pipeline()
        run_quietly(p)
        params <- pub_get_params(p)

        pipeflow::pip_set_params(
            p,
            list(
                alpha = 0.05,
                xTrans = "none",
                limits = param_value(params$limits),
                ylab = params$ylab,
                exclude = FALSE
            )
        )

        expect_true(all(p[["state"]] == "done"))
    })

    it("outdates the steps having a changed value and downstream steps", {
        p <- demo_pipeline()
        run_quietly(p)

        pipeflow::pip_set_params(p, list(alpha = 0.1, xTrans = "none"))

        outdated <- names(p[["state"]])[p[["state"]] == "outdated"]
        expect_identical(
            outdated,
            c("fit", "slope_table", "limits_check", "summary", "check")
        )
    })

    it("outdates only the steps whose value changes", {
        p <- pipeflow::pip_new("independent") |>
            pipeflow::pip_add("a", \(x = "") x) |>
            pipeflow::pip_add("b", \(x = "") x)
        pipeflow::pip_set_params(p, list(x = param("x")))
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "b"),
            list(x = "y"),
            scope = "view"
        )
        run_quietly(p)

        pipeflow::pip_set_params(p, list(x = "y"))

        expect_identical(p[["a", "state"]], "outdated")
        expect_identical(p[["b", "state"]], "done")
        expect_identical(param_value(stored(p, "x")$a), "y")
    })

    it("sets derived params from within a step via .self", {
        p <- demo_pipeline()
        run_quietly(p)
        expect_identical(param_value(pub_get_params(p)$xlab), "Time")

        pipeflow::pip_set_params(p, list(xTrans = "log"))
        expect_identical(p[["plot", "state"]], "done")
        run_quietly(p)

        xlab <- pub_get_params(p)$xlab
        expect_identical(param_value(xlab), "log(Time)")
        expect_identical(param_attr(xlab, "label"), "x-axis label")
        expect_identical(p[["plot", "out"]]$xlab, "log(Time)")
        expect_true(all(p[["state"]] == "done"))
    })
})

describe("applying a config with pip_set_params()", {
    it("sets the param objects into every step having the name", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(x = "a", y = 1) x) |>
            pipeflow::pip_add("s2", \(x = "a") x)
        cfg <- param_config(x = param("b", label = "X"), y = param(2))

        pipeflow::pip_set_params(p, cfg, unknown = "error")

        expect_identical(stored(p, "x"), list(s1 = cfg$x, s2 = cfg$x))
        expect_identical(stored(p, "y"), list(s1 = cfg$y))
    })

    it("signals an error for unknown names unless told otherwise", {
        p <- simple_pipeline()

        expect_error(
            pipeflow::pip_set_params(
                p,
                list(foo = param(1), bar = param(2)),
                unknown = "error"
            ),
            "not defined in the target: foo, bar"
        )
        expect_warning(
            pipeflow::pip_set_params(
                p,
                list(foo = param(1), y = param(4)),
                unknown = "warn"
            ),
            "not defined in the target: foo$"
        )
        expect_identical(param_value(stored(p, "y")$s1), 4)
        expect_silent(pipeflow::pip_set_params(
            p,
            list(foo = param(1)),
            unknown = "ignore"
        ))
    })

    it("leaves steps done if the config is already applied", {
        p <- simple_pipeline()
        run_quietly(p)

        pipeflow::pip_set_params(p, pub_get_params(p), unknown = "error")
        expect_true(all(p[["state"]] == "done"))
        pipeflow::pip_set_params(
            p,
            list(n = numeric_param(1, label = "other")),
            unknown = "error"
        )
        expect_identical(p[["s1", "state"]], "outdated")
    })

    it("outdates only the steps that hold a different object", {
        p <- pipeflow::pip_new("independent") |>
            pipeflow::pip_add("a", \(x = "") x) |>
            pipeflow::pip_add("b", \(x = "") x)
        pipeflow::pip_set_params(p, list(x = param("x")), unknown = "error")
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "b"),
            list(x = param("y")),
            unknown = "error",
            scope = "view"
        )
        run_quietly(p)

        pipeflow::pip_set_params(
            p,
            list(x = stored(p, "x")$b),
            unknown = "error"
        )

        expect_identical(p[["a", "state"]], "outdated")
        expect_identical(p[["b", "state"]], "done")
        expect_identical(stored(p, "x")$a, stored(p, "x")$b)
    })

    it("unifies params of combined pipelines with the merged config", {
        # rbind() warns that the units differ
        expect_warning(
            unmerged <- demo_combined_pipeline(apply_config = FALSE),
            "'yUnit' is \"mg\" in step 'label', but \"%\" in step 'data'",
            fixed = TRUE,
            class = "pipeflow_param_conflict"
        )
        yUnit <- stored(unmerged, "yUnit")
        expect_identical(names(yUnit), c("data", "label"))
        expect_false(identical(yUnit$data, yUnit$label))

        full <- demo_combined_pipeline()
        merged <- param_config(
            demo_prep_config(),
            demo_stats_config(),
            .duplicates = "first"
        )

        for (name in names(merged)) {
            for (value in stored(full, name)) {
                expect_identical(value, merged[[name]])
            }
        }
        expect_identical(param_attr(merged$yUnit, "label"), "Unit of y (data)")
        run_quietly(full)
        expect_identical(full[["label", "out"]], "y [%]")
        expect_identical(full[["fit", "out"]], demo_fit(demo_data(), "none", 0.05))
    })
})


# --------------
# Reading params
# --------------

describe("pub_get_params()", {
    it("returns the param objects of a pipeline in config order", {
        p <- demo_pipeline()

        params <- pub_get_params(p)

        expect_identical(names(params), names(demo_config()))
        expect_true(all(vapply(params, is_param, logical(1))))
        expect_identical(params$xTrans, stored(p, "xTrans")$settings)
    })

    it("finds a param shadowed by an earlier plain default", {
        p <- demo_pipeline()

        expect_identical(pipeflow::pip_get_params(p)$yUnit, "")
        yUnit <- pub_get_params(p)$yUnit
        expect_true(is_param(yUnit))
        expect_identical(param_value(yUnit), "%")
        expect_identical(param_attr(yUnit, "label"), "Unit of y")
    })

    it("filters by param attributes", {
        p <- demo_pipeline()

        res <- pub_get_params(p, source = "user", area = "plot")

        expect_identical(names(res), c("ylab", "yUnit", "showPoints", "smooth"))
        expect_identical(
            names(pub_get_params(p, source = "internal")),
            c("xlab", "failCheck")
        )
        expect_no_warning(res <- pub_get_params(p, source = "nope"))
        expect_identical(res, empty_list())
    })

    it("keeps the params without an attribute for a NULL filter", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("a", \(x = 1, y = 2) x)
        pipeflow::pip_set_params(
            p,
            param_config(x = param(1, source = "user"), y = param(2))
        )

        expect_identical(names(pub_get_params(p, source = NULL)), "y")
    })

    it("does no partial matching of attribute names", {
        p <- demo_pipeline()

        expect_identical(pub_get_params(p, sour = "user"), empty_list())
    })

    it("signals unnamed filters", {
        p <- demo_pipeline()

        expect_error(pub_get_params(p, "user"), "must be named")
        expect_error(pub_get_params(p, source = "user", "x"), "must be named")
    })

    it("sorts by pipeline order on request", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(b = 1, a = 2) a) |>
            pipeflow::pip_add("s2", \(c = 3) c)
        pipeflow::pip_set_params(
            p,
            param_config(
                c = param(3),
                a = param(2),
                b = param(1)
            ),
            unknown = "error"
        )

        expect_identical(names(pub_get_params(p)), c("c", "a", "b"))
        expect_identical(
            names(pub_get_params(p, order = "pipeline")),
            c("b", "a", "c")
        )
    })

    it("places a name where the pipeline first uses it, also as plain default", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(a = 1) a) |>
            pipeflow::pip_add("s2", \(b = 2) b) |>
            pipeflow::pip_add("s3", \(a = 1, b = 2) a)
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "s3"),
            list(a = param(1)),
            scope = "view"
        )
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "s2"),
            list(b = param(2)),
            scope = "view"
        )

        params <- pub_get_params(p, order = "pipeline")

        expect_identical(names(params), c("a", "b"))
        expect_identical(params$a, p[["s3", "params"]]$a)
    })

    it("puts params without order after the ordered ones", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(u = 1, b = 1, a = 2) a)
        pipeflow::pip_set_params(
            p,
            param_config(a = param(2), b = param(1)),
            unknown = "error"
        )
        pipeflow::pip_set_params(p, list(u = param(0)))

        expect_identical(names(pub_get_params(p)), c("a", "b", "u"))
    })

    it("places params without order where the pipeline first uses the name", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("data", \(yUnit = "") yUnit) |>
            pipeflow::pip_add("plot", \(ylab = "", yUnit = "") ylab)
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "plot"),
            list(ylab = param(""), yUnit = param("")),
            scope = "view"
        )

        expect_identical(names(pub_get_params(p)), c("yUnit", "ylab"))
    })

    it("keeps pipeline order for equal orders and orders that aren't one number", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(a = 1, b = 2, c = 3, d = 4, e = 5) a)
        pipeflow::pip_set_params(
            p,
            list(
                a = param(1, order = 2),
                b = param(2, order = "1"),
                c = param(3, order = 1),
                d = param(4, order = c(0, 1)),
                e = param(5, order = 1L)
            )
        )

        expect_identical(names(pub_get_params(p)), c("c", "e", "a", "b", "d"))
    })

    it("works on views", {
        p <- demo_pipeline()
        v <- pipeflow::pip_view(p, step = c("data", "fit"))

        expect_identical(
            names(pub_get_params(v)),
            c("alpha", "xTrans", "exclude")
        )
        expect_null(pub_get_params(v)$yUnit)
    })

    it("includes locked steps of a view", {
        p <- demo_pipeline()
        v <- pipeflow::pip_view(p, step = c("data", "fit"))
        pipeflow::pip_lock(pipeflow::pip_view(p, step = "fit"))

        expect_identical(names(pub_get_params(v)), c("alpha", "xTrans", "exclude"))
    })

    it("does not mark the params of locked steps", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(a = 1) a)
        pipeflow::pip_set_params(p, param_config(a = param(1)), unknown = "error")
        pipeflow::pip_lock(p)

        # set back (e.g. as a config), a mark would outlive pip_unlock()
        expect_null(attr(pub_get_params(p)$a, "locked"))
    })

    it("keeps the attribute locked of a config", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(a = 1, b = 2) a)
        pipeflow::pip_set_params(
            p,
            param_config(a = param(1, locked = TRUE), b = param(2, locked = FALSE)),
            unknown = "error"
        )

        expect_identical(names(pub_get_params(p, locked = TRUE)), "a")
        expect_false(attr(pub_get_params(p)$b, "locked"))
    })

    it("returns an empty named list for an empty pipeline", {
        res <- pub_get_params(pipeflow::pip_new("empty"))

        expect_identical(res, empty_list())
        expect_identical(names(res), character(0))
        noParams <- pipeflow::pip_add(pipeflow::pip_new("p"), "s1", \() 1)
        expect_identical(pub_get_params(noParams), empty_list())
        expect_error(pub_get_params(list()), "pipeline or view")
        expect_error(pub_get_params(demo_pipeline(), order = "x"), "must be one of")
    })
})


# ======================================================================================
# Step outputs
# ======================================================================================

# ------------------
# Up-to-date outputs
# ------------------

describe("pub_out()", {
    # 'content' depends on 'fit'; 'other' fails without being upstream
    test_pipeline <- function() {
        pipeflow::pip_new("Water") |>
            pipeflow::pip_add("data", \(n = 3) seq_len(n)) |>
            pipeflow::pip_add("fit", \(x = ~data, fail = FALSE) {
                if (fail) {
                    stop("no trend")
                }
                sum(x)
            }) |>
            pipeflow::pip_add("content", \(fit = ~fit) {
                pub_text(paste("Sum:", fit))
            }) |>
            pipeflow::pip_add("other", \(failOther = FALSE) {
                if (failOther) {
                    stop("other failure")
                }
                1
            })
    }
    run_failing <- function(p, on_error) {
        pipeflow::pip_set_params(p, list(fail = TRUE))
        suppressWarnings(
            try(run_quietly(p, on_error = on_error), silent = TRUE),
            classes = "pipeflow_run_failed"
        )
        p
    }

    it("returns the output of a step that is done", {
        p <- test_pipeline()
        run_quietly(p)

        expect_identical(pub_out(p, "content"), "Sum: 6")
        v <- pipeflow::pip_view(p, step = "content")
        expect_identical(pub_out(v, "content"), "Sum: 6")
    })

    it("finds the failed steps outside of a view", {
        p <- run_failing(test_pipeline(), "continue")
        v <- pipeflow::pip_view(p, step = "content")

        err <- expect_error(pub_out(v, "content"), class = "pubflow_not_done")

        expect_identical(err$failed, "fit")
        expect_match(conditionMessage(err), "no trend", fixed = TRUE)
        item <- pub_out(v, "content", on_error = "item")
        expect_identical(item$failed_step, "fit")
        expect_identical(item$pipeline, "Water")
    })

    it("returns partitioned outputs as they are", {
        p <- demo_split_report_pipeline()
        run_quietly(p)

        sections <- pub_out(p, "batch_section")

        expect_s3_class(sections, "pipeflow_partitioned")
        expect_identical(sections, p[["batch_section", "out"]])
    })

    it("signals an error for a step that never ran", {
        p <- test_pipeline()

        err <- expect_error(pub_out(p, "content"), class = "pubflow_not_done")

        expect_s3_class(err, "pubflow_error")
        expect_identical(err$pipeline, "Water")
        expect_identical(err$step, "content")
        expect_identical(err$state, "new")
        expect_identical(err$failed, character())
        expect_match(
            conditionMessage(err),
            paste(
                "The output of step 'content' of pipeline 'Water' is not",
                "up to date (state \"new\")."
            ),
            fixed = TRUE
        )
        expect_match(conditionMessage(err), "Run the pipeline first.", fixed = TRUE)
        expect_error(
            pub_out(p, "content", on_error = "item"),
            class = "pubflow_not_done"
        )
    })

    it("doesn't return the stale output after a failed run", {
        for (onError in c("stop", "continue")) {
            p <- test_pipeline()
            run_quietly(p)
            run_failing(p, onError)
            expect_identical(p[["content", "out"]], "Sum: 6")

            err <- expect_error(pub_out(p, "content"), class = "pubflow_not_done")

            expect_identical(err$state, "outdated")
            expect_identical(err$failed, "fit")
        }
    })

    it("names the message of a failed step", {
        for (on_error in c("continue", "stop")) {
            p <- run_failing(test_pipeline(), on_error)
            expect_error(
                pub_out(p, "content"),
                "Step 'fit' failed: no trend",
                fixed = TRUE
            )
        }
    })

    it("has no message for a failed step whose output was set", {
        p <- run_failing(test_pipeline(), "stop")
        p[["fit", "out"]] <- 1

        expect_error(
            pub_out(p, "content"),
            "Step 'fit' failed: no message kept",
            fixed = TRUE
        )
    })

    it("returns an error item for a failed part on request", {
        p <- run_failing(test_pipeline(), "continue")

        item <- pub_out(p, "content", on_error = "item")

        expect_identical(
            item,
            structure(
                list(
                    step = "content",
                    failed_step = "fit",
                    message = "no trend",
                    pipeline = "Water"
                ),
                class = "pub_error"
            )
        )
        expect_identical(pub_type(item), "error")
        item <- pub_out(p, "fit", on_error = "item")
        expect_identical(item$step, "fit")
        expect_identical(item$failed_step, "fit")
    })

    describe("a step that failed for some partition keys", {
        # 'show' is mapped after 'calc' and not run for the failed key
        split_pipeline <- function() {
            pipeflow::pip_new("Split") |>
                pipeflow::pip_add(
                    "split",
                    \(x = list(a = 1, b = 2)) x,
                    exec = "split"
                ) |>
                pipeflow::pip_add("calc", \(v = ~split) {
                    if (v > 1) stop("too big") else v
                }) |>
                pipeflow::pip_add("show", \(v = ~calc) {
                    pub_text(paste("Value", v))
                })
        }
        run_continued <- function(p) {
            suppressWarnings(
                run_quietly(p, on_error = "continue"),
                classes = "pipeflow_run_failed"
            )
            p
        }

        it("gives the outputs of the other keys and error items", {
            p <- run_continued(split_pipeline())

            out <- pub_out(p, "show", on_error = "item")

            expect_s3_class(out, "pipeflow_partitioned")
            expect_identical(out$a, p[["show", "out"]]$a)
            expect_identical(
                out$b,
                structure(
                    list(
                        step = "show",
                        failed_step = "calc",
                        message = "key 'b': too big",
                        pipeline = "Split"
                    ),
                    class = "pub_error"
                )
            )
            expect_identical(pub_out(p, "calc", on_error = "item")$b$step, "calc")
        })

        it("places one error box per failed key", {
            p <- run_continued(split_pipeline())

            doc <- pub_doc(pub_out(p, "show", on_error = "item"))

            keys <- doc$children
            expect_identical(vapply(keys, \(k) k$title, character(1)), c("a", "b"))
            expect_identical(keys[[1L]]$children[[1L]]$type, "text")
            expect_identical(keys[[2L]]$children[[1L]]$type, "error")
        })

        it("signals an error naming the failed keys by default", {
            p <- run_continued(split_pipeline())

            expect_error(
                pub_out(p, "show"),
                "key 'b': too big",
                class = "pubflow_not_done"
            )
        })

        it("gives one error item if the output holds no failures", {
            p <- run_continued(split_pipeline())
            p[["calc", "out"]] <- structure(
                list(a = 1),
                class = c("list", "pipeflow_partitioned")
            )

            item <- pub_out(p, "calc", on_error = "item")

            expect_s3_class(item, "pub_error")
            expect_identical(item$failed_step, "calc")
            expect_identical(item$message, "no message kept")
        })

        it("gives one error item after a run that stopped", {
            p <- split_pipeline()
            try(run_quietly(p), silent = TRUE)

            item <- pub_out(p, "show", on_error = "item")

            expect_s3_class(item, "pub_error")
            expect_identical(item$failed_step, "calc")
        })

        it("doesn't give outputs of an earlier run", {
            p <- split_pipeline() |>
                pipeflow::pip_add("other", \(z = 1) stop("other fails"))
            run_continued(p)
            pipeflow::pip_set_params(p, list(x = list(a = 2, b = 1)))
            try(run_quietly(p), silent = TRUE)
            run_continued(pipeflow::pip_view(p, step = "other"))

            item <- pub_out(p, "calc", on_error = "item")

            expect_s3_class(item, "pub_error")
            expect_identical(item$message, "key 'a': too big")
        })
    })

    it("counts only the failed steps that the step depends on", {
        p <- test_pipeline()
        pipeflow::pip_set_params(p, list(failOther = TRUE))
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )
        expect_identical(pub_out(p, "content"), "Sum: 6")
        # 'content' outdated, nothing failed
        pipeflow::pip_set_params(p, list(n = 4))

        err <- expect_error(
            pub_out(p, "content", on_error = "item"),
            class = "pubflow_not_done"
        )
        expect_identical(err$failed, character())
        expect_identical(p[["other", "state"]], "failed")
    })

    it("blames a step that failed itself after receiving a failure", {
        p <- pipeflow::pip_new("P") |>
            pipeflow::pip_add("fit", \(n = 1) stop("no trend")) |>
            pipeflow::pip_add("content", \(fit = ~ try(fit)) {
                stop("can't place it")
            })
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )

        item <- pub_out(p, "content", on_error = "item")

        expect_identical(item$step, "content")
        expect_identical(item$failed_step, "content")
        expect_identical(item$message, "can't place it")
    })

    it("stops looking for failures at steps that are done", {
        p <- pipeflow::pip_new("P") |>
            pipeflow::pip_add("fit", \(n = 1) stop("no trend")) |>
            pipeflow::pip_add("safe", \(fit = ~ try(fit)) "fallback") |>
            pipeflow::pip_add("content", \(x = ~safe, label = "A") {
                paste(label, x)
            })
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )
        expect_identical(pub_out(p, "content"), "A fallback")
        pipeflow::pip_set_params(p, list(label = "B"))

        err <- expect_error(
            pub_out(p, "content", on_error = "item"),
            class = "pubflow_not_done"
        )
        expect_identical(err$failed, character())
    })

    it("takes the message of a stopped run, not of an earlier run", {
        p <- pipeflow::pip_new("P") |>
            pipeflow::pip_add("fit", \(msg = "first") stop(msg)) |>
            pipeflow::pip_add("content", \(fit = ~fit) fit)
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )
        expect_error(pub_out(p, "content"), "Step 'fit' failed: first", fixed = TRUE)
        pipeflow::pip_set_params(p, list(msg = "second"))
        try(run_quietly(p), silent = TRUE)

        err <- expect_error(pub_out(p, "content"), class = "pubflow_not_done")
        expect_no_match(conditionMessage(err), "first", fixed = TRUE)
        expect_match(conditionMessage(err), "Step 'fit' failed: second", fixed = TRUE)
    })

    it("validates its arguments", {
        p <- test_pipeline()
        expect_error(pub_out(list(), "content"), "pipeline or view")
        expect_error(pub_out(p, c("a", "b")), "`step` must be a string")
        expect_error(pub_out(p, "content", on_error = "drop"), "must be one of")
    })
})


# -------------
# Layout inputs
# -------------

describe("pub_layout_inputs()", {
    # 'table' and 'mean' are tagged "short", 'mean' and 'max' "long"
    test_pipeline <- function() {
        pipeflow::pip_new("inputs") |>
            pipeflow::pip_add("data", \(n = 4) {
                data.frame(x = seq_len(n), y = seq_len(n)^2)
            }) |>
            pipeflow::pip_add("table", \(data = ~data) data, tags = "short") |>
            pipeflow::pip_add("fit", \(data = ~data, fail = FALSE) {
                if (fail) {
                    stop("no fit")
                }
                mean(data$y)
            }) |>
            pipeflow::pip_add(
                "mean",
                \(fit = ~fit) paste("Mean:", fit),
                tags = c("short", "long")
            ) |>
            pipeflow::pip_add(
                "max",
                \(data = ~data) {
                    paste("Maximum:", max(data$y))
                },
                tags = "long"
            )
    }
    add_layout <- function(p, step, tags, ...) {
        inputs <- pub_layout_inputs(pipeflow::pip_view(p, tags = tags))
        pipeflow::pip_add(p, step, \(...) pub_doc(list(...)), params = inputs, ...)
    }

    it("returns ~try(step) for the steps of a view, in pipeline order", {
        p <- test_pipeline()
        inputs <- pub_layout_inputs(pipeflow::pip_view(p, tags = "long"))
        expect_named(inputs, c("mean", "max"))
        expect_identical(
            lapply(inputs, deparse),
            list(mean = "~try(mean)", max = "~try(max)")
        )
        expect_named(pub_layout_inputs(p), c("data", "table", "fit", "mean", "max"))
    })

    it("gives formulas that don't hold the caller's environment", {
        inputs <- pub_layout_inputs(test_pipeline())
        expect_true(all(vapply(inputs, inherits, logical(1), "formula")))
        expect_true(all(vapply(
            inputs,
            \(f) identical(environment(f), emptyenv()),
            logical(1)
        )))
    })

    it("makes a layout step that runs only the steps it needs", {
        p <- add_layout(test_pipeline(), "short", "short")
        expect_identical(unname(p[["depends"]][["short"]]), c("table", "mean"))
        run_quietly(pipeflow::pip_view(p, step = "short"))

        expect_identical(p[["max", "state"]], "new")
        expect_snapshot(print(p[["short", "out"]]))
    })

    it("shows a failed input as an error box, not its old output", {
        p <- add_layout(test_pipeline(), "short", "short")
        run_quietly(p)
        pipeflow::pip_set_params(p, list(fail = TRUE))
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )

        doc <- p[["short", "out"]]
        expect_identical(p[["short", "state"]], "done")
        expect_identical(doc$children[[2L]]$title, "mean")
        item <- doc$children[[2L]]$children[[1L]]
        expect_identical(item$type, "error")
        expect_identical(item$object$failed_step, "fit")
    })

    it("places partitioned and other outputs once with exec = 'reduce'", {
        p <- pipeflow::pip_new("split") |>
            pipeflow::pip_add("data", \() {
                data.frame(batch = c("A", "A", "B", "B"), y = 1:4)
            }) |>
            pipeflow::pip_add(
                "split_data",
                \(data = ~data) {
                    split(data, data$batch)
                },
                exec = "split"
            ) |>
            pipeflow::pip_add("table", \(data = ~split_data) data, tags = "report") |>
            pipeflow::pip_add(
                "mean",
                \(data = ~data) {
                    paste("Mean:", mean(data$y))
                },
                tags = "report"
            )
        add_layout(p, "doc", "report", exec = "reduce")
        run_quietly(p)

        expect_snapshot(print(p[["doc", "out"]]))
    })

    it("works with step names that are not syntactic", {
        p <- pipeflow::pip_new("names") |>
            pipeflow::pip_add("fit table", \() "Text", tags = "report")
        add_layout(p, "doc", "report")
        run_quietly(p)

        expect_identical(p[["doc", "out"]]$children[[1L]]$title, "fit table")
    })

    it("validates its argument", {
        p <- test_pipeline()
        expect_error(pub_layout_inputs(list()), "pipeline or view")
        expect_error(
            pub_layout_inputs(pipeflow::pip_view(p, tags = "none")),
            "`x` has no steps"
        )
    })

    it("rejects steps named .self or ...", {
        # pipeflow reserves the argument .self and drops ... from the inputs
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add(".self", \() "a") |>
            pipeflow::pip_add("...", \() "b")
        expect_error(
            pub_layout_inputs(p),
            "A step named '.self', '...' can't be an input of a layout step"
        )
    })
})


# ---------------
# Layout sections
# ---------------

describe("pub_layout_sections()", {
    # 'table' is tagged "Data", 'mean' "Data" and "Model"; 'mean' and 'slope'
    # depend on 'fit'; 'slope' returns NULL if `show_model` is FALSE
    test_pipeline <- function() {
        pipeflow::pip_new("sections") |>
            pipeflow::pip_add("data", \(n = 4) {
                data.frame(x = seq_len(n), y = seq_len(n)^2)
            }) |>
            pipeflow::pip_add("table", \(data = ~data) data, tags = "Data") |>
            pipeflow::pip_add("fit", \(data = ~data, fail = FALSE) {
                if (fail) {
                    stop("no fit")
                }
                stats::lm(y ~ x, data = data)
            }) |>
            pipeflow::pip_add(
                "mean",
                \(fit = ~fit) paste("Mean:", mean(stats::fitted(fit))),
                tags = c("Data", "Model")
            ) |>
            pipeflow::pip_add(
                "slope",
                \(fit = ~fit, show_model = TRUE) {
                    if (!show_model) {
                        return(NULL)
                    }
                    paste("Slope:", stats::coef(fit)[["x"]])
                }
            )
    }
    views <- \(p) {
        list(
            Model = pipeflow::pip_view(p, depends = "fit"),
            Data = pipeflow::pip_view(p, tags = "Data")
        )
    }
    titles <- \(doc) vapply(doc$children, \(s) s$title, character(1))
    item_types <- \(section) vapply(section$children, \(i) i$type, character(1))

    it("makes one section per view, in the order of `sections`", {
        p <- test_pipeline()
        pipeflow::pip_add(p, "doc", pub_layout_sections(views(p)))
        run_quietly(p)

        doc <- p[["doc", "out"]]
        expect_s3_class(doc, "pub_doc")
        expect_identical(titles(doc), c("Model", "Data"))
        expect_identical(item_types(doc$children[[1L]]), c("text", "text"))
        expect_identical(doc$children[[1L]]$children[[1L]]$object, "Mean: 7.5")
        expect_identical(item_types(doc$children[[2L]]), c("table", "text"))
    })

    it("takes the steps of the views as ~try() inputs and runs only what it needs", {
        p <- test_pipeline()
        layout <- pub_layout_sections(list(Data = pipeflow::pip_view(p, tags = "Data")))
        expect_identical(
            lapply(formals(layout), deparse),
            list(table = "~try(table)", mean = "~try(mean)")
        )
        pipeflow::pip_add(p, "doc", layout)
        run_quietly(pipeflow::pip_view(p, step = "doc"))

        expect_identical(p[["slope", "state"]], "new")
        expect_identical(titles(p[["doc", "out"]]), "Data")
    })

    it("doesn't keep the views or the pipeline in the step function", {
        layout <- pub_layout_sections(views(test_pipeline()))
        expect_identical(ls(environment(layout)), "steps")
    })

    it("shows a failed input as an error box in its section", {
        p <- test_pipeline()
        pipeflow::pip_add(p, "doc", pub_layout_sections(views(p)))
        pipeflow::pip_set_params(p, list(fail = TRUE))
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )

        data <- p[["doc", "out"]]$children[[2L]]
        expect_identical(item_types(data), c("table", "error"))
        expect_identical(data$children[[2L]]$object$failed_step, "fit")
    })

    it("leaves out a section whose outputs are all NULL", {
        p <- test_pipeline()
        sections <- list(
            Data = pipeflow::pip_view(p, tags = "Data"),
            Slope = pipeflow::pip_view(p, step = "slope")
        )
        pipeflow::pip_add(p, "doc", pub_layout_sections(sections))
        pipeflow::pip_set_params(p, list(show_model = FALSE))
        run_quietly(p)

        expect_identical(titles(p[["doc", "out"]]), "Data")
    })

    it("works with step names that are not syntactic", {
        p <- pipeflow::pip_new("names") |>
            pipeflow::pip_add("fit table", \() "Text")
        pipeflow::pip_add(p, "doc", pub_layout_sections(list(Results = p)))
        run_quietly(p)

        section <- p[["doc", "out"]]$children[[1L]]
        expect_identical(section$children[[1L]]$object, "Text")
    })

    it("works with steps named like the variables of the step function", {
        p <- pipeflow::pip_new("names") |>
            pipeflow::pip_add("steps", \() "A") |>
            pipeflow::pip_add("values", \() "B") |>
            pipeflow::pip_add("title", \() "C")
        pipeflow::pip_add(p, "doc", pub_layout_sections(list(S = p)))
        run_quietly(p)

        section <- p[["doc", "out"]]$children[[1L]]
        objects <- vapply(section$children, \(i) i$object, character(1))
        expect_identical(objects, c("A", "B", "C"))
    })

    it("names the section and its steps if an output can't be placed", {
        p <- pipeflow::pip_new("bad") |>
            pipeflow::pip_add("env", \() new.env())
        pipeflow::pip_add(p, "doc", pub_layout_sections(list(S = p)))
        err <- tryCatch(
            pipeflow::pip_run(p, lgr = NULL),
            error = \(e) e
        )
        expect_match(
            conditionMessage(err),
            "Can't place the outputs of section 'S' (steps 'env')",
            fixed = TRUE
        )
    })

    it("validates its argument", {
        p <- test_pipeline()
        data <- pipeflow::pip_view(p, tags = "Data")
        f <- pub_layout_sections
        msg <- "`sections` must be a list of views named by unique titles"
        expect_error(f(data), msg)
        expect_error(f(list()), msg)
        expect_error(f(list(data)), msg)
        expect_error(f(list(Data = data, data)), msg)
        expect_error(f(list(Data = data, Data = data)), msg)
        expect_error(
            f(list(Data = data, Model = "fit")),
            "must hold pipeflow views; 'Model' is not one"
        )
        expect_error(
            f(list(Data = data, None = pipeflow::pip_view(p, tags = "none"))),
            "The view of 'None' has no steps"
        )
        other <- test_pipeline()
        expect_error(
            f(list(Data = data, Model = pipeflow::pip_view(other, depends = "fit"))),
            "must be views of the same pipeline"
        )
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# ----------------------
# Split/reduce pipelines
# ----------------------

describe("split/reduce pipelines", {
    it("runs wrapped steps once per partition with plain values", {
        p <- demo_split_pipeline()
        calls <- new.env()
        calls$n <- 0L
        pipeflow::pip_add(
            p,
            "probe",
            \(
                data = ~split_data,
                xTrans = factor("none", demo_trans_choices),
                byVar = "batch"
            ) {
                calls$n <- calls$n + 1L
                list(n = nrow(data), xTrans = xTrans, byVar = byVar)
            },
            after = "split_data"
        )
        pipeflow::pip_set_params(p, demo_split_config(), unknown = "error")

        run_quietly(p)

        probe <- p[["probe", "out"]]
        expect_identical(calls$n, 3L)
        expect_s3_class(probe, "pipeflow_partitioned")
        expect_identical(names(probe), c("A", "B", "C"))
        for (out in probe) {
            expect_identical(
                out,
                list(
                    n = 4L,
                    xTrans = factor("none", demo_trans_choices),
                    byVar = "batch"
                )
            )
        }
    })

    it("passes the partitioned list to the reduce step", {
        p <- demo_split_pipeline()
        pipeflow::pip_set_params(p, list(decimals = "1"))

        run_quietly(p)

        expect_s3_class(p[["coefs", "out"]], "pipeflow_partitioned")
        combined <- p[["combine", "out"]]
        expect_identical(combined$batch, c("A", "B", "C"))
        expect_identical(combined$x, c(-0.3, -0.2, -0.3))
    })
})


# ----------------
# Nested pipelines
# ----------------

describe("nested pipelines (as.function())", {
    # inner step 'b' fails for a negative input; 'n' counts the runs of 'a'
    counting_pipeline <- function(env) {
        pipeflow::pip_new("inner") |>
            pipeflow::pip_add("a", \(x = 1, k = 1) {
                env$n <- env$n + 1L
                x * k
            }) |>
            pipeflow::pip_add("b", \(a = ~a, digits = 1) {
                if (a < 0) {
                    stop("negative input")
                }
                round(a / 3, digits)
            })
    }
    counting_nested <- function(env) {
        inner <- counting_pipeline(env)
        pipeflow::pip_set_params(
            inner,
            list(
                digits = numeric_param(1, label = "Digits", min = 0, max = 5)
            )
        )
        pipeflow::pip_new("outer") |>
            pipeflow::pip_add("xs", \(xs = list(a = 1, b = 2)) xs, exec = "split") |>
            pipeflow::pip_add(
                "run",
                as.function(inner, out = "b"),
                params = list(x = ~xs)
            )
    }

    it("makes the inner param objects params of the outer step", {
        p <- demo_nested_pipeline()

        params <- p[["inner_run", "params"]]

        for (name in names(demo_inner_config())) {
            expect_true(is_param(params[[name]]))
            expect_identical(params[[name]], pub_get_params(p)[[name]])
        }
        expect_identical(names(pub_get_params(p)), names(demo_nested_config()))
    })

    it("outdates the outer step when an inner param changes", {
        p <- demo_nested_pipeline()
        run_quietly(p)

        pipeflow::pip_set_params(p, list(decimals = "1"))

        expect_identical(p[["data", "state"]], "done")
        expect_identical(p[["split_data", "state"]], "done")
        expect_identical(p[["inner_run", "state"]], "outdated")
        expect_identical(p[["coef_table", "state"]], "outdated")
    })

    it("validates inner params set through the outer pipeline", {
        p <- demo_nested_pipeline()

        err <- expect_error(
            pipeflow::pip_set_params(p, list(alpha = 0.9)),
            class = "pipeflow_set_params_error"
        )

        expect_identical(err$errors$step, "inner_run")
        expect_identical(param_value(pub_get_params(p)$alpha), 0.05)
    })

    it("runs one inner pipeline per batch with the outer params", {
        p <- demo_nested_pipeline()
        pipeflow::pip_set_params(p, list(xTrans = "sqrt", alpha = 0.1))

        expect_no_warning(run_quietly(p))

        res <- p[["inner_run", "out"]]
        expect_identical(names(res), c("A", "B", "C"))
        inners <- pipeflow::pip_inner(p, "inner_run")
        for (key in names(res)) {
            expect_identical(
                res[[key]]$settings,
                list(xTrans = factor("sqrt", demo_trans_choices), alpha = 0.1)
            )
            inner <- inners[[key]]
            xTrans <- pub_get_params(inner)$xTrans
            expect_identical(param_value(xTrans), factor("sqrt", demo_trans_choices))
            expect_identical(param_attr(xTrans, "label"), "x transformation")
            expect_identical(
                inner[["data", "out"]],
                split(demo_data(), demo_data()$batch)[[key]]
            )
        }
    })

    it("lets downstream steps combine the inner outputs", {
        p <- demo_nested_pipeline()
        run_quietly(p)

        tab <- p[["coef_table", "out"]]

        fits <- demo_fit(demo_data(), "none", 0.05)
        expect_identical(tab$batch, c("A", "B", "C"))
        expect_equal(tab$slope, pub_round(fits$slope, 2))
        expect_equal(tab$lower, pub_round(fits$lower, 2))
    })

    it("reruns only the inner steps that a changed param outdates", {
        env <- new.env()
        env$n <- 0L
        p <- counting_nested(env)
        run_quietly(p)
        expect_identical(env$n, 2L)

        pipeflow::pip_set_params(p, list(digits = 2))
        run_quietly(p)

        expect_identical(env$n, 2L)
        expect_identical(p[["run", "out"]]$a, 0.33)
        expect_identical(p[["run", "out"]]$b, 0.67)
    })

    it("fails the outer step for the key of the failed inner step", {
        env <- new.env()
        env$n <- 0L
        p <- counting_nested(env)
        pipeflow::pip_set_params(p, list(xs = list(a = 1, b = -1)))

        expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )

        expect_identical(p[["run", "state"]], "failed")
        out <- pub_out(p, "run", on_error = "item")
        expect_identical(out$a, p[["run", "out"]]$a)
        expect_s3_class(out$b, "pub_error")
        expect_match(out$b$message, "key 'b': .*negative input")
    })
})
