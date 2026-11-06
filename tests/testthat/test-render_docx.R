# ======================================================================================
# DOCX files
# ======================================================================================

# ------
# Render
# ------

describe("pub_render(format = \"docx\")", {
    render <- function(doc, spec = pub_report_spec("docx")) {
        skip_if_no_pandoc()
        file <- withr::local_tempfile(fileext = ".docx", .local_envir = parent.frame())
        pub_render(doc, "docx", file = file, spec = spec)
    }
    find <- function(xml, xpath) {
        xml2::xml_find_all(xml, xpath, xml2::xml_ns(xml))
    }
    styled <- function(style, node = "w:p", prop = "w:pPr/w:pStyle") {
        sprintf("//%s[%s/@w:val = '%s']", node, prop, style)
    }
    pg_attr <- function(sections, attr) {
        vapply(
            sections,
            \(s) {
                pgSz <- xml2::xml_find_first(s, "w:pgSz", xml2::xml_ns(xml))
                xml2::xml_attr(pgSz, attr, xml2::xml_ns(xml))
            },
            character(1)
        )
    }
    widget <- local_fake_widget()
    path <- render(
        markdown_node_doc(fallback_widget(widget)),
        pub_report_spec("docx", lock = TRUE)
    )
    xml <- docx_xml(path)

    it("writes native tables and figures, `lock` locks all but `locked = FALSE`", {
        expect_length(find(xml, "//w:tbl"), 3L)
        locked <- "//w:sdt[w:sdtPr/w:tag/@w:val = '%s']/w:sdtContent/%s"
        expect_length(find(xml, sprintf(locked, "locked-table", "w:tbl")), 2L)
        figures <- sprintf(locked, "locked-figure", "w:p[.//w:drawing]")
        expect_length(find(xml, figures), 3L)
        expect_length(find(xml, "//w:pStyle[starts-with(@w:val, 'Locked')]"), 0L)
    })

    it("writes cross-references as REF fields to the captions' bookmarks", {
        expect_identical(docx_ref_fields(xml)$result, c("Table 1", "Figure 2"))
        marks <- find(xml, "//w:bookmarkStart[starts-with(@w:name, '_Ref_pubflow')]")
        expect_identical(
            xml2::xml_text(xml2::xml_parent(marks)),
            c("Table 1: A & B", "Figure 2: Points")
        )
    })

    it("writes math as Word equations", {
        expect_length(find(xml, "//m:oMathPara"), 1L)
        expect_length(find(xml, "//m:oMath"), 2L)
    })

    it("numbers captions with SEQ fields", {
        instr <- xml2::xml_attr(
            find(xml, "//w:fldSimple[starts-with(@w:instr, ' SEQ')]"),
            "instr"
        )
        expect_identical(
            instr,
            sprintf(" SEQ %s \\* ARABIC ", c("Figure", "Table", "Figure", "Table"))
        )
        expect_identical(
            xml2::xml_text(find(xml, styled("TableCaption"))),
            c("Table 1: A & B", "Table 2: Wide")
        )
    })

    it("puts landscape parts into sections of their own", {
        sections <- find(xml, "//w:sectPr")
        expect_identical(
            pg_attr(sections, "w:orient"),
            c(NA, "landscape", NA, "landscape", NA)
        )
        expect_identical(
            pg_attr(sections, "w:w"),
            c("11906", "16838", "11906", "16838", "11906")
        )
        refs <- vapply(
            sections,
            \(s) {
                length(xml2::xml_find_all(s, "w:headerReference", xml2::xml_ns(xml)))
            },
            integer(1)
        )
        expect_true(all(refs == 1L))
    })

    it("writes a table of contents field and page breaks", {
        instr <- xml2::xml_text(find(xml, "//w:instrText[starts-with(., ' TOC')]"))
        expect_identical(instr, " TOC \\o \"1-2\" \\h \\z \\u ")
        expect_length(find(xml, "//w:br[@w:type = 'page']"), 4L)
    })

    it("uses the styles of the reference document", {
        styles <- xml2::xml_attr(find(xml, "//w:pStyle"), "val")
        expect_true(all(
            c(
                "Heading1",
                "Heading1Unnumbered",
                "Heading2Unnumbered",
                "ItemTitle",
                "Figure",
                "ImageCaption",
                "TableCaption"
            ) %in%
                styles
        ))
        placeholder <- styled("Placeholder", "w:r", "w:rPr/w:rStyle")
        expect_identical(xml2::xml_text(find(xml, placeholder)), "todo")
        expect_identical(xml2::xml_text(find(xml, styled("Title"))), "Every node")
        expect_match(
            docx_pandoc_text(path),
            "Text of an unnumbered section.",
            fixed = TRUE
        )
    })

    it("escapes raw content in texts", {
        text <- xml2::xml_text(find(xml, "//w:body/w:p"))
        expect_true("<b>not bold</b> and x{=latex}" %in% text)
    })

    it("writes the cell text of the common formatter", {
        file <- render(pub_doc(edge_case_table()))
        cells <- find(docx_xml(file), "//w:tbl/w:tr")
        text <- t(vapply(
            cells,
            \(row) {
                xml2::xml_text(xml2::xml_find_all(row, "w:tc", xml2::xml_ns(xml)))
            },
            character(ncol(edge_case_text()))
        ))
        expect_identical(text, unname(edge_case_text()))
    })

    it("refuses documents with error items", {
        doc <- pub_doc(pub_section("S", demo_failures()$fit))

        err <- expect_error(pub_render(doc, "docx"), class = "pubflow_render_error")
        expect_identical(err$format, "docx")
    })
})

