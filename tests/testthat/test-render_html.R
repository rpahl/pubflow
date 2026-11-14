describe("pub_html()", {
    dep_names <- function(html) {
        vapply(htmltools::htmlDependencies(html), \(d) d$name, character(1))
    }
    every_node_doc <- function(widget) {
        pub_doc(
            pub_section(
                "Text",
                pub_text(
                    c(
                        "Some **bold** text, $x^2$ and",
                        "[todo]{.placeholder}.",
                        "",
                        "<b>not bold</b>"
                    ),
                    title = "Note"
                ),
                pub_raw(html = "<hr class=\"custom\">", md = "---"),
                pub_raw(md = "Markdown only"),
                pub_pagebreak(),
                pub_toc(depth = 1L),
                widget
            ),
            pub_section(
                "Tables",
                pub_table(
                    data.frame(a = c(1.25, NA), b = c("x", "<y>")),
                    caption = "A & B",
                    digits = c(a = 1L)
                ),
                pub_set_meta(data.frame(z = 1L), title = "No caption")
            ),
            pub_section(
                "Figures",
                pub_figure(
                    recorded_plot(),
                    caption = "Points",
                    width = 3,
                    height = 2,
                    out_width = "50%",
                    id = "fig-points"
                ),
                pub_figure(recorded_plot(3L), width = 2, height = 2),
                pub_section("Nested", "Text of an unnumbered section."),
                numbered = FALSE
            ),
            pub_section(
                "Results",
                pub_section(
                    "Fit",
                    pub_figure(
                        recorded_plot(4L),
                        width = 2,
                        height = 2,
                        caption = "Fit"
                    )
                ),
                pub_section("Check", demo_failures()$table)
            ),
            title = "Every node",
            subtitle = "Subtitle & more",
            meta = list(
                author = "A. User",
                app = "tests",
                version = "1.0",
                time = as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
            )
        )
    }

    it("renders every node type (snapshot)", {
        widget <- local_fake_widget()

        html <- pub_html(every_node_doc(widget))

        expect_snapshot(cat(without_images(html)))
        expect_identical(dep_names(html), c("pubflow-doc", "mathjax", "fake"))
    })

    it("numbers sections, tables and figures with captions", {
        html <- as.character(pub_html(every_node_doc(NULL)))

        number <- "<span class=\"pubflow-section-number\">3.1</span> Fit"
        expect_match(html, number, fixed = TRUE)
        expect_match(html, "<h2>Figures</h2>", fixed = TRUE)
        expect_match(html, "<h3>Nested</h3>", fixed = TRUE)
        expect_match(html, "Table 1: A &amp; B", fixed = TRUE)
        expect_false(grepl("Table 2", html, fixed = TRUE))
        expect_match(html, "Figure 1: Points", fixed = TRUE)
        expect_match(html, "Figure 2: Fit", fixed = TRUE)
        expect_match(html, "id=\"pubflow-sec-3-1\"", fixed = TRUE)
        expect_match(
            html,
            "pubflow-figure\" id=\"pubflow-figure-fig-points\">",
            fixed = TRUE
        )
    })

    it("puts the numbered caption into the table, escaped", {
        doc <- pub_doc(pub_table(data.frame(a = 1), caption = "a < b \\1"))

        html <- as.character(pub_html(doc))

        expect_match(
            html,
            "<table [^>]*>\n<caption>Table 1: a &lt; b \\\\1</caption>\n"
        )
    })

    it("shows failed steps as error boxes", {
        html <- as.character(pub_html(pub_doc(unname(demo_failures()))))

        expect_identical(
            lengths(regmatches(
                html,
                gregexpr("pubflow-item pubflow-error", html, fixed = TRUE)
            )),
            1L + 1L
        )
        expect_match(
            html,
            "pubflow-error-title\">Step 'fit' failed</div>",
            fixed = TRUE
        )
        expect_match(html, "pubflow-error-message\">singular fit</div>", fixed = TRUE)
        expect_match(html, "Step 'table' was not run.", fixed = TRUE)
    })

    it("names the pipeline of an error item of pub_out()", {
        item <- structure(
            list(
                step = "content",
                failed_step = "fit",
                message = "no <trend>",
                pipeline = "Rain & Co"
            ),
            class = "pub_error"
        )

        html <- as.character(pub_html(pub_doc(item)))

        expect_match(
            html,
            paste0(
                "pubflow-error-title\">Step 'fit' of pipeline 'Rain &amp; Co' ",
                "failed</div>"
            ),
            fixed = TRUE
        )
        expect_match(
            html,
            "pubflow-error-message\">no &lt;trend&gt;</div>",
            fixed = TRUE
        )
        expect_match(html, "Step 'content' was not run.", fixed = TRUE)
    })

    it("adds a table of contents on request", {
        doc <- pub_doc(pub_section("A", pub_section("B", "x")), title = "T")

        expect_match(pub_html(doc), "<nav class=\"pubflow-toc\">", fixed = TRUE)
        expect_false(grepl("pubflow-toc", pub_html(doc, toc = FALSE)))
        expect_false(grepl("pubflow-toc", pub_html(pub_doc("x"))))
    })

    it("attaches MathJax only for math, and with math = \"mathjax\"", {
        doc <- pub_doc("Formula $a^2$.")

        expect_identical(dep_names(pub_html(pub_doc("No math."))), "pubflow-doc")
        expect_identical(dep_names(pub_html(doc)), c("pubflow-doc", "mathjax"))
        expect_identical(dep_names(pub_html(doc, math = "none")), "pubflow-doc")
    })

    it("renders figures as SVG and image files", {
        skip_if_not_installed("svglite")
        file <- withr::local_tempfile(fileext = ".svg")
        .render_figure(recorded_plot(), file, device = "svg", width = 2, height = 2)
        doc <- pub_doc(
            pub_figure(recorded_plot(), width = 2, height = 2),
            pub_figure(file)
        )

        html <- as.character(pub_html(doc, figure = list(device = "svg")))

        expect_identical(
            lengths(regmatches(
                html,
                gregexpr("data:image/svg+xml;base64,", html, fixed = TRUE)
            )),
            2L
        )
        # an svg file without a raster one is used with the png device too
        html <- as.character(pub_html(doc, figure = list(device = "png")))
        expect_match(html, "data:image/png;base64,", fixed = TRUE)
        expect_match(html, "data:image/svg+xml;base64,", fixed = TRUE)
    })

    it("validates its arguments", {
        doc <- pub_doc("x")

        expect_error(
            pub_html(pub_section("A", "x")),
            "made by `pub_doc()`",
            fixed = TRUE
        )
        expect_error(
            pub_html(doc, cache = list()),
            "made by `pub_cache()`",
            fixed = TRUE
        )
        expect_error(pub_html(doc, toc = NA), "`toc` must be")
        expect_error(
            pub_html(doc, figure = list(device = "pdf")),
            "must be \"png\" or \"svg\""
        )
        expect_error(pub_html(doc, figure = list(res = -1)), "positive number")
        expect_error(pub_html(doc, figure = list(dpi = 1)), "`device` and `res`")
        expect_error(pub_html(doc, figure = list("png")), "`device` and `res`")
        expect_error(pub_html(doc, figure = NULL), "`device` and `res`")
        expect_error(
            pub_html(doc, figure = list(device = c("png", "svg"))),
            "must be \"png\" or \"svg\""
        )
        expect_error(pub_html(doc, figure = list(res = "200")), "positive number")
        expect_error(pub_html(doc, math = "katex"), "`math` must be one of")
    })

    it("fills in the default figure settings", {
        expect_identical(
            .check_figure_settings(list()),
            list(device = "png", res = 200)
        )
        expect_identical(
            .check_figure_settings(list(device = "svg")),
            list(device = "svg", res = 200)
        )
    })
})

