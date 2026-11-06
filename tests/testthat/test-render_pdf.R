# ======================================================================================
# PDF files
# ======================================================================================

# ------
# Render
# ------

describe("pub_render(format = \"pdf\")", {
    render <- function(doc, engine) {
        skip_if_no_pdf_engine(engine)
        skip_if_not_installed("pdftools")
        file <- withr::local_tempfile(fileext = ".pdf", .local_envir = parent.frame())
        pub_render(doc, "pdf", file = file, pdf_engine = engine)
    }
    doc <- function() {
        pub_doc(
            pub_section(
                "Results",
                "Text $x^2$.",
                pub_toc(),
                pub_table(data.frame(a = 1:40), caption = "Long")
            ),
            pub_section(
                "Wide",
                pub_table(data.frame(w = 1), caption = "W"),
                landscape = TRUE
            ),
            pub_section("Annex", "End.", numbered = FALSE),
            title = "PDF",
            meta = list(footer = c(left = "trace"))
        )
    }
    pages <- function(path) {
        text <- pdftools::pdf_text(path)
        list(n = length(text), text = text, landscape = pdf_landscape(path))
    }

    it("makes a PDF via xelatex with landscape pages", {
        res <- pages(render(doc(), "xelatex"))

        expect_gte(res$n, 5L)
        expect_true(any(res$landscape))
        expect_false(res$landscape[[1L]])
        expect_match(res$text[[1L]], "trace")
        expect_match(res$text[[res$n]], sprintf("Page %d / %d", res$n, res$n))
        expect_true(any(grepl("1\\s+Results", res$text)))
        expect_true(any(grepl("Table 1: Long", res$text, fixed = TRUE)))
    })

    it("makes a PDF via Typst with landscape pages", {
        res <- pages(render(doc(), "typst"))

        expect_gte(res$n, 4L)
        expect_true(any(res$landscape))
        expect_match(res$text[[res$n]], sprintf("Page %d / %d", res$n, res$n))
        expect_true(any(grepl("Table 2: W", res$text, fixed = TRUE)))
    })

    it("removes the page number for an empty right footer", {
        for (engine in c("xelatex", "typst")) {
            doc <- pub_doc("x", meta = list(footer = c(left = "L", right = "")))
            res <- pages(render(doc, engine))
            expect_match(res$text[[1L]], "L", info = engine)
            expect_no_match(res$text[[1L]], "Page 1", info = engine)
        }
    })

    it("draws horizontal rules via both engines", {
        # pandoc >= 3.10.1 writes `#divider()`, which pubflow's Typst template defines
        for (engine in c("xelatex", "typst")) {
            res <- pages(render(pub_doc("Above\n\n***\n\nBelow"), engine))
            expect_match(res$text[[1L]], "Above\\s+Below", info = engine)
        }
    })

    it("refuses documents with error items", {
        bad <- pub_doc(pub_section("S", demo_failures()$fit))

        err <- expect_error(pub_render(bad, "pdf"), class = "pubflow_render_error")
        expect_identical(err$format, "pdf")
    })
})

