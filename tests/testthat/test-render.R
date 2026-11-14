# ======================================================================================
# Rendering files
# ======================================================================================

# ------
# Render
# ------

describe("pub_render()", {
    noon <- as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
    small_doc <- function(...) {
        pub_doc(
            pub_section("Results", "All sites meet the limits.", ...),
            title = "Demo report",
            meta = list(time = noon)
        )
    }
    read_text <- function(file) {
        paste(readLines(file, encoding = "UTF-8"), collapse = "\n")
    }

    it("writes a standalone HTML page and returns its path", {
        file <- withr::local_tempfile(fileext = ".html")

        expect_invisible(path <- pub_render(small_doc(), file = file))

        expect_identical(path, file)
        html <- read_text(file)
        expect_match(html, "^<!DOCTYPE html>")
        expect_match(html, "<title>Demo report</title>", fixed = TRUE)
        expect_match(html, "<main class=\"pubflow-page\">", fixed = TRUE)
        expect_match(html, ".pubflow-doc .pubflow-error {", fixed = TRUE)
        expect_false(grepl("pubflow-doc.css", html, fixed = TRUE))
        expect_false(grepl("mathjax", html, fixed = TRUE))
    })

    it("inlines images and links MathJax for math", {
        file <- withr::local_tempfile(fileext = ".html")
        doc <- small_doc(
            pub_figure(recorded_plot(), width = 2, height = 2),
            "Formula $a^2$."
        )

        pub_render(doc, file = file)

        html <- read_text(file)
        expect_match(html, "<img src=\"data:image/png;base64,", fixed = TRUE)
        mathjax <- "https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5"
        expect_match(
            html,
            sprintf("<script src=\"%s/tex-chtml.js\">", mathjax),
            fixed = TRUE
        )
    })

    it("escapes the title of the HTML page and has one without a title", {
        file <- withr::local_tempfile(fileext = ".html")

        pub_render(pub_doc("x", title = "A & <B>"), file = file)
        expect_match(read_text(file), "<title>A &amp; &lt;B&gt;</title>", fixed = TRUE)

        pub_render(pub_doc("x"), file = file)
        expect_match(read_text(file), "<title>Document</title>", fixed = TRUE)
    })

    it("overwrites an existing file", {
        file <- withr::local_tempfile(fileext = ".md")
        writeLines("old", file)

        pub_render(small_doc(), "md", file = file)

        expect_false(grepl("old", read_text(file), fixed = TRUE))
        expect_match(read_text(file), "All sites meet the limits.", fixed = TRUE)
    })

    it("signals an error (and no warning) if the file can't be written", {
        file <- file.path(withr::local_tempdir(), "missing", "report.md")

        expect_no_warning(
            err <- expect_error(
                pub_render(small_doc(), "md", file = file),
                "Can't write",
                class = "pubflow_render_error"
            )
        )
        expect_identical(err$format, "md")
        expect_identical(err$call[[1L]], quote(pub_render))
        expect_match(conditionMessage(err), "reason '", fixed = TRUE)
        expect_false(file.exists(file))
    })

    it("writes to the temporary directory by default", {
        path <- pub_render(small_doc())
        withr::defer(unlink(path))

        expect_identical(dirname(path), tempdir())
        expect_identical(basename(path), "20261005T120000Z_demo_report.html")
    })

    it("refuses documents with error items", {
        doc <- small_doc(demo_failures()$fit)

        err <- expect_error(pub_render(doc), class = "pubflow_render_error")
        expect_match(
            conditionMessage(err),
            "step 'fit' failed: singular fit",
            fixed = TRUE
        )
        expect_identical(err$format, "html")
        expect_error(
            pub_render(demo_failed_report_doc()),
            class = "pubflow_render_error"
        )
    })

    it("writes a Markdown file with its figures next to it", {
        dir <- withr::local_tempdir()
        file <- file.path(dir, "report.md")
        doc <- small_doc(pub_figure(recorded_plot(), width = 2, height = 2))

        pub_render(doc, "md", file = file)

        expect_match(
            read_text(file),
            "![Figure](<report_files/figure-1.png>)",
            fixed = TRUE
        )
        expect_identical(
            list.files(dir, recursive = TRUE),
            c("report.md", "report_files/figure-1.png")
        )
        path <- pub_render(small_doc(), "md")
        withr::defer(unlink(path))
        expect_identical(basename(path), "20261005T120000Z_demo_report.md")
    })

    it("merges render-time metadata over the document's", {
        seen <- NULL
        spy <- pub_report_spec(
            "md",
            post_process = list(
                function(path, doc, spec) seen <<- doc
            )
        )
        doc <- pub_doc(
            pub_section("S", "text"),
            title = "T",
            subtitle = "Sub",
            meta = list(author = "Doc")
        )
        dir <- withr::local_tempdir()

        path <- pub_render(
            doc,
            "md",
            spec = spy,
            file = file.path(dir, "r.md"),
            meta = list(author = "Jane", subtitle = NULL, app = "demo")
        )

        expect_identical(seen$meta$author, "Jane")
        expect_null(seen$meta$subtitle)
        expect_identical(seen$meta$app, "demo")
        expect_s3_class(seen$meta$time, "POSIXct")
        expect_match(
            read_text(path),
            sprintf(
                "date: \"%s\"",
                .format_utc(seen$meta$time)
            ),
            fixed = TRUE
        )
        expect_identical(doc$meta$author, "Doc")

        # a blank string is not given: the document's value stays
        pub_render(
            doc,
            "md",
            spec = spy,
            file = file.path(dir, "r.md"),
            meta = list(author = "", app = " ")
        )
        expect_identical(seen$meta$author, "Doc")
        expect_null(seen$meta$app)
    })

    it("uses one render time for file name, title block and stamp", {
        seen <- NULL
        spy <- pub_report_spec(
            "md",
            post_process = list(
                function(path, doc, spec) seen <<- doc
            )
        )
        doc <- pub_doc(pub_section("S", "text"), title = "T")

        path <- pub_render(doc, "md", spec = spy, meta = list(author = "A"))
        withr::defer(unlink(path))

        time <- seen$meta$time
        expect_identical(basename(path), pub_output_filename(seen$meta, "md"))
        expect_match(read_text(path), .format_utc(time), fixed = TRUE)
        expect_match(
            pub_trace_stamp(seen),
            format(time, "%H:%M:%S", tz = "UTC"),
            fixed = TRUE
        )
        # a time of the document or of `meta` wins
        pub_render(
            small_doc(),
            "md",
            spec = spy,
            file = withr::local_tempfile(fileext = ".md")
        )
        expect_identical(seen$meta$time, noon)
        later <- noon + 3600
        pub_render(
            small_doc(),
            "md",
            spec = spy,
            meta = list(time = later),
            file = withr::local_tempfile(fileext = ".md")
        )
        expect_identical(seen$meta$time, later)
    })

    it("renders now if `meta` removes the document's time", {
        seen <- NULL
        spy <- pub_report_spec(
            "md",
            post_process = list(function(path, doc, spec) seen <<- doc)
        )
        before <- Sys.time()

        pub_render(
            small_doc(),
            "md",
            spec = spy,
            meta = list(time = NULL),
            file = withr::local_tempfile(fileext = ".md")
        )

        expect_gte(as.numeric(seen$meta$time), as.numeric(before))
    })

    it("shows error items with a warning if the spec says so", {
        doc <- small_doc(demo_failures()$fit)
        file <- withr::local_tempfile(fileext = ".md")
        show <- pub_report_spec("md", error_items = "show")

        expect_warning(
            pub_render(doc, "md", file = file, spec = show),
            "step 'fit' failed: singular fit",
            class = "pubflow_render_warning"
        )

        expect_match(read_text(file), "> **Step 'fit' failed**", fixed = TRUE)
        html <- withr::local_tempfile(fileext = ".html")
        expect_warning(
            pub_render(doc, file = html, spec = pub_report_spec(error_items = "show")),
            class = "pubflow_render_warning"
        )
        expect_match(read_text(html), "pubflow-error-title", fixed = TRUE)
    })

    it("guards error items of the front matter too", {
        front <- function(doc, format) list(demo_failures()$table)
        file <- withr::local_tempfile(fileext = ".md")

        err <- expect_error(
            pub_render(
                small_doc(),
                "md",
                file = file,
                spec = pub_report_spec("md", front_matter = front)
            ),
            "step 'fit' failed",
            class = "pubflow_render_error"
        )
        expect_false(file.exists(file))
        expect_warning(
            pub_render(
                small_doc(),
                "md",
                file = file,
                spec = pub_report_spec("md", front_matter = front, error_items = "show")
            ),
            class = "pubflow_render_warning"
        )
        expect_match(read_text(file), "^> \\*\\*Step 'fit' failed")
    })

    it("runs the post-processors in order before writing the file", {
        calls <- character()
        log <- function(name) {
            function(path, doc, spec) {
                calls <<- c(calls, name)
                expect_true(file.exists(path))
                expect_identical(doc$meta$author, "A")
                expect_identical(spec$format, "md")
                cat("<!-- ", name, " -->\n", file = path, append = TRUE)
                "ignored"
            }
        }
        spec <- pub_report_spec("md", post_process = list(log("a"), log("b")))
        file <- withr::local_tempfile(fileext = ".md")

        pub_render(
            small_doc(),
            "md",
            file = file,
            spec = spec,
            meta = list(author = "A")
        )

        expect_identical(calls, c("a", "b"))
        expect_match(read_text(file), "<!--  a  -->\n<!--  b  -->$")
    })

    it("writes no file if a post-processor fails", {
        file <- withr::local_tempfile(fileext = ".html")
        spec <- pub_report_spec(
            post_process = list(
                function(path, doc, spec) NULL,
                function(path, doc, spec) stop("no bookmark")
            )
        )

        err <- expect_error(
            pub_render(small_doc(), file = file, spec = spec),
            "Post-processor 2 of the spec failed",
            class = "pubflow_render_error"
        )
        expect_match(conditionMessage(err$parent), "no bookmark")
        expect_false(file.exists(file))
    })

    it("names an automatic post-processor that fails", {
        skip_if_no_pandoc()
        file <- withr::local_tempfile(fileext = ".docx")
        doc <- pub_doc("Text.", meta = list(footer = c(left = "{trace}")))

        err <- expect_error(
            pub_render(doc, "docx", file = file),
            "The automatic post-processor `pub_pp_docx_header_footer\\(\\)`",
            class = "pubflow_render_error"
        )
        expect_match(conditionMessage(err$parent), "metadata `author`")
        expect_false(file.exists(file))
    })

    it("signals an error if the rendered file is gone", {
        file <- withr::local_tempfile(fileext = ".md")
        spec <- pub_report_spec("md", post_process = function(path, doc, spec) {
            file.rename(path, paste0(path, ".bak"))
        })

        err <- expect_error(
            pub_render(small_doc(), "md", file = file, spec = spec),
            "The rendered file '.*' is missing",
            class = "pubflow_render_error"
        )
        expect_identical(err$format, "md")
        expect_identical(err$call[[1L]], quote(pub_render))
        expect_false(file.exists(file))
    })

    it("applies the spec to HTML files", {
        file <- withr::local_tempfile(fileext = ".html")
        front <- function(doc, format) pub_section("Signatures", "Signed.")
        spec <- pub_report_spec(
            front_matter = front,
            toc_depth = 1L,
            number_sections = FALSE,
            placeholder_color = "#00AA00",
            labels = list(table = "Tab.")
        )
        doc <- small_doc(
            pub_section("Sub", pub_table(data.frame(a = 1), caption = "C")),
            "[todo]{.placeholder}"
        )

        pub_render(doc, file = file, spec = spec)

        html <- read_text(file)
        # the stylesheet names the classes too
        main <- sub("(?s).*<main", "", html, perl = TRUE)
        expect_false(grepl("pubflow-doc-header", main, fixed = TRUE))
        expect_match(main, "id=\"pubflow-sec-0-1\"", fixed = TRUE)
        expect_false(grepl("pubflow-section-number", main, fixed = TRUE))
        expect_match(html, "<caption>Tab. 1: C</caption>", fixed = TRUE)
        expect_match(html, "{ color: #00aa00; }", fixed = TRUE)
        toc <- regmatches(html, regexpr("(?s)<nav class=.*?</nav>", html, perl = TRUE))
        expect_match(toc, "Signatures", fixed = TRUE)
        expect_false(grepl("Sub", toc, fixed = TRUE))
    })

    it("validates its arguments", {
        expect_error(pub_render(list()), "made by `pub_doc()`", fixed = TRUE)
        expect_error(
            pub_render(small_doc(), "docx", spec = pub_report_spec("pdf")),
            "`spec` is for \"pdf\" output, not \"docx\""
        )
        expect_error(
            pub_render(small_doc(), spec = list()),
            "made by `pub_report_spec()`",
            fixed = TRUE
        )
        expect_error(
            pub_render(small_doc(), meta = list("x")),
            "`meta` must be a named list"
        )
        expect_error(
            pub_render(small_doc(), meta = NULL),
            "`meta` must be a named list"
        )
        expect_error(pub_render(small_doc(), meta = "x"), "`meta` must be a named list")
        expect_error(
            pub_render(small_doc(), meta = list(app = "a", "b")),
            "`meta` must be a named list"
        )
        expect_error(
            pub_render(small_doc(), meta = list(author = 1)),
            "`author` must be a single string"
        )
        expect_error(
            pub_render(small_doc(), format = "rtf"),
            "`format` must be one of \"html\", \"docx\", \"pdf\", or"
        )
        expect_error(
            pub_render(small_doc(), "pdf", pdf_engine = "lualatex"),
            "`pdf_engine` must be one of \"xelatex\" or \"typst\""
        )
        expect_error(pub_render(small_doc(), file = 1), "`file` must be")
        expect_error(pub_render(small_doc(), cache = 1), "pub_cache")
        expect_error(pub_render(small_doc(), quiet = NA), "`quiet` must be")
    })
})


