describe("pub_viewer_ui()", {
    it("has a table of contents and a document output (snapshot)", {
        expect_snapshot(cat(as.character(pub_viewer_ui("viewer"))))
        expect_snapshot(cat(as.character(
            pub_viewer_ui("viewer", toc = FALSE, height = "600px")
        )))
    })

    it("attaches the viewer and document dependencies", {
        deps <- htmltools::findDependencies(pub_viewer_ui("viewer"))

        expect_identical(
            vapply(deps, \(d) d$name, character(1)),
            c("pubflow-viewer", "pubflow-doc")
        )
        files <- system.file(
            "www",
            c(deps[[1L]]$script, deps[[1L]]$stylesheet),
            package = "pubflow"
        )
        expect_true(all(nzchar(files)))
    })

    it("validates its arguments", {
        expect_error(pub_viewer_ui("v", toc = NA), "`toc` must be")
        expect_error(pub_viewer_ui("v", height = "tall"))
    })
})

describe("pub_viewer_server()", {
    html_of <- function(x) paste(as.character(x$html), collapse = "")
    render_viewer <- function(value, cache = pub_cache()) {
        doc <- shiny::reactiveVal(value)
        out <- list()
        shiny::testServer(
            pub_viewer_server,
            args = list(doc = doc, cache = cache),
            {
                session$flushReact()
                out$doc <<- html_of(output$doc)
                out$toc <<- html_of(output$toc)
                out$deps <<- vapply(output$doc$deps, \(d) d$name, character(1))
                out$ns <<- session$ns("doc")
            }
        )
        out
    }

    it("renders the document and its table of contents", {
        res <- render_viewer(demo_report_doc())

        expect_match(res$doc, "<div class=\"pubflow-doc\">", fixed = TRUE)
        expect_match(
            res$doc,
            "<h1 class=\"pubflow-title\">Quality demo",
            fixed = TRUE
        )
        expect_false(grepl("pubflow-toc", res$doc, fixed = TRUE))
        expect_match(res$doc, sprintf("id=\"%s-sec-3-1\"", res$ns), fixed = TRUE)
        expect_match(res$toc, sprintf("<a href=\"#%s-sec-3-1\">", res$ns), fixed = TRUE)
        expect_match(res$toc, "<nav class=\"pubflow-toc\">", fixed = TRUE)
    })

    it("warns about unresolved cross-references and still shows the document", {
        expect_warning(
            res <- render_viewer(pub_doc("See @fig:nope.")),
            "no table or figure has the id 'nope'",
            class = "pubflow_render_warning"
        )

        expect_match(res$doc, "pubflow-ref-unresolved\">@fig:nope</span>", fixed = TRUE)
    })

    it("leaves the table of contents empty for a document without sections", {
        res <- render_viewer(pub_doc("Just text.", title = "Plain"))

        expect_match(res$doc, "Just text.", fixed = TRUE)
        expect_identical(res$toc, "")
    })

    it("lists sections up to level 3 in the table of contents", {
        doc <- pub_doc(
            pub_section(
                "One",
                pub_section("Two", pub_section("Three", pub_section("Four", "x")))
            )
        )

        res <- render_viewer(doc)

        expect_match(res$toc, " Three</a>", fixed = TRUE)
        expect_false(grepl("Four", res$toc, fixed = TRUE))
        expect_match(res$doc, "Four", fixed = TRUE)
    })

    it("attaches MathJax only for a document with math", {
        expect_identical(
            render_viewer(pub_doc("Formula $a^2$."))$deps,
            c("pubflow-doc", "mathjax")
        )
        expect_identical(render_viewer(pub_doc("No math."))$deps, "pubflow-doc")
    })

    it("shows a placeholder for NULL", {
        res <- render_viewer(NULL)

        expect_match(
            res$doc,
            "<div class=\"pubflow-viewer-empty\">No results",
            fixed = TRUE
        )
        expect_identical(res$toc, "")
    })

    it("shows the failures placed by a layout step as error boxes", {
        res <- render_viewer(demo_failed_report_doc())

        expect_match(res$doc, "Step 'check' failed", fixed = TRUE)
        expect_match(res$doc, "Step 'check_text' was not run.", fixed = TRUE)
        expect_match(res$doc, "Table 5: Acceptance criteria", fixed = TRUE)
    })

    it("shows one error box for a failed layout step", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("data", \(x = 1) x) |>
            pipeflow::pip_add("doc", \(data = ~data) stop("no title given"))
        suppressWarnings(
            run_quietly(p, on_error = "continue"),
            classes = "pipeflow_run_failed"
        )

        res <- render_viewer(p[["doc", "out"]])

        expect_identical(
            lengths(regmatches(
                res$doc,
                gregexpr("pubflow-error\"", res$doc, fixed = TRUE)
            )),
            1L
        )
        expect_match(res$doc, "The document could not be built", fixed = TRUE)
        expect_match(res$doc, "no title given", fixed = TRUE)
        expect_identical(res$toc, "")
    })

    it("escapes the message of a failed layout step", {
        res <- render_viewer(simpleError("<b>bad</b> & worse"))

        expect_match(res$doc, "&lt;b&gt;bad&lt;/b&gt; &amp; worse", fixed = TRUE)
        expect_false(grepl("<b>bad", res$doc, fixed = TRUE))
        expect_identical(res$deps, "pubflow-doc")
    })

    it("shows an error box for other values", {
        res <- render_viewer(data.frame(a = 1))

        expect_match(
            res$doc,
            "not a document (class &lt;data.frame&gt;).",
            fixed = TRUE
        )
        res <- render_viewer(structure(list(), class = c("a", "b")))
        expect_match(res$doc, "(class &lt;a/b&gt;)", fixed = TRUE)
        expect_identical(res$toc, "")
    })

    it("shows the message of a try-error", {
        res <- render_viewer(try(stop("no trend"), silent = TRUE))

        expect_match(res$doc, "pubflow-error-message\">no trend<", fixed = TRUE)
    })

    it("renders a changed document with figures from the cache", {
        renders <- 0L
        real <- .render_figure
        local_mocked_bindings(.render_figure = function(...) {
            renders <<- renders + 1L
            real(...)
        })
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("plot", \(n = 5) {
                pub_figure(recorded_plot(n), width = 2, height = 2)
            }) |>
            pipeflow::pip_add("doc", \(plot = ~plot, title = "A") {
                pub_doc(pub_section(title, plot))
            })
        run_quietly(p)
        doc <- shiny::reactiveVal(p[["doc", "out"]])

        shiny::testServer(pub_viewer_server, args = list(doc = doc), {
            session$flushReact()
            expect_match(html_of(output$toc), " A</a>", fixed = TRUE)
            pipeflow::pip_set_params(p, list(title = "B"))
            run_quietly(p)
            doc(p[["doc", "out"]])
            session$flushReact()
            expect_match(html_of(output$toc), " B</a>", fixed = TRUE)
        })
        expect_identical(renders, 1L)
    })

    it("takes figures from a cache shared by several viewers", {
        renders <- 0L
        real <- .render_figure
        local_mocked_bindings(.render_figure = function(...) {
            renders <<- renders + 1L
            real(...)
        })
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("plot", \(n = 3) {
                pub_figure(recorded_plot(n), width = 2, height = 2)
            }) |>
            pipeflow::pip_add("doc", \(plot = ~plot) pub_doc(pub_section("A", plot)))
        run_quietly(p)
        doc <- p[["doc", "out"]]
        cache <- pub_cache()

        first <- render_viewer(doc, cache = cache)
        second <- render_viewer(doc, cache = cache)

        expect_identical(renders, 1L)
        expect_identical(second$doc, first$doc)
    })

    it("validates its arguments", {
        expect_error(
            pub_viewer_server("v", doc = pub_doc()),
            "`doc` must be a reactive"
        )
        expect_error(
            pub_viewer_server("v", shiny::reactive(NULL), cache = 1),
            "pub_cache"
        )
    })
})