describe("pub_render(format = \"pdf\") with a spec", {
    render <- function(doc, engine, spec) {
        skip_if_no_pdf_engine(engine)
        skip_if_not_installed("pdftools")
        file <- withr::local_tempfile(fileext = ".pdf", .local_envir = parent.frame())
        pub_render(
            doc,
            "pdf",
            file = file,
            pdf_engine = engine,
            spec = spec,
            meta = list(
                author = "A. User",
                app = "demo",
                version = "1.0",
                time = as.POSIXct("2026-10-07 12:00:00", tz = "UTC")
            )
        )
    }
    doc <- pub_doc(
        pub_section(
            "Results",
            "Text.",
            pub_table(data.frame(a = 1:2), caption = "Data"),
            pub_figure(recorded_plot(), caption = "Plot", width = 3, height = 2)
        ),
        pub_section("Wide", "w", landscape = TRUE),
        title = "Spec & co",
        meta = list(footer = c(left = "{trace}"))
    )
    stamp <- "A. User at 07-Oct-2026 12:00:00 UTC (demo v1.0)"
    spec <- pub_report_spec(
        "pdf",
        page = pub_page("letter"),
        number_sections = FALSE,
        labels = list(table = "Tab.", figure = "Abb."),
        front_matter = function(doc, format) {
            list(pub_text("Signed by A. User."), pub_pagebreak())
        }
    )
    check <- function(path, engine) {
        text <- pdftools::pdf_text(path)
        sizes <- pdftools::pdf_pagesize(path)
        expect_identical(sizes$width[[1L]], 612, info = engine)
        expect_identical(sizes$height[[1L]], 792, info = engine)
        expect_match(text[[1L]], "Signed by A. User.", fixed = TRUE)
        expect_false(any(grepl("2026-10-07 12:00:00 UTC", text, fixed = TRUE)))
        expect_true(all(grepl(stamp, text, fixed = TRUE)), info = engine)
        expect_true(any(grepl("Tab. 1: Data", text, fixed = TRUE)), info = engine)
        expect_true(any(grepl("Abb. 1: Plot", text, fixed = TRUE)), info = engine)
        expect_false(any(grepl("1\\s+Results", text)), info = engine)
        expect_identical(pdftools::pdf_info(path)$keys$Title, "Spec & co")
    }

    it("applies page, labels, front matter and the stamp via xelatex", {
        check(render(doc, "xelatex", spec), "xelatex")
    })

    it("applies page, labels, front matter and the stamp via Typst", {
        check(render(doc, "typst", spec), "typst")
    })

    it("lists the captioned figures and tables via both engines", {
        listed <- pub_doc(
            doc$children[[1L]],
            pub_table(data.frame(b = 1)),
            pub_figure(recorded_plot(), width = 3, height = 2)
        )
        lists <- pub_report_spec("pdf", front_matter = function(doc, format) {
            list(pub_toc(what = "figures"), pub_toc(what = "tables"), pub_pagebreak())
        })
        # entries of a list: the lines with dot leaders, without them and the page
        entries <- function(part) {
            lines <- strsplit(part, "\n", fixed = TRUE)[[1L]]
            trimws(sub(
                "\\s*(\\. ){2,}.*",
                "",
                grep("\\. \\. \\.", lines, value = TRUE)
            ))
        }
        for (engine in c("xelatex", "typst")) {
            first <- pdftools::pdf_text(render(listed, engine, lists))[[1L]]
            parts <- strsplit(first, "List of Tables", fixed = TRUE)[[1L]]
            expect_match(parts[[1L]], "List of Figures", fixed = TRUE)
            expect_match(entries(parts[[1L]]), "^(Figure )?1\\s+Plot$", info = engine)
            expect_match(entries(parts[[2L]]), "^(Table )?1\\s+Data$", info = engine)
        }
    })

    it("turns the whole document for a landscape page", {
        turned <- pub_report_spec("pdf", page = pub_page(orientation = "landscape"))
        for (engine in c("xelatex", "typst")) {
            path <- render(doc, engine, turned)
            expect_true(all(pdf_landscape(path)), info = engine)
            sizes <- pdftools::pdf_pagesize(path)
            expect_true(all(sizes$width > sizes$height), info = engine)
        }
    })
})

describe("pub_render(format = \"pdf\") via a stand-in for typst", {
    skip_on_os("windows")

    it("compiles pandoc's Typst file inside the work directory", {
        skip_if_no_pandoc()
        log <- withr::local_tempfile()
        script <- withr::local_tempfile()
        writeLines(
            c(
                "#!/bin/sh",
                sprintf("printf '%%s\\n' \"$@\" > '%s'", log),
                "cp \"$4\" \"$5\""
            ),
            script
        )
        Sys.chmod(script, "755")
        local_mocked_bindings(.find_typst = function(...) script)
        file <- withr::local_tempfile(fileext = ".pdf")
        doc <- pub_doc(pub_section("S", "Text $x$."), title = "T")

        pub_render(doc, "pdf", file = file, pdf_engine = "typst")

        args <- readLines(log)
        expect_identical(args[1:2], c("compile", "--root"))
        expect_identical(basename(args[4:5]), c("document.typ", "document.pdf"))
        expect_identical(dirname(args[4]), args[[3L]])
        typ <- readLines(file)
        expect_true(any(grepl("supplement: [Table]", typ, fixed = TRUE)))
        expect_true(any(grepl("Text", typ, fixed = TRUE)))
    })
})

describe(".run_typst()", {
    skip_on_os("windows")

    it("returns typst's output invisibly when it succeeds", {
        script <- withr::local_tempfile()
        writeLines(c("#!/bin/sh", "echo 'compiled'"), script)
        Sys.chmod(script, "755")
        local_mocked_bindings(.find_typst = function(...) script)

        expect_invisible(out <- .run_typst("a.typ", "a.pdf", tempdir(), call = NULL))
        expect_identical(as.character(out), "compiled")
    })

    it("signals typst's failure with its messages", {
        script <- withr::local_tempfile()
        writeLines(
            c("#!/bin/sh", "echo 'error: unknown variable' >&2", "exit 1"),
            script
        )
        Sys.chmod(script, "755")
        local_mocked_bindings(.find_typst = function(...) script)

        err <- expect_error(
            .run_typst("a.typ", "a.pdf", tempdir(), call = NULL),
            class = "pubflow_render_error"
        )
        expect_match(
            conditionMessage(err),
            "typst failed (exit status 1)",
            fixed = TRUE
        )
        expect_match(conditionMessage(err), "unknown variable", fixed = TRUE)
    })
})


