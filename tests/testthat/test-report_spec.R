# ======================================================================================
# Report specs
# ======================================================================================

# ---------------
# Specs and pages
# ---------------

describe("pub_report_spec()", {
    file <- withr::local_tempfile(fileext = ".docx")
    writeLines("x", file)

    it("makes a spec of a format with NULL as the format default", {
        spec <- pub_report_spec("docx")

        expect_s3_class(spec, "pub_report_spec")
        expect_identical(spec$format, "docx")
        expect_null(spec$page)
        expect_null(spec$lock)
        expect_null(spec$placeholder_color)
        expect_true(spec$toc)
        expect_identical(spec$toc_depth, 3L)
        expect_identical(spec$error_items, "refuse")
        expect_identical(pub_report_spec()$format, "html")
    })

    it("takes NULL and empty lists as the defaults", {
        spec <- pub_report_spec(
            "pdf",
            toc = NULL,
            toc_depth = NULL,
            number_sections = NULL,
            figure = list(),
            labels = NULL,
            post_process = NULL,
            pandoc_args = NULL
        )
        expect_identical(spec, pub_report_spec("pdf"))
    })

    it("merges labels over the defaults and keeps paths absolute", {
        withr::local_dir(dirname(file))
        spec <- pub_report_spec(
            "docx",
            reference_docx = basename(file),
            labels = list(table = "Tab.")
        )

        expect_identical(spec$labels, list(table = "Tab.", figure = "Figure"))
        expect_identical(spec$reference_docx, normalizePath(file))
    })

    it("wraps a single post-processor in a list", {
        pp <- function(path, doc, spec) NULL

        expect_identical(
            pub_report_spec("md", post_process = pp)$post_process,
            list(pp)
        )
    })

    it("refuses fields that the format can't use", {
        cases <- list(
            list("pdf", reference_docx = file),
            list("docx", latex_preamble = file),
            list("html", typst_template = file),
            list("html", page = pub_page()),
            list("md", page = pub_page()),
            list("docx", placeholder_color = "#000000"),
            list("md", placeholder_color = "#000000"),
            list("pdf", lock = TRUE),
            list("html", lock = FALSE),
            list("md", pandoc_args = "--toc")
        )
        for (args in cases) {
            expect_error(
                do.call(pub_report_spec, args),
                "can't be used for",
                info = toString(names(args))
            )
        }
        expect_error(
            pub_report_spec("pdf", reference_docx = file),
            paste("`reference_docx` can't be used for pdf reports,", "only for docx")
        )
        for (pp in list(pub_pp_docx_lock(), pub_pp_docx_header_footer())) {
            expect_error(
                pub_report_spec("pdf", post_process = pp),
                "`pub_pp_docx_lock()` can't be used for pdf reports",
                fixed = TRUE
            )
        }
        expect_silent(pub_report_spec("docx", post_process = pub_pp_docx_lock()))
        expect_error(
            pub_report_spec("docx", lock = FALSE, post_process = pub_pp_docx_lock()),
            "`lock = FALSE` locks nothing",
            fixed = TRUE
        )
    })

    it("checks the figure devices of its format", {
        expect_error(
            pub_report_spec("docx", figure = list(device = "svg")),
            "`figure$device` of docx reports must be \"png\"",
            fixed = TRUE
        )
        expect_error(
            pub_report_spec("html", figure = list(device = "pdf")),
            "must be \"png\" or \"svg\""
        )
        expect_error(pub_report_spec("md", figure = list(res = 0)), "positive number")
        expect_error(pub_report_spec("md", figure = list(res = Inf)), "positive number")
        expect_error(
            pub_report_spec("md", figure = list(dpi = 300)),
            "`figure` must be a list"
        )
    })

    it("validates its arguments", {
        expect_error(pub_report_spec("rtf"), "`format` must be one of")
        expect_error(
            pub_report_spec("docx", reference_docx = "none.docx"),
            "path of an existing file"
        )
        expect_error(
            pub_report_spec("docx", reference_docx = tempdir()),
            "path of an existing file"
        )
        expect_error(
            pub_report_spec("md", front_matter = "title"),
            "`front_matter` must be a function"
        )
        expect_error(pub_report_spec("md", toc = NA), "`toc` must be")
        expect_error(
            pub_report_spec("md", number_sections = 1),
            "`number_sections` must be"
        )
        expect_error(pub_report_spec("md", toc_depth = 7), "between 1 and 6")
        expect_error(pub_report_spec("md", toc_depth = 1.5), "between 1 and 6")
        expect_error(pub_report_spec("docx", page = "a4"), "`pub_page()`", fixed = TRUE)
        expect_error(
            pub_report_spec("md", labels = list(tab = "T")),
            "`labels` must be"
        )
        expect_error(
            pub_report_spec("md", labels = list(table = "")),
            "`labels` must be"
        )
        expect_error(
            pub_report_spec("pdf", placeholder_color = "blue"),
            "must be a colour"
        )
        expect_error(pub_report_spec("docx", lock = NA), "`lock` must be")
        expect_error(
            pub_report_spec("md", error_items = "ignore"),
            "`error_items` must be one of"
        )
        expect_error(
            pub_report_spec("md", post_process = list("x")),
            "list of functions"
        )
        expect_error(
            pub_report_spec("pdf", pandoc_args = NA_character_),
            "character vector"
        )
    })

    it("handles the corner cases of its arguments", {
        expect_identical(pub_report_spec("md", toc_depth = 2)$toc_depth, 2L)
        expect_identical(
            pub_report_spec("md", labels = list())$labels,
            list(table = "Table", figure = "Figure")
        )
        # empty pandoc_args and post_process count as not set
        expect_silent(pub_report_spec("md", pandoc_args = character()))
        expect_identical(
            pub_report_spec("md", post_process = list())$post_process,
            list()
        )
        expect_null(pub_report_spec("pdf", lock = NULL)$lock)
        expect_identical(
            pub_report_spec("md", figure = list(res = 96L))$figure,
            list(res = 96L)
        )
        for (depth in list(0, NA, NA_integer_, "3", c(1, 2))) {
            expect_error(
                pub_report_spec("md", toc_depth = depth),
                "between 1 and 6",
                info = toString(depth)
            )
        }
        for (labels in list(
            list("T"),
            list(table = NA_character_),
            c(table = "T")
        )) {
            expect_error(
                pub_report_spec("md", labels = labels),
                "`labels` must be",
                info = toString(labels)
            )
        }
        for (path in list(c(file, file), NA_character_, 1)) {
            expect_error(
                pub_report_spec("docx", reference_docx = path),
                "`reference_docx` must be the path",
                info = toString(path)
            )
        }
        for (color in list("#abc", "0083c0", c("#000000", "#111111"), NA_character_)) {
            expect_error(
                pub_report_spec("html", placeholder_color = color),
                "must be a colour",
                info = toString(color)
            )
        }
        for (figure in list(list("png"), "png")) {
            expect_error(
                pub_report_spec("md", figure = figure),
                "`figure` must be a list",
                info = toString(figure)
            )
        }
        for (res in list(NA, -1, c(100, 200), "300")) {
            expect_error(
                pub_report_spec("md", figure = list(res = res)),
                "`figure$res` must be a positive number",
                fixed = TRUE,
                info = toString(res)
            )
        }
        expect_error(
            pub_report_spec("md", figure = list(device = c("png", "svg"))),
            "`figure$device`",
            fixed = TRUE
        )
        expect_error(pub_report_spec("md", post_process = "f"), "list of functions")
        expect_error(pub_report_spec("pdf", pandoc_args = 1), "character vector")
        expect_error(pub_report_spec(c("pdf", "md")), "`format` must be")
    })

    it("prints the fields of its format", {
        expect_snapshot({
            pub_report_spec("docx")
            pub_report_spec(
                "pdf",
                page = pub_page("letter"),
                toc = FALSE,
                figure = list(device = "png", res = 300),
                labels = list(table = "Tab."),
                placeholder_color = "#123456",
                pandoc_args = c("--dpi", "300")
            )
            pub_report_spec(
                "md",
                front_matter = function(doc, format) NULL,
                error_items = "show",
                post_process = function(path, doc, spec) NULL
            )
        })
    })
})

