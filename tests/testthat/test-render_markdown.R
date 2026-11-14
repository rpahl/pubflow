# ======================================================================================
# Markdown documents
# ======================================================================================

# ------
# Render
# ------

describe("pub_markdown()", {
    markdown <- function(
        doc,
        target,
        dir = withr::local_tempdir(
            .local_envir = parent.frame()
        ),
        ...
    ) {
        pub_markdown(doc, target, file.path(dir, "doc_files"), ...)
    }
    lines_of <- function(md) strsplit(md, "\n", fixed = TRUE)[[1L]]
    no_toc <- function(target) {
        pub_report_spec(.target_format(target), toc = FALSE)
    }

    it("writes Markdown for Word (snapshot)", {
        widget <- fallback_widget(local_fake_widget())
        doc <- markdown_node_doc(widget, demo_failures()$table)

        spec <- pub_report_spec("docx", lock = TRUE)
        expect_snapshot(cat(markdown(doc, "docx", spec = spec)))
    })

    it("writes a Markdown document (snapshot)", {
        widget <- fallback_widget(local_fake_widget())
        doc <- markdown_node_doc(widget, demo_failures()$table)

        expect_snapshot(cat(markdown(doc, "md")))
    })

    it("writes Markdown for LaTeX (snapshot)", {
        skip_if_no_pandoc() # the math check
        widget <- fallback_widget(local_fake_widget())
        doc <- markdown_node_doc(widget, demo_failures()$table)

        expect_snapshot(cat(markdown(doc, "latex")))
    })

    it("writes Markdown for Typst (snapshot)", {
        widget <- fallback_widget(local_fake_widget())
        doc <- markdown_node_doc(widget, demo_failures()$table)

        expect_snapshot(cat(markdown(doc, "typst")))
    })

    it("marks unnumbered headings for LaTeX and Typst", {
        doc <- pub_doc(
            pub_section(
                "A {x}",
                pub_section(
                    "B",
                    pub_section(
                        "C",
                        pub_section(
                            "D",
                            pub_section("E", pub_section("F", "deep"))
                        )
                    )
                ),
                numbered = FALSE
            ),
            pub_section("G", "text")
        )

        for (target in c("latex", "typst")) {
            headings <- grep("^#+ ", lines_of(markdown(doc, target)), value = TRUE)
            expect_identical(
                headings,
                c(
                    "# A \\{x\\} {.unnumbered}",
                    "## B {.unnumbered}",
                    "### C {.unnumbered}",
                    "#### D {.unnumbered}",
                    "##### E {.unnumbered}",
                    "##### F {.unnumbered}",
                    "# G"
                ),
                info = target
            )
        }
    })

    it("writes the breaks of LaTeX and Typst", {
        doc <- pub_doc(
            pub_section("A", "a", landscape = TRUE),
            pub_section("B", "b", pub_pagebreak(), "c"),
            pub_section("C", pub_set_meta(data.frame(x = 1), landscape = TRUE))
        )
        kinds <- function(md, marks) {
            # LaTeX tables have blank lines
            md <- gsub(
                "(?s)```\\{=latex\\}\n\\\\begingroup.*?```",
                "table",
                md,
                perl = TRUE
            )
            blocks <- strsplit(md, "\n\n", fixed = TRUE)[[1L]]
            res <- sub("^# ", "", blocks)
            for (mark in names(marks)) {
                res[grepl(marks[[mark]], blocks, fixed = TRUE)] <- mark
            }
            res[grepl("table", blocks, fixed = TRUE)] <- "table"
            res
        }

        latex <- kinds(
            markdown(doc, "latex", spec = no_toc("latex")),
            c(
                L = "\\begin{landscape}",
                P = "\\end{landscape}",
                `|` = "clearpage"
            )
        )
        typst <- kinds(
            markdown(doc, "typst", spec = no_toc("typst")),
            c(
                L = "flipped: true",
                P = "flipped: false",
                `|` = "#pagebreak"
            )
        )

        # a landscape start is marked before the first content, unlike Word
        expected <- c("L", "A", "a", "P", "B", "b", "|", "c", "|", "C", "L", "table")
        expect_identical(latex, c(expected, "P"))
        expect_identical(typst, expected)
        expect_match(markdown(doc, "docx", spec = no_toc("docx")), "^# A\n")
    })

    it("writes figures with captions as figures, others centred", {
        doc <- pub_doc(
            pub_figure(recorded_plot(), caption = "A *b*", width = 2, height = 2),
            pub_figure(recorded_plot(), width = 2, height = 2, out_width = "50%"),
            pub_figure(recorded_plot(), landscape = TRUE)
        )

        latex <- markdown(doc, "latex")
        typst <- markdown(doc, "typst")

        expect_match(
            latex,
            paste0(
                "![A \\*b\\*](<doc_files/figure-1.png>){width=5.67in}\n\n",
                "```{=latex}\n\\begingroup\\centering\n```\n\n",
                "![](<doc_files/figure-2.png>){width=3.15in}\n\n",
                "```{=latex}\n\\par\\endgroup\n```"
            ),
            fixed = TRUE
        )
        expect_match(typst, "```{=typst}\n#align(center)[\n```", fixed = TRUE)
        # a landscape figure keeps within 85% of the text height
        expect_match(latex, "figure-3.png>){width=7.14in}", fixed = TRUE)
        expect_match(typst, "figure-3.png>){width=7.36in}", fixed = TRUE)
    })

    it("writes vector figures if the spec asks for them", {
        doc <- pub_doc(pub_figure(recorded_plot(), width = 2, height = 2))
        vector <- function(device) {
            pub_report_spec("pdf", figure = list(device = device))
        }

        expect_match(
            markdown(doc, "latex", spec = vector("pdf")),
            "figure-1.pdf>",
            fixed = TRUE
        )
        skip_if_not_installed("svglite")
        expect_match(
            markdown(doc, "typst", spec = vector("svg")),
            "figure-1.svg>",
            fixed = TRUE
        )
    })

    it("writes placeholders, contents and errors for LaTeX and Typst", {
        doc <- pub_doc(
            pub_toc(depth = 6L),
            "[a <b>]{.placeholder}",
            demo_failures()$table
        )

        latex <- markdown(doc, "latex")
        typst <- markdown(doc, "typst")

        expect_match(
            latex,
            paste0(
                "`\\textcolor[HTML]{0083C0}{`{=latex}a \\<b\\>`}`{=latex}"
            ),
            fixed = TRUE
        )
        expect_match(
            typst,
            paste0(
                "`#text(fill: rgb(\"#0083c0\"))[`{=typst}a \\<b\\>`]`{=typst}"
            ),
            fixed = TRUE
        )
        expect_match(
            latex,
            "\\setcounter{tocdepth}{5}\n\\tableofcontents",
            fixed = TRUE
        )
        expect_match(typst, "#outline(depth: 6)", fixed = TRUE)
        expect_match(
            latex,
            paste0(
                "\\begin{pubflowerror}\n```\n\n**Step 'fit' failed**\\\n",
                "singular fit\\\nStep 'table' was not run.\n\n```{=latex}\n",
                "\\end{pubflowerror}"
            ),
            fixed = TRUE
        )
        expect_match(typst, "#block(stroke: 0.75pt + rgb(\"#c00000\")", fixed = TRUE)
    })

    it("writes lists of figures and tables for Word, LaTeX and Typst", {
        doc <- pub_doc(pub_toc(what = "figures"), pub_toc(what = "tables"), "a")
        md <- function(target) markdown(doc, target, spec = no_toc(target))

        expect_match(md("docx"), " TOC \\h \\z \\c \"Figure\" ", fixed = TRUE)
        expect_match(md("docx"), " TOC \\h \\z \\c \"Table\" ", fixed = TRUE)
        expect_match(md("docx"), "show the list of figures.", fixed = TRUE)
        expect_match(md("latex"), "\\listoffigures\n```", fixed = TRUE)
        expect_match(md("latex"), "\\listoftables\n```", fixed = TRUE)
        expect_match(
            md("typst"),
            "#outline(title: [List of Figures], target: figure.where(kind: image))",
            fixed = TRUE
        )
        expect_match(
            md("typst"),
            "#outline(title: [List of Tables], target: figure.where(kind: table))",
            fixed = TRUE
        )
        expect_identical(markdown(doc, "md"), "a\n")
    })

    it("refuses math that could run TeX commands", {
        skip_if_no_pandoc()
        bad <- pub_doc("Text $\\input{/etc/passwd}$ and $\\newcommand{\\a}{1}$")

        err <- expect_error(markdown(bad, "latex"), class = "pubflow_render_error")
        expect_match(conditionMessage(err), "$\\input{/etc/passwd}$", fixed = TRUE)
        expect_match(conditionMessage(err), "\\newcommand{\\a}{1}", fixed = TRUE)
        expect_match(markdown(bad, "typst"), "\\input{/etc/passwd}", fixed = TRUE)
    })

    it("writes the figures into the assets directory", {
        dir <- withr::local_tempdir()
        widget <- fallback_widget(local_fake_widget())

        md <- markdown(markdown_node_doc(widget), "md", dir)

        expect_identical(
            list.files(file.path(dir, "doc_files")),
            sprintf("figure-%d.png", 1:3)
        )
        expect_match(md, "![Widget](<doc_files/figure-1.png>)", fixed = TRUE)
        expect_match(md, "![Points](<doc_files/figure-2.png>)", fixed = TRUE)
    })

    it("refuses image files in the assets directory", {
        dir <- withr::local_tempdir()
        assets <- file.path(dir, "doc_files")
        dir.create(assets)
        files <- file.path(assets, c("figure-2.png", "figure-1.png"))
        for (file in files) {
            .render_figure(recorded_plot(), file, device = "png", res = 25)
        }
        before <- tools::md5sum(files)
        doc <- pub_doc(pub_figure(files[[1L]]), pub_figure(files[[2L]]))

        expect_error(
            markdown(doc, "md", dir),
            "must not hold the image files",
            class = "pubflow_render_error"
        )
        expect_identical(tools::md5sum(files), before)
    })

    it("numbers sections in the Markdown target, captions in both", {
        md <- markdown(markdown_node_doc(), "md")
        docx <- markdown(markdown_node_doc(), "docx")

        headings <- grep("^#", lines_of(md), value = TRUE)
        expect_identical(
            headings,
            c(
                "# 1 Text",
                "# 2 Tables",
                "# Figures",
                "## Nested",
                "# 3 Wide",
                "# 4 Results",
                "## 4.1 Check"
            )
        )
        expect_match(md, "\nTable 2: Wide\n", fixed = TRUE)
        expect_match(md, "\nFigure 1: Points\n", fixed = TRUE)
        seq <- "`<w:fldSimple w:instr=\" SEQ Table \\* ARABIC \"><w:r><w:t>2"
        expect_match(docx, seq, fixed = TRUE)
        unnumbered <- "::: {custom-style=\"Heading %d Unnumbered\"}\n%s"
        expect_match(docx, sprintf(unnumbered, 1L, "Figures"), fixed = TRUE)
        expect_match(docx, sprintf(unnumbered, 2L, "Nested"), fixed = TRUE)
    })

    it("writes page and section breaks only where needed", {
        brk <- "<w:br w:type=\"page\"/>"
        sect <- "<w:sectPr>"
        land <- "<w:sectPr><w:pgSz w:orient=\"landscape\"/></w:sectPr>"
        count <- function(md, x) {
            lengths(regmatches(md, gregexpr(x, md, fixed = TRUE)))
        }
        # level-1 sections start on a new page, unless a section break starts one; no
        # break before the first content; adjacent landscape parts share a section
        doc <- pub_doc(
            pub_section("A", "a"),
            pub_section("B", "b", landscape = TRUE),
            pub_section("C", "c", landscape = TRUE),
            pub_section("D", "d", page_break = FALSE),
            pub_section(
                "E",
                "e",
                pub_pagebreak(),
                "f",
                pub_set_meta(data.frame(x = 1), landscape = TRUE)
            )
        )

        md <- markdown(doc, "docx", spec = no_toc("docx"))

        blocks <- strsplit(md, "\n\n", fixed = TRUE)[[1L]]
        kinds <- sub("^# ", "", blocks)
        kinds[grepl(brk, blocks, fixed = TRUE)] <- "|"
        kinds[grepl(sect, blocks, fixed = TRUE)] <- "P"
        kinds[grepl(land, blocks, fixed = TRUE)] <- "L"
        kinds[grepl("<w:tbl>", blocks, fixed = TRUE)] <- "table"
        expect_identical(
            kinds,
            c(
                "A",
                "a",
                "P",
                "B",
                "b",
                "|",
                "C",
                "c",
                "L",
                "D",
                "d",
                "|",
                "E",
                "e",
                "|",
                "f",
                "P",
                "table",
                "L"
            )
        )
        expect_identical(count(markdown(doc, "md"), "openxml"), 0L)
    })

    it("writes error items as marked paragraphs", {
        doc <- pub_doc(pub_section("S", demo_failures()$table))

        expect_match(
            markdown(doc, "docx"),
            paste0(
                "::: {custom-style=\"Error\"}\n",
                "**Step 'fit' failed**\\\nsingular fit\\\n",
                "Step 'table' was not run.\n:::"
            ),
            fixed = TRUE
        )
        expect_match(
            markdown(doc, "md"),
            "> **Step 'fit' failed**\\\n> singular fit",
            fixed = TRUE
        )
    })

    it("names the pipeline of an error item of pub_out()", {
        item <- structure(
            list(
                step = "fit",
                failed_step = "fit",
                message = "no trend",
                pipeline = "Rain"
            ),
            class = "pub_error"
        )
        doc <- pub_doc(pub_section("S", item))

        expect_match(
            markdown(doc, "md"),
            "> **Step 'fit' of pipeline 'Rain' failed**\\\n> no trend",
            fixed = TRUE
        )
        expect_no_match(markdown(doc, "md"), "was not run", fixed = TRUE)
    })

    it("escapes text and the strings it writes", {
        doc <- pub_doc(
            pub_section(
                "# Title {.unnumbered} $x$",
                pub_text("`x`{=openxml} <b>", title = "- item"),
                pub_table(data.frame(a = "*b* <c> $d$"), caption = "1. *c*")
            ),
            title = "T"
        )

        docx <- markdown(doc, "docx")
        md <- markdown(doc, "md")

        expect_match(docx, "\n# \\# Title \\{.unnumbered\\} \\$x\\$\n", fixed = TRUE)
        expect_match(docx, "`x`\\{=openxml} &lt;b>", fixed = TRUE)
        expect_match(docx, "Item Title\"}\n\\- item\n", fixed = TRUE)
        expect_match(docx, "{=openxml}: 1\\. \\*c\\*\n", fixed = TRUE)
        expect_match(docx, ">*b* &lt;c&gt; $d$</w:t>", fixed = TRUE)
        expect_match(md, "\\*b\\* \\<c\\> \\$d\\$", fixed = TRUE)
        expect_match(md, "\nTable 1: 1\\. \\*c\\*\n", fixed = TRUE)
    })

    it("writes the document header as YAML front matter (Markdown)", {
        md <- markdown(markdown_node_doc(), "md")

        expect_match(
            md,
            paste0(
                "^---\ntitle: \"Every node\"\nsubtitle: \"Subtitle & \\\\\"more",
                "\\\\\"\"\nauthor: \"A. User\"\ndate: \"2026-10-05 12:00:00 UTC\"",
                "\n---\n\n"
            )
        )
        expect_false(grepl(
            "Every node",
            markdown(markdown_node_doc(), "docx"),
            fixed = TRUE
        ))
    })

    it("leaves out widgets without a fallback, with a warning", {
        widget <- local_fake_widget()
        doc <- pub_doc(pub_section("S", pub_set_meta(widget, title = "Map")))

        expect_warning(
            md <- markdown(doc, "md"),
            "Widget 'Map' has no `fallback` figure",
            class = "pubflow_render_warning"
        )
        expect_identical(md, "# 1 S\n")
        bad <- pub_set_meta(widget, fallback = "text")
        expect_error(
            markdown(pub_doc(bad), "md"),
            "A widget: the `fallback` must be a figure",
            class = "pubflow_render_error"
        )
    })

    it("gives the same Markdown for a restored document", {
        doc <- markdown_node_doc()
        file <- withr::local_tempfile(fileext = ".rds")
        without_package_env_warning(saveRDS(doc, file))

        expect_identical(markdown(readRDS(file), "md"), markdown(doc, "md"))
        expect_identical(markdown(readRDS(file), "docx"), markdown(doc, "docx"))
    })

    it("sizes Word tables and figures to the page", {
        doc <- pub_doc(
            pub_table(data.frame(a = 1), widths = c(a = 1)),
            pub_figure(recorded_plot(), out_width = "50%"),
            pub_set_meta(
                pub_table(data.frame(a = 1), widths = c(a = 1)),
                landscape = TRUE
            ),
            pub_figure(recorded_plot(), landscape = TRUE)
        )

        md <- markdown(doc, "docx")

        expect_identical(
            .docx_text_width(.template_file("reference.docx")),
            c(portrait = 9072L, landscape = 14004L)
        )
        expect_identical(
            regmatches(md, gregexpr("<w:tblW [^>]*>", md))[[1L]],
            c(
                "<w:tblW w:w=\"9072\" w:type=\"dxa\"/>",
                "<w:tblW w:w=\"14004\" w:type=\"dxa\"/>"
            )
        )
        expect_identical(
            regmatches(md, gregexpr("width=[0-9.]+in", md))[[1L]],
            c("width=3.15in", "width=8.75in")
        )
    })

    report <- function(...) {
        pub_doc(
            pub_section(
                "Results",
                "Text.",
                pub_table(data.frame(a = 1), caption = "Data")
            ),
            ...,
            title = "Report",
            meta = list(author = "A")
        )
    }
    front <- function(doc, format) {
        list(
            pub_text(sprintf("Front of %s", format)),
            pub_section(
                "Signatures",
                pub_table(data.frame(name = doc$meta$author), caption = "Signed"),
                page_break = FALSE
            ),
            pub_pagebreak()
        )
    }
    with_front <- function(target, ...) {
        pub_report_spec(.target_format(target), front_matter = front, ...)
    }
    blocks_of <- function(md) strsplit(md, "\n\n", fixed = TRUE)[[1L]]

    it("writes the front matter first, unnumbered, then the body", {
        md <- markdown(report(), "md", spec = with_front("md"))

        expect_match(
            md,
            paste0(
                "^Front of md\n\n# Signatures\n\nTable 1: Signed\n\n",
                "-+\n"
            )
        )
        expect_match(md, "\n# 1 Results\n\nText.\n\nTable 2: Data\n")
        expect_false(grepl("title:", md, fixed = TRUE))
        # front matter is not a title block: no break before it
        for (target in c("docx", "latex", "typst")) {
            blocks <- blocks_of(markdown(report(), target, spec = with_front(target)))
            expect_identical(
                blocks[[1L]],
                sprintf("Front of %s", .target_format(target)),
                info = target
            )
        }
        docx <- markdown(report(), "docx", spec = with_front("docx"))
        expect_match(
            docx,
            paste0("::: {custom-style=\"Heading 1 Unnumbered\"}", "\nSignatures\n:::"),
            fixed = TRUE
        )
        expect_match(
            markdown(report(), "latex", spec = with_front("latex")),
            "\n# Signatures {.unnumbered}\n",
            fixed = TRUE
        )
    })

    it("puts the table of contents after the front matter", {
        kinds <- function(md) {
            blocks <- blocks_of(md)
            res <- sub("^# ", "", blocks)
            res[grepl("TOC \\o \"1-2\"", blocks, fixed = TRUE)] <- "TOC"
            res[grepl("<w:br w:type=\"page\"/>", blocks, fixed = TRUE)] <- "|"
            res[grepl("custom-style", blocks, fixed = TRUE)] <- "styled"
            res[grepl("<w:tbl>", blocks, fixed = TRUE)] <- "table"
            res
        }

        docx <- markdown(report(), "docx", spec = with_front("docx", toc_depth = 2L))
        plain <- markdown(
            report(),
            "docx",
            spec = pub_report_spec("docx", toc_depth = 2L)
        )

        # front matter (ended by its page break), TOC, body on a new page
        expect_identical(
            kinds(docx),
            c(
                "Front of docx",
                "styled",
                "styled",
                "table",
                "|",
                "TOC",
                "|",
                "Results",
                "Text.",
                "styled",
                "table"
            )
        )
        # after the title block
        expect_identical(kinds(plain)[1:3], c("TOC", "|", "Results"))
        expect_match(
            markdown(report(), "latex"),
            "^```\\{=latex\\}\n\\\\setcounter\\{tocdepth\\}\\{3\\}"
        )
        expect_match(markdown(report(), "typst"), "^```\\{=typst\\}\n#outline")
    })

    it("adds no table of contents without sections or with a placed one", {
        count <- function(md) {
            lengths(regmatches(md, gregexpr(" TOC \\o", md, fixed = TRUE)))
        }

        expect_identical(count(markdown(pub_doc("text"), "docx")), 0L)
        expect_identical(count(markdown(report(pub_toc()), "docx")), 1L)
        placed <- pub_report_spec("docx", front_matter = \(doc, format) {
            pub_toc()
        })
        expect_identical(count(markdown(report(), "docx", spec = placed)), 1L)
        expect_identical(count(markdown(report(), "docx", spec = no_toc("docx"))), 0L)
        listed <- pub_report_spec("docx", front_matter = \(doc, format) {
            pub_toc(what = "figures")
        })
        expect_identical(count(markdown(report(), "docx", spec = listed)), 1L)
        expect_false(grepl("outline", markdown(report(), "md"), fixed = TRUE))
    })

    it("leaves sections unnumbered with number_sections = FALSE", {
        doc <- report(pub_section("More", pub_section("Sub", "x")))

        for (target in c("docx", "latex", "typst", "md")) {
            spec <- pub_report_spec(
                .target_format(target),
                number_sections = FALSE,
                toc = FALSE
            )
            headings <- grep(
                "^#+ |Heading",
                lines_of(markdown(doc, target, spec = spec)),
                value = TRUE
            )
            expected <- switch(
                target,
                docx = sprintf(
                    "::: {custom-style=\"Heading %d Unnumbered\"}",
                    c(1L, 1L, 2L)
                ),
                md = c("# Results", "# More", "## Sub"),
                c(
                    "# Results {.unnumbered}",
                    "# More {.unnumbered}",
                    "## Sub {.unnumbered}"
                )
            )
            expect_identical(headings, expected, info = target)
        }
    })

    it("uses the labels, lock and figure settings of the spec", {
        doc <- report(pub_figure(
            recorded_plot(),
            caption = "Plot",
            width = 2,
            height = 2
        ))
        labels <- list(table = "Tab.", figure = "Abb.")

        md <- markdown(doc, "md", spec = pub_report_spec("md", labels = labels))
        docx <- markdown(
            doc,
            "docx",
            spec = pub_report_spec(
                "docx",
                labels = labels,
                lock = FALSE,
                toc = FALSE
            )
        )
        dir <- withr::local_tempdir()
        markdown(
            doc,
            "md",
            dir,
            spec = pub_report_spec(
                "md",
                figure = list(device = "svg")
            )
        )

        expect_match(md, "\nTab. 1: Data\n", fixed = TRUE)
        expect_match(md, "\nAbb. 1: Plot", fixed = TRUE)
        expect_match(docx, "Tab. `<w:fldSimple w:instr=\" SEQ Table", fixed = TRUE)
        expect_match(docx, "Abb. `<w:fldSimple w:instr=\" SEQ Figure", fixed = TRUE)
        expect_false(grepl("<w:sdt>", docx, fixed = TRUE))
        expect_false(grepl("<w:sdt>", markdown(doc, "docx"), fixed = TRUE))
        locked <- markdown(doc, "docx", spec = pub_report_spec("docx", lock = TRUE))
        expect_match(
            locked,
            "<w:tag w:val=\"locked-table\"/><w:lock w:val=\"sdtContentLocked\"/>",
            fixed = TRUE
        )
        # the figure's control opens before its paragraph and closes after it
        expect_match(
            locked,
            paste0(
                "<w:tag w:val=\"locked-figure\"/>",
                "<w:lock w:val=\"sdtContentLocked\"/></w:sdtPr><w:sdtContent>\n```\n\n",
                "::: {custom-style=\"Figure\"}\n"
            ),
            fixed = TRUE
        )
        expect_match(
            locked,
            paste0(
                "}\n:::\n\n```{=openxml}\n</w:sdtContent></w:sdt>\n```\n\n",
                "::: {custom-style=\"Image Caption\"}"
            ),
            fixed = TRUE
        )
        expect_identical(list.files(file.path(dir, "doc_files")), "figure-1.svg")
    })

    it("locks no table or figure with `locked = FALSE`", {
        doc <- pub_doc(
            pub_set_meta(data.frame(a = 1), locked = FALSE),
            pub_figure(recorded_plot(), width = 2, height = 2, locked = FALSE)
        )

        expect_false(grepl("<w:sdt>", markdown(doc, "docx"), fixed = TRUE))
    })

    it("keeps a turned document on its pages", {
        doc <- pub_doc(
            pub_section("A", "a"),
            pub_section(
                "B",
                pub_table(data.frame(w = 1), widths = c(w = 1)),
                landscape = TRUE
            )
        )
        turned <- \(format) {
            pub_report_spec(
                format,
                page = pub_page(orientation = "landscape"),
                toc = FALSE
            )
        }

        latex <- markdown(doc, "latex", spec = turned("pdf"))
        typst <- markdown(doc, "typst", spec = turned("pdf"))
        docx <- markdown(doc, "docx", spec = turned("docx"))

        expect_false(grepl("landscape}", latex, fixed = TRUE))
        expect_false(grepl("flipped", typst, fixed = TRUE))
        expect_false(grepl("<w:sectPr>", docx, fixed = TRUE))
        # tables fill the width of the turned page (A4: 29.7 - 5 cm)
        expect_match(docx, "<w:tblW w:w=\"14004\" w:type=\"dxa\"/>", fixed = TRUE)
    })

    it("gives the same Markdown for the same document and spec", {
        doc <- markdown_node_doc()
        file <- withr::local_tempfile(fileext = ".rds")
        without_package_env_warning(saveRDS(doc, file))
        spec <- with_front("docx", labels = list(table = "T"))

        md <- markdown(doc, "docx", spec = spec)

        expect_identical(markdown(doc, "docx", spec = spec), md)
        expect_identical(markdown(readRDS(file), "docx", spec = spec), md)
    })

    it("writes raw content of the target only, fenced longer than its backticks", {
        doc <- pub_doc(
            "a",
            pub_raw(latex = "x ``` y", typst = "#line()", md = "---", html = "<hr>")
        )

        expect_identical(
            markdown(doc, "latex", spec = no_toc("latex")),
            "a\n\n````{=latex}\nx ``` y\n````\n"
        )
        expect_identical(
            markdown(doc, "typst", spec = no_toc("typst")),
            "a\n\n```{=typst}\n#line()\n```\n"
        )
        expect_identical(markdown(doc, "md"), "a\n\n---\n")
        expect_identical(markdown(doc, "docx", spec = no_toc("docx")), "a\n")
    })

    it("writes no block for empty content", {
        doc <- pub_doc("a", pub_raw(md = "", docx = "", latex = ""), "b")

        expect_identical(markdown(doc, "md"), "a\n\nb\n")
        expect_identical(markdown(doc, "docx", spec = no_toc("docx")), "a\n\nb\n")
        expect_identical(markdown(doc, "latex", spec = no_toc("latex")), "a\n\nb\n")
    })

    it("leaves out a table of contents item in the Markdown target", {
        expect_identical(markdown(pub_doc("a", pub_toc(), "b"), "md"), "a\n\nb\n")
    })

    it("breaks the page before the first section only after a title block", {
        sections <- list(pub_section("A", "a"), pub_section("B", "b"))
        time <- as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
        first <- function(doc) {
            md <- markdown(doc, "docx", spec = no_toc("docx"))
            strsplit(md, "\n\n", fixed = TRUE)[[1L]][[1L]]
        }

        titled <- do.call(pub_doc, c(sections, title = "T"))
        timed <- do.call(pub_doc, c(sections, list(meta = list(time = time))))

        expect_match(first(titled), "<w:br w:type=\"page\"/>", fixed = TRUE)
        expect_identical(first(timed), "# A")
        # a time alone makes no front matter either
        expect_match(markdown(timed, "md"), "^# 1 A\n")
    })

    it("caps heading levels at Word's 5 and Markdown's 6", {
        doc <- pub_doc(Reduce(
            \(child, title) pub_section(title, child),
            c("G", "F", "E", "D", "C", "B", "A"),
            "deep"
        ))

        docx <- grep("^#", lines_of(markdown(doc, "docx")), value = TRUE)
        md <- grep("^#", lines_of(markdown(doc, "md")), value = TRUE)

        expect_identical(
            docx,
            c("# A", "## B", "### C", "#### D", "##### E", "##### F", "##### G")
        )
        expect_identical(md[6:7], c("###### 1.1.1.1.1.1 F", "###### 1.1.1.1.1.1.1 G"))
    })

    it("writes no title line for a blank item title", {
        doc <- pub_doc(pub_text("x", title = "  "))

        expect_identical(markdown(doc, "md"), "x\n")
        expect_identical(markdown(doc, "docx"), "x\n")
    })

    it("drops blank lines of an error message", {
        item <- structure(
            list(step = "fit", failed_step = "fit", message = "a\n\n  \nb\n"),
            class = "pub_error"
        )

        expect_identical(
            markdown(pub_doc(item), "md"),
            "> **Step 'fit' failed**\\\n> a\\\n> b\n"
        )
    })

    it("writes Markdown tables with spanning cells without warnings", {
        ht <- pub_table(
            data.frame(a = 1, b = 2, c = 3),
            header = c(b = "Model", c = "Model"),
            footnotes = c(a = "Note.")
        )

        expect_no_warning(md <- markdown(pub_doc(ht), "md"))
        expect_match(md, "**Model**", fixed = TRUE)
        expect_match(md, "Note.", fixed = TRUE)
    })

    it("escapes angle brackets and backslashes in the paths of figures", {
        # `<`, `>` and `\` are not allowed in Windows file names (basename() splits at
        # backslashes there)
        skip_on_os("windows")
        dir <- withr::local_tempdir()
        doc <- pub_doc(pub_figure(recorded_plot(), width = 2, height = 2))

        md <- pub_markdown(doc, "md", file.path(dir, "a<b>"))

        expect_identical(md, "![Figure](<a\\<b\\>/figure-1.png>)\n")
        expect_true(file.exists(file.path(dir, "a<b>", "figure-1.png")))
        md <- pub_markdown(doc, "md", file.path(dir, "a\\_files"))
        expect_identical(md, "![Figure](<a\\\\_files/figure-1.png>)\n")
    })

    it("limits image files of PDFs only if their size is known", {
        file <- withr::local_tempfile(fileext = ".png")
        .render_figure(recorded_plot(), file, device = "png", res = 25)
        doc <- pub_doc(
            pub_figure(file, landscape = TRUE),
            pub_figure(file, width = 8, height = 6, landscape = TRUE),
            pub_figure(file, width = 8, landscape = TRUE)
        )

        md <- markdown(doc, "typst")

        widths <- regmatches(md, gregexpr("width=[0-9.]+in", md))[[1L]]
        # 90% of the landscape text width; the size limited like a plot (see above)
        expect_identical(widths, c("width=8.75in", "width=7.36in", "width=8.75in"))
    })

    it("signals a figure file it can't write", {
        dir <- withr::local_tempdir()
        assets <- file.path(dir, "doc_files")
        file.create(assets) # a file, not a directory
        doc <- pub_doc(pub_figure(recorded_plot(), width = 2, height = 2))

        expect_no_warning(
            err <- expect_error(
                pub_markdown(doc, "md", assets),
                "Can't write the figure file",
                class = "pubflow_render_error"
            )
        )
        expect_match(conditionMessage(err), "reason '", fixed = TRUE)
    })

    it("validates its arguments", {
        doc <- pub_doc()

        expect_error(
            pub_markdown(doc, "latex", "x", spec = pub_report_spec("docx")),
            "`spec` is for \"docx\" output, not \"pdf\""
        )
        expect_error(
            pub_markdown(doc, "md", "x", spec = list()),
            "made by `pub_report_spec()`",
            fixed = TRUE
        )
        expect_error(
            pub_markdown(list(), "md", "x"),
            "made by `pub_doc()`",
            fixed = TRUE
        )
        expect_error(pub_markdown(doc, "pdf", "x"), "`target` must be one of")
        for (dir in list(1, "", NA_character_, c("a", "b"))) {
            expect_error(pub_markdown(doc, "md", dir), "`assets_dir` must be")
        }
        expect_error(pub_markdown(doc, "md", "x", cache = 1), "pub_cache")
    })
})


