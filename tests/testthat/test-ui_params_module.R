# Tests of the param UI module. In shiny::testServer() the module namespace is "proxy1":
# build expected ids with session$ns().

# Count the emissions of a reactive (inside testServer())
count_emissions <- function(r) {
    counter <- new.env(parent = emptyenv())
    counter$n <- -1L # the observer's first run is no emission
    shiny::observe({
        r()
        counter$n <- counter$n + 1L
    })
    counter
}

default_group <- list(lower = "0.80", upper = "1.25", use = TRUE)


# ======================================================================================
# Module
# ======================================================================================

# -------------
# UI and server
# -------------

describe("pub_params_ui()", {
    it("returns the output container and pubflow's html dependency", {
        ui <- pub_params_ui("params")
        html <- html_of(ui)

        expect_match(
            html,
            paste0(
                '<div class="shiny-html-output pubflow-params" ',
                'id="params-pubflow-params">'
            )
        )
        deps <- htmltools::findDependencies(ui)
        expect_true("pubflow" %in% vapply(deps, \(d) d$name, ""))
        expect_error(pub_params_ui(1), "`id` must be a single")
    })

    for (bs in c("3", "5")) {
        it(sprintf("renders in a Bootstrap %s page", bs), {
            skip_if_not_installed("bslib")
            rendered <- render_page(pub_params_ui("params"), bootstrap = bs)
            names <- vapply(rendered$dependencies, \(d) d$name, "")

            expect_match(bootstrap_version(rendered), paste0("^", bs, "\\."))
            expect_true("pubflow" %in% names)
            expect_snapshot(cat(as.character(rendered$html)))
        })
    }
})