describe("pub_page()", {
    it("fills in the default margins", {
        page <- pub_page(margins = c(left = 3, top = 1))

        expect_s3_class(page, "pub_page")
        expect_identical(page$size, "a4")
        expect_identical(page$orientation, "portrait")
        expect_identical(page$margins, c(top = 1, bottom = 2, left = 3, right = 2.5))
    })

    it("validates its arguments", {
        expect_error(pub_page("a5"), "`size` must be one of")
        expect_error(pub_page(orientation = "flipped"), "`orientation`")
        for (margins in list(
            c(1, 2),
            c(inner = 1),
            c(top = -1),
            c(top = NA),
            c(top = 1, top = 2),
            "1"
        )) {
            expect_error(
                pub_page(margins = margins),
                "`margins` must be",
                info = toString(margins)
            )
        }
    })

    it("refuses margins that leave no text area", {
        expect_error(
            pub_page(margins = c(left = 10, right = 11)),
            "no text area on the page (A4 portrait, 21 x 29.7 cm)",
            fixed = TRUE
        )
        expect_error(
            pub_page("letter", margins = c(top = 14, bottom = 14)),
            "(Letter portrait, 21.59 x 27.94 cm)",
            fixed = TRUE
        )
        # landscape: 21 cm high
        expect_error(
            pub_page(orientation = "landscape", margins = c(top = 11, bottom = 10)),
            "(A4 landscape, 29.7 x 21 cm)",
            fixed = TRUE
        )
        expect_s3_class(pub_page(margins = c(top = 13, bottom = 13)), "pub_page")
    })

    it("handles the corner cases of the margins", {
        zero <- c(top = 0, bottom = 0, left = 0, right = 0)
        expect_identical(pub_page(margins = zero)$margins, zero)
        expect_identical(pub_page(margins = c(top = 1L))$margins[["top"]], 1)
        # a text area must remain: margins as wide as the page are refused
        expect_error(
            pub_page(margins = c(left = 10.5, right = 10.5)),
            "no text area"
        )
        expect_s3_class(pub_page(margins = c(left = 10.5, right = 10.4)), "pub_page")
        for (margins in list(numeric(), c(top = Inf), c(top = 1, 2), list(top = 1))) {
            expect_error(
                pub_page(margins = margins),
                "`margins` must be",
                info = toString(margins)
            )
        }
    })

    it("prints its size and margins", {
        expect_snapshot(pub_page("letter", "landscape", c(bottom = 1.5)))
    })
})


