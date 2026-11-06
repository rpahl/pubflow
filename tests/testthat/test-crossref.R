# ======================================================================================
# Cross-references
# ======================================================================================

# -------
# Targets
# -------

describe(".ref_state()", {
    fig <- function(id, caption = "Fig") {
        .new_item("figure", pub_figure(recorded_plot(), caption = caption, id = id))
    }
    tab <- function(id, caption = "Tab") {
        .new_item("table", pub_set_meta(pub_table(data.frame(a = 1), caption), id = id))
    }

    it("collects tables and figures with an id from nested sections in order", {
        nodes <- list(
            tab("a"),
            pub_section("S", pub_section("T", fig("b", caption = NULL))),
            .new_item("text", pub_set_meta(pub_text("x"), id = "c"))
        )

        state <- .ref_state(nodes, list(table = "Table", figure = "Figure"))

        expect_named(state$targets, c("a", "b"))
        expect_identical(
            state$targets$b,
            list(type = "figure", captioned = FALSE, index = 2L)
        )
        expect_identical(state$problems, character())
    })

    it("reports duplicate ids and keeps them out of the targets", {
        nodes <- list(tab("a"), fig("a"), fig("b"))

        state <- .ref_state(nodes, list())

        expect_named(state$targets, "b")
        expect_identical(state$targets$b$index, 3L)
        expect_identical(state$duplicated, "a")
        expect_match(state$problems, "The id 'a' is used by 2 items")
    })

    it("gives anchors and labels only to captioned targets of the type", {
        state <- .ref_state(list(tab("a"), fig("b", caption = NULL)), list())
        ctx <- list(refs = state)

        expect_identical(.ref_anchor(state, list(id = "a"), "table")$index, 1L)
        expect_null(.ref_anchor(state, list(id = "a"), "figure"))
        expect_null(.ref_anchor(state, list(id = "b"), "figure"))
        expect_null(.ref_anchor(state, list(id = "x"), "table"))
        expect_null(.ref_anchor(NULL, list(id = "a"), "table"))
        expect_identical(.ref_label(ctx, list(id = "a"), "table"), "a")
        expect_null(.ref_label(ctx, list(), "table"))
    })

    it("records the numbers of targets only", {
        state <- .ref_state(list(tab("a")), list())

        .ref_number(state, list(id = "a"), "table", 3L)
        .ref_number(state, list(id = "x"), "table", 4L)
        .ref_number(state, list(), "table", 5L)

        expect_identical(state$numbers, c(a = 3L))
    })
})


# ------------------
# References in text
# ------------------

describe(".protect_refs()", {
    protect <- function(text, context = NULL) {
        store <- .token_store()
        text <- .protect_refs(text, store, \(match) sprintf("<%s>", match), context)
        .restore_tokens(text, store)
    }

    it("finds references, without trailing punctuation", {
        expect_identical(
            protect("See @fig:a, @tab:b-2. (@fig:c_d) **@fig:e-**\n"),
            "See <@fig:a>, <@tab:b-2>. (<@fig:c_d>) **<@fig:e>-**\n"
        )
        expect_identical(
            protect("- item @fig:a\n\n> é @tab:b"),
            "- item <@fig:a>\n\n> é <@tab:b>"
        )
    })

    it("ignores escaped references, addresses and other prefixes", {
        text <- "\\@fig:a user@fig:b é@fig:c a_@fig:d @sec:e @fig: @fig:1a"
        expect_identical(protect(text), text)
        expect_identical(protect("\\\\@fig:a"), "\\\\<@fig:a>")
    })

    it("leaves links, autolinks and image descriptions alone", {
        text <- "[see @fig:a](https://e.org/@fig:a) <https://e.org/@fig:b>"
        expect_identical(protect(text), text)
        expect_identical(protect("![a @fig:a](i.png)"), "![a @fig:a](i.png)")
        # the label of a shortcut link must stay as it is to find its definition
        text <- "[@fig:a] and [@fig:a][]\n\n[@fig:a]: https://e.org"
        expect_identical(protect(text), text)
    })

    it("finds links and images by the definitions in the context", {
        text <- "![a @fig:a][i] @fig:b"

        expect_identical(protect(text), "![a <@fig:a>][i] <@fig:b>")
        expect_identical(
            protect(text, context = "x\n\n[i]: i.png"),
            "![a @fig:a][i] <@fig:b>"
        )
    })

    it("leaves the text alone without a converter", {
        expect_identical(.protect_refs("@fig:a", .token_store(), NULL), "@fig:a")
    })
})

