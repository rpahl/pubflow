# ======================================================================================
# Metadata
# ======================================================================================

# -------------------
# Getting and setting
# -------------------

describe("pub_meta(), pub_set_meta(), `pub_meta<-`", {
    it("reads, sets and removes entries", {
        x <- pub_set_meta(1:3, title = "Numbers", locked = FALSE)

        expect_identical(pub_meta(x), list(title = "Numbers", locked = FALSE))
        expect_identical(pub_meta(x, "title"), "Numbers")
        expect_null(pub_meta(x, "caption"))
        expect_identical(attr(x, "pubflow"), pub_meta(x))

        x <- pub_set_meta(x, locked = NULL, extra = list(a = 1))
        expect_identical(pub_meta(x), list(title = "Numbers", extra = list(a = 1)))
    })

    it("returns an empty list without metadata", {
        expect_identical(pub_meta(1), list())
        expect_null(pub_meta("a", "title"))
    })

    it("replaces the whole list", {
        x <- pub_set_meta("text", title = "A", id = "a")

        pub_meta(x) <- list(caption = "C")
        expect_identical(pub_meta(x), list(caption = "C"))

        pub_meta(x) <- NULL
        expect_null(attributes(x))
        expect_identical(x, "text")
    })

    it("keeps the caption of a huxtable in huxtable's caption", {
        ht <- huxtable::hux(a = 1)

        ht <- pub_set_meta(ht, caption = "Table", title = "T")

        expect_identical(huxtable::caption(ht), "Table")
        expect_identical(pub_meta(ht), list(title = "T", caption = "Table"))
        expect_null(attr(ht, "pubflow")$caption)
        ht <- pub_set_meta(ht, caption = NULL)
        expect_identical(huxtable::caption(ht), NA_character_)
        expect_null(pub_meta(ht, "caption"))
    })

    it("treats a blank caption as none", {
        expect_null(pub_meta(pub_set_meta(1, caption = ""), "caption"))
        ht <- pub_set_meta(huxtable::hux(a = 1), caption = " ")
        expect_identical(huxtable::caption(ht), NA_character_)
        huxtable::caption(ht) <- ""
        expect_null(pub_meta(ht, "caption"))
        expect_identical(
            huxtable::caption(pub_table(data.frame(a = 1), caption = "")),
            NA_character_
        )
        old <- pub_table(data.frame(a = 1), caption = "Old")
        expect_identical(huxtable::caption(pub_table(old, caption = "")), NA_character_)
        expect_identical(huxtable::caption(pub_table(old)), "Old")
    })

    it("removes the caption of a huxtable with the whole list", {
        ht <- pub_set_meta(huxtable::hux(a = 1), caption = "Table", title = "T")

        pub_meta(ht) <- NULL

        expect_identical(huxtable::caption(ht), NA_character_)
        expect_null(attr(ht, "pubflow"))
        expect_identical(pub_meta(ht), list())
    })

    it("leaves the object alone without entries", {
        x <- pub_set_meta(1, title = "A")

        expect_identical(pub_set_meta(1), 1)
        expect_identical(pub_set_meta(x), x)
    })

    it("works on ggplot objects (ggplot2 3.x and 4.x)", {
        skip_if_not_installed("ggplot2")
        p <- ggplot2::ggplot()

        p <- pub_set_meta(p, caption = "Plot")

        expect_identical(pub_meta(p, "caption"), "Plot")
        expect_true(inherits(p, "ggplot"))
    })

    it("reports the function the user called", {
        err <- rlang::catch_cnd(pub_set_meta(1, width = -1), "error")
        expect_identical(err$call[[1L]], quote(pub_set_meta))
        x <- 1
        err <- rlang::catch_cnd(pub_meta(x) <- list(width = -1), "error")
        expect_identical(err$call[[1L]], quote(`pub_meta<-`))
        err <- rlang::catch_cnd(pub_set_meta(NULL, a = 1), "error")
        expect_identical(err$call[[1L]], quote(pub_set_meta))
    })

    it("validates the known keys", {
        expect_error(pub_set_meta(1, title = 1), "`title` must be a single")
        expect_error(pub_set_meta(1, width = -1), "`width` must be a positive")
        expect_error(pub_set_meta(1, width = Inf), "`width` must be a positive")
        for (bad in c("90", ".%", "90.%", "1.2.3%", "0%", "-5%", "5 %")) {
            expect_error(
                pub_set_meta(1, out_width = bad),
                "`out_width` must be a positive percentage"
            )
        }
        for (ok in c("90%", "12.5%", ".5%", "120%")) {
            expect_identical(
                pub_meta(pub_set_meta(1, out_width = ok)),
                list(out_width = ok)
            )
        }
        expect_error(pub_set_meta(1, landscape = "yes"), "`TRUE` or `FALSE`")
        expect_error(pub_set_meta(1, locked = NA), "`locked` must be `TRUE`")
        expect_error(pub_set_meta(1, title = NA_character_), "`title` must be")
        expect_error(pub_set_meta(1, id = c("a", "b")), "`id` must be")
        expect_error(pub_set_meta(1, height = c(1, 2)), "`height` must be")
        expect_error(pub_set_meta(1, font_size = 0), "`font_size` must be")
        expect_error(pub_set_meta(1, width = NA_real_), "`width` must be")
        expect_identical(
            pub_meta(pub_set_meta(1, extra = NA, type = 1)),
            list(extra = NA, type = 1)
        )
        expect_error(pub_set_meta(1, "x"), "must be named")
        expect_error(pub_set_meta(NULL, title = "x"), "metadata of `NULL`")
        x <- 1
        expect_error(pub_meta(x) <- list(1), "named list")
        expect_error(pub_meta(x) <- list(a = 1, 2), "named list")
        expect_error(pub_meta(x) <- "a", "named list")
        expect_error(pub_set_meta(1, a = 1, 2), "must be named")
        expect_error(pub_meta(1, key = 1), "`key` must be")
    })

    it("accepts ids that are valid as HTML ids and LaTeX and Typst labels", {
        for (id in c("a", "fig-1", "trend_lot2", "A9")) {
            expect_identical(pub_meta(pub_set_meta(1, id = id), "id"), id)
        }
        for (id in c("", "1a", "-a", "a-", "a_", "a b", "a:b", "a\"b", "a.b", "a\n")) {
            expect_error(pub_set_meta(1, id = id), "`id` must be a string of letters")
        }
    })
})