# --------
# Printing
# --------

describe(".spec_lines()", {
    it("lists only the fields that the format uses", {
        pdf <- .spec_lines(pub_report_spec("pdf"))
        html <- .spec_lines(pub_report_spec("html", toc_depth = 2))
        md <- .spec_lines(pub_report_spec("md"))
        docx <- .spec_lines(pub_report_spec("docx", lock = FALSE))

        expect_identical(pdf[["page"]], "A4")
        expect_identical(pdf[["latex_preamble"]], "none")
        expect_identical(pdf[["placeholder_color"]], "default")
        expect_identical(html[["toc"]], "depth 2")
        expect_identical(md[["toc"]], "no")
        expect_identical(docx[["lock"]], "FALSE")
        for (field in c("page", "lock", "pandoc_args", "reference_docx")) {
            expect_false(field %in% names(html), info = field)
        }
        expect_false("placeholder_color" %in% names(docx))
    })
})


# ------
# Checks
# ------

describe(".check_report_spec()", {
    it("accepts only a spec of the output format", {
        spec <- pub_report_spec("docx")

        expect_identical(.check_report_spec(spec, "docx"), spec)
        expect_error(
            .check_report_spec(list(format = "docx"), "docx"),
            "`spec` must be made by `pub_report_spec()`",
            fixed = TRUE
        )
        expect_error(
            .check_report_spec(spec, "pdf"),
            "`spec` is for \"docx\" output, not \"pdf\"",
            fixed = TRUE
        )
    })

    it("checks fields edited after pub_report_spec() again", {
        spec <- pub_report_spec("docx")
        spec$toc_depth <- 9L
        expect_error(.check_report_spec(spec, "docx"), "`toc_depth` must be")

        spec <- pub_report_spec("docx")
        spec$placeholder_color <- "#ff0000"
        expect_error(
            .check_report_spec(spec, "docx"),
            "`placeholder_color` can't be used for docx reports"
        )

        spec <- pub_report_spec("docx")
        spec$reference_docx <- "no-such-file.docx"
        expect_error(.check_report_spec(spec, "docx"), "`reference_docx` must be")

        spec <- pub_report_spec("docx")
        spec$error_items <- "hide"
        expect_error(.check_report_spec(spec, "docx"), "`error_items` must be")

        spec <- pub_report_spec("docx")
        spec$toc_dpeth <- 2L
        expect_error(
            .check_report_spec(spec, "docx"),
            "`spec` has unknown fields: toc_dpeth."
        )
    })

    it("normalises edited fields as pub_report_spec() does", {
        spec <- pub_report_spec("docx")
        spec$labels <- list(table = "Tab")
        spec$post_process <- identity
        spec$toc_depth <- 2
        spec$toc <- NULL # not matched partially by toc_depth
        res <- .check_report_spec(spec, "docx")
        expect_true(res$toc)
        expect_equal(res$labels, list(table = "Tab", figure = "Figure"))
        expect_identical(res$post_process, list(identity))
        expect_identical(res$toc_depth, 2L)
        expect_identical(
            .check_report_spec(pub_report_spec("md"), "md"),
            pub_report_spec("md")
        )
    })
})