describe("pub_params_server()", {
    it("checks its arguments", {
        f <- pub_params_server
        r <- shiny::reactive(list())

        expect_error(f(1, r), "`id` must be a single")
        expect_error(f("p", list()), "`params` must be a reactive")
        expect_error(f("p", r, on_invalid = "x"), "on_invalid")
        expect_error(f("p", r, update_on = "x"), "update_on")
        expect_error(f("p", r, group_by = 1), "`group_by`")
        expect_error(f("p", r, group_labels = "x"), "`group_labels`")
        expect_error(f("p", r, width = 1), "`width`")
        expect_error(f("p", r, tooltips = NA), "`tooltips` and `reset`")
    })

    it("checks the remaining options and accepts NULL and named lists", {
        f <- pub_params_server
        r <- shiny::reactive(list())

        expect_error(f("p", r, reset = NA), "`tooltips` and `reset`")
        expect_error(f("p", r, reset = c(TRUE, FALSE)), "`tooltips` and `reset`")
        expect_error(f("", r), "`id` must be a single non-empty string")
        expect_error(f(NA_character_, r), "`id` must be a single")
        expect_error(f(c("a", "b"), r), "`id` must be a single")
        expect_error(f("p", r, group_by = c("a", "b")), "`group_by`")
        expect_error(f("p", r, group_labels = c(a = "A", "B")), "`group_labels`")
        expect_error(f("p", r, group_labels = list("A")), "`group_labels`")

        opts <- .module_options(
            group_by = NULL,
            group_labels = list(a = "A"),
            width = NULL
        )
        expect_null(opts$group_by)
        expect_null(opts$width)
        expect_equal(opts$group_labels, list(a = "A"))
        expect_equal(opts$on_invalid, "restore")
        expect_equal(opts$update_on, "blur")
    })

    it("checks the params", {
        expect_error(.check_params(list(1)), "named list of params")
        expect_error(.check_params(list(a = 1)), "named list of params")
        expect_error(.check_params(1), "named list of params")
        expect_error(.check_params(data.frame(a = 1)), "named list of params")
        expect_error(
            .check_params(rlang::set_names(list(param(1), param(2)), c("a", ""))),
            "named list of params"
        )
        expect_error(
            .check_params(list(a = param(1), a = param(2))),
            "must be unique, duplicated: a"
        )
        expect_error(
            .check_params(list(
                g_a = param(1),
                g = param_group(list(a = param(2)))
            )),
            "must be unique, duplicated: g_a"
        )
        expect_error(
            .check_params(list(`pubflow-reset` = param(1))),
            "must not start with 'pubflow-': pubflow-reset"
        )
        expect_error(
            .check_params(list(`pubflow-params` = param(1))),
            "pubflow-params"
        )
        nested <- param_group(list(inner = param_group(list(n = param(1)))))
        expect_error(.check_params(list(g = nested)), "can't contain param groups")
        expect_identical(
            .check_params(list()),
            rlang::set_names(list(), character(0))
        )
        expect_identical(
            .check_params(param_config(a = param(1))),
            list(a = param_config(a = param(1))$a)
        )
    })

    it("emits nothing initially and when the inputs appear", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                emitted <- count_emissions(res$changed)
                log <- capture_messages(session)

                expect_null(res$changed())
                expect_equal(
                    res$values(),
                    lapply(unclass(ui_test_params()), param_value)
                )
                expect_true(res$valid())

                mount_inputs(session)
                expect_null(res$changed())
                expect_equal(emitted$n, 0L)
                expect_length(log$custom, 0L)
                expect_length(log$input, 0L)
            }
        )
    })

    it("emits valid changes in changed and values", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)

                session$setInputs(
                    num = 0.15,
                    on_off = "on",
                    txt = "Observed Concentration",
                    factor_single = "identity",
                    factor_multi = c("brief", "standard"),
                    num_slider = 6,
                    switch = TRUE
                )
                changed <- res$changed()
                expect_setequal(
                    names(changed),
                    c(
                        "num",
                        "on_off",
                        "txt",
                        "factor_single",
                        "factor_multi",
                        "num_slider",
                        "switch"
                    )
                )
                expect_equal(changed$num, 0.15)
                expect_equal(changed$num_slider, 6)
                expect_equal(changed$on_off, factor("on", c("on", "off")))
                expect_true(changed$switch)
                expect_equal(changed$txt, "Observed Concentration")
                expect_equal(as.character(changed$factor_single), "identity")
                expect_equal(
                    as.character(changed$factor_multi),
                    c("brief", "standard")
                )
                expect_equal(res$values()[names(changed)], changed)
                expect_equal(res$values()$group, default_group)

                # the next emission holds only the next change
                session$setInputs(txt = "Again")
                expect_equal(res$changed(), list(txt = "Again"))
                expect_equal(res$values()$num, 0.15)
            }
        )
    })

    it("emits a changed param group value", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)

                session$setInputs(group_lower = "0.90")
                expect_equal(
                    res$changed(),
                    list(group = list(lower = "0.90", upper = "1.25", use = TRUE))
                )
            }
        )
    })

    it("waits until all inputs of a param group are present", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()

                session$setInputs(group_lower = "0.90")
                expect_null(res$changed())
                session$setInputs(group_upper = "1.25", group_use = TRUE)
                expect_equal(res$changed()$group$lower, "0.90")
            }
        )
    })

    it("processes a group whose child reports NULL", {
        g <- param_group(
            list(
                lower = param(NA_real_, label = "Lower", validity = \(x) ""),
                upper = numeric_param(5, label = "Upper")
            ),
            validity = \(x) ""
        )
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(list(g = g))),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(g_lower = NULL, g_upper = 5)
                expect_null(res$changed())

                session$setInputs(g_upper = 6)

                expect_equal(
                    res$changed(),
                    list(g = list(lower = NA_real_, upper = 6))
                )
            }
        )
    })

    it("processes a group whose multiple choice child is empty", {
        g <- param_group(list(
            tags = param(
                factor(character(0), levels = c("a", "b")),
                validity = \(x) "",
                ui_args = list(multiple = TRUE)
            ),
            n = numeric_param(5)
        ))
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(list(g = g))),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(g_tags = NULL, g_n = 5)

                session$setInputs(g_n = 6)

                expect_equal(res$changed()$g$n, 6)
            }
        )
    })

    it("emits the same change again after it was undone", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                emitted <- count_emissions(res$changed)
                mount_inputs(session)

                session$setInputs(num = 0.2)
                session$setInputs(num = 0.05)
                session$setInputs(num = 0.2)
                expect_equal(emitted$n, 3L)
                expect_equal(res$changed(), list(num = 0.2))
            }
        )
    })

    it("reads date-time input in the time zone of the param", {
        withr::local_timezone("Europe/Berlin")
        time <- as.POSIXct("2026-01-01 10:00:00", tz = "UTC")
        params <- param_config(
            time = param(
                time,
                validity = \(x) "",
                ui_widget = function(inputId, value, ...) {
                    shiny::textInput(inputId, NULL, format(value, tz = "UTC"))
                }
            )
        )
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(params)),
            {
                session$flushReact()
                res <- session$getReturned()
                emitted <- count_emissions(res$changed)

                # the widget reports the value back unchanged: no change
                session$setInputs(time = "2026-01-01 10:00:00")
                session$setInputs(time = "2026-01-01T10:00:00Z")
                expect_equal(emitted$n, 0L)
                expect_identical(res$values()$time, time)

                session$setInputs(time = "2026-01-01 11:00:00")
                expect_identical(res$changed()$time, time + 3600)
            }
        )
    })

    it("rejects invalid input: no emission, inline message, restore", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                session$setInputs(num = 0.2)
                emitted <- count_emissions(res$changed)
                session$flushReact()
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(num = -1),
                    "'Numeric parameter' input: value must be greater than 0",
                    fixed = TRUE
                )
                expect_equal(emitted$n, 0L)
                expect_equal(res$values()$num, 0.2)
                expect_true(res$valid())

                id <- session$ns("num")
                expect_equal(
                    log$types(),
                    c(
                        "pubflow:showInputInlineMessage",
                        "pubflow:triggerClassAttrib",
                        "pubflow:syncInputValue"
                    )
                )
                inline <- log$custom[[1]]$message
                expect_equal(inline$id, id)
                expect_equal(inline$text, "value must be greater than 0")
                glow <- log$custom[[2]]$message
                expect_equal(glow$id, id)
                expect_equal(glow$what, "pubflow-warn-glow")
                expect_equal(glow$attrib, list(`aria-invalid` = "true"))
                sync <- log$custom[[3]]$message
                expect_equal(sync, list(inputs = list(list(id = id, value = 0.2))))
                # restore: the input is updated with the last valid value
                expect_length(log$input, 1L)
                expect_match(log$input[[1]]$id, "num$")
                expect_equal(log$input[[1]]$message$value, "0.2")
            }
        )
    })

    it("notifies about repeated invalid input of the same field", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                log <- capture_messages(session)

                expect_message(session$setInputs(num = -1), "greater than 0")
                # the browser receives the restored value (syncInputValue)
                expect_silent(session$setInputs(num = 0.05))
                expect_message(session$setInputs(num = -1), "greater than 0")
                expect_length(
                    log$of_type("pubflow:showInputInlineMessage"),
                    2L
                )
                expect_null(res$changed())
            }
        )
    })

    it("restores invalid single and multiple choice input", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                session$setInputs(
                    factor_single = "identity",
                    factor_multi = c("brief", "standard")
                )
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(factor_single = "don't select me"),
                    "please select a valid transformation"
                )
                expect_message(
                    session$setInputs(
                        factor_multi = c("brief", "detailed", "standard")
                    ),
                    "select one or two factors"
                )
                expect_message(
                    session$setInputs(factor_single = "unknown"),
                    "value must be one of: log2, log10"
                )
                expect_equal(
                    lapply(log$synced(), \(i) i$value),
                    list("identity", c("brief", "standard"), "identity")
                )
                expect_equal(
                    vapply(log$input, \(m) toString(m$message$value), ""),
                    c("identity", "brief, standard", "identity")
                )
                expect_equal(
                    as.character(res$values()$factor_multi),
                    c("brief", "standard")
                )
            }
        )
    })

    it("treats an empty numeric input as NA", {
        params <- list(
            n = numeric_param(1, label = "N"),
            na = param(NA_real_, label = "NA ok", validity = \(x) "")
        )
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(params)),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(n = 1)

                expect_message(
                    session$setInputs(n = NULL),
                    "'N' input: value cannot be NA"
                )
                expect_equal(res$values()$n, 1)

                # an NA value shows an empty input; a value set later can be cleared
                # again
                session$setInputs(na = NULL)
                expect_null(res$changed())
                session$setInputs(na = 2)
                expect_equal(res$changed(), list(na = 2))
                session$setInputs(na = NULL)
                expect_equal(res$changed(), list(na = NA_real_))
            }
        )
    })

    it("rejects fractions for integer params", {
        params <- list(k = param(2L, label = "K"))
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(params)),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(k = 2)

                expect_message(
                    session$setInputs(k = 2.5),
                    "value must be a whole number"
                )
                session$setInputs(k = 3)
                expect_identical(res$changed(), list(k = 3L))
            }
        )
    })

    it("marks the changed child of a group that fails its own rule", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(group_lower = "1.30"),
                    paste(
                        "'Group of parameters' input:",
                        "lower bound must be less than upper bound"
                    ),
                    fixed = TRUE
                )
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[1]]$message$id, session$ns("group_lower"))

                # the restore set the lower bound back
                session$setInputs(group_lower = "0.80")
                expect_message(session$setInputs(group_upper = "0.50"))
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[2]]$message$id, session$ns("group_upper"))

                # one message per restore: the children reach the server together
                expect_length(log$of_type("pubflow:syncInputValue"), 2L)
                expect_equal(
                    vapply(log$synced(), \(i) i$id, ""),
                    session$ns(rep(
                        c("group_lower", "group_upper", "group_use"),
                        2
                    ))
                )
                expect_null(res$changed())
            }
        )
    })

    it("marks the child of a group that fails its own validity", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params())),
            {
                session$flushReact()
                mount_inputs(session)
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(group_upper = "3"),
                    paste(
                        "'Group of parameters (Upper bound)' input:",
                        "value must be less than or equal to max (2)"
                    ),
                    fixed = TRUE
                )
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[1]]$message$id, session$ns("group_upper"))
            }
        )
    })

    it("marks the child just edited, also in keep mode", {
        shiny::testServer(
            pub_params_server,
            args = list(
                params = shiny::reactive(ui_test_params()),
                on_invalid = "keep"
            ),
            {
                session$flushReact()
                mount_inputs(session)
                log <- capture_messages(session)

                expect_message(session$setInputs(group_lower = "1.30"))
                expect_message(session$setInputs(group_upper = "1.20"))

                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(
                    vapply(inline, \(m) m$message$id, ""),
                    session$ns(c("group_lower", "group_upper"))
                )
            }
        )
    })

    it("marks the child whose conversion failed", {
        g <- param_group(
            list(a = param(1L, label = "A"), b = param(2L, label = "B")),
            label = "G"
        )
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(list(g = g))),
            {
                session$flushReact()
                session$setInputs(g_a = 1, g_b = 2)
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(g_b = 2.5),
                    "'G (B)' input: value must be a whole number",
                    fixed = TRUE
                )

                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[1]]$message$id, session$ns("g_b"))
            }
        )
    })

    it("keeps invalid input with on_invalid = 'keep'", {
        shiny::testServer(
            pub_params_server,
            args = list(
                params = shiny::reactive(ui_test_params()),
                on_invalid = "keep"
            ),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                log <- capture_messages(session)

                expect_message(session$setInputs(num = -1))
                expect_false(res$valid())
                expect_equal(res$values()$num, 0.05)
                expect_length(log$input, 0L)
                expect_equal(
                    log$types(),
                    c(
                        "pubflow:showInputInlineMessage",
                        "pubflow:triggerClassAttrib",
                        "pubflow:setInputAttrib"
                    )
                )
                expect_null(log$custom[[2]]$message$attrib)
                expect_equal(
                    log$custom[[3]]$message,
                    list(id = session$ns("num"), attrib = list(`aria-invalid` = "true"))
                )

                # other inputs still work; the invalid one is not reported again
                expect_silent(session$setInputs(txt = "New"))
                expect_equal(res$changed(), list(txt = "New"))
                expect_false(res$valid())

                # back to the last valid value: valid, nothing emitted
                log$reset()
                session$setInputs(num = 0.05)
                expect_true(res$valid())
                expect_equal(res$changed(), list(txt = "New"))
                expect_equal(
                    log$custom[[1]]$message,
                    list(id = session$ns("num"), attrib = list(`aria-invalid` = FALSE))
                )

                expect_message(session$setInputs(num = 2))
                session$setInputs(num = 0.3)
                expect_true(res$valid())
                expect_equal(res$changed(), list(num = 0.3))
            }
        )
    })

    it("updates the inputs in place if only values change", {
        renders <- 0L
        local_mocked_bindings(.params_table = function(...) {
            renders <<- renders + 1L
            htmltools::div()
        })
        params <- shiny::reactiveVal(ui_test_params())
        shiny::testServer(
            pub_params_server,
            args = list(params = params),
            {
                session$flushReact()
                res <- session$getReturned()
                output[["pubflow-params"]]
                mount_inputs(session)
                expect_equal(renders, 1L)
                log <- capture_messages(session)

                new <- ui_test_params()
                param_value(new$num) <- 0.5
                param_value(new$group) <- list(
                    lower = "0.9",
                    upper = "1.25",
                    use = TRUE
                )
                # fresh validity functions don't change the structure
                new$txt <- add_validity(new$txt, \(x) {
                    if (x == "Forbidden") "not allowed" else ""
                })
                params(new)
                session$flushReact()
                output[["pubflow-params"]]

                expect_equal(renders, 1L)
                expect_equal(res$values()$num, 0.5)
                expect_equal(res$values()$group$lower, "0.9")
                expect_null(res$changed())
                expect_equal(
                    vapply(log$synced(), \(i) i$id, ""),
                    session$ns(c("group_lower", "group_upper", "group_use", "num"))
                )
                expect_length(log$input, 4L)

                # the browser reports the updated values: no change
                session$setInputs(num = 0.5, group_lower = "0.9")
                expect_null(res$changed())

                # the new validity functions are used
                expect_message(
                    session$setInputs(txt = "Forbidden"),
                    "not allowed"
                )
            }
        )
    })

    it("renders again if the structure changes", {
        renders <- 0L
        local_mocked_bindings(.params_table = function(params, ...) {
            renders <<- renders + 1L
            htmltools::div(paste(names(params), collapse = " "))
        })
        params <- shiny::reactiveVal(ui_test_params())
        shiny::testServer(
            pub_params_server,
            args = list(params = params),
            {
                session$flushReact()
                res <- session$getReturned()
                output[["pubflow-params"]]
                mount_inputs(session)
                session$setInputs(num = 0.2)
                emitted <- count_emissions(res$changed)
                session$flushReact()
                log <- capture_messages(session)

                new <- ui_test_params()
                new$another <- param(0.1, label = "Another", min = 0, max = 1)
                attr(new$num, "max") <- 0.5
                params(new)
                session$flushReact()
                output[["pubflow-params"]]
                expect_equal(renders, 2L)
                expect_equal(res$values()$num, 0.05)
                expect_true("another" %in% names(res$values()))

                # until the new widgets report, the inputs hold the old values: neither
                # changes nor invalid input
                expect_silent(session$setInputs(txt = "Changed"))
                expect_equal(emitted$n, 1L)
                expect_equal(res$changed(), list(txt = "Changed"))
                session$setInputs(num = 0.05, another = 0.1)
                expect_equal(emitted$n, 1L)
                expect_length(log$custom, 0L)

                # order changes are structural, too
                params(param_config(rev(unclass(new))))
                session$flushReact()
                output[["pubflow-params"]]
                expect_equal(renders, 3L)
            }
        )
    })

    it("sorts the params in config order", {
        table <- NULL
        local_mocked_bindings(.params_table = function(params, ...) {
            table <<- names(params)
            htmltools::div()
        })
        cfg <- param_config(b = param(1), a = param(2), c = param(3))
        params <- list(x = param(0), cfg$c, cfg$a, cfg$b) |>
            rlang::set_names(c("x", "c", "a", "b"))
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(params)),
            {
                session$flushReact()
                output[["pubflow-params"]]
                expect_equal(table, c("b", "a", "c", "x"))
                expect_equal(
                    names(session$getReturned()$values()),
                    c("b", "a", "c", "x")
                )
            }
        )
    })

    it("renders the parameter table with the module's ids and options", {
        shiny::testServer(
            pub_params_server,
            args = list(
                params = shiny::reactive(demo_config()),
                group_labels = c(analysis = "Analysis"),
                reset = TRUE
            ),
            {
                session$flushReact()
                html <- output[["pubflow-params"]]$html

                for (id in c("alpha", "limits_lower", "pubflow-reset")) {
                    expect_match(html, sprintf('id="%s"', session$ns(id)))
                }
                expect_match(html, ">Analysis</legend>")
            }
        )
    })

    it("renders nothing for no params", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(list())),
            {
                session$flushReact()
                expect_length(session$getReturned()$values(), 0L)
                expect_no_match(
                    output[["pubflow-params"]]$html,
                    "pubflow-param-row"
                )
            }
        )
    })

    it("restores the values of params() with the reset button", {
        shiny::testServer(
            pub_params_server,
            args = list(
                params = shiny::reactive(ui_test_params()),
                on_invalid = "keep",
                reset = TRUE
            ),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                session$setInputs(num = 0.2, txt = "New")
                expect_message(session$setInputs(group_lower = "-1"))
                expect_false(res$valid())
                log <- capture_messages(session)

                session$setInputs(`pubflow-reset` = 1)
                expect_true(res$valid())
                expect_equal(
                    res$changed(),
                    list(num = 0.05, txt = "Theoretical Concentration")
                )
                expect_equal(
                    res$values(),
                    lapply(unclass(ui_test_params()), param_value)
                )
                ids <- vapply(log$synced(), \(i) i$id, "")
                expect_equal(
                    ids,
                    session$ns(c(
                        "group_lower",
                        "group_upper",
                        "group_use",
                        "num",
                        "txt"
                    ))
                )
            }
        )
    })

    it("resets to values that params() updated", {
        params <- shiny::reactiveVal(ui_test_params())
        shiny::testServer(
            pub_params_server,
            args = list(params = params, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)

                new <- ui_test_params()
                param_value(new$num) <- 0.5
                params(new)
                session$flushReact()
                session$setInputs(num = 0.5)
                session$setInputs(num = 0.6, txt = "New")

                session$setInputs(`pubflow-reset` = 1)
                expect_equal(
                    res$changed(),
                    list(num = 0.5, txt = "Theoretical Concentration")
                )
            }
        )
    })
})