describe("pub_render(format = \"docx\") with a spec", {
    render <- function(doc, spec) {
        skip_if_no_pandoc()
        file <- withr::local_tempfile(fileext = ".docx", .local_envir = parent.frame())
        pub_render(
            doc,
            "docx",
            file = file,
            spec = spec,
            meta = list(author = "A. User")
        )
    }
    find <- function(xml, xpath) {
        xml2::xml_find_all(xml, xpath, xml2::xml_ns(xml))
    }
    page_of <- function(xml) {
        lapply(find(xml, "//w:sectPr"), \(s) {
            attrs <- \(node) {
                unlist(xml2::xml_attrs(xml2::xml_find_first(
                    s,
                    node,
                    xml2::xml_ns(xml)
                )))
            }
            size <- attrs("w:pgSz")
            margins <- attrs("w:pgMar")
            c(
                size[intersect(c("w", "h", "orient"), names(size))],
                margins[c("top", "bottom", "left", "right")]
            )
        })
    }
    doc <- pub_doc(
        pub_section("A", pub_table(data.frame(a = 1), widths = c(a = 1))),
        pub_section(
            "B",
            pub_table(data.frame(b = 1), widths = c(b = 1)),
            landscape = TRUE
        ),
        pub_section("C", "c"),
        title = "Spec & co"
    )

    it("sets the page of the spec in every section and in the widths", {
        page <- pub_page("letter", margins = c(left = 3, bottom = 1.5))
        xml <- docx_xml(render(doc, pub_report_spec("docx", page = page)))

        portrait <- c(
            w = "12240",
            h = "15840",
            top = "1417",
            bottom = "850",
            left = "1701",
            right = "1417"
        )
        landscape <- c(w = "15840", h = "12240", orient = "landscape", portrait[3:6])
        expect_identical(page_of(xml), list(portrait, landscape, portrait))
        # text width from the written twips: 12240 - 1701 - 1417
        widths <- xml2::xml_attr(find(xml, "//w:tblW"), "w")
        expect_identical(widths, c("9122", "12722"))
        sect <- find(xml, "//w:body/w:sectPr/w:pgMar")
        expect_identical(xml2::xml_attr(sect, "header"), "708")
    })

    it("turns the whole document for a landscape page", {
        page <- pub_page(orientation = "landscape")
        xml <- docx_xml(render(doc, pub_report_spec("docx", page = page)))

        expect_identical(
            page_of(xml),
            list(c(
                w = "16838",
                h = "11906",
                orient = "landscape",
                top = "1417",
                bottom = "1134",
                left = "1417",
                right = "1417"
            ))
        )
        expect_identical(
            xml2::xml_attr(find(xml, "//w:tblW"), "w"),
            c("14004", "14004")
        )
    })

    it("keeps the title in the file properties with front matter", {
        front <- function(doc, format) "Signed by A."
        path <- render(doc, pub_report_spec("docx", front_matter = front))
        xml <- docx_xml(path)
        core <- docx_xml(path, "docProps/core.xml")
        dc <- c(dc = "http://purl.org/dc/elements/1.1/")

        expect_length(find(xml, "//w:p[w:pPr/w:pStyle/@w:val = 'Title']"), 0L)
        expect_identical(
            xml2::xml_text(find(xml, "//w:body/w:p")[[1L]]),
            "Signed by A."
        )
        expect_identical(
            xml2::xml_text(xml2::xml_find_first(core, "//dc:title", dc)),
            "Spec & co"
        )
        expect_identical(
            xml2::xml_text(xml2::xml_find_first(core, "//dc:creator", dc)),
            "A. User"
        )
    })

    it("shows the title block only with a title, subtitle or author", {
        skip_if_no_pandoc()
        file <- withr::local_tempfile(fileext = ".docx")
        pub_render(pub_doc(pub_section("S", "x")), "docx", file = file)
        styles <- xml2::xml_attr(find(docx_xml(file), "//w:pStyle"), "val")

        expect_false(any(c("Title", "Date") %in% styles))
    })

    it("passes pandoc_args to pandoc", {
        spec <- pub_report_spec("docx", pandoc_args = "--metadata=subject:Spec args")
        core <- docx_xml(render(doc, spec), "docProps/core.xml")
        dc <- c(dc = "http://purl.org/dc/elements/1.1/")

        expect_identical(
            xml2::xml_text(xml2::xml_find_first(core, "//dc:subject", dc)),
            "Spec args"
        )
    })
})