# ------------
# Front matter
# ------------

describe(".yaml_string()", {
    it("escapes backslashes, quotes and control characters", {
        expect_identical(
            .yaml_string(c("a\\b \"c\"", "1\n2\r3\t4", "")),
            c("\"a\\\\b \\\"c\\\"\"", "\"1\\n2\\r3\\t4\"", "\"\"")
        )
    })
})


# ======================================================================================
# Pandoc runs
# ======================================================================================

# --------------
# Markdown files
# --------------

describe(".render_md()", {
    it("writes the Markdown as UTF-8 with its figures next to it", {
        work <- withr::local_tempdir()
        text <- paste("Gr", intToUtf8(252L), "\u00df", sep = "")
        doc <- pub_doc(text, pub_figure(recorded_plot(), width = 2, height = 2))
        settings <- .render_settings(pub_report_spec("md"), "md")

        file <- .render_md(doc, settings, NULL, work, "report", front = NULL)

        expect_identical(file, file.path(work, "report.md"))
        lines <- readLines(file, encoding = "UTF-8")
        expect_identical(lines[[1L]], text)
        expect_identical(lines[[3L]], "![Figure](<report_files/figure-1.png>)")
        expect_true(file.exists(file.path(work, "report_files", "figure-1.png")))
    })
})