describe("pub_params_server() reset", {
    it("does not reset to a value the current validity rejects", {
        params <- shiny::reactiveVal(list(n = numeric_param(1, label = "N")))
        shiny::testServer(
            pub_params_server,
            args = list(params = params, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(n = 1)
                session$setInputs(n = 2)
                atLeast2 <- \(x) if (x < 2) "must be at least 2" else ""
                params(list(
                    n = add_validity(numeric_param(2, label = "N"), atLeast2)
                ))
                session$flushReact()
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(`pubflow-reset` = 1),
                    "'N' input: must be at least 2",
                    fixed = TRUE
                )

                expect_equal(res$values()$n, 2)
                expect_true(res$valid())
                expect_equal(res$changed(), list(n = 2))
                expect_length(log$input, 0L)
            }
        )
    })
})

describe("pub_params_server() with locked params", {
    it("ignores changes of locked inputs and restores them", {
        params <- list(
            n = numeric_param(1, label = "N", locked = TRUE),
            g = param_group(
                list(a = param("a"), b = param("b")),
                label = "G",
                locked = TRUE
            ),
            m = numeric_param(2, label = "M")
        )
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(params)),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(n = 1, g_a = "a", g_b = "b", m = 2)
                emitted <- count_emissions(res$changed)
                session$flushReact()
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(n = 5),
                    "'N' input: locked, change ignored",
                    fixed = TRUE
                )
                expect_message(
                    session$setInputs(g_b = "x"),
                    "'G' input: locked, change ignored",
                    fixed = TRUE
                )
                expect_equal(emitted$n, 0L)
                expect_equal(res$values()$n, 1)
                expect_equal(res$values()$g, list(a = "a", b = "b"))
                expect_equal(
                    vapply(log$synced(), \(i) i$id, ""),
                    session$ns(c("n", "g_a", "g_b"))
                )
                expect_equal(vapply(log$input, \(m) m$id, ""), c("n", "g_a", "g_b"))

                # a conversion that fails is ignored too
                expect_message(session$setInputs(n = "x"), "locked, change ignored")
                expect_equal(res$values()$n, 1)

                # unlocked params still change
                session$setInputs(m = 3)
                expect_equal(res$changed(), list(m = 3))
            }
        )
    })

    it("keeps the reset baselines of the other params when a param gets locked", {
        params <- shiny::reactiveVal(list(n = numeric_param(1), k = numeric_param(5)))
        shiny::testServer(
            pub_params_server,
            args = list(params = params, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(n = 1, k = 5)
                session$setInputs(n = 2)
                # as a pipeline holding the new value and a locked step for `k`
                params(list(n = numeric_param(2), k = numeric_param(5, locked = TRUE)))
                session$flushReact()

                session$setInputs(`pubflow-reset` = 1)

                expect_equal(res$values()$n, 1)
                expect_equal(res$changed(), list(n = 1))
            }
        )
    })

    it("renders again when a param gets locked", {
        renders <- 0L
        local_mocked_bindings(.params_table = function(params, ...) {
            renders <<- renders + 1L
            htmltools::div()
        })
        params <- shiny::reactiveVal(list(n = numeric_param(1)))
        shiny::testServer(
            pub_params_server,
            args = list(params = params),
            {
                session$flushReact()
                output[["pubflow-params"]]
                params(list(n = numeric_param(1, locked = TRUE)))
                session$flushReact()
                output[["pubflow-params"]]

                expect_equal(renders, 2L)
            }
        )
    })
})

