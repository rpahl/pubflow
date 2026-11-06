# ======================================================================================
# Post-processors
# ======================================================================================

# ------------
# Constructors
# ------------

describe("pub_pp_docx_lock()", {
    # a DOCX file with a table and a figure that pub_markdown() locked (without ids),
    # and a content control with id 7 in the header
    locked_docx <- function(frame = parent.frame()) {
        path <- local_docx_copy(frame = frame)
        wrap <- function(tag, content) {
            sdt <- .md_locked_sdt(tag)
            paste0(sdt[["open"]], content, sdt[["close"]])
        }
        body <- paste0(
            wrap("locked-table", "<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>"),
            wrap(
                "locked-figure",
                paste0(
                    "<w:p><w:pPr><w:pStyle w:val=\"Figure\"/></w:pPr>",
                    "<w:r><w:drawing/></w:r></w:p>"
                )
            )
        )
        docx_edit_part(path, "word/document.xml", "<w:body>", paste0("<w:body>", body))
        docx_edit_part(
            path,
            "word/header1.xml",
            "</w:p>",
            paste0(
                "</w:p><w:sdt><w:sdtPr><w:id w:val=\"7\"/></w:sdtPr>",
                "<w:sdtContent><w:p/></w:sdtContent></w:sdt>"
            )
        )
    }

    ids_of <- function(path, part) {
        xml2::xml_attr(
            xml2::xml_find_all(docx_xml(path, part), "//w:sdtPr/w:id", .w_ns),
            "w:val",
            ns = .w_ns
        )
    }
    apply_lock <- function(path) {
        pub_pp_docx_lock()(path, pub_doc(), pub_report_spec("docx"))
    }
    # the document's relationships without the header and footer
    drop_head_foot <- function(path) {
        rels <- "word/_rels/document.xml.rels"
        text <- docx_part_text(path, rels)
        for (kind in c("header", "footer")) {
            old <- regmatches(
                text,
                regexpr(sprintf("<Relationship [^>]*/%s\" [^>]*/>", kind), text)
            )
            docx_edit_part(path, rels, old, "")
        }
        invisible(path)
    }

    it("locks the header and the footer in place, after the ids in the file", {
        path <- locked_docx()
        pp <- pub_pp_docx_lock()

        expect_s3_class(pp, "pub_pp_docx_lock")
        expect_invisible(res <- pp(path, pub_doc(), pub_report_spec("docx")))
        expect_identical(res, path)

        expect_identical(ids_of(path, "word/document.xml"), character())
        for (part in c("header", "footer")) {
            locked <- sprintf(
                paste0(
                    "/*[count(*) = 1]/w:sdt[w:sdtPr/w:tag/@w:val = 'locked-%s' ",
                    "and w:sdtPr/w:lock/@w:val = 'sdtContentLocked']"
                ),
                part
            )
            xml <- docx_xml(path, sprintf("word/%s1.xml", part))
            expect_length(xml2::xml_find_all(xml, locked, .w_ns), 1L)
        }
        # the header's own content control stays inside its lock
        expect_identical(ids_of(path, "word/header1.xml"), c("8", "7"))
        expect_identical(ids_of(path, "word/footer1.xml"), "9")
        instr <- xml2::xml_find_all(
            docx_xml(path, "word/footer1.xml"),
            "//w:sdtContent//w:instrText",
            .w_ns
        )
        expect_identical(trimws(xml2::xml_text(instr)), c("PAGE", "NUMPAGES"))
        expect_identical(docx_bad_parts(path), character())
    })

    it("changes nothing when applied twice", {
        path <- local_docx_copy()
        apply_lock(path)
        once <- tools::md5sum(path)

        apply_lock(path)

        expect_identical(tools::md5sum(path), once)
    })

    it("takes ids above those of the other parts, e.g. the footnotes", {
        path <- locked_docx()
        docx_edit_part(
            path,
            "word/footnotes.xml",
            "<w:r><w:t>Footnote Text.",
            paste0(
                "<w:sdt><w:sdtPr><w:id w:val=\"20\"/></w:sdtPr>",
                "<w:sdtContent/></w:sdt><w:r><w:t>Footnote Text."
            )
        )

        apply_lock(path)

        expect_identical(ids_of(path, "word/document.xml"), character())
        expect_identical(ids_of(path, "word/header1.xml"), c("21", "7"))
        expect_identical(ids_of(path, "word/footer1.xml"), "22")
    })

    it("ignores content control ids that aren't numbers", {
        path <- locked_docx()
        docx_edit_part(path, "word/header1.xml", "w:val=\"7\"", "w:val=\"x\"")

        apply_lock(path)

        expect_identical(ids_of(path, "word/document.xml"), character())
        expect_identical(ids_of(path, "word/header1.xml"), c("1", "x"))
        expect_identical(ids_of(path, "word/footer1.xml"), "2")
    })

    it("leaves a file without header and footer as it is", {
        path <- drop_head_foot(locked_docx())
        before <- tools::md5sum(path)

        apply_lock(path)

        expect_identical(tools::md5sum(path), before)
    })

    it("finds the header and footer parts by their relationships", {
        path <- local_docx_copy()
        docx_move_part(path, "word/header1.xml", "word/parts/top.xml")

        apply_lock(path)

        expect_length(
            xml2::xml_find_all(
                docx_xml(path, "word/parts/top.xml"),
                "/*/w:sdt[w:sdtPr/w:tag/@w:val = 'locked-header']",
                .w_ns
            ),
            1L
        )
        expect_identical(docx_bad_parts(path), character())
    })
})