describe(".html_doc() with spec settings", {
    doc <- pub_doc(
        pub_section("A", pub_section("B", pub_table(data.frame(x = 1), caption = "X"))),
        title = "T"
    )
    front <- .as_children(list(
        pub_section("Front", pub_table(data.frame(y = 1), caption = "Y")),
        "Signed."
    ))
    html_of <- function(...) {
        as.character(.html_doc(
            doc,
            NULL,
            toc = TRUE,
            math = "none",
            figure = list(device = "png", res = 72),
            ...
        ))
    }

    it("limits the table of contents to toc_depth", {
        toc <- function(html) {
            regmatches(html, regexpr("(?s)<nav.*?</nav>", html, perl = TRUE))
        }

        expect_match(toc(html_of()), "B</a>", fixed = TRUE)
        expect_false(grepl("B</a>", toc(html_of(toc_depth = 1L)), fixed = TRUE))
    })

    it("leaves sections unnumbered with numbered = FALSE", {
        expect_match(html_of(), "pubflow-section-number", fixed = TRUE)
        expect_false(grepl(
            "pubflow-section-number",
            html_of(numbered = FALSE),
            fixed = TRUE
        ))
    })

    it("escapes the caption labels", {
        html <- html_of(labels = list(table = "Tab <&>", figure = "Fig"))

        expect_match(html, "<caption>Tab &lt;&amp;&gt; 1: X</caption>", fixed = TRUE)
    })

    it("replaces the header by front matter with ids of their own", {
        html <- html_of(front = front)

        expect_false(grepl("pubflow-doc-header", html, fixed = TRUE))
        expect_match(
            html,
            paste0(
                "<section class=\"pubflow-section pubflow-level-1\" ",
                "id=\"pubflow-sec-0-1\">\n<h2>Front</h2>"
            ),
            fixed = TRUE
        )
        expect_match(html, "id=\"pubflow-sec-1\">\n<h2><span", fixed = TRUE)
        # the front matter comes first, its table counts
        expect_lt(
            regexpr("Signed.", html, fixed = TRUE),
            regexpr("<nav", html, fixed = TRUE)
        )
        expect_match(html, "Table 1: Y", fixed = TRUE)
        expect_match(html, "Table 2: X", fixed = TRUE)
    })
})