# ======================================================================================
# Page setup and properties
# ======================================================================================

# ----------
# Page setup
# ----------

describe(".docx_page()", {
    it("reads the page size and margins of the last section", {
        path <- local_docx_body(paste0(
            "<w:p/><w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/>",
            "<w:pgMar w:left=\"1000\" w:right=\"900\"/></w:sectPr>"
        ))

        expect_identical(
            .docx_page(path),
            list(width = 12240, height = 15840, left = 1000, right = 900)
        )
    })

    it("defaults missing or invalid values to A4 with 2.5 cm margins", {
        a4 <- list(width = 11906, height = 16838, left = 1417, right = 1417)
        expect_identical(.docx_page(local_docx_body("<w:p/>")), a4)
        path <- local_docx_body(paste0(
            "<w:sectPr><w:pgSz w:w=\"auto\" w:h=\"12240\"/>",
            "<w:pgMar w:left=\"\"/></w:sectPr>"
        ))
        expect_identical(.docx_page(path), utils::modifyList(a4, list(height = 12240)))
    })
})

describe(".docx_text_width()", {
    it("takes the shorter side of the reference's page as portrait", {
        path <- local_docx_body(paste0(
            "<w:sectPr><w:pgSz w:w=\"16838\" w:h=\"11906\" w:orient=\"landscape\"/>",
            "<w:pgMar w:left=\"1000\" w:right=\"1000\"/></w:sectPr>"
        ))

        expect_identical(
            .docx_text_width(path),
            c(portrait = 9906L, landscape = 14838L)
        )
    })

    it("takes the spec's page instead of the reference's", {
        path <- local_docx_body("<w:sectPr><w:pgSz w:w=\"1\" w:h=\"2\"/></w:sectPr>")
        page <- .settings_page(pub_page("letter", margins = c(left = 3)), "docx")

        # 12240 - 1701 - 1417 and 15840 - 1701 - 1417
        expect_identical(
            .docx_text_width(path, page),
            c(portrait = 9122L, landscape = 12722L)
        )
    })

    it("gives a turned page's width as the normal width", {
        page <- .settings_page(pub_page(orientation = "landscape"), "docx")

        expect_identical(
            .docx_text_width(NULL, page),
            c(portrait = 14004L, landscape = 9072L)
        )
    })
})