describe("pub_pp_docx_header_footer()", {
    noon <- as.POSIXct("2026-10-08 12:00:00", tz = "UTC")
    stamp <- "A. User at 08-Oct-2026 12:00:00 UTC (demo v1.0)"
    doc_with <- function(...) {
        pub_doc(
            meta = list(
                author = "A. User",
                app = "demo",
                version = "1.0",
                time = noon,
                ...
            )
        )
    }
    apply_pp <- function(pp, doc, path) {
        pp(path, doc, pub_report_spec("docx"))
    }
    # text of a bookmark in a part
    bookmark <- function(path, name, part = NULL) {
        if (is.null(part)) {
            part <- sprintf("word/%s1.xml", sub("_.*", "", name))
        }
        xml <- docx_xml(path, part)
        start <- xml2::xml_find_first(
            xml,
            sprintf("//w:bookmarkStart[@w:name = '%s']", name),
            .w_ns
        )
        id <- xml2::xml_attr(start, "w:id", ns = .w_ns)
        runs <- xml2::xml_find_all(
            start,
            sprintf(
                paste0(
                    "following-sibling::w:r[following-sibling::",
                    "w:bookmarkEnd[@w:id = '%s']]"
                ),
                id
            ),
            .w_ns
        )
        paste(xml2::xml_text(runs), collapse = "")
    }
    fields <- function(path) {
        trimws(xml2::xml_text(xml2::xml_find_all(
            docx_xml(path, "word/footer1.xml"),
            "//w:instrText",
            .w_ns
        )))
    }

    it("writes the document's lines at the bookmarks, with the stamp", {
        path <- local_docx_copy()
        doc <- doc_with(
            header = c(left = "Left", center = "Centre", right = "Right"),
            footer = c(left = "{trace}", center = "Page bottom")
        )

        pp <- pub_pp_docx_header_footer()
        expect_s3_class(pp, "pub_pp_docx_header_footer")
        expect_invisible(apply_pp(pp, doc, path))

        names <- c(
            "header_left",
            "header_center",
            "header_right",
            "footer_left",
            "footer_center"
        )
        expect_identical(
            vapply(
                names,
                \(name) bookmark(path, name),
                character(1),
                USE.NAMES = FALSE
            ),
            c("Left", "Centre", "Right", stamp, "Page bottom")
        )
        expect_identical(fields(path), c("PAGE", "NUMPAGES"))
        expect_identical(docx_bad_parts(path), character())
    })

    it("replaces the page number with a right footer line", {
        path <- local_docx_copy()

        apply_pp(pub_pp_docx_header_footer(), doc_with(footer = c(right = "R")), path)

        expect_identical(bookmark(path, "footer_right"), "R")
        expect_identical(fields(path), character())
    })

    it("clears a bookmark with an empty line, also the page number", {
        path <- local_docx_copy()

        apply_pp(pub_pp_docx_header_footer(), doc_with(footer = c(right = "")), path)

        expect_identical(bookmark(path, "footer_right"), "")
        expect_identical(fields(path), character())
        expect_identical(docx_bad_parts(path), character())
    })

    it("fills a bookmark without content", {
        path <- local_docx_copy()
        docx_edit_part(
            path,
            "word/header1.xml",
            "<w:r><w:t xml:space=\"preserve\"></w:t></w:r>",
            ""
        )

        apply_pp(pub_pp_docx_header_footer(), doc_with(header = c(left = "B")), path)

        expect_identical(bookmark(path, "header_left"), "B")
        rPr <- xml2::xml_find_all(
            docx_xml(path, "word/header1.xml"),
            "//w:bookmarkStart[@w:name = 'header_left']/following-sibling::w:r[1]/*",
            .w_ns
        )
        expect_identical(xml2::xml_name(rPr), "t")
    })

    it("keeps the format of the bookmark's first run", {
        path <- local_docx_copy()
        docx_edit_part(
            path,
            "word/header1.xml",
            "<w:r><w:t xml:space=\"preserve\"></w:t></w:r>",
            paste0(
                "<w:r><w:rPr><w:b /></w:rPr><w:t>old</w:t></w:r>",
                "<w:r><w:t>er</w:t></w:r>"
            )
        )

        apply_pp(pub_pp_docx_header_footer(), doc_with(header = c(left = "B")), path)

        xml <- docx_xml(path, "word/header1.xml")
        start <- xml2::xml_find_first(
            xml,
            "//w:bookmarkStart[@w:name = 'header_left']",
            .w_ns
        )
        run <- xml2::xml_find_first(start, "following-sibling::w:r[1]", .w_ns)
        expect_length(xml2::xml_find_all(run, "w:rPr/w:b", .w_ns), 1L)
        t <- xml2::xml_find_first(run, "w:t", .w_ns)
        expect_identical(xml2::xml_attr(t, "space"), "preserve")
        expect_identical(bookmark(path, "header_left"), "B")
    })

    it("replaces all the content of a bookmark, keeping other bookmarks", {
        path <- local_docx_copy()
        docx_edit_part(
            path,
            "word/header1.xml",
            "<w:r><w:t xml:space=\"preserve\"></w:t></w:r>",
            paste0(
                "<w:hyperlink w:anchor=\"x\"><w:r><w:rPr><w:i />",
                "</w:rPr><w:t>link</w:t></w:r></w:hyperlink>",
                "<w:bookmarkStart w:id=\"1\" w:name=\"inner\" />",
                "<w:fldSimple w:instr=\" PAGE \"><w:r><w:t>1</w:t>",
                "</w:r></w:fldSimple><w:bookmarkEnd w:id=\"1\" />"
            )
        )

        apply_pp(pub_pp_docx_header_footer(), doc_with(header = c(left = "B")), path)

        xml <- docx_xml(path, "word/header1.xml")
        find <- \(xpath) xml2::xml_find_all(xml, xpath, .w_ns)
        expect_identical(bookmark(path, "header_left"), "B")
        expect_length(find("//w:hyperlink | //w:fldSimple"), 0L)
        expect_length(
            find(paste0(
                "//w:bookmarkStart[@w:name = 'header_left']",
                "/following-sibling::w:r[1]/w:rPr/w:i"
            )),
            1L
        )
        expect_length(find("//*[@w:id = '1']"), 2L)
    })

    it("writes the text literally, on one line", {
        path <- local_docx_copy()

        apply_pp(
            pub_pp_docx_header_footer(),
            doc_with(header = c(left = "A & <B>\n  C  ")),
            path
        )

        expect_identical(bookmark(path, "header_left"), "A & <B> C")
    })

    it("takes explicit lines instead of the document's", {
        path <- local_docx_copy()
        doc <- doc_with(
            header = c(left = "Doc", right = "Doc"),
            footer = c(left = "Doc footer")
        )

        apply_pp(pub_pp_docx_header_footer(header = c(center = "{trace}")), doc, path)

        expect_identical(bookmark(path, "header_left"), "")
        expect_identical(bookmark(path, "header_center"), stamp)
        expect_identical(bookmark(path, "header_right"), "")
        expect_identical(bookmark(path, "footer_left"), "Doc footer")
    })

    it("leaves the file as it is without lines", {
        path <- local_docx_copy()
        before <- tools::md5sum(path)

        apply_pp(pub_pp_docx_header_footer(), doc_with(), path)
        apply_pp(
            pub_pp_docx_header_footer(header = character()),
            doc_with(header = c(left = "x")),
            path
        )

        expect_identical(tools::md5sum(path), before)
    })

    it("finds the header and footer parts by their relationships", {
        path <- local_docx_copy()
        docx_move_part(path, "word/footer1.xml", "word/parts/bottom.xml")

        apply_pp(pub_pp_docx_header_footer(), doc_with(footer = c(left = "F")), path)

        expect_identical(bookmark(path, "footer_left", "word/parts/bottom.xml"), "F")
    })

    it("signals an error for lines without bookmark, naming them", {
        path <- local_docx_copy(headers_template())
        before <- tools::md5sum(path)
        doc <- doc_with(
            header = c(left = "L", center = "C"),
            footer = c(right = "R", center = "")
        )

        expect_error(
            apply_pp(pub_pp_docx_header_footer(), doc, path),
            "no bookmark.*header_center.*footer_right"
        )
        expect_identical(tools::md5sum(path), before)
    })

    it("signals an error for lines of a file without header and footer", {
        path <- local_docx_copy()
        rels <- "word/_rels/document.xml.rels"
        text <- docx_part_text(path, rels)
        old <- regmatches(text, regexpr("<Relationship [^>]*/header\" [^>]*/>", text))
        docx_edit_part(path, rels, old, "")

        expect_error(
            apply_pp(
                pub_pp_docx_header_footer(),
                doc_with(header = c(left = "L")),
                path
            ),
            "no bookmark.*header_left"
        )
    })

    it("fills every header with the bookmark and keeps the settings", {
        path <- local_docx_copy(headers_template())
        unchanged <- c("word/header1.xml", "word/header3.xml", "word/settings.xml")
        before <- vapply(unchanged, \(part) docx_part_text(path, part), character(1))

        apply_pp(
            pub_pp_docx_header_footer(),
            doc_with(header = c(left = "{trace}"), footer = c(left = "Footer")),
            path
        )

        expect_identical(bookmark(path, "header_left", "word/header2.xml"), stamp)
        expect_identical(bookmark(path, "footer_left", "word/footer2.xml"), "Footer")
        expect_identical(
            vapply(unchanged, \(part) docx_part_text(path, part), character(1)),
            before
        )
    })

    it("fills a header that is locked already", {
        path <- local_docx_copy()
        pub_pp_docx_lock()(path, pub_doc(), pub_report_spec("docx"))

        apply_pp(pub_pp_docx_header_footer(), doc_with(header = c(left = "L")), path)

        expect_identical(bookmark(path, "header_left"), "L")
        expect_length(
            xml2::xml_find_all(
                docx_xml(path, "word/header1.xml"),
                "/*/w:sdt[w:sdtPr/w:tag/@w:val = 'locked-header']",
                .w_ns
            ),
            1L
        )
    })

    it("needs the author for the stamp", {
        path <- local_docx_copy()
        doc <- pub_doc(meta = list(footer = c(left = "{trace}")))

        expect_error(
            apply_pp(pub_pp_docx_header_footer(), doc, path),
            "without the metadata `author`",
            class = "pubflow_render_error"
        )
    })

    it("validates its arguments", {
        expect_error(
            pub_pp_docx_header_footer(header = "x"),
            "`header` must be `NULL` or a character vector"
        )
        expect_error(
            pub_pp_docx_header_footer(footer = c(top = "x")),
            "`footer` must be"
        )
        expect_error(
            pub_pp_docx_header_footer(footer = list(left = "x")),
            "`footer` must be"
        )
        expect_error(
            pub_pp_docx_header_footer(header = c(left = NA_character_)),
            "`header` must be"
        )
        expect_error(
            pub_pp_docx_header_footer(header = c(left = "a", left = "b")),
            "`header` must be"
        )
    })
})