# -----
# LaTeX
# -----

describe("pandoc's options for PDF", {
    work <- withr::local_tempdir()
    meta <- list(title = "T & co", author = "A", time = Sys.time())
    settings <- function(...) {
        .render_settings(pub_report_spec("pdf", ...), "latex")
    }

    it("set paper, geometry and numbering for LaTeX", {
        options <- .latex_options(
            meta,
            settings(
                page = pub_page("letter", "landscape"),
                number_sections = FALSE
            ),
            work,
            front = NULL
        )

        expect_false(options$`number-sections`)
        expect_identical(options$variables$papersize, "letter")
        expect_identical(
            options$variables$geometry,
            c(
                "top=2.5cm",
                "bottom=2cm",
                "left=2.5cm",
                "right=2.5cm",
                "headheight=14pt",
                "landscape"
            )
        )
        expect_identical(options$metadata$title, "T & co")
        expect_null(options$variables$`title-meta`)
    })

    it("move title and author into the PDF properties with front matter", {
        options <- .latex_options(meta, settings(), work, front = list())

        expect_null(options$metadata)
        expect_identical(options$variables$`title-meta`, "T \\& co")
        expect_identical(options$variables$`author-meta`, "A")
        multi <- list(title = "Line\n two", author = c("A", "B"))
        options <- .latex_options(multi, settings(), work, front = list())
        expect_identical(options$variables$`title-meta`, "Line two")
        expect_identical(options$variables$`author-meta`, c("A", "B"))
    })

    it("leave out missing title and author with front matter", {
        options <- .latex_options(list(), settings(), work, front = list())

        expect_null(options$variables$`title-meta`)
        expect_null(options$variables$`author-meta`)
        expect_null(.latex_meta_text(NULL))
    })

    it("include pubflow's header, the spec's and then the head and foot file", {
        header <- withr::local_tempfile(fileext = ".tex")
        writeLines("% spec", header)
        options <- .latex_options(
            meta,
            settings(latex_preamble = header),
            work,
            front = NULL
        )

        expect_identical(
            basename(options$`include-in-header`),
            c("pubflow-header.tex", basename(header), "pubflow-head-foot.tex")
        )
        expect_identical(options$`pdf-engine`, "xelatex")
        expect_false("landscape" %in% options$variables$geometry)
    })

    it("set paper, title block and the head file for Typst", {
        typst <- .render_settings(
            pub_report_spec(
                "pdf",
                page = pub_page("letter", "landscape"),
                labels = list(table = "Tab. #1")
            ),
            "typst"
        )

        options <- .typst_options(meta, typst, work, front = list())

        expect_identical(options$variables$papersize, "us-letter")
        expect_false(options$variables$`title-block`)
        expect_identical(options$metadata$title, "T & co")
        expect_identical(
            readLines(options$`include-in-header`),
            c(
                "// pubflow: page orientation and caption labels",
                "#set page(flipped: true)",
                paste0(
                    "#show figure.where(kind: table): set figure(supplement: ",
                    "[Tab\\. \\#1])"
                ),
                "#show figure.where(kind: image): set figure(supplement: [Figure])"
            )
        )
        default <- .typst_options(meta, default_settings("typst"), work, front = NULL)
        expect_true(default$variables$`title-block`)
        expect_identical(default$variables$papersize, "a4")
    })
})

