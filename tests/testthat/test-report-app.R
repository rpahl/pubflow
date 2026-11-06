# The report app (inst/examples/report-app) is checked manually in a browser; these
# tests only make sure that its UI and server run.

describe("report app", {
    it("has a Bootstrap 3 and a Bootstrap 5 page", {
        skip_if_not_installed("bslib")
        env <- example_app_env("report-app")

        for (bs in c("3", "5")) {
            page <- env$ui(list(QUERY_STRING = paste0("?bs=", bs)))
            rendered <- htmltools::renderTags(page)
            expect_match(bootstrap_version(rendered), paste0("^", bs, "\\."))
            html <- as.character(rendered$html)
            for (id in c("params-pubflow-params", "download", "viewer-viewer")) {
                expect_match(html, sprintf('id="%s"', id), fixed = TRUE)
            }
        }
    })

    it("runs the pipeline after valid parameter changes", {
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "Ozone in New York: Temp.Celsius explains", fixed = TRUE)

            session$setInputs(`params-title` = "Ozone in New York")
            session$setInputs(`params-title` = "New title")
            expect_equal(params$revision(), 1L)
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "New title: Temp.Celsius explains", fixed = TRUE)
        })
    })

    it("gives a new predictor its range, starting at the range of the data", {
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            window <- pub_get_params(pip)$window
            expect_equal(param_value(window), list(from = 13, to = 37))
            expect_equal(param_attr(window, "label"), "Range of Temp.Celsius")
            expect_equal(nrow(pip[["prep", "out"]]), nrow(pip[["data", "out"]]))

            session$setInputs(`params-xVar` = "Temp.Celsius")
            # The pipeline runs once, with the new range (no failed run)
            expect_no_message(session$setInputs(`params-xVar` = "Wind"))
            window <- pub_get_params(pip)$window
            expect_equal(param_value(window), list(from = 1, to = 21))
            expect_equal(param_attr(window, "label"), "Range of Wind")
            expect_equal(param_attr(window, "order"), 4L)
            expect_equal(params$values()$window, list(from = 1, to = 21))
            table <- as.character(output$`params-pubflow-params`$html)
            expect_match(table, "Range of Wind", fixed = TRUE)
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "Wind explains", fixed = TRUE)

            # The range filters the days by the predictor
            session$setInputs(`params-window_from` = "1", `params-window_to` = "21")
            session$setInputs(`params-window_to` = "10")
            expect_true(all(pip[["prep", "out"]]$Wind <= 10))
            expect_lt(nrow(pip[["prep", "out"]]), nrow(pip[["data", "out"]]))
        })
    })

    it("shows the short or the long report, running only its steps", {
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "Short report", fixed = TRUE)
            expect_match(
                html,
                "The effect of the predictor is significant.",
                fixed = TRUE
            )
            expect_no_match(html, "Methods", fixed = TRUE)
            expect_identical(pip[["month_tables", "state"]], "new")

            session$setInputs(report = "long")
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "Long report", fixed = TRUE)
            expect_match(html, "September", fixed = TRUE)
            expect_match(html, "Methods", fixed = TRUE)

            session$setInputs(`params-months` = c("May", "June"))
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "June", fixed = TRUE)
            expect_no_match(html, "September", fixed = TRUE)
        })
    })

    it("shows failed steps as error boxes", {
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()

            suppressMessages(session$setInputs(`params-failCheck` = "yes"))
            html <- as.character(output$`viewer-doc`$html)
            expect_match(html, "Step 'check' failed", fixed = TRUE)
            expect_match(html, "Table 1: Coefficients", fixed = TRUE)
        })
    })

    # Every read of output$download renders again: read it once per format
    it("downloads the report shown as DOCX or HTML", {
        skip_if_no_pandoc()
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            session$setInputs(report = "long", format = "docx")
            docx <- output$download
            text <- docx_pandoc_text(docx)
            expect_match(text, "Data per month", fixed = TRUE)
            expect_match(text, "September", fixed = TRUE)
            expect_match(
                xml2::xml_text(docx_xml(docx, "word/footer1.xml")),
                "demo user at .* UTC \\(pubflow report app v"
            )

            session$setInputs(format = "html")
            html <- paste(readLines(output$download, warn = FALSE), collapse = "\n")
            expect_match(html, "Long report", fixed = TRUE)
        })
    })

    # The engines are tested in the scenario below; here only that the choice
    # reaches pub_render() (typst: the faster engine)
    it("downloads the report shown as PDF", {
        skip_if_no_pdf_engine("typst")
        skip_if_not_installed("pdftools")
        env <- example_app_env("report-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            session$setInputs(format = "pdf_typst")
            text <- paste(pdftools::pdf_text(output$download), collapse = "\n")
            expect_match(text, "demo user at .* UTC")
        })
    })

    it("refuses to download a report with failed steps", {
        env <- example_app_env("report-app")
        notes <- list()
        removed <- character()
        local_mocked_bindings(
            showNotification = function(ui, ...) {
                notes[[length(notes) + 1L]] <<- list(ui = ui, ...)
            },
            removeNotification = function(id, ...) removed <<- c(removed, id),
            .package = "shiny"
        )
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            suppressMessages(session$setInputs(`params-failCheck` = "yes"))
            session$setInputs(format = "html")
            expect_error(output$download, class = "pubflow_render_error")
            last <- notes[[length(notes)]]
            expect_identical(last$type, "error")
            text <- as.character(last$ui)
            expect_match(text, "Can't render a document with error items")
            expect_match(text, "white-space: pre-line", fixed = TRUE)
            expect_length(removed, 0L)

            # a download that works removes the notification
            suppressMessages(session$setInputs(`params-failCheck` = "no"))
            expect_true(file.exists(output$download))
            expect_identical(removed, "download")
        })
    })
})