describe("pub_params_server() reset without changes", {
    it("emits nothing if no value differs from its initial value", {
        shiny::testServer(
            pub_params_server,
            args = list(params = shiny::reactive(ui_test_params()), reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                emitted <- count_emissions(res$changed)
                session$flushReact()
                log <- capture_messages(session)

                session$setInputs(`pubflow-reset` = 1)

                expect_equal(emitted$n, 0L)
                expect_null(res$changed())
                expect_length(log$custom, 0L)
                expect_length(log$input, 0L)
            }
        )
    })
})

describe("pub_pipeline_params_server()", {
    it("checks its arguments", {
        f <- pub_pipeline_params_server
        pip <- demo_pipeline()

        expect_error(f(1, pip), "`id` must be a single")
        expect_error(f("p", list()), "`pip` must be a pipeflow pipeline")
        expect_error(f("p", pip, filter = list(1)), "`filter` must be a named")
        for (name in c("x", "order")) {
            filter <- rlang::set_names(list(1), name)
            expect_error(f("p", pip, filter = filter), "must not be arguments")
        }
        expect_error(f("p", pip, refresh = 1), "`refresh` must be")
        expect_error(f("p", pip, on_invalid = "x"), "on_invalid")
        expect_error(f("p", pip, foo = 1), "unused argument")
    })

    it("has the options of pub_params_server() with the same defaults", {
        options <- as.list(formals(pub_params_server))[-(1:2)]
        pipOptions <- as.list(formals(pub_pipeline_params_server))[names(options)]
        expect_identical(pipOptions, options)
        expect_identical(as.list(formals(.module_options)), options)
    })

    it("checks that filter is a list", {
        expect_error(
            pub_pipeline_params_server("p", demo_pipeline(), filter = "user"),
            "`filter` must be a named"
        )
    })

    it("shows all params by default", {
        pip <- demo_pipeline()
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip),
            {
                session$flushReact()
                expect_setequal(
                    names(session$getReturned()$values()),
                    names(pub_get_params(pip))
                )
                expect_true("failCheck" %in% names(session$getReturned()$values()))
            }
        )
    })

    it("waits while the reactive pipeline is NULL", {
        pip <- shiny::reactiveVal(NULL)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip),
            {
                session$flushReact()
                res <- session$getReturned()
                expect_null(res$values())
                expect_equal(res$revision(), 0L)

                pip(demo_pipeline())
                session$flushReact()
                expect_equal(res$values()$alpha, 0.05)
            }
        )
    })

    it("shows the params that the filter keeps in config order", {
        pip <- demo_pipeline()
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, filter = list(source = "user")),
            {
                session$flushReact()
                res <- session$getReturned()
                expected <- pub_get_params(pip, source = "user")

                expect_equal(names(res$values()), names(expected))
                expect_equal(res$values(), lapply(expected, param_value))
                expect_equal(res$revision(), 0L)
                html <- output[["pubflow-params"]]$html
                expect_match(html, sprintf('id="%s"', session$ns("alpha")))
                expect_no_match(html, session$ns("failCheck"))
            }
        )
    })

    it("sets valid changes in the pipeline and bumps the revision", {
        pip <- demo_pipeline()
        run_quietly(pip)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, filter = list(area = "analysis")),
            {
                session$flushReact()
                res <- session$getReturned()
                expect_equal(
                    names(res$values()),
                    c("alpha", "xTrans", "exclude")
                )
                session$setInputs(
                    alpha = 0.05,
                    xTrans = "none",
                    exclude = FALSE
                )
                expect_equal(res$revision(), 0L)

                session$setInputs(alpha = 0.1, xTrans = "log")
                expect_equal(res$revision(), 1L)
                stored <- pub_get_params(pip)
                expect_equal(param_value(stored$alpha), 0.1)
                expect_equal(
                    param_value(stored$xTrans),
                    factor("log", demo_trans_choices)
                )
                expect_equal(param_attr(stored$alpha, "label"), "Significance level")
                expect_equal(pip[["fit", "state"]], "outdated")
                expect_equal(pip[["data", "state"]], "done")

                session$setInputs(exclude = TRUE)
                expect_equal(res$revision(), 2L)
            }
        )
    })

    it("shows the params of locked steps disabled and does not set them", {
        pip <- demo_pipeline()
        pipeflow::pip_lock(pipeflow::pip_view(pip, step = "fit"))
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, filter = list(area = "analysis")),
            {
                session$flushReact()
                res <- session$getReturned()
                html <- output[["pubflow-params"]]$html
                expect_match(
                    html,
                    sprintf(
                        '<input id="%s" type="number"[^>]* disabled',
                        session$ns("alpha")
                    )
                )
                expect_no_match(
                    html,
                    sprintf('id="%s"[^>]* disabled', session$ns("exclude"))
                )
                session$setInputs(alpha = 0.05, xTrans = "none", exclude = FALSE)

                expect_message(session$setInputs(alpha = 0.1), "locked, change ignored")
                expect_equal(res$revision(), 0L)
                expect_equal(param_value(pub_get_params(pip)$alpha), 0.05)

                session$setInputs(exclude = TRUE)
                expect_equal(res$revision(), 1L)
                expect_true(param_value(pub_get_params(pip)$exclude))
            }
        )
    })

    it("sets the inner params of a nested pipeline", {
        pip <- demo_nested_pipeline()
        run_quietly(pip)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, filter = list(source = "user")),
            {
                session$flushReact()
                res <- session$getReturned()
                expect_equal(
                    names(res$values()),
                    c("xTrans", "alpha", "decimals")
                )
                session$setInputs(xTrans = "none", alpha = 0.05, decimals = "2")

                session$setInputs(alpha = 0.1)
                expect_equal(res$revision(), 1L)
                expect_equal(param_value(pub_get_params(pip)$alpha), 0.1)
                expect_equal(pip[["inner_run", "state"]], "outdated")
                expect_equal(pip[["split_data", "state"]], "done")
            }
        )
    })

    it("shows the params of a view and sets them in the whole pipeline", {
        p <- pipeflow::pip_new("view") |>
            pipeflow::pip_add("fit", \(alpha = 0.05, beta = 1) alpha * beta) |>
            pipeflow::pip_add(
                "plot",
                \(x = ~fit, alpha = 0.05) c(x, alpha),
                tags = "plot"
            )
        pipeflow::pip_set_params(
            p,
            param_config(
                alpha = numeric_param(0.05, label = "Alpha", source = "user"),
                beta = numeric_param(1, label = "Beta", source = "user")
            )
        )
        run_quietly(p)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pipeflow::pip_view(p, tags = "plot")),
            {
                session$flushReact()
                res <- session$getReturned()
                expect_equal(names(res$values()), "alpha")
                session$setInputs(alpha = 0.05)

                session$setInputs(alpha = 0.1)
                expect_equal(res$revision(), 1L)
                stored <- p[["params"]]
                expect_equal(param_value(stored$fit$alpha), 0.1)
                expect_identical(stored$fit$alpha, stored$plot$alpha)
                expect_equal(p[["fit", "state"]], "outdated")
            }
        )
    })

    it("checks a value a step outside the view rejects with that step's param", {
        p <- pipeflow::pip_new("view") |>
            pipeflow::pip_add("fit", \(alpha = 0.05) alpha) |>
            pipeflow::pip_add("plot", \(x = ~fit, alpha = 0.05) x, tags = "plot")
        alpha <- numeric_param(0.05, label = "Alpha", source = "user")
        strict <- add_validity(alpha, \(x) if (x > 0.5) "too large for the fit" else "")
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "fit"),
            list(alpha = strict)
        )
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "plot"),
            list(alpha = alpha),
            scope = "view"
        )
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pipeflow::pip_view(p, tags = "plot")),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(alpha = 0.05)
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(alpha = 0.8),
                    "'Alpha' input: too large for the fit",
                    fixed = TRUE
                )
                expect_equal(res$revision(), 0L)
                expect_equal(res$values()$alpha, 0.05)
                stored <- p[["params"]]
                expect_equal(param_value(stored$fit$alpha), 0.05)
                expect_equal(param_value(stored$plot$alpha), 0.05)
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[1]]$message$id, session$ns("alpha"))
                expect_match(inline[[1]]$message$text, "too large for the fit")
            }
        )
    })

    it("reports a value a step outside the view rejects with the shown param", {
        p <- pipeflow::pip_new("view") |>
            pipeflow::pip_add("fit", \(alpha = 0.05) alpha) |>
            pipeflow::pip_add("plot", \(x = ~fit, alpha = 0.05) x, tags = "plot")
        alpha <- numeric_param(0.05, label = "Alpha (fit)", source = "user") |>
            add_validity(\(x) if (x > 0.5) "too large for the fit" else "")
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "fit"),
            list(alpha = alpha),
            scope = "view"
        )
        pipeflow::pip_set_params(
            pipeflow::pip_view(p, step = "plot"),
            list(alpha = numeric_param(0.1, label = "Alpha", source = "user")),
            scope = "view"
        )
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pipeflow::pip_view(p, tags = "plot")),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(alpha = 0.1)

                expect_message(
                    session$setInputs(alpha = 0.8),
                    "'Alpha' input: too large for the fit",
                    fixed = TRUE
                )
                session$flushReact()
                expect_equal(res$revision(), 0L)
                expect_equal(res$values()$alpha, 0.1)
            }
        )
    })

    it("reads the params again when refresh fires", {
        pip <- demo_pipeline()
        refresh <- shiny::reactiveVal(0L)
        renders <- 0L
        local_mocked_bindings(.params_table = function(...) {
            renders <<- renders + 1L
            htmltools::div()
        })
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, refresh = refresh),
            {
                session$flushReact()
                res <- session$getReturned()
                output[["pubflow-params"]]
                log <- capture_messages(session)

                # a data-derived value set in the pipeline
                pipeflow::pip_set_params(
                    pip,
                    list(limits = list(lower = "97", upper = "103"))
                )
                session$flushReact()
                expect_equal(res$values()$limits$lower, "95")

                refresh(1L)
                session$flushReact()
                output[["pubflow-params"]]
                expect_equal(res$values()$limits$lower, "97")
                expect_equal(renders, 1L)
                expect_equal(
                    vapply(log$input, \(m) m$message$value, ""),
                    c("97", "103")
                )
                # the children of the group are synced in one message, so the
                # browser sends them back together: no change, nothing set
                expect_length(log$of_type("pubflow:syncInputValue"), 1L)
                session$setInputs(limits_lower = "97", limits_upper = "103")
                expect_null(res$changed())
                expect_equal(res$revision(), 0L)
            }
        )
    })

    it("reports params the pipeline rejects and shows its values again", {
        pip <- demo_pipeline()
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(alpha = 0.05)

                # the pipeline got a stricter param after the UI read it
                alpha <- pub_get_params(pip)$alpha |>
                    add_validity(\(x) if (x > 0.08) "alpha too large" else "")
                pipeflow::pip_set_params(pip, list(alpha = alpha))
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(alpha = 0.1),
                    "'Significance level' input: alpha too large",
                    fixed = TRUE
                )
                expect_equal(res$revision(), 0L)
                expect_equal(param_value(pub_get_params(pip)$alpha), 0.05)
                expect_equal(res$values()$alpha, 0.05)
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(inline[[1]]$message$id, session$ns("alpha"))
                syncs <- log$of_type("pubflow:syncInputValue")
                expect_equal(
                    syncs[[1]]$message,
                    list(inputs = list(list(id = session$ns("alpha"), value = 0.05)))
                )

                # the next valid change is set
                session$setInputs(alpha = 0.05)
                session$setInputs(alpha = 0.07)
                expect_equal(res$revision(), 1L)
                expect_equal(param_value(pub_get_params(pip)$alpha), 0.07)
            }
        )
    })

    it("marks the changed child of a group the pipeline rejects", {
        pip <- demo_pipeline()
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(limits_lower = "95", limits_upper = "105")

                limits <- pub_get_params(pip)$limits |>
                    add_validity(\(x) {
                        if (as.numeric(x$upper) > 105) {
                            "upper limit too high"
                        } else {
                            ""
                        }
                    })
                pipeflow::pip_set_params(pip, list(limits = limits))
                log <- capture_messages(session)

                expect_message(
                    session$setInputs(limits_upper = "106"),
                    "'Specification limits' input: upper limit too high"
                )
                inline <- log$of_type("pubflow:showInputInlineMessage")
                expect_equal(
                    inline[[1]]$message$id,
                    session$ns("limits_upper")
                )
                expect_equal(res$values()$limits$upper, "105")
                expect_equal(res$revision(), 0L)
            }
        )
    })

    it("resets to the values before the user's changes after refresh", {
        pip <- demo_pipeline()
        refresh <- shiny::reactiveVal(0L)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, refresh = refresh, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(title = "Quality demo", alpha = 0.05)
                session$setInputs(title = "New", alpha = 0.1)
                expect_equal(res$revision(), 1L)

                # read back from the pipeline: the user's values, and a data-derived
                # value
                pipeflow::pip_set_params(
                    pip,
                    list(limits = list(lower = "97", upper = "103"))
                )
                refresh(1L)
                session$flushReact()
                session$setInputs(limits_lower = "97", limits_upper = "103")

                session$setInputs(`pubflow-reset` = 1)
                expect_equal(
                    res$changed(),
                    list(title = "Quality demo", alpha = 0.05)
                )
                expect_equal(res$revision(), 2L)
                stored <- lapply(pub_get_params(pip), param_value)
                expect_equal(stored$title, "Quality demo")
                expect_equal(stored$alpha, 0.05)
                expect_equal(stored$limits$lower, "97")
            }
        )
    })

    it("keeps the reset baseline when the pipeline rejects a value", {
        pip <- demo_pipeline()
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(alpha = 0.05)
                session$setInputs(alpha = 0.07)
                alpha <- pub_get_params(pip)$alpha |>
                    add_validity(\(x) if (x > 0.08) "alpha too large" else "")
                pipeflow::pip_set_params(pip, list(alpha = alpha))
                expect_message(session$setInputs(alpha = 0.1), "too large")
                session$setInputs(alpha = 0.07)

                session$setInputs(`pubflow-reset` = 1)

                expect_equal(res$changed(), list(alpha = 0.05))
                expect_equal(param_value(pub_get_params(pip)$alpha), 0.05)
                expect_equal(res$revision(), 2L)
            }
        )
    })

    it("still takes data-derived values as reset baseline", {
        pip <- demo_pipeline()
        refresh <- shiny::reactiveVal(0L)
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = pip, refresh = refresh, reset = TRUE),
            {
                session$flushReact()
                res <- session$getReturned()
                session$setInputs(alpha = 0.05)
                pipeflow::pip_set_params(pip, list(alpha = 0.06))
                refresh(1L)
                session$flushReact()
                session$setInputs(alpha = 0.06)
                session$setInputs(alpha = 0.07)

                session$setInputs(`pubflow-reset` = 1)

                expect_equal(res$changed(), list(alpha = 0.06))
            }
        )
    })

    it("works with a reactive pipeline", {
        pips <- list(a = demo_pipeline("a"), b = demo_pipeline("b"))
        pipeflow::pip_set_params(pips$b, list(alpha = 0.2))
        selected <- shiny::reactiveVal("a")
        shiny::testServer(
            pub_pipeline_params_server,
            args = list(pip = shiny::reactive(pips[[selected()]])),
            {
                session$flushReact()
                res <- session$getReturned()
                expect_equal(res$values()$alpha, 0.05)
                session$setInputs(alpha = 0.05)

                selected("b")
                session$flushReact()
                expect_equal(res$values()$alpha, 0.2)

                session$setInputs(alpha = 0.3)
                expect_equal(param_value(pub_get_params(pips$b)$alpha), 0.3)
                expect_equal(param_value(pub_get_params(pips$a)$alpha), 0.05)
            }
        )
    })
})