# ----------
# File names
# ----------

describe("pub_output_filename()", {
    noon <- as.POSIXct("2026-10-05 14:30:05", tz = "UTC")

    it("combines the UTC time and the title in snake case", {
        meta <- list(title = "Quality report: Site A (v2)", time = noon)

        expect_identical(
            pub_output_filename(meta, "docx"),
            "20261005T143005Z_quality_report_site_a_v2.docx"
        )
        expect_identical(
            pub_output_filename(pub_doc(title = "T", meta = list(time = noon)), "pdf"),
            "20261005T143005Z_t.pdf"
        )
    })

    it("keeps only ASCII letters and digits", {
        meta <- list(title = "\u00dcber caf\u00e9 \u2014 5%", time = noon)
        expect_identical(
            pub_output_filename(meta, "md"),
            "20261005T143005Z_ber_caf_5.md"
        )
    })

    it("uses \"document\" without a title and now without a time", {
        name <- pub_output_filename(list(title = "!!"), "html")

        expect_match(name, "^[0-9]{8}T[0-9]{6}Z_document\\.html$")
        expect_identical(
            substr(name, 1L, 8L),
            format(Sys.time(), "%Y%m%d", tz = "UTC")
        )
    })

    it("drops other characters at the start and end of the title", {
        expect_identical(
            pub_output_filename(list(title = " (Draft) report. ", time = noon), "md"),
            "20261005T143005Z_draft_report.md"
        )
    })

    it("formats the time in UTC", {
        local <- as.POSIXct("2026-10-05 16:30:05", tz = "Europe/Berlin")

        expect_match(
            pub_output_filename(list(time = local), "md"),
            "^20261005T143005Z_"
        )
    })

    it("validates its arguments", {
        expect_error(pub_output_filename("x", "md"), "`meta` must be a list")
        expect_error(pub_output_filename(list(), ".md"), "file extension")
        expect_error(pub_output_filename(NULL, "md"), "`meta` must be a list")
        for (ext in list(NA_character_, c("md", "pdf"), 1, "")) {
            expect_error(pub_output_filename(list(), ext), "file extension")
        }
        expect_error(
            pub_output_filename(list(time = "today"), "md"),
            "single date-time"
        )
    })
})