describe(".html_header()", {
    it("has no header without metadata", {
        expect_null(.html_header(list()))
        expect_identical(
            as.character(pub_html(pub_doc())),
            "<div class=\"pubflow-doc\">\n</div>"
        )
    })

    it("shows the metadata there is, escaped", {
        expect_identical(
            .html_header(list(version = "1.0")),
            c(
                "<header class=\"pubflow-doc-header\">",
                "<p class=\"pubflow-doc-meta\">1.0</p>",
                "</header>"
            )
        )
        header <- .html_header(list(title = "A < B", author = "Me & you"))
        expect_identical(header[[2L]], "<h1 class=\"pubflow-title\">A &lt; B</h1>")
        expect_identical(header[[3L]], "<p class=\"pubflow-doc-meta\">Me &amp; you</p>")
    })
})

describe(".html_toc()", {
    entry <- function(id, level) {
        list(id = id, number = NULL, title = id, level = level)
    }
    count <- function(pattern, x) {
        lengths(regmatches(x, gregexpr(pattern, x, fixed = TRUE)))
    }

    it("closes the nested lists when going up levels", {
        outline <- list(
            entry("a", 1L),
            entry("b", 2L),
            entry("c", 3L),
            entry("d", 1L),
            entry("e", 2L)
        )

        toc <- paste(.html_toc(outline, depth = 3L), collapse = "\n")

        expect_identical(count("<ul>", toc), count("</ul>", toc))
        expect_identical(count("<li>", toc), count("</li>", toc))
        expect_identical(count("<li>", toc), 5L)
        expect_match(toc, "c</a>\n</li>\n</ul></li>\n</ul></li>\n<li>", fixed = TRUE)
    })

    it("is NULL without sections up to depth", {
        expect_null(.html_toc(list(), depth = 3L))
        expect_null(.html_toc(list(entry("b", 2L)), depth = 1L))
    })

    it("fills each table of contents item with its own depth", {
        doc <- pub_doc(
            pub_toc(depth = 1L),
            pub_section("A", pub_section("B", "x")),
            pub_toc(depth = 2L)
        )

        html <- as.character(pub_html(doc, toc = FALSE))

        tocs <- regmatches(html, gregexpr("(?s)<nav.*?</nav>", html, perl = TRUE))[[1]]
        expect_length(tocs, 2L)
        expect_false(grepl("B</a>", tocs[[1L]], fixed = TRUE))
        expect_match(tocs[[2L]], "B</a>", fixed = TRUE)
        expect_false(grepl("<!--pubflow-toc", html, fixed = TRUE))
    })

    it("leaves out lists of figures and tables, with their titles", {
        doc <- pub_doc(
            pub_set_meta(pub_toc(what = "figures"), title = "Figures"),
            pub_toc(what = "tables"),
            pub_section("A", "x")
        )

        html <- as.character(pub_html(doc, toc = FALSE))

        expect_false(grepl("<nav", html, fixed = TRUE))
        expect_false(grepl("Figures", html, fixed = TRUE))
        expect_false(grepl("pubflow-toc", html, fixed = TRUE))
    })

    it("fills a table of contents item in the front matter", {
        html <- as.character(.html_doc(
            pub_doc(pub_section("A", "x")),
            NULL,
            toc = FALSE,
            math = "none",
            figure = list(device = "png", res = 72),
            front = .as_children(list(pub_toc()))
        ))

        expect_match(html, "<a href=\"#pubflow-sec-1\">", fixed = TRUE)
        expect_false(grepl("<!--pubflow-toc", html, fixed = TRUE))
    })
})