# ======================================================================================
# Server to browser
# ======================================================================================

# ----------
# New params
# ----------

describe(".mark_step_locks()", {
    it("locks the names held by a locked step, also outside the view", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("s1", \(a = 1, b = 2) a) |>
            pipeflow::pip_add("s2", \(a = 1, c = 3) a)
        pipeflow::pip_set_params(
            p,
            param_config(a = param(1), b = param(2), c = param(3)),
            unknown = "error"
        )
        params <- pub_get_params(p)
        expect_identical(.mark_step_locks(params, p), params)

        pipeflow::pip_lock(pipeflow::pip_view(p, step = "s2"))
        marked <- .mark_step_locks(params, p)
        locked <- vapply(marked, .is_locked, logical(1))
        expect_identical(locked, c(a = TRUE, b = FALSE, c = TRUE))

        # s2 is outside the view, but holds `a`
        v <- pipeflow::pip_view(p, step = "s1")
        marked <- .mark_step_locks(pub_get_params(v), v)
        expect_true(.is_locked(marked$a))
        expect_false(.is_locked(marked$b))

        # the stored params are unchanged
        expect_null(attr(p[["s2", "params"]]$a, "locked"))
    })
})

describe(".structure_signature()", {
    it("ignores values, validity functions, attribute order and factor length", {
        multi <- param(
            factor("a", levels = c("a", "b")),
            ui_args = list(multiple = TRUE)
        )
        twoChosen <- multi
        param_value(twoChosen) <- c("a", "b")
        num <- param(1, label = "N", min = 0)
        reordered <- num
        attributes(reordered) <- rev(attributes(num))
        withRule <- add_validity(num, \(x) "")

        sig <- .structure_signature
        expect_identical(sig(list(m = multi)), sig(list(m = twoChosen)))
        expect_identical(sig(list(n = num)), sig(list(n = reordered)))
        expect_identical(sig(list(n = num)), sig(list(n = withRule)))
    })

    it("compares functions in attributes by their code, such as a ui_widget", {
        widget <- function() {
            function(inputId, value, ...) shiny::textInput(inputId, NULL)
        }
        a <- param("x", ui_widget = widget())
        b <- param("x", ui_widget = widget())
        area <- param(
            "x",
            ui_widget = \(inputId, value, ...) shiny::textAreaInput(inputId, NULL)
        )

        expect_false(identical(a, b))
        sig <- .structure_signature
        expect_identical(sig(list(a = a)), sig(list(a = b)))
        expect_false(identical(sig(list(a = a)), sig(list(a = area))))
    })

    it("changes with the length of a vector, attributes and children", {
        num <- param(1, label = "N")
        long <- num
        param_value(long) <- c(1, 2)
        relabelled <- num
        attr(relabelled, "label") <- "M"
        g <- param_group(list(a = param(1), b = param(2)))
        g2 <- param_group(list(a = param(1), b = param(2, label = "B")))

        sig <- .structure_signature
        expect_false(identical(sig(list(n = num)), sig(list(n = long))))
        expect_false(identical(sig(list(n = num)), sig(list(n = relabelled))))
        expect_false(identical(sig(list(n = num)), sig(list(m = num))))
        expect_false(identical(sig(list(g = g)), sig(list(g = g2))))
        locked <- num
        attr(locked, "locked") <- TRUE
        expect_false(identical(sig(list(n = num)), sig(list(n = locked))))
    })
})