# ======================================================================================
# Steps of rendering
# ======================================================================================

# -----------
# Error items
# -----------

describe(".guard_error_items()", {
    failures <- demo_failures()

    it("lists every error item, also those in nested sections", {
        nodes <- pub_doc(
            pub_text("ok"),
            pub_section("A", pub_section("B", failures$fit)),
            failures$table
        )$children

        err <- expect_error(
            .guard_error_items(nodes, "refuse", "pdf"),
            class = "pubflow_render_error"
        )

        expect_length(gregexpr("failed", conditionMessage(err))[[1L]], 3L)
        expect_identical(err$format, "pdf")
    })

    it("accepts nodes without error items", {
        nodes <- pub_doc(pub_section("A", pub_text("ok")))$children

        expect_no_error(.guard_error_items(nodes, "refuse", "html"))
        expect_no_warning(.guard_error_items(nodes, "show", "html"))
    })
})


# ---------------
# Post-processors
# ---------------

describe(".post_processors()", {
    own <- function(path, doc, spec) NULL
    classes <- function(pp) {
        vapply(pp, \(f) class(f)[[1L]], character(1), USE.NAMES = FALSE)
    }

    it("puts the header and footer and the lock before a DOCX spec's", {
        pp <- .post_processors(
            pub_report_spec("docx", lock = TRUE, post_process = own)
        )

        expect_identical(
            classes(pp),
            c("pub_pp_docx_header_footer", "pub_pp_docx_lock", "function")
        )
        expect_identical(
            names(pp),
            c(
                "The automatic post-processor `pub_pp_docx_header_footer()`",
                "The automatic post-processor `pub_pp_docx_lock()`",
                "Post-processor 1 of the spec"
            )
        )
    })

    it("adds no lock without `lock = TRUE`", {
        for (lock in list(NULL, FALSE)) {
            pp <- .post_processors(pub_report_spec("docx", lock = lock))

            expect_identical(classes(pp), "pub_pp_docx_header_footer")
        }
    })

    it("doesn't add those that the spec lists", {
        spec <- pub_report_spec(
            "docx",
            post_process = list(
                own,
                pub_pp_docx_lock(),
                pub_pp_docx_header_footer(c(left = "x"))
            )
        )

        pp <- .post_processors(spec)

        expect_identical(
            classes(pp),
            c("function", "pub_pp_docx_lock", "pub_pp_docx_header_footer")
        )
        expect_identical(names(pp), sprintf("Post-processor %d of the spec", 1:3))
    })

    it("adds none to other formats", {
        for (format in c("html", "pdf", "md")) {
            spec <- pub_report_spec(format, post_process = own)
            expect_identical(classes(.post_processors(spec)), "function")
        }
        expect_length(.post_processors(pub_report_spec("html")), 0L)
    })
})