describe(".docx_twips()", {
    it("rounds cm to whole twips in a fixed order", {
        page <- list(right = 1, left = 2.5, bottom = 0, top = 0.01, height = 2.54)
        page$width <- 21

        expect_identical(
            .docx_twips(page),
            c(
                width = 11906,
                height = 1440,
                top = 6,
                bottom = 0,
                left = 1417,
                right = 567
            )
        )
    })
})


# --------------
# Section breaks
# --------------

describe(".docx_complete_sections()", {
    ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    last <- paste0(
        "<w:sectPr><w:headerReference w:type=\"default\"/>",
        "<w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:left=\"1417\"/>",
        "<w:titlePg/></w:sectPr>"
    )
    brk <- function(landscape) {
        sprintf(
            "<w:p><w:pPr><w:sectPr>%s</w:sectPr></w:pPr></w:p>",
            if (landscape) "<w:pgSz w:orient=\"landscape\"/>" else ""
        )
    }
    sections <- function(path) {
        xml <- docx_xml(path)
        lapply(xml2::xml_find_all(xml, "//w:sectPr", ns), \(s) {
            pgSz <- xml2::xml_find_first(s, "w:pgSz", ns)
            list(
                size = vapply(
                    c("w:w", "w:h", "w:orient"),
                    \(a) {
                        xml2::xml_attr(pgSz, a, ns)
                    },
                    character(1),
                    USE.NAMES = FALSE
                ),
                children = xml2::xml_name(xml2::xml_children(s))
            )
        })
    }
    core_xml <- paste0(
        "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/",
        "2006/metadata/core-properties\" ",
        "xmlns:dc=\"http://purl.org/dc/elements/1.1/\">",
        "<dc:title>Old</dc:title></cp:coreProperties>"
    )
    with_core <- function(path) {
        dir <- withr::local_tempdir()
        zip::unzip(path, exdir = dir)
        dir.create(file.path(dir, "docProps"))
        writeLines(core_xml, file.path(dir, "docProps", "core.xml"))
        .zip_dir(dir, path)
        path
    }
    dc_text <- function(path, name) {
        core <- docx_xml(path, "docProps/core.xml")
        dc <- c(dc = "http://purl.org/dc/elements/1.1/")
        xml2::xml_text(xml2::xml_find_all(core, paste0("/*/dc:", name), dc))
    }

    it("copies the last section's properties, swapped for landscape", {
        path <- local_docx_body(paste0(
            "<w:p/>",
            brk(FALSE),
            "<w:p/>",
            brk(TRUE),
            "<w:p/>",
            last
        ))

        .docx_complete_sections(path)

        res <- sections(path)
        expect_length(res, 3L)
        expect_identical(res[[1L]]$size, c("11906", "16838", NA))
        expect_identical(res[[2L]]$size, c("16838", "11906", "landscape"))
        expect_identical(res[[3L]]$size, c("11906", "16838", NA))
        # a different first page only in the first section
        expect_identical(
            res[[1L]]$children,
            c("headerReference", "pgSz", "pgMar", "titlePg")
        )
        expect_identical(res[[2L]]$children, c("headerReference", "pgSz", "pgMar"))
        expect_identical(res[[3L]]$children, c("headerReference", "pgSz", "pgMar"))
    })

    it("makes the last section landscape for a break at the end", {
        path <- local_docx_body(paste0("<w:p/>", brk(FALSE), "<w:p/>", brk(TRUE), last))

        .docx_complete_sections(path)

        res <- sections(path)
        expect_length(res, 2L)
        # the portrait section copied from it isn't marked landscape
        expect_identical(res[[1L]]$size, c("11906", "16838", NA))
        expect_identical(res[[2L]]$size, c("16838", "11906", "landscape"))
        expect_length(xml2::xml_find_all(docx_xml(path), "//w:p", ns), 3L)
    })

    it("keeps the first page of a single landscape section", {
        path <- local_docx_body(paste0("<w:p/>", brk(TRUE), last))

        .docx_complete_sections(path)

        res <- sections(path)
        expect_length(res, 1L)
        expect_identical(res[[1L]]$size, c("16838", "11906", "landscape"))
        expect_identical(
            res[[1L]]$children,
            c("headerReference", "pgSz", "pgMar", "titlePg")
        )
    })

    it("leaves documents without breaks alone", {
        path <- local_docx_body(paste0("<w:p/>", last))
        before <- unname(tools::md5sum(path))

        .docx_complete_sections(path)
        .docx_complete_sections(path, properties = list(title = NULL))

        expect_identical(unname(tools::md5sum(path)), before)
    })

    it("sets the page of a document without breaks", {
        path <- local_docx_body(paste0("<w:p/>", last))
        page <- .settings_page(pub_page(orientation = "landscape"), "docx")

        .docx_complete_sections(path, page = page)

        res <- sections(path)
        expect_identical(res[[1L]]$size, c("16838", "11906", "landscape"))
    })

    it("sets only the given core properties", {
        path <- with_core(local_docx_body(paste0("<w:p/>", last)))

        .docx_complete_sections(path, properties = list(title = NULL, creator = "Me"))

        expect_identical(dc_text(path, "title"), "Old")
        expect_identical(dc_text(path, "creator"), "Me")
        expect_identical(sections(path)[[1L]]$size, c("11906", "16838", NA))
    })
})