describe("sections and items", {
    it("uses <h6> for every heading below level 5", {
        section <- "x"
        for (i in 7:1) {
            section <- pub_section(paste0("L", i), section)
        }

        html <- as.character(pub_html(pub_doc(section), toc = FALSE))

        expect_identical(
            regmatches(html, gregexpr("<h[0-9]>", html))[[1]],
            c("<h2>", "<h3>", "<h4>", "<h5>", "<h6>", "<h6>", "<h6>")
        )
        expect_match(html, "id=\"pubflow-sec-1-1-1-1-1-1-1\"", fixed = TRUE)
    })

    it("writes the item id with prefix and type and escapes the title", {
        item <- pub_set_meta(pub_text("x"), id = "a-b", title = "<T>")

        html <- as.character(pub_html(pub_doc(item)))

        expect_match(html, "pubflow-text\" id=\"pubflow-text-a-b\">", fixed = TRUE)
        expect_match(html, "pubflow-item-title\">&lt;T&gt;</div>", fixed = TRUE)
    })

    it("has no detail line if the step itself failed", {
        error <- structure(
            list(step = "fit", failed_step = "fit", message = "m"),
            class = "pub_error"
        )

        html <- .html_error(error)

        expect_match(html, "Step 'fit' failed", fixed = TRUE)
        expect_false(grepl("pubflow-error-detail", html, fixed = TRUE))
    })
})

