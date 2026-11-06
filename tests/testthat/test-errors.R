describe(".pubflow_error()", {
    it("creates an rlang error inheriting from pubflow_error", {
        cnd <- .pubflow_error("pubflow_x", "boom")

        expect_s3_class(cnd, "pubflow_x")
        expect_equal(
            class(cnd),
            c("pubflow_x", "pubflow_error", "rlang_error", "error", "condition")
        )
        expect_equal(conditionMessage(cnd), "boom")
    })

    it("puts several subclasses in front in the given order", {
        cnd <- .pubflow_error(c("pubflow_a", "pubflow_b"), "boom")

        expect_equal(
            class(cnd)[1:3],
            c("pubflow_a", "pubflow_b", "pubflow_error")
        )
    })

    it("has no parent and no call by default", {
        cnd <- .pubflow_error("pubflow_x", "boom")

        expect_null(cnd$parent)
        expect_null(conditionCall(cnd))
    })

    it("is not signalled until cnd_signal() is called", {
        expect_no_error(cnd <- .pubflow_error("pubflow_x", "boom"))

        expect_error(rlang::cnd_signal(cnd), "boom", class = "pubflow_x")
        expect_error(rlang::cnd_signal(cnd), class = "pubflow_error")
    })

    it("stores header and formatted bullets in the message field", {
        cnd <- .pubflow_error("pubflow_x", c("Header.", x = "bad", i = "hint"))

        lines <- strsplit(cnd$message, "\n", fixed = TRUE)[[1]]
        expect_length(lines, 3L)
        expect_equal(lines[[1]], "Header.")
        expect_match(lines[[2]], "bad", fixed = TRUE)
        expect_match(lines[[3]], "hint", fixed = TRUE)
    })

    it("ignores the name of the header line", {
        cnd <- .pubflow_error("pubflow_x", c(i = "Header.", x = "bad"))

        lines <- strsplit(cnd$message, "\n", fixed = TRUE)[[1]]
        expect_equal(lines[[1]], "Header.")
        expect_length(lines, 2L)
    })

    it("keeps braces in messages literally", {
        cnd <- .pubflow_error("pubflow_x", c("{trace}", i = "C:\\{x}"))

        expect_match(cnd$message, "{trace}", fixed = TRUE)
        expect_match(cnd$message, "C:\\{x}", fixed = TRUE)
    })

    it("stores extra fields, parent and call", {
        parent <- simpleError("original")
        cnd <- .pubflow_error(
            "pubflow_x",
            "boom",
            answer = 42,
            parent = parent,
            call = quote(pub_fun())
        )

        expect_equal(cnd$answer, 42)
        expect_identical(cnd$parent, parent)
        expect_equal(conditionCall(cnd), quote(pub_fun()))
    })

    it("takes the call from an execution environment", {
        pub_fun <- function() helper()
        helper <- function(call = rlang::caller_env()) {
            .pubflow_error("pubflow_x", "boom", call = call)
        }

        expect_equal(conditionCall(pub_fun()), quote(pub_fun()))
    })

    it("validates its arguments", {
        expect_error(.pubflow_error(character(), "boom"))
        expect_error(.pubflow_error("pubflow_x", character()))
        expect_error(.pubflow_error("pubflow_x", 1))
        expect_error(.pubflow_error(1, "boom"))
        expect_error(.pubflow_error(NULL, "boom"))
    })

    it("prints as an rlang error", {
        expect_snapshot(
            rlang::cnd_signal(.pubflow_error(
                "pubflow_x",
                c("Header.", x = "bad", i = "hint"),
                call = quote(pub_fun())
            )),
            error = TRUE
        )
    })
})

describe(".invalid_param_error()", {
    it("carries the message and the label of the param", {
        cnd <- .invalid_param_error(
            param(2, label = "Significance level"),
            "must be <= 1"
        )

        expect_s3_class(cnd, "pubflow_invalid_param")
        expect_s3_class(cnd, "pubflow_error")
        expect_identical(conditionMessage(cnd), "must be <= 1")
        expect_identical(cnd$label, "Significance level")
        expect_identical(
            .invalid_param_error(structure(1, class = "param"), "x")$label,
            NA_character_
        )
    })

    it("formats bullets of the message and keeps the call", {
        cnd <- .invalid_param_error(
            param(2),
            c("Invalid value:", x = "must be <= 1"),
            call = quote(pub_fun())
        )

        lines <- strsplit(cnd$message, "\n", fixed = TRUE)[[1L]]
        expect_identical(lines[[1L]], "Invalid value:")
        expect_match(lines[[2L]], "must be <= 1", fixed = TRUE)
        expect_equal(conditionCall(cnd), quote(pub_fun()))
    })

    it("is listed per step and param by pip_set_params()", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("fit", \(alpha = 0.05, lsl = "1", usl = "2") {
                alpha
            })
        pipeflow::pip_set_params(
            p,
            param_config(
                alpha = numeric_param(0.05, label = "Significance level", max = 1),
                lsl = param("1", validity = \(x) {
                    if (identical(x, "3")) "must be < usl" else ""
                })
            )
        )

        expect_snapshot(
            pipeflow::pip_set_params(p, list(alpha = 2, lsl = "3")),
            error = TRUE
        )
    })
})