describe(".update_values()", {
    it("sets an input that holds an invalid value back to the value of params()", {
        params <- shiny::reactiveVal(ui_test_params())
        shiny::testServer(
            pub_params_server,
            args = list(params = params, on_invalid = "keep"),
            {
                session$flushReact()
                res <- session$getReturned()
                mount_inputs(session)
                expect_message(session$setInputs(num = -1))
                expect_false(res$valid())
                log <- capture_messages(session)

                params(ui_test_params())
                session$flushReact()

                expect_true(res$valid())
                expect_null(res$changed())
                expect_equal(
                    log$types(),
                    c("pubflow:syncInputValue", "pubflow:setInputAttrib")
                )
                expect_equal(
                    log$custom[[2]]$message,
                    list(id = session$ns("num"), attrib = list(`aria-invalid` = FALSE))
                )
                expect_equal(log$input[[1]]$id, "num")
            }
        )
    })
})


# --------------
# Setting inputs
# --------------

describe(".input_form()", {
    it("turns factors into strings and keeps other values", {
        expect_identical(.input_form(NULL, factor(c("a", "b"))), c("a", "b"))
        expect_identical(.input_form(NULL, factor(character(0))), character(0))
        expect_identical(.input_form(NULL, 1.5), 1.5)
        expect_null(.input_form(NULL, NULL))
    })
})