# ------------------
# Editing DOCX files
# ------------------

describe(".docx_header_footer_parts()", {
    it("takes each header and footer target once, also absolute ones", {
        dir <- withr::local_tempdir()
        dir.create(file.path(dir, "word", "_rels"), recursive = TRUE)
        type <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
        rel <- sprintf(
            "<Relationship Id=\"rId%d\" Type=\"%s%s\" Target=\"%s\"/>",
            1:4,
            type,
            c("styles", "header", "footer", "footer"),
            c("styles.xml", "/word/parts/top.xml", "footer1.xml", "footer1.xml")
        )
        writeLines(
            paste0(
                "<Relationships xmlns=\"http://schemas.openxmlformats.org/",
                "package/2006/relationships\">",
                paste(rel, collapse = ""),
                "</Relationships>"
            ),
            file.path(dir, "word", "_rels", "document.xml.rels")
        )

        files <- file.path(dir, "word", c("parts/top.xml", "footer1.xml"))
        dir.create(dirname(files[[1L]]))
        file.create(files)

        parts <- .docx_header_footer_parts(dir)

        expect_named(parts, c("header", "footer"))
        expect_identical(unname(normalizePath(parts)), normalizePath(files))
    })

    it("finds no parts in a file without relationships", {
        dir <- withr::local_tempdir()
        dir.create(file.path(dir, "word"))

        expect_identical(
            .docx_header_footer_parts(dir),
            rlang::set_names(character(), character())
        )
    })
})


