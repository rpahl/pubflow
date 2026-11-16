# The helper file apps copy into their tests (inst/testhelpers/helper-pubflow.R)

h <- new.env()
sys.source(system.file("testhelpers", "helper-pubflow.R", package = "pubflow"), h)

# ======================================================================================
# Tables
# ======================================================================================

describe("table helpers", {
    df <- data.frame(site = c("A", "B"), slope = c(0.12345, NA), n = 1:2)
    ht <- pub_table(
        df,
        labels = c(slope = "Slope"),
        digits = c(slope = 2),
        footnotes = c(slope = "Per month.")
    )

    it("read the body cells, labels and footnotes by row role", {
        cells <- h$table_cells(ht)
        expect_named(cells, names(df))
        expect_identical(cells$site, c("A", "B"))
        expect_identical(h$table_labels(ht)[["site"]], "site")
        expect_match(h$table_labels(ht)[["slope"]], "Slope")
        expect_length(h$table_footnotes(ht), 1L)
        expect_match(h$table_footnotes(ht), "Per month.")
        expect_null(h$table_spanners(ht))
    })

    it("count the decimals of numeric cells only", {
        expect_identical(h$table_decimals(ht, "slope"), 2L)
        expect_identical(h$table_decimals(ht, "n"), 0L)
    })

    it("ignore footnote markers on body cells when counting decimals", {
        notes <- data.frame(row = 1, col = "slope", text = "Rounded.")
        marked <- pub_table(df, digits = c(slope = 2), footnotes = notes)
        expect_match(h$table_cells(marked)$slope[[1L]], "^0.12")
        expect_false(identical(h$table_cells(marked)$slope[[1L]], "0.12"))
        expect_identical(h$table_decimals(marked, "slope"), 2L)
    })

    it("return a style of the body cells named by column", {
        style <- h$table_style(huxtable::set_bold(ht, 3, "site"), huxtable::bold)
        expect_identical(colnames(style), names(df))
        expect_identical(nrow(style), 2L)
        expect_identical(unname(style[, "site"]), c(FALSE, TRUE))
        expect_false(any(style[, "n"]))
    })
})

# ======================================================================================
# Documents
# ======================================================================================

describe("document helpers", {
    tab <- pub_set_meta(data.frame(a = 1), locked = TRUE)
    doc <- pub_doc(
        pub_section("One", tab, pub_section("Inner", pub_text("x"))),
        pub_section("Two", pub_text("y"))
    )

    it("read titles, child types and subsections", {
        expect_identical(h$section_titles(doc), c("One", "Two"))
        expect_identical(h$child_types(h$section_of(doc, "One")), c("table", "section"))
        expect_identical(h$section_titles(h$section_of(doc, "One")), "Inner")
        expect_error(h$section_of(doc, "Three"), "No section")
    })

    it("collect the items of all levels, optionally by type", {
        expect_length(h$doc_items(doc), 3L)
        expect_length(h$doc_items(doc, "table"), 1L)
    })

    it("include the front matter first", {
        front <- pub_doc(pub_section("S", tab), front_matter = pub_text("cover"))
        expect_identical(
            vapply(h$doc_items(front), \(x) x$type, ""),
            c("text", "table")
        )
    })

    it("expect all items to be locked", {
        h$expect_all_locked(h$doc_items(doc, "table"))
        expect_failure(h$expect_all_locked(h$doc_items(doc)))
        expect_failure(h$expect_all_locked(list()))
    })
})

# ======================================================================================
# Word files
# ======================================================================================

describe("docx_xml()", {
    it("reads a part of a rendered Word file", {
        skip_if_no_pandoc()
        path <- withr::local_tempfile(fileext = ".docx")
        pub_render(pub_doc(pub_section("One", pub_text("hello"))), "docx", path)
        expect_match(as.character(h$docx_xml(path)), "hello")
    })
})