describe("references in texts", {
    state <- .ref_state(
        list(
            .new_item("figure", pub_figure(recorded_plot(), caption = "F", id = "f")),
            .new_item("table", pub_set_meta(pub_table(data.frame(a = 1)), id = "t"))
        ),
        list(table = "Table", figure = "Figure")
    )

    it("record a problem for each reference that doesn't resolve", {
        state$problems <- character()

        expect_identical(.ref_resolve("@fig:f", state), list(id = "f", type = "figure"))
        expect_null(.ref_resolve("@fig:x", state))
        expect_null(.ref_resolve("@tab:f", state))
        expect_null(.ref_resolve("@tab:t", state))

        expect_identical(
            state$problems,
            c(
                "`@fig:x`: no table or figure has the id 'x'.",
                "`@tab:f`: 'f' is a figure.",
                "`@tab:t`: the table 't' has no caption, so it has no number."
            )
        )
    })

    it("become engine references in LaTeX and Typst, markers elsewhere", {
        expect_identical(
            .ref_converter(state, "latex")("@fig:f"),
            "`\\hyperref[f]{\\figurename~\\ref*{f}}`{=latex}"
        )
        expect_identical(
            .ref_converter(state, "typst")("@fig:f"),
            "`#ref(<f>)`{=typst}"
        )
        for (target in c("html", "docx", "md")) {
            expect_identical(.ref_converter(state, target)("@fig:f"), .ref_marker("f"))
        }
    })

    it("stay marked text if they don't resolve", {
        expect_identical(
            .ref_converter(state, "html")("@fig:x"),
            "<span class=\"pubflow-ref-unresolved\">@fig:x</span>"
        )
        expect_identical(.ref_converter(state, "docx")("@fig:x"), "\\@fig:x")
    })

    it("are found with the link definitions of the whole text", {
        text <- "![a @fig:f][i]\n\n```\ncode\n```\n\n[i]: i.png"
        html <- .markdown_html(text, ref = \(m) "REF")$html
        md <- .markdown_pandoc(text, "docx", ref = \(m) "REF")

        expect_match(html, "alt=\"a @fig:f\"", fixed = TRUE)
        expect_match(md, "![a @fig:f][i]", fixed = TRUE)
    })

    it("are left alone in code, math and placeholders and without a converter", {
        convert <- function(m) "REF"
        html <- .markdown_html(
            "@fig:f `@fig:f` $@fig:f$ [@fig:f]{.placeholder}",
            ref = convert
        )$html
        md <- .markdown_pandoc("@fig:f `@fig:f` $@fig:f$", "docx", ref = convert)

        expect_match(html, "<p>REF <code>@fig:f</code> ", fixed = TRUE)
        expect_match(html, "\\(@fig:f\\)", fixed = TRUE)
        expect_match(html, "placeholder\">@fig:f</span>", fixed = TRUE)
        expect_identical(md, "REF `@fig:f` $@fig:f$")
        expect_identical(.markdown_pandoc("@fig:f", "docx"), "@fig:f")
    })
})


# -------
# Writers
# -------

describe(".insert_refs()", {
    state <- .ref_state(
        list(
            .new_item(
                "table",
                pub_set_meta(pub_table(data.frame(a = 1), "T"), id = "t")
            ),
            .new_item("figure", pub_figure(recorded_plot(), caption = "F", id = "f"))
        ),
        list(table = "Tab.", figure = "Fig.")
    )
    .ref_number(state, list(id = "t"), "table", 2L)
    .ref_number(state, list(id = "f"), "figure", 1L)
    text <- paste("See", .ref_marker("f"), "and", .ref_marker("t"), .ref_marker("f"))

    it("links the numbers to the items' element ids in HTML", {
        expect_identical(
            .insert_refs(text, state, "html", "p"),
            paste(
                "See <a class=\"pubflow-ref\" href=\"#p-figure-f\">Fig. 1</a> and",
                "<a class=\"pubflow-ref\" href=\"#p-table-t\">Tab. 2</a>",
                "<a class=\"pubflow-ref\" href=\"#p-figure-f\">Fig. 1</a>"
            )
        )
    })

    it("writes REF fields to the bookmarks in DOCX", {
        docx <- .insert_refs(text, state, "docx")

        expect_match(
            docx,
            paste0(
                "> REF _Ref_pubflow_1 \\h \\* MERGEFORMAT </w:instrText></w:r><w:r>",
                "<w:fldChar w:fldCharType=\"separate\"/></w:r>`{=openxml}Tab. 2`<w:r>",
                "<w:fldChar w:fldCharType=\"end\"/></w:r>`{=openxml}"
            ),
            fixed = TRUE
        )
        expect_length(gregexpr("REF _Ref_pubflow_2 ", docx, fixed = TRUE)[[1L]], 2L)
    })

    it("writes the numbers as text in md", {
        expect_identical(
            .insert_refs(text, state, "md"),
            "See Fig. 1 and Tab. 2 Fig. 1"
        )
    })
})