describe(".docx_set_page()", {
    ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    sect <- function(children) {
        xml2::read_xml(sprintf("<w:sectPr xmlns:w=\"%s\">%s</w:sectPr>", ns, children))
    }
    attrs <- function(x, node) {
        xml2::xml_attrs(xml2::xml_find_first(x, node, ns))
    }
    page <- .settings_page(pub_page("letter", margins = c(top = 1)), "docx")

    it("keeps the header and footer distances and the gutter", {
        x <- sect(paste0(
            "<w:pgSz w:w=\"1\" w:h=\"2\" w:orient=\"landscape\"/>",
            "<w:pgMar w:top=\"1\" w:right=\"1\" w:bottom=\"1\" w:left=\"1\" ",
            "w:header=\"500\" w:footer=\"400\" w:gutter=\"10\"/>"
        ))

        .docx_set_page(x, page, ns)

        # portrait now
        expect_identical(attrs(x, "w:pgSz"), c(w = "12240", h = "15840"))
        expect_identical(
            attrs(x, "w:pgMar"),
            c(
                top = "567",
                right = "1417",
                bottom = "1134",
                left = "1417",
                header = "500",
                footer = "400",
                gutter = "10"
            )
        )
    })

    it("adds all margins after the page size if there are none", {
        x <- sect("<w:pgSz w:w=\"1\" w:h=\"2\"/><w:titlePg/>")

        .docx_set_page(x, page, ns)

        expect_identical(
            xml2::xml_name(xml2::xml_children(x)),
            c("pgSz", "pgMar", "titlePg")
        )
        expect_setequal(
            names(attrs(x, "w:pgMar")),
            c("top", "right", "bottom", "left", "header", "footer", "gutter")
        )
        expect_identical(
            attrs(x, "w:pgMar")[c("header", "gutter")],
            c(header = "708", gutter = "0")
        )
    })
})