# ======================================================================================
# Output types
# ======================================================================================

# -----
# Types
# -----

describe("pub_type()", {
    it("knows the supported outputs", {
        recorded <- structure(list(), class = "recordedplot")
        widget <- structure(list(), class = c("datatables", "htmlwidget"))
        partitioned <- structure(
            list(a = 1),
            class = c("list", "pipeflow_partitioned")
        )
        section <- structure(list(), class = c("pub_section", "pub_node"))

        expect_identical(pub_type(NULL), "null")
        expect_identical(pub_type(list(a = 1, 2)), "list")
        expect_identical(pub_type(partitioned), "list")
        expect_identical(pub_type(section), "section")
        expect_identical(pub_type(.new_pub_png(as.raw(1:3), list())), "figure")
        expect_identical(pub_type(huxtable::hux(a = 1)), "table")
        expect_identical(pub_type(data.frame(a = 1)), "table")
        expect_identical(pub_type(matrix(letters[1:4], 2)), "table")
        expect_identical(pub_type(recorded), "figure")
        expect_identical(pub_type(widget), "widget")
        expect_identical(pub_type(c("a", "b")), "text")
        expect_identical(pub_type(pub_text("a")), "text")
        expect_identical(pub_type(structure("a", class = "glue")), "text")
        expect_identical(pub_type(pub_raw(md = "x")), "raw")
        expect_identical(pub_type(pub_pagebreak()), "pagebreak")
        expect_identical(pub_type(pub_toc()), "toc")
        expect_identical(pub_type(demo_failures()$fit), "error")
    })

    it("handles empty and borderline objects", {
        expect_identical(pub_type(character(0)), "text")
        expect_identical(pub_type(list()), "list")
        expect_identical(pub_type(matrix(1:4, 2)), "table")
        expect_identical(pub_type(data.frame()), "table")
        expect_identical(
            pub_type(pub_set_meta(data.frame(a = 1), type = "figure")),
            "table"
        )
        for (x in list(1, NA, factor("a"), array(1:8, c(2, 2, 2)))) {
            expect_error(pub_type(x), class = "pubflow_unsupported_output")
        }
    })

    it("recognises ggplot objects of the installed ggplot2", {
        skip_if_not_installed("ggplot2")

        expect_identical(pub_type(ggplot2::ggplot()), "figure")
    })

    it("recognises image files marked by pub_figure()", {
        file <- withr::local_tempfile(fileext = ".png")
        writeBin(as.raw(1:10), file)

        expect_identical(pub_type(file), "text")
        expect_identical(pub_type(pub_figure(file)), "figure")
    })

    it("converts other objects with as_pub_output()", {
        local_as_pub_output_method("legacy_result", \(x, ...) {
            pub_table(data.frame(value = unclass(x)))
        })
        local_as_pub_output_method("broken_result", \(x, ...) x)

        expect_identical(pub_type(structure(1, class = "legacy_result")), "table")
        expect_error(
            pub_type(structure(1, class = "broken_result")),
            "returned an unsupported output of class <broken_result>"
        )
    })

    it("calls as_pub_output() once, also if its result is unsupported", {
        calls <- 0L
        local_as_pub_output_method("counted_result", \(x, ...) {
            calls <<- calls + 1L
            structure(list(), class = "still_unsupported")
        })

        expect_error(
            pub_type(structure(1, class = "counted_result")),
            "unsupported output of class <still_unsupported>"
        )
        expect_identical(calls, 1L)
    })

    it("accepts NULL and lists from as_pub_output()", {
        local_as_pub_output_method("empty_result", \(x, ...) NULL)
        local_as_pub_output_method("list_result", \(x, ...) list(a = "text"))

        expect_identical(pub_type(structure(1, class = "empty_result")), "null")
        expect_identical(pub_type(structure(1, class = "list_result")), "list")
    })

    it("rejects a pipeline returned by as_pub_output()", {
        local_as_pub_output_method("pipeline_result", \(x, ...) pipeflow::pip_new("p"))

        expect_error(
            pub_type(structure(1, class = "pipeline_result")),
            "returned an unsupported output of class <pipeflow>"
        )
    })

    it("signals an error for unsupported outputs", {
        err <- expect_error(
            pub_type(structure(list(), class = c("foo", "bar"))),
            class = "pubflow_unsupported_output"
        )

        expect_s3_class(err, "pubflow_error")
        expect_match(
            conditionMessage(err),
            paste(
                "unsupported output of class <foo/bar>; provide an",
                "as_pub_output\\(\\) method"
            )
        )
        expect_error(pub_type(sum), class = "pubflow_unsupported_output")
        expect_error(
            pub_type(stats::lm(y ~ x, data.frame(x = 1:3, y = 1:3))),
            "class <lm>"
        )
    })
})