describe("tables and figures", {
    it("sets the font size of a table", {
        table <- pub_table(data.frame(a = 1))

        html <- as.character(pub_html(pub_doc(pub_set_meta(table, font_size = 7))))

        expect_match(html, "font-size: 7pt;", fixed = TRUE)
        expect_false(grepl("font-size: 7pt;", pub_html(pub_doc(table)), fixed = TRUE))
    })

    it("gives the column widths the same meaning as in DOCX and PDF", {
        html_of <- function(widths) {
            df <- data.frame(a = 1, b = 2, c = 3)
            html <- as.character(pub_html(pub_doc(pub_table(df, widths = widths))))
            cols <- regmatches(html, gregexpr("<col[^>]*>", html))[[1L]]
            table <- regmatches(html, regexpr("<table[^>]*>", html))
            list(cols = cols, spans = grepl("width: 100%;", table, fixed = TRUE))
        }
        col <- function(width) sprintf("<col style=\"width: %s\">", width)

        expect_identical(
            html_of(c(a = 2, b = 1, c = 1)),
            list(cols = col(c("50%", "25%", "25%")), spans = TRUE)
        )
        expect_identical(
            html_of(c(a = 3, b = 1)),
            list(cols = col(c("60%", "20%", "20%")), spans = TRUE)
        )
        expect_identical(
            html_of(c(a = "2.5cm", b = 1, c = 3)),
            list(
                cols = col(c("2.5cm; min-width: 2.5cm", "25%", "75%")),
                spans = TRUE
            )
        )
        expect_identical(
            html_of(c(a = "2cm", b = "1cm", c = "1cm")),
            list(
                cols = col(c(
                    "2cm; min-width: 2cm",
                    "1cm; min-width: 1cm",
                    "1cm; min-width: 1cm"
                )),
                spans = FALSE
            )
        )
        expect_identical(html_of(NULL), list(cols = rep("<col>", 3), spans = FALSE))
        expect_identical(
            html_of(c(a = "auto", b = "auto", c = "auto")),
            list(cols = col(rep("auto", 3)), spans = FALSE)
        )
        half <- pub_table(data.frame(a = 1, b = 2), widths = c(a = 1))
        huxtable::width(half) <- 0.5
        expect_match(as.character(pub_html(pub_doc(half))), "width: 50%;", fixed = TRUE)
    })

    it("takes the alt text from the caption, the title or \"Figure\"", {
        alt_of <- function(...) {
            figure <- pub_figure(recorded_plot(), width = 2, height = 2, ...)
            html <- as.character(pub_html(pub_doc(figure)))
            regmatches(html, regexpr("alt=\"[^\"]*\"", html))
        }

        expect_identical(alt_of(caption = "C", title = "T"), "alt=\"C\"")
        expect_identical(alt_of(title = "a \"T\""), "alt=\"a &quot;T&quot;\"")
        expect_identical(alt_of(), "alt=\"Figure\"")
    })

    it("deletes the image file of a figure rendered without a cache", {
        figures <- function() list.files(tempdir(), "^pubflow-figure-")
        before <- figures()

        pub_html(pub_doc(pub_figure(recorded_plot(), width = 2, height = 2)))

        expect_identical(figures(), before)
    })

    it("gives image files the MIME type of their extension", {
        dir <- withr::local_tempdir()
        files <- file.path(dir, c("a.JPG", "b.jpeg", "c.svg", "d.png"))
        for (file in files) {
            writeBin(charToRaw("x\n"), file)
        }

        uris <- vapply(files, .data_uri, character(1), USE.NAMES = FALSE)

        expect_identical(
            sub(";base64,.*", "", uris),
            paste0("data:image/", c("jpeg", "jpeg", "svg+xml", "png"))
        )
        expect_identical(sub(".*;base64,", "", uris[[1L]]), "eAo=")
    })
})