describe(".ref_bookmarked()", {
    it("puts a bookmark around the content of a target only", {
        expect_identical(.ref_bookmarked(NULL, "Table 1"), "Table 1")
        expect_identical(
            .ref_bookmarked(list(index = 3L), "Table 1"),
            paste0(
                "`<w:bookmarkStart w:id=\"90003\" ",
                "w:name=\"_Ref_pubflow_3\"/>`{=openxml}",
                "Table 1`<w:bookmarkEnd w:id=\"90003\"/>`{=openxml}"
            )
        )
    })
})

describe(".ref_signal()", {
    state <- new.env()
    state$problems <- c("`@fig:x`: one.", "`@fig:x`: one.", "two")

    it("is an error listing every problem once in reports", {
        err <- expect_error(
            .ref_signal(state, "error", "docx"),
            class = "pubflow_render_error"
        )

        expect_identical(err$format, "docx")
        expect_identical(err$problems, c("`@fig:x`: one.", "two"))
        expect_snapshot(cat(conditionMessage(err)))
    })

    it("is a warning otherwise", {
        cnd <- expect_warning(
            .ref_signal(state, "warn", "html"),
            "x `@fig:x`: one.\n.*two",
            class = "pubflow_render_warning"
        )
        expect_identical(cnd$problems, c("`@fig:x`: one.", "two"))
        state$problems <- character()
        expect_no_condition(.ref_signal(state, "error", "docx"))
    })
})


# ---------
# Scenarios
# ---------