# ---------
# Scenarios
# ---------
describe("the report app's pipeline", {
    # The acceptance test of v0.1: pipeline -> layout step -> pub_render() of
    # every format
    # The pipeline is run once, by the first test that renders
    pip <- NULL
    render <- function(report, format, dir, ...) {
        if (is.null(pip)) {
            pip <<- example_app_env("report-app")$demo_pipeline() |>
                pipeflow::pip_run(lgr = NULL)
        }
        meta <- list(author = "Jane Doe", app = "demo", version = "1.0")
        file <- file.path(dir, paste(report, format, sep = "."))
        pub_render(pip[[report, "out"]], format, file = file, meta = meta, ...)
    }

    it("renders both reports to HTML, Markdown and DOCX", {
        skip_if_no_pandoc()
        dir <- withr::local_tempdir()
        texts <- list()
        for (report in c("short", "long")) {
            html <- paste(readLines(render(report, "html", dir)), collapse = "\n")
            expect_match(html, "Significance", fixed = TRUE)

            md <- render(report, "md", dir)
            expect_match(paste(readLines(md), collapse = "\n"), "Results")
            expect_length(dir(file.path(dir, paste0(report, "_files"))), 1L)

            docx <- render(report, "docx", dir)
            texts[[report]] <- docx_pandoc_text(docx)
            expect_match(texts[[report]], "predictor is significant", fixed = TRUE)
            footer <- xml2::xml_text(docx_xml(docx, "word/footer1.xml"))
            expect_match(footer, "Jane Doe at")
        }
        expect_no_match(texts$short, "Methods", fixed = TRUE)
        expect_match(texts$long, "Methods", fixed = TRUE)
    })

    for (engine in c("xelatex", "typst")) {
        it(sprintf("renders the long report to PDF with %s", engine), {
            skip_if_no_pdf_engine(engine)
            skip_if_not_installed("pdftools")
            dir <- withr::local_tempdir()
            pdf <- render("long", "pdf", dir, pdf_engine = engine)
            text <- paste(pdftools::pdf_text(pdf), collapse = "\n")
            expect_match(text, "Jane Doe at")
            expect_match(text, "Data per month")
        })
    }

    it("keeps large unrelated data out of its documents (D20)", {
        env <- example_app_env("report-app")
        n <- 1e5
        # January: a month that the params leave out
        ballast <- data.frame(
            Ozone = stats::runif(n),
            Solar.R = stats::runif(n),
            Wind = stats::runif(n),
            Temp = stats::runif(n),
            Month = 1L,
            Day = 1L
        )
        data <- rbind(datasets::airquality, ballast)
        pip <- env$demo_pipeline(data) |>
            pipeflow::pip_run(lgr = NULL)
        doc <- pip[["long", "out"]]
        expect_gt(utils::object.size(data), 2e6)
        expect_lt(length(serialize(doc, NULL)), 1e6)
        expect_false(reaches_pipeline(doc))
    })
})