# ------
# pandoc
# ------

describe(".pandoc_metadata()", {
    time <- as.POSIXct("2026-10-05 13:00:00", tz = "Europe/Berlin")

    it("gives the header fields only with a title block", {
        expect_identical(.pandoc_metadata(list()), list())
        expect_identical(.pandoc_metadata(list(time = time, app = "x")), list())
        expect_identical(
            .pandoc_metadata(list(author = "A", time = time, app = "x")),
            list(author = "A", date = "2026-10-05 11:00:00 UTC")
        )
        expect_identical(
            .pandoc_metadata(list(subtitle = "S", title = "T")),
            list(title = "T", subtitle = "S")
        )
    })
})

describe(".run_pandoc()", {
    skip_on_os("windows")
    fake_pandoc <- function(lines, status) {
        script <- withr::local_tempfile(.local_envir = parent.frame())
        writeLines(
            c("#!/bin/sh", sprintf("echo '%s' >&2", lines), sprintf("exit %d", status)),
            script
        )
        Sys.chmod(script, "755")
        script
    }

    it("signals pandoc's failure with its messages", {
        pandoc <- fake_pandoc("Could not find reference.docx", 1L)
        local_mocked_bindings(.find_pandoc = function(...) pandoc)
        work <- withr::local_tempdir()

        err <- expect_error(
            .run_pandoc(
                list(to = "docx"),
                work,
                format = "docx",
                quiet = TRUE,
                call = NULL
            ),
            class = "pubflow_render_error"
        )
        expect_match(
            conditionMessage(err),
            "pandoc failed (exit status 1)",
            fixed = TRUE
        )
        expect_match(
            conditionMessage(err),
            "Could not find reference.docx",
            fixed = TRUE
        )
    })

    it("passes pandoc's warnings on unless quiet", {
        pandoc <- fake_pandoc("[WARNING] Missing font", 0L)
        local_mocked_bindings(.find_pandoc = function(...) pandoc)
        work <- withr::local_tempdir()

        expect_silent(.run_pandoc(
            list(to = "docx"),
            work,
            format = "docx",
            quiet = TRUE,
            call = NULL
        ))
        expect_warning(
            .run_pandoc(
                list(to = "docx"),
                work,
                format = "docx",
                quiet = FALSE,
                call = NULL
            ),
            "Missing font",
            class = "pubflow_render_warning"
        )
    })

    it("passes the defaults file and then the further arguments", {
        script <- withr::local_tempfile()
        writeLines(c("#!/bin/sh", "printf '%s\\n' \"$@\""), script)
        Sys.chmod(script, "755")
        local_mocked_bindings(.find_pandoc = function(...) script)
        work <- withr::local_tempdir()

        out <- .run_pandoc(
            list(to = "docx", reference = NULL),
            work,
            format = "docx",
            quiet = TRUE,
            call = NULL,
            args = c("--toc", "a b")
        )

        defaults <- file.path(work, "pandoc-defaults.yaml")
        expect_identical(out, c("--defaults", defaults, "--toc", "a b"))
        expect_identical(readLines(defaults), "to: \"docx\"")
    })

    it("writes its options into a defaults file", {
        lines <- .yaml_lines(list(
            to = "docx",
            `input-files` = "a b.md",
            `resource-path` = "C:\\x",
            metadata = list(title = "A \"quoted\" title")
        ))

        expect_identical(
            lines,
            c(
                "to: \"docx\"",
                "input-files:",
                "- \"a b.md\"",
                "resource-path:",
                "- \"C:\\\\x\"",
                "metadata:",
                "  title: \"A \\\"quoted\\\" title\""
            )
        )
        expect_identical(
            .yaml_lines(list(
                `number-sections` = TRUE,
                `include-in-header` = "h.tex",
                variables = list(`block-headings` = FALSE)
            )),
            c(
                "number-sections: true",
                "include-in-header:",
                "- \"h.tex\"",
                "variables:",
                "  block-headings: false"
            )
        )
    })
})