# ---------------
# Standalone HTML
# ---------------

describe(".inline_dependency()", {
    it("inlines the files of a dependency and links URLs", {
        dir <- withr::local_tempdir()
        writeLines("a { color: red; }", file.path(dir, "a.css"))
        writeLines("var x = '</script>';", file.path(dir, "a.js"))
        local <- htmltools::htmlDependency(
            "a",
            "1",
            src = dir,
            script = "a.js",
            stylesheet = "a.css"
        )
        remote <- htmltools::htmlDependency(
            "b",
            "1",
            src = c(href = "https://example.org/b"),
            script = "b.js"
        )

        expect_identical(
            .inline_dependency(local),
            c(
                "<style>\na { color: red; }\n</style>",
                "<script>\nvar x = '<\\/script>';\n</script>"
            )
        )
        expect_identical(
            .inline_dependency(remote),
            "<script src=\"https://example.org/b/b.js\"></script>"
        )
    })

    it("reads the files of a package and links the stylesheets of URLs", {
        local <- htmltools::htmlDependency(
            "pubflow-doc",
            "1",
            src = "www",
            package = "pubflow",
            stylesheet = "pubflow-doc.css",
            head = "<meta name=\"x\">"
        )
        remote <- htmltools::htmlDependency(
            "b",
            "1",
            src = c(href = "https://example.org/b"),
            script = list(list(src = "b.js", type = "module")),
            stylesheet = "b.css"
        )

        lines <- .inline_dependency(local)

        expect_length(lines, 2L)
        expect_match(lines[[1L]], "^<style>\n(?s).*\\.pubflow-doc", perl = TRUE)
        expect_identical(lines[[2L]], "<meta name=\"x\">")
        expect_identical(
            .inline_dependency(remote),
            c(
                "<link rel=\"stylesheet\" href=\"https://example.org/b/b.css\">",
                "<script src=\"https://example.org/b/b.js\"></script>"
            )
        )
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# ------------------------
# Cross-format consistency
# ------------------------

describe("cross-format consistency", {
    expected <- unname(edge_case_text())
    doc <- pub_doc(edge_case_table())
    # cells in table order (row by row) and which are struck through
    as_cells <- function(text, struck) {
        list(
            text = matrix(trimws(text), ncol = ncol(expected), byrow = TRUE),
            struck = matrix(struck, ncol = ncol(expected), byrow = TRUE)
        )
    }
    check <- function(cells, format) {
        expect_identical(cells$text, expected, info = format)
        expect_identical(
            unname(which(cells$struck, arr.ind = TRUE)),
            unname(edge_case_struck()),
            info = format
        )
    }
    # text from position `from` (after an opening bracket) to the matching closing one;
    # backslash escapes are skipped
    group <- function(x, from, open, close) {
        chars <- strsplit(substring(x, from), "")[[1L]]
        depth <- 1L
        i <- 0L
        while (depth > 0L) {
            i <- i + 1L
            if (chars[[i]] == "\\") {
                i <- i + 1L
            } else if (chars[[i]] == open) {
                depth <- depth + 1L
            } else if (chars[[i]] == close) {
                depth <- depth - 1L
            }
        }
        paste(chars[seq_len(i - 1L)], collapse = "")
    }
    markdown <- function(target) {
        pub_markdown(doc, target, file.path(withr::local_tempdir(), "f"))
    }

    it("shows the same cell text in HTML", {
        xml <- xml2::read_html(as.character(pub_html(doc)))
        cells <- xml2::xml_find_all(xml, "//table//th | //table//td")

        check(
            as_cells(
                xml2::xml_text(cells),
                vapply(
                    cells,
                    \(cell) {
                        length(xml2::xml_find_all(cell, ".//del")) > 0L
                    },
                    logical(1)
                )
            ),
            "html"
        )
    })

    it("shows the same cell text in Markdown", {
        lines <- strsplit(markdown("md"), "\n", fixed = TRUE)[[1L]]
        sep <- grep("^-+( +-+)+ *$", lines)
        runs <- gregexpr("-+", lines[[sep]])[[1L]]
        rows <- c(lines[[sep - 1L]], lines[seq(sep + 1L, length(lines))])
        rows <- rows[grepl("[^ -]", rows)]
        text <- unlist(lapply(rows, \(row) {
            substring(row, runs, runs + attr(runs, "match.length") - 1L)
        }))
        text <- gsub("\\*\\*", "", trimws(text))
        struck <- grepl("^~~.*~~$", text)
        text <- gsub("\\\\([[:punct:]])", "\\1", gsub("~~", "", text))

        check(as_cells(text, struck), "md")
    })

    it("shows the same cell text in LaTeX", {
        # the table as it goes into the .tex file, without the repeated head
        tex <- sub(
            "(?s)\\\\endfirsthead.*?\\\\endhead",
            "",
            markdown("latex"),
            perl = TRUE
        )
        starts <- gregexpr("\\selectfont ", tex, fixed = TRUE)[[1L]] + 12L
        text <- trimws(vapply(starts, \(i) group(tex, i, "{", "}"), character(1)))
        struck <- grepl("^\\\\sout\\{", text)
        text <- sub("^\\\\sout\\{(.*)\\}$", "\\1", text)

        check(as_cells(text, struck), "latex")
    })

    it("shows the same cell text in Typst", {
        typ <- markdown("typst")
        # cells, not huxtable's set rule for them
        starts <- gregexpr("(?<!set )table\\.cell\\(", typ, perl = TRUE)[[1L]] +
            11L
        content <- vapply(
            starts,
            \(i) {
                options <- group(typ, i, "(", ")")
                group(typ, i + nchar(options) + 2L, "[", "]")
            },
            character(1)
        )
        struck <- grepl("#strike[", content, fixed = TRUE)
        text <- trimws(content)
        pattern <- "(?s)^#[a-z]+(\\([^()]*\\))?\\[(.*)\\];?$"
        while (any(hit <- grepl(pattern, text, perl = TRUE))) {
            text[hit] <- trimws(sub(pattern, "\\2", text[hit], perl = TRUE))
        }

        check(as_cells(gsub("\\\\(.)", "\\1", text), struck), "typst")
    })

    it("shows the same cell text in Word", {
        skip_if_no_pandoc()
        file <- pub_render(doc, "docx", file = withr::local_tempfile(fileext = ".docx"))
        xml <- docx_xml(file)
        cells <- xml2::xml_find_all(xml, "//w:tbl//w:tc", xml2::xml_ns(xml))

        check(
            as_cells(
                xml2::xml_text(cells),
                vapply(
                    cells,
                    \(cell) {
                        length(xml2::xml_find_all(
                            cell,
                            ".//w:strike",
                            xml2::xml_ns(xml)
                        )) >
                            0L
                    },
                    logical(1)
                )
            ),
            "docx"
        )
    })
})