# ----------
# Conversion
# ----------

describe("as_pub_output()", {
    it("errors by default", {
        err <- expect_error(as_pub_output(1L), class = "pubflow_unsupported_output")

        expect_s3_class(err, "pubflow_error")
        expect_identical(err$class_name, "integer")
        expect_match(conditionMessage(err), "class <integer>")
    })
})


# ======================================================================================
# Content nodes
# ======================================================================================

# ---------------------------------------------
# Page break, table of contents and raw content
# ---------------------------------------------

describe("pub_pagebreak(), pub_toc(), pub_raw()", {
    it("create structure outputs", {
        expect_s3_class(pub_pagebreak(), "pub_pagebreak")
        expect_identical(pub_toc()$depth, 3L)
        expect_identical(pub_toc(depth = 1)$depth, 1L)
        expect_identical(pub_toc(depth = 6)$depth, 6L)
        expect_identical(pub_toc()$what, "sections")
        expect_identical(pub_toc(what = "figures")$what, "figures")
        expect_identical(pub_toc(what = "tables")$what, "tables")
    })

    it("joins raw content per target", {
        raw <- pub_raw(html = c("<hr>", "<br>"), latex = "\\hrule")

        expect_identical(unclass(raw), list(html = "<hr>\n<br>", latex = "\\hrule"))
        expect_identical(unclass(pub_raw(md = character(0))), list(md = ""))
    })

    it("print a short description", {
        expect_output(print(pub_pagebreak()), "page break")
        expect_output(print(pub_toc(2)), "table of contents, depth 2")
        expect_output(print(pub_toc(what = "tables")), "<pubflow list of tables>")
        expect_output(
            print(pub_raw(md = "x", typst = "y")),
            "raw content for typst, md"
        )
    })

    it("validate their input", {
        expect_error(pub_toc(0), "between 1 and 6")
        expect_error(pub_toc(2.5), "between 1 and 6")
        for (bad in list(7, NA, NA_integer_, "3", c(1, 2), TRUE, integer(0))) {
            expect_error(pub_toc(bad), "between 1 and 6")
        }
        expect_error(pub_toc(what = "pages"), "must be one of")
        expect_error(pub_raw(), "at least one target")
        expect_error(pub_raw(html = 1), "`html` must be a character")
        expect_error(pub_raw(md = NA_character_), "`md` must be a character")
        expect_error(pub_raw(md = factor("a")), "`md` must be a character")
        expect_error(pub_raw(html = "<hr>", typst = 1), "`typst` must be a character")
        expect_error(pub_raw(html = NULL, md = NULL), "at least one target")
    })
})