describe("header and footer", {
    meta <- list(
        header = c(left = "A \"b\" & c", right = "R"),
        footer = c(center = "x\ny")
    )

    labels <- list(table = "Tab.", figure = "Abb. & co")

    it("writes fancyhdr lines for LaTeX, escaped, and the labels", {
        expect_identical(
            .latex_head_foot(meta, labels),
            c(
                "% header and footer of the document",
                "\\fancyhead[L]{A \\textquotedbl{}b\\textquotedbl{} \\& c}",
                "\\fancyhead[R]{R}",
                "\\fancyfoot[C]{x y}",
                "% caption labels",
                paste0(
                    "\\AtBeginDocument{\\renewcommand{\\tablename}{Tab.}",
                    "\\renewcommand{\\figurename}{Abb. \\& co}}"
                )
            )
        )
        expect_length(.latex_head_foot(list(), labels), 3L)
    })

    it("passes them as metadata to the Typst template", {
        expect_identical(
            .typst_head_foot(meta),
            list(
                `header-left` = "A \"b\" & c",
                `header-right` = "R",
                `footer-center` = "x y"
            )
        )
        expect_identical(.typst_head_foot(list()), list())
        expect_identical(
            .typst_head_foot(list(footer = c(right = ""))),
            list(`footer-right` = "", `footer-right-empty` = TRUE)
        )
    })

    it("expand {trace}", {
        traced <- list(
            author = "A",
            time = as.POSIXct("2026-10-07", tz = "UTC"),
            footer = c(left = "{trace}", right = "R")
        )
        line <- "A at 07-Oct-2026 00:00:00 UTC"

        expect_identical(
            .latex_head_foot(traced, labels)[[2L]],
            sprintf("\\fancyfoot[L]{%s}", line)
        )
        expect_identical(.typst_head_foot(traced)$`footer-left`, line)
        expect_error(
            .typst_head_foot(traced[-1L]),
            "Can't expand",
            class = "pubflow_render_error"
        )
    })
})

describe("pubflow-header.tex", {
    it("loads every LaTeX package that huxtable needs", {
        header <- readLines(.template_file("pubflow-header.tex"))
        deps <- huxtable::report_latex_dependencies(quiet = TRUE)

        lines <- vapply(
            deps,
            \(d) {
                options <- if (!is.null(d$options)) {
                    sprintf("[%s]", paste(d$options, collapse = ","))
                } else {
                    ""
                }
                sprintf("\\usepackage%s{%s}", options, d$name)
            },
            character(1)
        )
        expect_true(all(lines %in% header), info = toString(lines))
        expect_true(all(
            sprintf(
                "\\usepackage{%s}",
                c(
                    "pdflscape",
                    "fancyhdr",
                    "lastpage",
                    "xcolor",
                    "float",
                    "newunicodechar"
                )
            ) %in%
                header
        ))
    })
})


# ======================================================================================
# Page and math
# ======================================================================================

# ----------
# Text width
# ----------

describe(".pdf_text_area()", {
    page <- list(width = 20, height = 30, top = 1, bottom = 2, left = 3, right = 4)
    pt <- 72 / 2.54

    it("turns the portrait text area in LaTeX", {
        area <- .pdf_text_area(page, "latex")

        expect_equal(area$portrait, c(width = 13 * pt, height = 27 * pt))
        expect_equal(area$landscape, c(width = 27 * pt, height = 13 * pt))
        expect_equal(
            .latex_text_width(page),
            c(portrait = 13 * pt, landscape = 27 * pt)
        )
    })

    it("keeps the margins of the turned page in Typst", {
        area <- .pdf_text_area(page, "typst")

        expect_equal(area$portrait, c(width = 13 * pt, height = 27 * pt))
        expect_equal(area$landscape, c(width = 23 * pt, height = 17 * pt))
    })
})

# ----
# Math
# ----

describe(".check_latex_math()", {
    it("accepts math that pandoc's math parser reads", {
        skip_if_no_pandoc()
        md <- "$\\frac{a}{b} \\le \\hat\\beta$ and\n\n$$\n\\sqrt{x}\n$$\n"

        expect_identical(.check_latex_math(md), md)
        expect_identical(.check_latex_math("no math"), "no math")
        expect_identical(.check_latex_math("Costs $5."), "Costs $5.")
    })

    it("names only the bad formulas and shortens long ones", {
        skip_if_no_pandoc()
        long <- paste0("$\\input{", strrep("a", 80L), "}$")
        md <- paste("Good $x^2$, bad $\\input{x}$ and", long)

        err <- expect_error(.check_latex_math(md), class = "pubflow_render_error")
        msg <- conditionMessage(err)
        expect_match(msg, "\\input{x}", fixed = TRUE)
        expect_match(msg, paste0("\\input{", strrep("a", 49L), "..."), fixed = TRUE)
        expect_no_match(msg, strrep("a", 50L), fixed = TRUE)
        expect_no_match(msg, "x^2", fixed = TRUE)
        expect_identical(err$format, "latex")
    })

    it("refuses unknown commands, macro definitions and ^^", {
        skip_if_no_pandoc()
        bad <- c(
            "$\\input{x}$",
            "$\\tag{\\input{x}}$",
            "$\\csname x\\endcsname$",
            "$\\newcommand{\\a}{1}\\a$",
            "$\\def\\a{1}$",
            "$x^^41$"
        )

        for (md in bad) {
            expect_error(
                .check_latex_math(md),
                "Can't use this math",
                class = "pubflow_render_error",
                info = md
            )
        }
    })
})