# ======================================================================================
# Settings of a target
# ======================================================================================

# -------
# Targets
# -------

describe(".target_format() and .format_target()", {
    it("map targets and formats onto each other", {
        for (format in c("html", "docx", "md")) {
            expect_identical(.format_target(format), format)
            expect_identical(.target_format(format), format)
        }
        expect_identical(.format_target("pdf"), "latex")
        expect_identical(.format_target("pdf", "typst"), "typst")
        expect_identical(.format_target("html", "typst"), "html")
        expect_identical(.target_format("latex"), "pdf")
        expect_identical(.target_format("typst"), "pdf")
    })
})


# --------
# Settings
# --------

describe(".render_settings()", {
    it("keeps the earlier default settings (regression)", {
        defaultPage <- list(
            paper = "a4",
            width = 21,
            height = 29.7,
            top = 2.5,
            bottom = 2,
            left = 2.5,
            right = 2.5
        )
        for (target in c("docx", "latex", "typst", "md")) {
            s <- default_settings(target)
            expect_identical(s$target, target)
            # one default for all formats and the viewer, so that they share the cached
            # figures
            expect_identical(s$figure, list(device = "png", res = 200), info = target)
            expect_identical(s$labels, list(table = "Table", figure = "Figure"))
            expect_true(s$toc)
            expect_true(s$number_sections)
            expect_length(s$pandoc_args, 0L)
            expect_identical(s$lock, if (target != "docx") FALSE)
        }
        docx <- default_settings("docx")
        expect_identical(docx$reference_docx, .template_file("reference.docx"))
        expect_null(docx$page)
        for (target in c("latex", "typst")) {
            s <- default_settings(target)
            expect_identical(s$page[names(defaultPage)], defaultPage, info = target)
            expect_false(s$page$turn)
            expect_identical(s$placeholder_color, "0083C0")
        }
        expect_identical(
            default_settings("latex")$latex_preamble,
            .template_file("pubflow-header.tex")
        )
        expect_identical(
            default_settings("typst")$typst_template,
            .template_file("pubflow.typ")
        )
    })

    it("resolves templates, pages and colours of a target", {
        header <- withr::local_tempfile(fileext = ".tex")
        writeLines("% mine", header)
        spec <- pub_report_spec(
            "pdf",
            latex_preamble = header,
            page = pub_page("letter", "landscape"),
            placeholder_color = "#AbCdEf"
        )

        latex <- .render_settings(spec, "latex")

        expect_identical(
            latex$latex_preamble,
            c(.template_file("pubflow-header.tex"), normalizePath(header))
        )
        expect_identical(
            latex$page[c("paper", "width", "height", "turn")],
            list(paper = "letter", width = 27.94, height = 21.59, turn = TRUE)
        )
        expect_identical(latex$placeholder_color, "AbCdEf")
        expect_null(.render_settings(spec, "typst")$latex_preamble)
        expect_null(.render_settings(pub_report_spec("html"), "html")$page)
        expect_null(.render_settings(pub_report_spec("html"), "html")$placeholder_color)
        html <- pub_report_spec("html", placeholder_color = "#00ff00")
        expect_identical(.render_settings(html, "html")$placeholder_color, "00ff00")
        docx <- pub_report_spec("docx", page = pub_page(), lock = FALSE)
        expect_identical(.render_settings(docx, "docx")$page$width, 21)
        expect_false(.render_settings(docx, "docx")$lock)
    })

    it("merges figure settings and checks the device of the target", {
        html <- pub_report_spec("html", figure = list(res = 300))
        pdf <- pub_report_spec("pdf", figure = list(device = "pdf"))
        svg <- pub_report_spec("pdf", figure = list(device = "svg"))

        expect_identical(
            .render_settings(html, "html")$figure,
            list(device = "png", res = 300)
        )
        expect_identical(
            .render_settings(pdf, "latex")$figure,
            list(device = "pdf", res = 200)
        )
        err <- expect_error(
            .render_settings(pdf, "typst"),
            "PDF via typst output can't use the device \"pdf\"",
            class = "pubflow_render_error"
        )
        expect_identical(err$format, "pdf")
        expect_error(.render_settings(svg, "latex"), class = "pubflow_render_error")
    })
})