# ------------
# Session info
# ------------

describe("pub_session_info()", {
    it("is a section with the session info as code block", {
        withr::local_envvar(TZ = "UTC")

        res <- pub_session_info()

        expect_named(res, "Session info")
        expect_identical(pub_type(res), "list")
        text <- res[[1]]
        expect_match(text, "^```\nR version ")
        expect_match(text, "\n```$")
        expect_match(text, "pubflow", fixed = TRUE)
        expect_silent(.check_markdown(text))
        expect_named(pub_session_info("Annex: R"), "Annex: R")
        expect_error(pub_session_info(""), "non-empty string")
        for (bad in list(NA_character_, c("a", "b"), 1, NULL)) {
            expect_error(pub_session_info(bad), "non-empty string")
        }
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# -----------------------
# Report pipeline fixture
# -----------------------

stored_step_param <- function(p, step, name) {
    p[[step, "params"]][[name]]
}

describe("demo_report_pipeline() (fixture for documents)", {
    it("produces styled tables, a figure, text and a named list", {
        p <- demo_report_pipeline()

        run_quietly(p)
        out <- \(step) p[[step, "out"]]

        types <- vapply(demo_report_steps, \(s) pub_type(out(s)), "")
        expect_identical(
            unname(types),
            c("table", "table", "table", "figure", "text", "list")
        )
        data <- out("data_table")
        expect_identical(
            cell_text(data)[1:3, 1:3],
            rbind(
                c("", "Time [months]", "Time [months]"),
                c("Site\u00b9", "0", "3"),
                c("A", "100.00", "99.10")
            )
        )
        expect_identical(unname(huxtable::text_color(data)[5, 5]), "red")
        fit <- out("fit_table")
        expect_identical(unname(huxtable::rowspan(fit)[3, 1]), 2)
        expect_identical(cell_text(fit)[3, 2:5], c("Intercept", "99.94", "-", "-"))
        criteria <- out("criteria_table")
        expect_identical(
            unname(huxtable::markdown(criteria)[, 1]),
            c(FALSE, FALSE, FALSE, TRUE)
        )
        expect_identical(
            cell_text(criteria)[4, ],
            c("~~Slope below zero~~", "~~0~~", "~~-~~")
        )
        expect_identical(pub_meta(out("trend_plot"), "caption"), "Yield over time")
        expect_identical(pub_meta(out("conclusion"), "title"), "Conclusion")
        expect_named(out("results"), c("Fit", "Conclusion"))
        expect_identical(
            unname(vapply(out("results")$Fit, pub_type, "")),
            c("table", "figure")
        )
    })

    it("formats tables by the decimals param", {
        p <- demo_report_pipeline()
        pipeflow::pip_set_params(p, list(decimals = "1"))

        run_quietly(p)

        expect_identical(cell_text(p[["data_table", "out"]])[3, 2], "100.0")
        decimals <- pub_get_params(p)$decimals
        expect_identical(param_attr(decimals, "label"), "Decimal places")
        expect_identical(
            stored_step_param(p, "fit_table", "decimals"),
            decimals
        )
    })
})