describe("pub_html() with a cache", {
    count_calls <- function(name, frame = parent.frame()) {
        counter <- new.env()
        counter$n <- 0L
        real <- get(name, envir = asNamespace("pubflow"))
        local_mocked_bindings(
            !!name := function(...) {
                counter$n <- counter$n + 1L
                real(...)
            },
            .env = frame
        )
        counter
    }
    plot_pipeline <- function() {
        pipeflow::pip_new("p") |>
            pipeflow::pip_add("plot", \(n = 5) {
                pub_figure(recorded_plot(n), width = 2, height = 2)
            }) |>
            pipeflow::pip_add("doc", \(plot = ~plot) pub_doc(plot))
    }

    it("renders a figure once and again after its step re-ran", {
        renders <- count_calls(".render_figure")
        p <- plot_pipeline()
        run_quietly(p)
        cache <- pub_cache()

        first <- pub_html(p[["doc", "out"]], cache = cache)
        second <- pub_html(p[["doc", "out"]], cache = cache)
        expect_identical(renders$n, 1L)
        expect_identical(as.character(second), as.character(first))

        run_quietly(p, force = TRUE)
        pub_html(p[["doc", "out"]], cache = cache)
        expect_identical(renders$n, 2L)
    })

    it("shares the figures with the viewer and every format", {
        renders <- count_calls(".render_figure")
        p <- plot_pipeline()
        run_quietly(p)
        doc <- p[["doc", "out"]]
        cache <- pub_cache()

        .viewer_render(doc, cache, prefix = "v")
        pub_html(doc, cache = cache)
        for (target in c("docx", "latex", "typst", "md")) {
            pub_markdown(
                doc,
                target,
                file.path(withr::local_tempdir(), "f"),
                cache = cache
            )
        }

        expect_identical(renders$n, 1L)
    })

    it("renders figures without a stamp every time", {
        renders <- count_calls(".render_figure")
        doc <- pub_doc(pub_figure(recorded_plot(), width = 2, height = 2))
        cache <- pub_cache()

        pub_html(doc, cache = cache)
        pub_html(doc, cache = cache)

        expect_identical(renders$n, 2L)
        expect_length(cache$entries, 0L)
    })

    it("keeps the HTML of tables", {
        conversions <- count_calls(".huxtable_html")
        doc <- pub_doc(pub_table(data.frame(a = 1:2), caption = "A"))
        cache <- pub_cache()

        first <- pub_html(doc, cache = cache)
        second <- pub_html(doc, cache = cache)

        expect_identical(conversions$n, 1L)
        expect_identical(as.character(second), as.character(first))
        expect_identical(as.character(pub_html(doc)), as.character(first))
    })

    it("keeps the HTML of a table per font size", {
        conversions <- count_calls(".huxtable_html")
        table <- pub_table(data.frame(a = 1:2))
        cache <- pub_cache()

        pub_html(pub_doc(table), cache = cache)
        small <- pub_html(pub_doc(pub_set_meta(table, font_size = 7)), cache = cache)
        pub_html(pub_doc(pub_set_meta(table, font_size = 7)), cache = cache)

        expect_identical(conversions$n, 2L)
        expect_match(small, "font-size: 7pt;", fixed = TRUE)
    })

    it("renders a figure again for other device settings", {
        renders <- count_calls(".render_figure")
        p <- plot_pipeline()
        run_quietly(p)
        doc <- p[["doc", "out"]]
        cache <- pub_cache()

        pub_html(doc, cache = cache)
        pub_html(doc, cache = cache, figure = list(res = 72))
        pub_html(doc, cache = cache, figure = list(res = 72))

        expect_identical(renders$n, 2L)
        expect_length(cache$entries, 2L)
        files <- vapply(cache$entries, \(e) e$value, character(1))
        expect_true(all(file.exists(files)))
    })
})

describe("pub_html() of the fixture documents", {
    roundtrip <- function(x) {
        file <- withr::local_tempfile(fileext = ".rds")
        without_package_env_warning(saveRDS(x, file))
        readRDS(file)
    }

    it("renders documents restored with readRDS() as the originals", {
        docs <- list(
            demo_report_doc(),
            demo_split_doc(),
            demo_nested_doc(),
            demo_series_doc(),
            demo_failed_report_doc()
        )

        for (doc in docs) {
            expect_identical(
                as.character(pub_html(roundtrip(doc))),
                as.character(pub_html(doc))
            )
        }
    })

    it("renders the report document (snapshot)", {
        expect_snapshot(cat(without_images(pub_html(demo_report_doc()))))
    })
})