describe("errors of pipeline steps (pipeflow)", {
    it("name the step once in errors, warnings and failures", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("fit", \(x = 1) stop("boom")) |>
            pipeflow::pip_add("doc", \(fit = ~ try(fit)) fit)

        expect_error(
            run_quietly(p),
            "^step 'fit': boom$",
            class = "pipeflow_step_error"
        )
        w <- expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )
        expect_match(conditionMessage(w), "'fit': boom$")
        expect_identical(
            conditionMessage(p[["doc", "out"]]),
            "step 'fit' failed: boom"
        )
    })

    it("keep the class and bullets of a pubflow error raised by a step", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("fit", \(x = 1) {
                rlang::cnd_signal(.pubflow_error(
                    "pubflow_invalid_param",
                    c(
                        "Invalid value for 1 parameter:",
                        x = "'alpha' (Alpha): must be <= 1"
                    )
                ))
            })

        err <- expect_error(run_quietly(p), class = "pipeflow_step_error")
        expect_s3_class(err$parent, "pubflow_invalid_param")
        expect_match(
            conditionMessage(err),
            "^step 'fit': Invalid value for 1 parameter:"
        )
        expect_match(
            conditionMessage(err),
            "'alpha' (Alpha): must be <= 1",
            fixed = TRUE
        )
    })
})

describe(".not_done_error()", {
    it("names the pipeline, the step, its state and the failed steps", {
        cnd <- .not_done_error(
            "Water",
            "content",
            "outdated",
            failed = c("data", "fit"),
            messages = c("no file", "no trend")
        )

        expect_s3_class(cnd, "pubflow_not_done")
        expect_s3_class(cnd, "pubflow_error")
        expect_identical(cnd$pipeline, "Water")
        expect_identical(cnd$step, "content")
        expect_identical(cnd$state, "outdated")
        expect_identical(cnd$failed, c("data", "fit"))
        lines <- strsplit(cnd$message, "\n", fixed = TRUE)[[1L]]
        expect_identical(
            lines[[1L]],
            paste(
                "The output of step 'content' of pipeline 'Water' is not up to",
                "date (state \"outdated\")."
            )
        )
        expect_match(lines[[2L]], "Step 'data' failed: no file", fixed = TRUE)
        expect_match(lines[[3L]], "Step 'fit' failed: no trend", fixed = TRUE)
    })

    it("asks to run the pipeline if no step failed", {
        cnd <- .not_done_error("Water", "content", "new")

        expect_match(cnd$message, "Run the pipeline first.", fixed = TRUE)
        expect_identical(cnd$failed, character())
    })

    it("lists a single failed step with its message", {
        cnd <- .not_done_error(
            "Water",
            "content",
            "failed",
            failed = "content",
            messages = "boom",
            call = quote(pub_fun())
        )

        lines <- strsplit(cnd$message, "\n", fixed = TRUE)[[1L]]
        expect_length(lines, 2L)
        expect_match(lines[[1L]], "(state \"failed\")", fixed = TRUE)
        expect_match(lines[[2L]], "Step 'content' failed: boom", fixed = TRUE)
        expect_no_match(cnd$message, "Run the pipeline first.", fixed = TRUE)
        expect_equal(conditionCall(cnd), quote(pub_fun()))
    })

    it("requires one message per failed step", {
        expect_error(.not_done_error("Water", "content", "failed", failed = "a"))
        expect_error(
            .not_done_error("Water", "content", "new", messages = "boom")
        )
    })

    it("is signalled with its classes", {
        expect_error(
            rlang::cnd_signal(.not_done_error("Water", "content", "new")),
            "not up to date",
            class = "pubflow_not_done"
        )
    })
})

describe(".render_error()", {
    it("creates a pubflow_render_error with format and extra fields", {
        cnd <- .render_error(
            c("pandoc failed.", x = "exit status 1"),
            format = "docx",
            output = "pandoc: error"
        )

        expect_s3_class(cnd, "pubflow_render_error")
        expect_s3_class(cnd, "pubflow_error")
        expect_equal(cnd$format, "docx")
        expect_equal(cnd$output, "pandoc: error")
        expect_match(cnd$message, "exit status 1", fixed = TRUE)
    })

    it("keeps a parent condition", {
        parent <- simpleError("disk full")
        cnd <- .render_error("Can't write file.", "html", parent = parent)

        expect_identical(cnd$parent, parent)
    })

    it("validates the format", {
        expect_error(.render_error("Failed.", NA_character_))
        expect_error(.render_error("Failed.", c("docx", "pdf")))
        expect_error(.render_error("Failed.", 1))
        expect_error(.render_error("Failed."))
    })
})

describe(".tool_missing_error()", {
    it("creates a pubflow_tool_missing error with the tool name", {
        cnd <- .tool_missing_error(
            "typst",
            c("typst was not found.", i = "Install it."),
            candidates = character()
        )

        expect_s3_class(cnd, "pubflow_tool_missing")
        expect_s3_class(cnd, "pubflow_error")
        expect_equal(cnd$tool, "typst")
        expect_equal(cnd$candidates, character())
        expect_match(cnd$message, "Install it.", fixed = TRUE)
    })

    it("validates the tool name", {
        expect_error(.tool_missing_error(c("a", "b"), "missing"))
        expect_error(.tool_missing_error(NA_character_, "missing"))
        expect_error(.tool_missing_error(character(), "missing"))
    })

    it("keeps the call", {
        cnd <- .tool_missing_error("pandoc", "missing", call = quote(pub_fun()))

        expect_equal(conditionCall(cnd), quote(pub_fun()))
    })
})