describe(".update_input()", {
    textWidget <- function(inputId, value, ...) {
        shiny::textInput(inputId, NULL, value)
    }
    make_params <- function(v) {
        list(
            s = numeric_param(v, min = 1, max = 8, ui_widget = "slider"),
            r = choice_param(
                if (v == 2) "a" else "b",
                choices = c("a", "b"),
                ui_widget = "radio"
            ),
            w = param(v == 2),
            cu = param(as.character(v), validity = \(x) "", ui_widget = textWidget)
        )
    }

    it("updates slider, radio, switch and custom widgets", {
        params <- shiny::reactiveVal(make_params(2))
        shiny::testServer(
            pub_params_server,
            args = list(params = params),
            {
                session$flushReact()
                log <- capture_messages(session)

                params(make_params(3))
                session$flushReact()

                inputs <- log$input
                expect_equal(
                    vapply(inputs, \(m) m$id, ""),
                    c("s", "r", "w", "cu")
                )
                expect_equal(inputs[[1]]$message$value, "3")
                expect_equal(inputs[[2]]$message$selected, "b")
                expect_false(inputs[[3]]$message$value)
                # custom widgets get the generic input message
                expect_equal(inputs[[4]]$message, list(value = "3"))
            }
        )
    })
})


# ======================================================================================
# Browser to server
# ======================================================================================

# --------------
# Reading inputs
# --------------