# ======================================================================================
# Front matter and table of contents
# ======================================================================================

# ------------
# Front matter
# ------------

describe(".front_nodes()", {
    doc <- pub_doc(title = "T", meta = list(author = "A"))

    it("calls the front matter with the document and the format", {
        spec <- pub_report_spec("pdf", front_matter = function(doc, format) {
            list(
                sprintf("%s by %s (%s)", doc$meta$title, doc$meta$author, format),
                pub_pagebreak()
            )
        })

        nodes <- .front_nodes(.render_settings(spec, "typst"), doc)

        expect_length(nodes, 2L)
        expect_identical(nodes[[1L]]$object, pub_text("T by A (pdf)"))
        expect_identical(nodes[[2L]]$type, "pagebreak")
        expect_null(.front_nodes(default_settings("md"), doc))
        empty <- pub_report_spec("md", front_matter = \(doc, format) NULL)
        expect_identical(.front_nodes(.render_settings(empty, "md"), doc), list())
    })

    it("takes the document's front matter unless the spec has a function", {
        fronted <- pub_doc(front_matter = list("Cover", pub_pagebreak()))
        combine <- pub_report_spec("md", front_matter = function(doc, format) {
            list(doc$front_matter, pub_text(format))
        })
        replace <- pub_report_spec("md", front_matter = \(doc, format) "Own")

        expect_identical(
            .front_nodes(default_settings("md"), fronted),
            fronted$front_matter
        )
        nodes <- .front_nodes(.render_settings(combine, "md"), fronted)
        expect_identical(
            vapply(nodes, \(x) x$type, ""),
            c("text", "pagebreak", "text")
        )
        nodes <- .front_nodes(.render_settings(replace, "md"), fronted)
        expect_identical(nodes[[1L]]$object, pub_text("Own"))
        expect_length(nodes, 1L)
    })

    it("wraps errors of the front matter in a render error", {
        spec <- pub_report_spec("md", front_matter = function(doc, format) {
            stop("no signature table")
        })

        err <- expect_error(
            .front_nodes(.render_settings(spec, "md"), doc),
            "`front_matter` failed",
            class = "pubflow_render_error"
        )
        expect_match(conditionMessage(err$parent), "no signature table")
    })
})


# -----------------
# Table of contents
# -----------------

describe(".wants_toc()", {
    sectioned <- pub_doc(pub_section("A", pub_text("a")))

    it("adds a table of contents only to documents with sections", {
        expect_true(.wants_toc(default_settings("docx"), sectioned, NULL))
        expect_false(.wants_toc(default_settings("docx"), pub_doc(pub_text("a")), NULL))
        expect_false(.wants_toc(default_settings("docx"), pub_doc(), NULL))
        expect_false(.wants_toc(default_settings("md"), sectioned, NULL))
        noToc <- .render_settings(pub_report_spec("html", toc = FALSE), "html")
        expect_false(.wants_toc(noToc, sectioned, NULL))
    })

    it("adds none if the document or the front matter places one", {
        settings <- default_settings("latex")
        nested <- pub_doc(pub_section("A", pub_section("B", pub_toc())))
        top <- pub_doc(pub_toc(), pub_section("A", pub_text("a")))
        front <- .as_children(list(pub_toc(2L)))

        expect_false(.wants_toc(settings, nested, NULL))
        expect_false(.wants_toc(settings, top, NULL))
        expect_false(.wants_toc(settings, sectioned, front))
        expect_false(.has_toc(list()))
    })
})