# ======================================================================================
# Lock
# ======================================================================================

# ----------------
# Content controls
# ----------------

describe(".docx_lock_part()", {
    header <- function(...) {
        xml2::read_xml(paste0(
            "<w:hdr xmlns:w=\"",
            .w_ns[["w"]],
            "\">",
            ...,
            "</w:hdr>"
        ))
    }
    find <- function(xml, xpath) xml2::xml_find_all(xml, xpath, .w_ns)

    it("wraps all the content into one locked content control", {
        xml <- header("<w:p><w:r><w:t>a</w:t></w:r></w:p>", "<w:tbl/>", "<w:p/>")

        expect_true(.docx_lock_part(xml, "locked-header", 3))

        expect_length(find(xml, "/w:hdr/*"), 1L)
        content <- find(xml, "/w:hdr/w:sdt/w:sdtContent/*")
        expect_identical(xml2::xml_name(content), c("p", "tbl", "p"))
        pr <- find(xml, "/w:hdr/w:sdt/w:sdtPr/*")
        expect_identical(xml2::xml_name(pr), c("tag", "id", "lock"))
        expect_identical(
            xml2::xml_attr(pr, "w:val", ns = .w_ns),
            c("locked-header", "3", "sdtContentLocked")
        )
    })

    it("leaves an empty part and a locked one alone", {
        xml <- header("<w:p/>")
        .docx_lock_part(xml, "locked-header", 1)
        once <- as.character(xml)

        expect_false(.docx_lock_part(header(), "locked-header", 1))
        expect_false(.docx_lock_part(xml, "locked-header", 2))
        expect_identical(as.character(xml), once)
    })
})