describe(".input_value()", {
    it("turns an empty input into NA or an empty vector by type", {
        expect_identical(.input_value(NULL, param(1)), NA_real_)
        expect_identical(.input_value(NULL, param(1L)), NA_real_)
        expect_identical(.input_value(NULL, param(TRUE)), NA)
        expect_identical(.input_value(NULL, param("a")), character(0))
        expect_identical(
            .input_value(NULL, choice_param("a", c("a", "b"))),
            character(0)
        )
        expect_null(.input_value(NULL, param(as.Date("2026-01-01"))))
    })

    it("converts numeric input and passes other input through", {
        expect_identical(.input_value("2.5", param(1)), 2.5)
        expect_identical(.input_value("abc", param(1)), NA_real_)
        expect_identical(.input_value(NA, param(1L)), NA_real_)
        expect_identical(.input_value(3, param(1L)), 3)
        expect_error(.input_value(c(1, 1.5), param(1L)), "whole number")
        expect_identical(.input_value("x", param("a")), "x")
        expect_identical(.input_value(TRUE, param(FALSE)), TRUE)
    })
})


# --------------
# Invalid inputs
# --------------

describe(".invalid_target()", {
    g <- param_group(
        list(a = param(1, label = "A"), b = param(2, label = "B")),
        label = "G"
    )
    prev <- list(a = 1, b = 2)

    it("uses the first input of a param and its label, else the name", {
        expect_equal(
            .invalid_target(param(1, label = "N"), "n", "msg", 2, 1),
            list(id = "n", label = "N")
        )
        unlabelled <- param(1)
        attr(unlabelled, "label") <- NULL
        expect_equal(
            .invalid_target(unlabelled, "n", c(x = "msg"), 2, 1),
            list(id = "n", label = "n")
        )
    })

    it("prefers the named child, then the edited child, then the changed one", {
        target <- .invalid_target(g, "g", c(b = "msg"), prev, prev, edited = "a")
        expect_equal(target, list(id = "g_b", label = "G (B)"))

        target <- .invalid_target(g, "g", "msg", list(a = 1, b = 3), prev, "a")
        expect_equal(target, list(id = "g_a", label = "G"))

        # an unknown child name and unknown edited names are ignored
        target <- .invalid_target(
            g,
            "g",
            c(z = "msg"),
            list(a = 1, b = 3),
            prev,
            edited = "z"
        )
        expect_equal(target, list(id = "g_b", label = "G"))
    })

    it("falls back to the first child", {
        expect_equal(.invalid_target(g, "g", "msg", prev, prev)$id, "g_a")
        # the conversion failed: no value
        expect_equal(.invalid_target(g, "g", "msg", NULL, prev)$id, "g_a")
    })
})

describe(".first_invalid_message()", {
    it("returns the first message, the conversion error or the default", {
        x <- param(1, validity = \(x) if (x < 0) "negative" else "")
        g <- param_group(
            list(a = param(1, validity = \(x) if (x < 0) "a negative" else "")),
            validity = \(x) if (x$a > 5) "a above 5" else ""
        )

        expect_equal(.first_invalid_message(x, -2, "default"), "negative")
        expect_equal(
            .first_invalid_message(g, list(a = -1), NULL),
            c(a = "a negative")
        )
        expect_equal(.first_invalid_message(x, 1, "default"), "default")
        expect_null(.first_invalid_message(x, 1, NULL))
        expect_match(
            .first_invalid_message(g, list(b = 1), NULL),
            "named list with names: a"
        )
    })

    it("gives errors without ANSI colours", {
        withr::local_options(cli.num_colors = 256L)
        x <- param(1, validity = \(x) rlang::abort(c("bad", x = "negative")))

        expect_no_match(.first_invalid_message(x, -1, NULL), "\033", fixed = TRUE)
        expect_match(.first_invalid_message(x, -1, NULL), "negative")
    })
})


# ----------------------
# Emitting and resetting
# ----------------------

describe(".on_reset()", {
    it("leaves locked params alone", {
        m <- .module_state(NULL, .module_options(reset = TRUE))
        m$params <- list(n = numeric_param(2, locked = TRUE))
        m$validValues <- list(n = 2)
        m$initial <- list(n = 1)

        expect_silent(.on_reset(m))
        expect_null(shiny::isolate(m$emission()))
        expect_equal(m$validValues, list(n = 2))
    })
})

describe(".apply_values()", {
    session <- list(ns = identity, sendCustomMessage = function(...) NULL)

    it("reports a param held by several steps once", {
        pip <- demo_pipeline()
        xTrans <- pub_get_params(pip)$xTrans |>
            add_validity(\(x) if (x == "log") "no log" else "")
        pipeflow::pip_set_params(pip, list(xTrans = xTrans))
        value <- factor("log", demo_trans_choices)

        msgs <- testthat::capture_messages(
            ok <- .apply_values(pip, list(xTrans = value), session)
        )

        expect_false(ok)
        expect_equal(msgs, "'x transformation' input: no log\n")
        expect_equal(as.character(param_value(pub_get_params(pip)$xTrans)), "none")
    })

    it("reports with the shown param if the rejecting step holds a plain value", {
        pip <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("fit", \(alpha = 0.05) alpha) |>
            pipeflow::pip_add("plot", \(alpha = 0.05) alpha)
        pipeflow::pip_set_params(
            pipeflow::pip_view(pip, step = "plot"),
            list(alpha = numeric_param(0.05, label = "Alpha")),
            scope = "view"
        )
        errors <- data.frame(step = "fit", name = "alpha", message = "fit refuses")
        local_mocked_bindings(
            pip_set_params = function(...) {
                rlang::abort(
                    "set failed",
                    class = "pipeflow_set_params_error",
                    errors = errors
                )
            },
            .package = "pipeflow"
        )
        sent <- list()
        session$sendCustomMessage <- function(type, message) {
            sent[[length(sent) + 1L]] <<- list(type = type, message = message)
        }

        expect_message(
            ok <- .apply_values(pip, list(alpha = 0.1), session),
            "'Alpha' input: fit refuses",
            fixed = TRUE
        )
        expect_false(ok)
        types <- vapply(sent, \(m) m$type, "")
        expect_true("pubflow:showInputInlineMessage" %in% types)
    })

    it("reports a rejected name that is no param of the pipeline", {
        pip <- demo_pipeline()
        alpha <- pub_get_params(pip)$alpha |>
            add_validity(\(x) if (x > 0.08) "alpha too large" else "")
        pipeflow::pip_set_params(pip, list(alpha = alpha))
        local_mocked_bindings(pub_get_params = function(...) list())

        expect_message(
            ok <- .apply_values(pip, list(alpha = 0.1), session),
            "'alpha' input: ",
            fixed = TRUE
        )
        expect_false(ok)
    })
})

# ======================================================================================
# Helpers
# ======================================================================================

# --------
# Messages
# --------

describe(".send_custom_message()", {
    it("does nothing outside a Shiny session", {
        expect_null(shiny::getDefaultReactiveDomain())
        expect_silent(res <- .send_custom_message("x", list(a = 1)))
        expect_null(res)
    })

    it("sends the message through the session", {
        sent <- list()
        session <- list(sendCustomMessage = function(type, message) {
            sent <<- list(type = type, message = message)
        })
        .send_custom_message("x", list(a = 1), session = session)
        expect_equal(sent, list(type = "x", message = list(a = 1)))
    })
})