describe("cross-references in documents", {
    doc <- pub_doc(
        pub_section(
            "A",
            pub_text("See @fig:trend and @tab:slopes."),
            pub_figure(recorded_plot(), caption = "Other", width = 2, height = 2),
            pub_set_meta(
                pub_table(data.frame(a = 1:2), caption = "Slopes"),
                id = "slopes"
            ),
            pub_figure(
                recorded_plot(),
                caption = "Trend",
                id = "trend",
                width = 2,
                height = 2
            )
        )
    )
    front <- function(doc, format) {
        list(pub_section("Front", pub_table(data.frame(f = 1), "F")))
    }
    bad <- pub_doc(
        pub_text("@fig:nope"),
        pub_figure(recorded_plot(), id = "x", width = 2, height = 2)
    )

    it("number forward references in HTML, counting the front matter", {
        spec <- pub_report_spec("html", front_matter = front, toc = FALSE)
        html <- as.character(.standalone_html(
            doc,
            .render_settings(spec, "html"),
            NULL,
            .front_nodes(.render_settings(spec, "html"), doc)
        ))

        expect_match(html, "href=\"#pubflow-figure-trend\">Figure 2</a>", fixed = TRUE)
        expect_match(html, "href=\"#pubflow-table-slopes\">Table 2</a>", fixed = TRUE)
        expect_match(
            html,
            "pubflow-figure\" id=\"pubflow-figure-trend\">",
            fixed = TRUE
        )
    })

    it("are found after CR and CRLF line endings", {
        doc <- pub_doc(
            pub_figure(recorded_plot(), caption = "Trend", id = "trend"),
            pub_text("intro\rSee @fig:trend.\r\nAgain @fig:trend.")
        )

        html <- as.character(pub_html(doc, math = "none"))

        expect_length(gregexpr(">Figure 1</a>", html, fixed = TRUE)[[1L]], 2L)
    })

    it("link to the item of the viewer's prefix, not to a text with the id", {
        doc <- pub_doc(
            pub_set_meta(pub_text("Trend"), id = "trend"),
            pub_figure(recorded_plot(), caption = "Trend", id = "trend"),
            pub_text("See @fig:trend.")
        )

        html <- as.character(.html_doc(
            .check_doc(doc),
            NULL,
            toc = FALSE,
            math = "none",
            figure = list(device = "png", res = 72),
            prefix = "v1-doc"
        ))

        expect_match(html, "pubflow-text\" id=\"v1-doc-text-trend\">", fixed = TRUE)
        expect_match(html, "id=\"v1-doc-figure-trend\">", fixed = TRUE)
        expect_match(html, "href=\"#v1-doc-figure-trend\">Figure 1</a>", fixed = TRUE)
    })

    it("are marked with a warning by pub_html(), an error in reports", {
        expect_warning(
            html <- as.character(pub_html(bad)),
            "no table or figure has the id 'nope'",
            class = "pubflow_render_warning"
        )
        expect_match(html, "<span class=\"pubflow-ref-unresolved\">@fig:nope</span>")
        expect_error(
            pub_render(bad, "html", file = withr::local_tempfile(fileext = ".html")),
            "no table or figure has the id 'nope'",
            class = "pubflow_render_error"
        )
        dir <- withr::local_tempdir()
        for (target in c("docx", "latex", "typst", "md")) {
            expect_error(
                pub_markdown(bad, target, file.path(dir, "files")),
                class = "pubflow_render_error"
            )
        }
    })

    it("number with the report spec's labels in Markdown", {
        spec <- pub_report_spec("md", labels = list(figure = "Fig."))

        md <- pub_markdown(doc, "md", withr::local_tempdir(), spec = spec)

        expect_match(md, "See Fig. 2 and Table 1.", fixed = TRUE)
    })

    it("point at a bookmark around the caption number in DOCX", {
        skip_if_no_pandoc()

        path <- pub_render(doc, "docx", file = withr::local_tempfile(fileext = ".docx"))
        xml <- docx_xml(path)
        ns <- xml2::xml_ns(xml)

        refs <- docx_ref_fields(xml)
        expect_identical(
            refs$instr,
            paste0(" REF _Ref_pubflow_", 2:1, " \\h \\* MERGEFORMAT ")
        )
        expect_identical(refs$result, c("Figure 2", "Table 1"))
        mark <- xml2::xml_find_all(
            xml,
            "//w:bookmarkStart[starts-with(@w:name, '_Ref')]",
            ns
        )
        expect_identical(
            xml2::xml_attr(mark, "w:name", ns),
            c("_Ref_pubflow_1", "_Ref_pubflow_2")
        )
        # the bookmark holds the label and the SEQ field
        caption <- xml2::xml_parent(mark[[2L]])
        expect_identical(xml2::xml_text(caption), "Figure 2: Trend")
        inside <- xml2::xml_find_all(
            caption,
            "w:bookmarkStart/following-sibling::*[following-sibling::w:bookmarkEnd]",
            ns
        )
        expect_identical(paste(xml2::xml_text(inside), collapse = ""), "Figure 2")
    })

    pdf_text <- function(path) {
        gsub("\\s+", " ", paste(pdftools::pdf_text(path), collapse = " "))
    }

    it("take the formatting of the text around them in DOCX", {
        skip_if_no_pandoc()
        doc <- pub_doc(
            pub_figure(recorded_plot(), caption = "Trend", id = "trend"),
            pub_text("**See @fig:trend.** Plain @fig:trend.")
        )

        path <- pub_render(doc, "docx", file = withr::local_tempfile(fileext = ".docx"))

        refs <- docx_ref_fields(docx_xml(path))
        expect_identical(refs$result, c("Figure 1", "Figure 1"))
        expect_identical(refs$bold, c(TRUE, FALSE))
    })

    it("are resolved by LaTeX", {
        skip_if_not_installed("pdftools")
        skip_if_no_pdf_engine("xelatex")

        path <- pub_render(doc, "pdf", file = withr::local_tempfile(fileext = ".pdf"))

        expect_match(pdf_text(path), "See Figure 2 and Table 1.", fixed = TRUE)
    })

    it("are resolved by Typst", {
        skip_if_not_installed("pdftools")
        skip_if_no_pdf_engine("typst")

        path <- pub_render(
            doc,
            "pdf",
            file = withr::local_tempfile(fileext = ".pdf"),
            pdf_engine = "typst"
        )

        expect_match(pdf_text(path), "See Figure 2 and Table 1.", fixed = TRUE)
    })
})