describe(".docx_sdt_ids()", {
    it("returns the numeric ids, leaving out others", {
        xml <- xml2::read_xml(paste0(
            "<w:hdr xmlns:w=\"",
            .w_ns[["w"]],
            "\">",
            "<w:sdt><w:sdtPr><w:id w:val=\"5\"/></w:sdtPr></w:sdt>",
            "<w:sdt><w:sdtPr><w:id w:val=\"-3\"/></w:sdtPr></w:sdt>",
            "<w:sdt><w:sdtPr><w:id w:val=\"x\"/></w:sdtPr></w:sdt>",
            "<w:sdt><w:sdtPr><w:id/></w:sdtPr></w:sdt>",
            "<w:sdt><w:sdtPr/></w:sdt>",
            "</w:hdr>"
        ))

        expect_identical(.docx_sdt_ids(xml), c(5, -3))
    })
})

# ======================================================================================
# Scenarios
# ======================================================================================

# ----------------------------------
# Rendering with the post-processors
# ----------------------------------

describe("pub_render(format = \"docx\") with the post-processors", {
    render <- function(doc, ..., lock = TRUE, frame = parent.frame()) {
        skip_if_no_pandoc()
        file <- withr::local_tempfile(fileext = ".docx", .local_envir = frame)
        pub_render(
            doc,
            "docx",
            file = file,
            spec = pub_report_spec("docx", lock = lock, ...),
            meta = list(author = "A. User", app = "demo", version = "1.0")
        )
    }
    doc <- pub_doc(
        pub_section(
            "Results",
            pub_table(data.frame(a = 1), caption = "Locked table"),
            pub_set_meta(data.frame(b = "unlocked"), locked = FALSE),
            pub_figure(recorded_plot(), caption = "Locked", width = 2, height = 2),
            pub_figure(
                recorded_plot(2L),
                caption = "Unlocked",
                width = 2,
                height = 2,
                locked = FALSE
            )
        ),
        title = "Locks",
        meta = list(
            time = as.POSIXct("2026-10-08 12:00:00", tz = "UTC"),
            header = c(left = "Locks"),
            footer = c(left = "{trace}")
        )
    )
    count <- function(xml, xpath) {
        length(xml2::xml_find_all(xml, xpath, .w_ns))
    }
    sdt <- function(tag, content) {
        sprintf(
            paste0(
                "//w:sdt[w:sdtPr/w:tag/@w:val = '%s' and ",
                "count(w:sdtContent/*) = 1 and w:sdtContent/%s]"
            ),
            tag,
            content
        )
    }
    # the content control ids of the document, header and footer parts
    all_ids <- function(path) {
        parts <- grep(
            "^word/(document|header[0-9]+|footer[0-9]+)\\.xml$",
            zip::zip_list(path)$filename,
            value = TRUE
        )
        unlist(lapply(parts, \(part) .docx_sdt_ids(docx_xml(path, part))))
    }
    locked_part <- function(path, part) {
        tag <- sub("^word/(header|footer)[0-9]+\\.xml$", "locked-\\1", part)
        count(
            docx_xml(path, part),
            sprintf(
                paste0(
                    "/*[count(*) = 1]/w:sdt[w:sdtPr/w:tag/@w:val = '%s' and ",
                    "w:sdtPr/w:lock/@w:val = 'sdtContentLocked']"
                ),
                tag
            )
        ) ==
            1L
    }
    path <- render(doc)
    xml <- docx_xml(path)

    it("locks the tables and figures that aren't `locked = FALSE`", {
        expect_identical(count(xml, "//w:sdt"), 2L)
        expect_identical(count(xml, sdt("locked-table", "w:tbl")), 1L)
        expect_identical(
            count(xml, sdt("locked-figure", "w:p[.//w:drawing]")),
            1L
        )
        expect_identical(count(xml, "//w:tbl[not(ancestor::w:sdt)]"), 1L)
        expect_identical(count(xml, "//w:drawing[not(ancestor::w:sdt)]"), 1L)
        expect_identical(
            count(xml, "//w:sdt//w:pStyle[contains(@w:val, 'Caption')]"),
            0L
        )
    })

    it("locks the header and the footer, with unique ids", {
        expect_true(locked_part(path, "word/header1.xml"))
        expect_true(locked_part(path, "word/footer1.xml"))
        expect_length(all_ids(path), 2L)
        expect_identical(anyDuplicated(all_ids(path)), 0L)
    })

    it("keeps the ids unique next to a content control in raw content", {
        raw <- pub_raw(
            docx = paste0(
                "<w:sdt><w:sdtPr><w:id w:val=\"1\"/></w:sdtPr><w:sdtContent>",
                "<w:p><w:r><w:t>Raw</w:t></w:r></w:p></w:sdtContent></w:sdt>"
            )
        )
        file <- render(pub_doc(raw, pub_table(data.frame(a = 1), caption = "T")))

        expect_identical(count(docx_xml(file), sdt("locked-table", "w:tbl")), 1L)
        expect_identical(sort(all_ids(file)), c(1, 2, 3))
    })

    it("writes the header and footer lines with the stamp", {
        footer <- xml2::xml_text(docx_xml(path, "word/footer1.xml"))
        expect_identical(xml2::xml_text(docx_xml(path, "word/header1.xml")), "Locks")
        expect_match(
            footer,
            paste0("^A. User at 08-Oct-2026 12:00:00 UTC ", "\\(demo v1.0\\)Page")
        )
    })

    it("writes a file that pandoc reads, with no extra declarations", {
        unlocked <- render(doc, lock = FALSE)

        expect_identical(docx_bad_parts(path), character())
        # the locked table with its cell and caption
        expect_match(docx_pandoc_text(path), "1.0000[-[:space:]]+: : Locked")
        for (part in c("word/document.xml", "word/header1.xml", "word/footer1.xml")) {
            expect_identical(
                docx_xmlns_count(path, part),
                docx_xmlns_count(unlocked, part),
                info = part
            )
        }
    })

    it("locks nothing with `lock = FALSE`, also not items with `locked = TRUE`", {
        marked <- pub_doc(pub_set_meta(data.frame(a = 1), locked = TRUE))
        unlocked <- render(marked, lock = FALSE)

        expect_length(all_ids(unlocked), 0L)
        expect_identical(count(docx_xml(unlocked), "//w:sdt"), 0L)
    })

    it("locks only the items with `locked = TRUE` by default", {
        opted <- pub_doc(
            pub_set_meta(pub_table(data.frame(a = 1), caption = "L"), locked = TRUE),
            pub_table(data.frame(b = 2), caption = "Unlocked")
        )
        file <- render(opted, lock = NULL)
        body <- docx_xml(file)

        expect_identical(count(body, "//w:sdt"), 1L)
        expect_identical(count(body, sdt("locked-table", "w:tbl")), 1L)
        expect_false(locked_part(file, "word/header1.xml"))
        expect_false(locked_part(file, "word/footer1.xml"))
    })

    it("applies a listed post-processor in its place only", {
        calls <- character()
        spy <- function(path, doc, spec) {
            calls <<- c(
                calls,
                if (count(docx_xml(path, "word/header1.xml"), "//w:sdt") > 0L) {
                    "locked"
                } else {
                    "unlocked"
                }
            )
        }

        render(doc, post_process = list(spy, pub_pp_docx_lock(), spy))

        expect_identical(calls, c("unlocked", "locked"))
    })

    it("writes the lines into a reference document and locks it", {
        file <- render(doc, reference_docx = headers_template())

        header <- docx_xml(file, "word/header2.xml")
        expect_identical(xml2::xml_text(header), "Locks")
        expect_identical(count(docx_xml(file), sdt("locked-table", "w:tbl")), 1L)
        # even, default and first-page headers and footers
        for (part in sprintf(
            "word/%s%d.xml",
            rep(c("header", "footer"), 3),
            rep(1:3, each = 2)
        )) {
            expect_true(locked_part(file, part), info = part)
        }
        # the body's controls have no ids, those of the headers and footers follow the
        # id of the template's page number control
        ids <- all_ids(file)
        expect_identical(.docx_sdt_ids(docx_xml(file)), numeric())
        headFoot <- setdiff(ids, 1728636285)
        expect_length(headFoot, 6L)
        expect_true(all(headFoot > 1728636285))
        expect_identical(anyDuplicated(ids), 0L)
        expect_identical(docx_bad_parts(file), character())
    })
})