describe(".set_orientation()", {
    ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    sect <- function(children) {
        xml2::read_xml(sprintf("<w:sectPr xmlns:w=\"%s\">%s</w:sectPr>", ns, children))
    }
    pgSz <- function(x) {
        xml2::xml_attrs(xml2::xml_find_first(x, "w:pgSz", ns))
    }

    it("swaps width and height and sets or removes w:orient", {
        x <- sect("<w:pgSz w:w=\"12240\" w:h=\"15840\"/>")

        .set_orientation(x, TRUE, ns)
        expect_identical(pgSz(x), c(w = "15840", h = "12240", orient = "landscape"))
        .set_orientation(x, TRUE, ns)
        expect_identical(pgSz(x), c(w = "15840", h = "12240", orient = "landscape"))
        .set_orientation(x, FALSE, ns)
        expect_identical(pgSz(x), c(w = "12240", h = "15840"))
    })

    it("adds an A4 page size before the margins if there is none", {
        x <- sect("<w:headerReference/><w:pgMar w:left=\"1\"/>")

        .set_orientation(x, TRUE, ns)

        expect_identical(
            xml2::xml_name(xml2::xml_children(x)),
            c("headerReference", "pgSz", "pgMar")
        )
        expect_identical(pgSz(x), c(w = "16838", h = "11906", orient = "landscape"))
        y <- sect("")
        .set_orientation(y, FALSE, ns)
        expect_identical(pgSz(y), c(w = "11906", h = "16838"))
    })

    it("adds the page size in schema order without margins", {
        names_after <- function(children) {
            x <- sect(children)
            .set_orientation(x, FALSE, ns)
            xml2::xml_name(xml2::xml_children(x))
        }

        expect_identical(
            names_after("<w:footerReference/><w:type/><w:titlePg/><w:docGrid/>"),
            c("footerReference", "type", "pgSz", "titlePg", "docGrid")
        )
        expect_identical(
            names_after("<w:cols/><w:titlePg/>"),
            c("pgSz", "cols", "titlePg")
        )
    })

    it("uses A4 for an invalid page size", {
        x <- sect("<w:pgSz w:w=\"auto\" w:h=\"12240\"/>")

        .set_orientation(x, FALSE, ns)

        expect_identical(pgSz(x), c(w = "11906", h = "16838"))
    })
})


# ---------------
# Core properties
# ---------------

describe(".docx_set_properties()", {
    it("replaces or adds dc:title and dc:creator (escaped)", {
        file <- withr::local_tempfile(fileext = ".xml")
        writeLines(
            paste0(
                "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/",
                "package/2006/metadata/core-properties\" ",
                "xmlns:dc=\"http://purl.org/dc/elements/1.1/\">",
                "<dc:title>Old</dc:title></cp:coreProperties>"
            ),
            file
        )

        .docx_set_properties(file, list(title = "A & <B>", creator = "Me"))

        xml <- xml2::read_xml(file)
        dc <- c(dc = "http://purl.org/dc/elements/1.1/")
        texts <- \(name) xml2::xml_text(xml2::xml_find_all(xml, name, dc))
        expect_identical(texts("/*/dc:title"), "A & <B>")
        expect_identical(texts("/*/dc:creator"), "Me")
        expect_match(paste(readLines(file), collapse = ""), "A &amp; &lt;B&gt;")
    })
})


# -------
# Packing
# -------

describe(".zip_dir()", {
    it("writes [Content_Types].xml first and replaces an existing file", {
        dir <- withr::local_tempdir()
        dir.create(file.path(dir, "_rels"))
        writeLines("a", file.path(dir, "_rels", ".rels"))
        writeLines("b", file.path(dir, "[Content_Types].xml"))
        writeLines("c", file.path(dir, "a.xml"))
        path <- withr::local_tempfile(fileext = ".docx")
        writeLines("old", path)

        expect_identical(.zip_dir(dir, path), path)

        expect_identical(
            zip::zip_list(path)$filename,
            c("[Content_Types].xml", "_rels/.rels", "a.xml")
        )
    })

    it("writes directories without [Content_Types].xml", {
        dir <- withr::local_tempdir()
        writeLines("c", file.path(dir, "a.xml"))
        path <- withr::local_tempfile(fileext = ".zip")

        .zip_dir(dir, path)

        expect_identical(zip::zip_list(path)$filename, "a.xml")
    })
})
