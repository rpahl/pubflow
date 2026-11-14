# ======================================================================================
# Document tree
# ======================================================================================

# ----------------------
# Documents and sections
# ----------------------

describe("pub_doc()", {
    it("holds children and metadata", {
        time <- as.POSIXct("2026-10-04 12:00:00", tz = "UTC")
        doc <- pub_doc(
            pub_section("A", "text"),
            title = "Report",
            meta = list(
                title = "ignored",
                author = "Jane",
                time = time,
                header = c(left = "L", right = "R"),
                extra = 1:2
            )
        )

        expect_s3_class(doc, c("pub_doc", "pub_node"), exact = TRUE)
        expect_identical(names(doc), c("meta", "children"))
        expect_identical(
            doc$meta,
            list(
                title = "Report",
                author = "Jane",
                time = time,
                header = c(left = "L", right = "R"),
                extra = 1:2
            )
        )
        expect_length(doc$children, 1L)
        expect_identical(pub_doc(subtitle = "S")$meta, list(subtitle = "S"))
    })

    it("takes the title from `meta` if the argument is NULL", {
        doc <- pub_doc(meta = list(title = "M", subtitle = "S"))

        expect_identical(doc$meta, list(title = "M", subtitle = "S"))
        expect_identical(pub_doc()$meta, list())
    })

    it("validates the known metadata keys", {
        expect_error(pub_doc(title = 1), "`title` must be a single string")
        expect_error(pub_doc(meta = list(app = c("a", "b"))), "`app`")
        expect_error(
            pub_doc(meta = list(time = "2026-10-04")),
            "`time` must be a single date-time"
        )
        expect_error(
            pub_doc(meta = list(footer = c(top = "x"))),
            "`footer` must be a character vector named by"
        )
        expect_error(pub_doc(meta = list(header = "x")), "`header`")
        expect_error(pub_doc(meta = list(1)), "`meta` must be a named list")
        expect_error(pub_doc(meta = "x"), "`meta` must be a named list")
        expect_error(pub_doc(meta = NULL), "`meta` must be a named list")
        expect_error(
            pub_doc(meta = list(a = 1, 2)),
            "`meta` must be a named list"
        )
    })

    it("rejects named children and documents as children", {
        expect_error(pub_doc(a = "text"), "must not be named")
        expect_error(pub_doc(pub_doc()), "A document can't be part")
        expect_error(pub_section("A", pub_doc()), "A document can't be part")
        expect_error(
            pub_doc(list(a = pub_doc())),
            "Can't place entry 'a'.",
            fixed = TRUE
        )
        expect_error(pub_doc(list(a = pub_doc())), "A document can't be part")
    })
})

describe("pub_section()", {
    it("holds the title, children and settings", {
        s <- pub_section(
            "Results",
            "Some text",
            numbered = FALSE,
            landscape = TRUE,
            page_break = FALSE,
            on_empty = "keep"
        )

        expect_s3_class(s, c("pub_section", "pub_node"), exact = TRUE)
        expect_identical(s$title, "Results")
        expect_false(s$numbered)
        expect_true(s$landscape)
        expect_false(s$page_break)
        expect_identical(s$on_empty, "keep")
        expect_length(s$children, 1L)
    })

    it("has defaults: numbered, portrait, page break by level, drop", {
        s <- pub_section("A")

        expect_true(s$numbered)
        expect_false(s$landscape)
        expect_null(s$page_break)
        expect_identical(s$on_empty, "drop")
        expect_identical(s$children, list())
    })

    it("validates its arguments", {
        expect_error(pub_section(""), "`title` must be a non-empty string")
        expect_error(pub_section(NA_character_), "`title`")
        expect_error(pub_section("A", numbered = NA), "`numbered` and")
        expect_error(pub_section("A", landscape = "yes"), "`landscape`")
        expect_error(pub_section("A", page_break = 1), "`page_break` must be")
        expect_error(pub_section("A", page_break = NA), "`page_break` must be")
        expect_error(pub_section(c("A", "B")), "`title` must be a non-empty")
        expect_error(pub_section("A", on_empty = "skip"), "`on_empty`")
    })
})


# ------
# Checks
# ------

describe(".check_doc()", {
    it("returns a document invisibly", {
        doc <- pub_doc()

        expect_invisible(.check_doc(doc))
        expect_identical(.check_doc(doc), doc)
    })

    it("rejects other values, naming the caller", {
        render <- function(doc) .check_doc(doc)

        err <- expect_error(render(list()), "`doc` must be a document made by")
        expect_identical(err$call, quote(render(list())))
        expect_error(.check_doc(pub_section("A", "x")), "`doc` must be")
    })
})

describe(".check_doc_meta()", {
    it("rejects times that are missing, not POSIXct or not single", {
        time <- as.POSIXct("2026-10-04 12:00:00", tz = "UTC")

        expect_error(.check_doc_meta(list(time = time[NA])), "`time` must be")
        expect_error(.check_doc_meta(list(time = time + 0:1)), "`time` must be")
        expect_error(.check_doc_meta(list(time = as.Date(time))), "`time` must be")
        expect_invisible(.check_doc_meta(list(time = time)))
    })

    it("checks every known string key and ignores free keys", {
        expect_error(.check_doc_meta(list(subtitle = NA)), "`subtitle`")
        expect_error(.check_doc_meta(list(author = character())), "`author`")
        expect_error(.check_doc_meta(list(version = 1)), "`version`")
        meta <- list(other = 1, version = "1.0")
        expect_identical(.check_doc_meta(meta), meta)
    })

    it("drops blank strings of the known string keys", {
        meta <- list(title = "", author = "  ", app = "a", other = "")
        expect_identical(.check_doc_meta(meta), list(app = "a", other = ""))
        expect_null(pub_doc(title = "")$meta$title)
        expect_null(pub_meta(pub_text("a", title = " "), "title"))
    })
})

describe(".is_head_foot()", {
    it("accepts character named by left, center and right", {
        expect_true(.is_head_foot(c(left = "L", center = "C", right = "R")))
        expect_true(.is_head_foot(c(center = "")))
    })

    it("rejects unnamed, duplicated, unknown, NA or non-character values", {
        expect_false(.is_head_foot("x"))
        expect_false(.is_head_foot(character()))
        expect_false(.is_head_foot(c(left = "a", left = "b")))
        expect_false(.is_head_foot(c(left = "a", middle = "b")))
        expect_false(.is_head_foot(c(left = NA_character_)))
        expect_false(.is_head_foot(list(left = "a")))
        expect_false(.is_head_foot(NULL))
    })
})


# ======================================================================================
# Placing outputs
# ======================================================================================

# --------
# Children
# --------

describe("children of documents and sections", {
    it("rejects children of which only some are named", {
        expect_error(pub_doc("a", b = "x"), "must not be named")
        expect_error(pub_section("A", "a", b = "x"), "must not be named")
    })

    it("accepts children with empty names", {
        doc <- do.call(pub_doc, stats::setNames(list("a", "b"), c("", "")))

        expect_identical(vapply(doc$children, \(x) x$object, ""), c("a", "b"))
    })
})


# -------
# Outputs
# -------

describe("placing outputs", {
    it("wraps outputs into items", {
        s <- pub_section(
            "A",
            pub_text("Hello", title = "T"),
            pub_pagebreak(),
            pub_toc(2),
            pub_raw(md = "---")
        )

        types <- vapply(s$children, \(x) x$type, character(1))
        expect_identical(types, c("text", "pagebreak", "toc", "raw"))
        item <- s$children[[1L]]
        expect_s3_class(item, c("pub_item", "pub_node"), exact = TRUE)
        expect_identical(names(item), c("type", "object", "meta"))
        expect_identical(item$meta, list(title = "T"))
    })

    it("joins text lines and rejects headings", {
        s <- pub_section("A", pub_set_meta(c("a", "b"), title = "T"))

        expect_identical(s$children[[1L]]$object, pub_set_meta("a\nb", title = "T"))
        expect_error(pub_section("A", c("# Head", "text")), "must not contain headings")
        expect_error(pub_section("A", c("a", NA)), "must not contain `NA`")
    })

    it("converts data.frames and matrices to tables, keeping metadata", {
        df <- pub_set_meta(data.frame(a = 1:2), caption = "C", title = "T")

        s <- pub_section("A", df, matrix(1:4, 2L))

        ht <- s$children[[1L]]$object
        expect_true(huxtable::is_huxtable(ht))
        expect_identical(huxtable::caption(ht), "C")
        expect_identical(pub_meta(ht), list(title = "T", caption = "C"))
        expect_identical(s$children[[1L]]$meta, pub_meta(ht))
        expect_identical(pub_cell_text(ht)[, 1L], c("a", "1", "2"))
        expect_true(huxtable::is_huxtable(s$children[[2L]]$object))
    })

    it("expands lists: named elements become sections", {
        s <- pub_section(
            "A",
            list("one", list(B = "two", "three", C = list(D = "four")), NULL)
        )

        kinds <- vapply(s$children, \(x) class(x)[[1L]], character(1))
        expect_identical(kinds, c("pub_item", "pub_section", "pub_item", "pub_section"))
        expect_identical(s$children[[2L]]$title, "B")
        expect_identical(s$children[[2L]]$children[[1L]]$object, "two")
        expect_identical(s$children[[4L]]$children[[1L]]$title, "D")
        expect_identical(pub_section("A", NULL)$children, list())
    })

    it("treats elements with NA names as unnamed", {
        x <- list("a", "b")
        names(x) <- c(NA, "B")

        s <- pub_section("S", x)

        expect_identical(s$children[[1L]]$object, "a")
        expect_identical(s$children[[2L]]$title, "B")
    })

    it("places a table unchanged, keeping its metadata", {
        ht <- pub_set_meta(pub_table(data.frame(a = 1:2)), title = "T")

        item <- pub_section("A", ht)$children[[1L]]

        expect_identical(item$object, ht)
        expect_identical(item$meta, list(title = "T"))
    })

    it("drops named elements that end up empty", {
        s <- pub_section(
            "A",
            list(B = NULL, C = list(D = NULL, E = list()), F = "x")
        )

        expect_length(s$children, 1L)
        expect_identical(s$children[[1L]]$title, "F")
    })

    it("places a partitioned output as one section per key", {
        parts <- structure(
            list(A = "a", B = "b"),
            class = c("list", "pipeflow_partitioned")
        )

        s <- pub_section("S", parts)

        expect_identical(vapply(s$children, \(x) x$title, ""), c("A", "B"))
        expect_identical(s$children[[2L]]$children[[1L]]$object, "b")
        items <- pub_section("S", unname(parts))$children
        expect_identical(vapply(items, \(x) x$object, ""), c("a", "b"))
    })

    it("keeps sections and items, e.g. of another document", {
        doc <- pub_doc(pub_section("A", "x"), "y")

        s <- pub_section("B", doc$children, list(Info = "text"))

        expect_identical(s$children[1:2], doc$children)
        expect_identical(s$children[[3L]]$title, "Info")
        expect_identical(s$children[[3L]]$children[[1L]]$type, "text")
    })

    it("accepts figures", {
        grDevices::pdf(NULL)
        grDevices::dev.control("enable")
        graphics::plot(1:3)
        rp <- grDevices::recordPlot()
        grDevices::dev.off()

        s <- pub_section("A", pub_figure(rp, caption = "Plot"))

        expect_identical(s$children[[1L]]$type, "figure")
        expect_identical(s$children[[1L]]$meta, list(caption = "Plot"))
    })

    it("rejects pipelines with a hint to place their outputs", {
        p <- pipeflow::pip_new("p")

        expect_error(pub_section("A", p), class = "pubflow_pipeline_output")
        err <- expect_error(
            pub_section("A", list(a = list(p))),
            class = "pubflow_pipeline_output"
        )
        expect_identical(err$path, c("a", "1"))
        top <- expect_error(pub_doc(p), class = "pubflow_pipeline_output")
        expect_identical(top$path, character())
        expect_no_match(conditionMessage(top), "entry")
        expect_match(conditionMessage(err), "(entry 'a$1')", fixed = TRUE)
        expect_match(conditionMessage(err), "p[[\"step\", \"out\"]]", fixed = TRUE)
    })

    it("rejects tables without rows or columns", {
        ht <- huxtable::hux(a = 1:2, add_colnames = FALSE)
        expect_error(
            suppressWarnings(pub_doc(ht[integer(0), ])),
            "A table needs at least one row and one column."
        )
        expect_error(pub_doc(ht[, integer(0)]), "at least one row and one column")
    })

    it("rejects unsupported outputs, naming the list entry", {
        expect_error(pub_section("A", 1), class = "pubflow_unsupported_output")
        err <- expect_error(
            pub_section("A", list(b = list(c = TRUE))),
            "Can't place entry 'b$c'.",
            fixed = TRUE
        )
        expect_s3_class(err$parent, "pubflow_unsupported_output")
        expect_error(
            pub_section("A", list("ok", "# Heading")),
            "Can't place entry '2'.",
            fixed = TRUE
        )
    })
})

describe("empty sections", {
    it("are dropped recursively when placed (default)", {
        doc <- pub_doc(
            pub_section("A", pub_section("B", NULL), pub_section("C")),
            pub_section("D", "text")
        )

        expect_length(doc$children, 1L)
        expect_identical(doc$children[[1L]]$title, "D")
    })

    it("are dropped if they hold only blank text", {
        doc <- pub_doc(
            pub_section("A", character()),
            pub_section("B", pub_text(c("", " "))),
            pub_section("C", "", "c")
        )

        expect_length(doc$children, 1L)
        expect_length(doc$children[[1L]]$children, 1L)
        expect_identical(doc$children[[1L]]$children[[1L]]$object, "c")
        titled <- pub_doc(pub_text(character(), title = "Notes"))
        expect_length(titled$children, 1L)
        expect_error(pub_doc(NA_character_), "NA")
        expect_error(pub_section("A", c("", NA_character_)), "NA")
    })

    it("are kept with on_empty = \"keep\"", {
        doc <- pub_doc(pub_section("A", pub_section("B"), on_empty = "keep"))

        expect_identical(doc$children[[1L]]$title, "A")
        expect_identical(doc$children[[1L]]$children, list())
    })

    it("signal an error with on_empty = \"stop\" when placed", {
        s <- pub_section("E", NULL, on_empty = "stop")

        expect_error(pub_section("A", s), "Section 'E' is empty.", fixed = TRUE)
        expect_error(pub_doc(list(x = s)), "Section 'E' is empty.", fixed = TRUE)
        expect_error(pub_doc(list(x = s)), "Can't place entry 'x'.", fixed = TRUE)
        filled <- pub_section("E", "text", on_empty = "stop")
        expect_identical(pub_doc(filled)$children, list(filled))
    })

    it("count as empty if all their children were dropped", {
        s <- pub_section("E", pub_section("B"), list(C = NULL), on_empty = "stop")

        expect_identical(s$children, list())
        expect_error(pub_doc(s), "Section 'E' is empty.", fixed = TRUE)
    })
})


# ------------
# Item content
# ------------

describe("placing failure objects (error items)", {
    error_content <- function(step, failed_step, message) {
        structure(
            list(step = step, failed_step = failed_step, message = message),
            class = "pub_error"
        )
    }

    it("places failure objects as error items with the root message", {
        failures <- demo_failures()

        nodes <- pub_section("Results", unname(failures))$children

        expect_identical(vapply(nodes, \(x) x$type, ""), c("error", "error"))
        expect_identical(
            nodes[[1L]]$object,
            error_content("fit", "fit", "singular fit")
        )
        # 'table' was not run because 'fit' failed
        expect_identical(
            nodes[[2L]]$object,
            error_content("table", "fit", "singular fit")
        )
        expect_identical(nodes[[1L]]$meta, list())
    })

    it("places failures inside lists, also as sections", {
        doc <- pub_doc(demo_failures())

        expect_identical(vapply(doc$children, \(x) x$title, ""), c("fit", "table"))
        expect_identical(doc$children[[2L]]$children[[1L]]$type, "error")
    })

    it("shows the failed step and the message when printed", {
        doc <- pub_doc(pub_section("Fit", demo_failures()$table))

        expect_output(print(doc), "error \"step 'fit' failed: singular fit\"")
    })

    it("places error items of pub_out() with their pipeline", {
        item <- structure(
            list(
                step = "content",
                failed_step = "fit",
                message = "no trend",
                pipeline = "Water"
            ),
            class = "pub_error"
        )

        doc <- pub_doc(list(Assay = "Fine.", Water = item))

        water <- doc$children[[2L]]
        expect_identical(water$title, "Water")
        expect_identical(water$children[[1L]]$type, "error")
        expect_identical(water$children[[1L]]$object, item)
        expect_output(
            print(doc),
            "step 'fit' of pipeline 'Water' failed: no trend",
            fixed = TRUE
        )
    })
})


# -----------
# Error items
# -----------

describe("pub_error_items()", {
    failures <- demo_failures()
    item <- structure(
        list(step = "content", failed_step = "fit", message = "no trend"),
        class = "pub_error"
    )
    steps <- \(errors) vapply(errors, \(x) x$step, "")

    it("finds failures and error items in nested step outputs, in order", {
        parts <- list(
            A = data.frame(x = 1),
            B = list("text", list(failures$fit, NULL)),
            item,
            failures$table
        )

        errors <- pub_error_items(parts)

        expect_identical(steps(errors), c("fit", "content", "table"))
        expect_true(all(vapply(errors, inherits, NA, "pub_error")))
        expect_identical(errors[[1L]]$message, "singular fit")
        expect_identical(errors[[2L]], item)
    })

    it("finds the error items of documents, sections and items", {
        doc <- pub_doc(
            pub_text("ok"),
            pub_section("A", pub_section("B", failures$fit)),
            list(C = item)
        )

        expect_identical(steps(pub_error_items(doc)), c("fit", "content"))
        expect_identical(steps(pub_error_items(doc$children[[2L]])), "fit")
        expect_identical(pub_error_items(doc$children[[3L]]$children[[1L]]), list(item))
    })

    it("converts other objects with as_pub_output(), as a document does", {
        local_as_pub_output_method("fit_result", \(x, ...) unclass(x))
        out <- structure(
            list(tab = data.frame(x = 1), fit = item),
            class = "fit_result"
        )

        expect_identical(pub_error_items(out), list(item))
        expect_error(pub_error_items(structure(1, class = "unknown")), "as_pub_output")
    })

    it("refuses a pipeline, whose outputs are what a document shows", {
        expect_error(
            pub_error_items(list(pipeflow::pip_new("p"))),
            class = "pubflow_pipeline_output"
        )
    })

    it("returns an empty list without error items", {
        expect_identical(pub_error_items(NULL), list())
        expect_identical(pub_error_items(list()), list())
        expect_identical(pub_error_items(pub_doc(pub_text("ok"))), list())
        expect_identical(pub_error_items(list(a = data.frame(x = 1), "b")), list())
    })
})


# ======================================================================================
# Printing
# ======================================================================================

# -------------
# Print methods
# -------------

describe("print()", {
    it("shows an indented tree with item types and labels", {
        doc <- pub_doc(
            pub_section(
                "Introduction",
                pub_text(c(
                    "A first line that is longer than forty characters",
                    "characters and a second line"
                )),
                pub_set_meta(data.frame(a = 1), caption = "Data"),
                pub_section(
                    "Details",
                    "text",
                    numbered = FALSE,
                    landscape = TRUE,
                    page_break = TRUE
                ),
                on_empty = "stop"
            ),
            pub_section(
                "Annex",
                pub_text("x", title = "With \"quotes\""),
                page_break = FALSE
            ),
            pub_pagebreak(),
            title = "Report"
        )

        expect_snapshot(print(doc))
        expect_snapshot(print(doc$children[[2L]]))
        expect_snapshot(print(doc$children[[2L]]$children[[1L]]))
        expect_snapshot(print(pub_doc()))
    })

    it("returns its argument invisibly", {
        doc <- pub_doc(pub_section("A", "text"))
        section <- doc$children[[1L]]

        for (x in list(doc, section, section$children[[1L]])) {
            utils::capture.output(res <- withVisible(print(x)))
            expect_false(res$visible)
            expect_identical(res$value, x)
        }
    })
})


# ----------
# Formatting
# ----------

describe(".format_item()", {
    item <- function(object, type = pub_type(object)) {
        .new_item(type, object)
    }

    it("labels an item by its caption, else its title", {
        x <- pub_set_meta("text", title = "T", caption = "C")

        expect_identical(.format_item(item(x)), "text \"C\"")
        expect_identical(
            .format_item(item(pub_set_meta("x", title = "T"))),
            "text \"T\""
        )
    })

    it("shows the type alone for items without a label", {
        expect_identical(.format_item(item(pub_table(data.frame(a = 1)))), "table")
        expect_identical(.format_item(item(pub_pagebreak())), "pagebreak")
    })

    it("labels error items by the failure, shortened to 60 characters", {
        err <- .pub_error("s", "f", strrep("m", 100L))

        label <- .format_item(item(err, "error"))

        expect_identical(nchar(label), nchar("error \"\"") + 60L)
        expect_match(label, "^error \"step 'f' failed: m+\\.\\.\\.\"$")
    })
})

describe(".section_flags()", {
    it("is empty for the default settings", {
        expect_identical(.section_flags(pub_section("A")), NULL)
    })

    it("names the settings that differ from the defaults", {
        s <- pub_section("A", on_empty = "keep", page_break = TRUE)

        expect_identical(.section_flags(s), c("page break", "on empty: keep"))
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# -------------------------
# Documents of layout steps
# -------------------------

describe("documents made by layout steps (fixtures)", {
    titles <- function(nodes) vapply(nodes, \(x) x$title, character(1))
    items <- function(section) {
        Filter(\(x) inherits(x, "pub_item"), section$children)
    }
    roundtrip <- function(x) {
        file <- withr::local_tempfile(fileext = ".rds")
        without_package_env_warning(saveRDS(x, file))
        readRDS(file)
    }
    is_figure <- function(x) inherits(x, "pub_item") && x$type == "figure"
    without_figures <- function(x) {
        if (inherits(x, "pub_section")) {
            x$children <- lapply(x$children, without_figures)
        }
        if (is_figure(x)) NULL else x
    }
    figure_items <- function(nodes) {
        found <- lapply(nodes, \(x) {
            if (inherits(x, "pub_section")) {
                figure_items(x$children)
            } else if (is_figure(x)) {
                list(x)
            }
        })
        .unlist1(found)
    }
    render_png <- function(x) {
        file <- withr::local_tempfile(fileext = ".png")
        file <- .render_figure(x, file, device = "png", res = 50)
        readBin(file, "raw", file.size(file))
    }

    it("builds the report document", {
        p <- demo_report_pipeline()
        run_quietly(p)

        doc <- p[["doc", "out"]]

        expect_snapshot(print(doc))
        expect_identical(doc$meta$author, "Demo user")
        check <- doc$children[[2L]]$children[[2L]]$object
        expect_identical(huxtable::caption(check), "Predicted values at 12 months")
        expect_identical(
            doc$children[[3L]]$children[[1L]]$object,
            p[["fit_table", "out"]]
        )
        expect_false(reaches_pipeline(doc))
    })

    it("places the outputs of several partitioned steps per batch (split)", {
        p <- demo_split_report_pipeline()
        run_quietly(p)

        doc <- p[["doc", "out"]]

        expect_snapshot(print(doc))
        batches <- doc$children[[2L]]$children
        expect_identical(
            titles(batches),
            c("Batch A (4 values)", "Batch B (4 values)", "Batch C (4 values)")
        )
        for (i in seq_along(batches)) {
            key <- c("A", "B", "C")[[i]]
            parts <- items(batches[[i]])
            expect_identical(parts[[1L]]$object, p[["partition_table", "out"]][[key]])
            expect_identical(parts[[3L]]$object, p[["coef_text", "out"]][[key]])
        }
        reduced <- items(doc$children[[1L]])
        expect_length(reduced, 1L)
        expect_identical(reduced[[1L]]$object, p[["summary_table", "out"]])
        expect_identical(titles(doc$children[[3L]]$children), c("A", "B", "C"))
        expect_false(reaches_pipeline(doc))
    })

    it("places one section per inner pipeline (nested)", {
        p <- demo_nested_report_pipeline()
        run_quietly(p)

        doc <- p[["doc", "out"]]

        expect_snapshot(print(doc))
        expect_identical(titles(doc$children[2:4]), c("Batch A", "Batch B", "Batch C"))
        res <- p[["inner_run", "out"]]
        for (i in 2:4) {
            key <- c("A", "B", "C")[[i - 1L]]
            parts <- items(doc$children[[i]])
            expect_identical(parts[[1L]]$object, res[[key]]$fit_table)
            expect_identical(parts[[3L]]$object, res[[key]]$note)
        }
        expect_false(reaches_pipeline(doc))
    })

    it("assembles one section per pipeline of a list (one per test)", {
        doc <- demo_tests_doc()

        expect_snapshot(print(doc))
        expect_identical(titles(doc$children), c("Assay", "Water"))
        expect_false(reaches_pipeline(doc))
    })

    it("builds a report across the test pipelines", {
        doc <- demo_tests_report_doc()

        expect_snapshot(print(doc))
        expect_identical(titles(doc$children), c("Results", "Summary"))
        expect_identical(titles(doc$children[[1L]]$children), c("Assay", "Water"))
        slopes <- doc$children[[2L]]$children[[1L]]$object
        expect_identical(
            pub_cell_text(slopes)[-1L, 1L],
            rep(c("Assay", "Water"), each = 3L)
        )
        expect_false(reaches_pipeline(doc))
    })

    it("keeps the report done if the parts are set again unchanged", {
        pips <- demo_test_pipelines()
        for (p in pips) {
            run_quietly(p)
        }
        report <- demo_tests_report_pipeline()
        pipeflow::pip_set_params(report, demo_test_parts(pips))
        run_quietly(report)

        pipeflow::pip_set_params(report, demo_test_parts(pips))
        expect_true(all(report[["state"]] == "done"))

        pipeflow::pip_set_params(pips$Water, list(decimals = "3"))
        run_quietly(pips$Water)
        pipeflow::pip_set_params(report, demo_test_parts(pips))
        expect_identical(report[["tests", "state"]], "outdated")
        expect_identical(report[["fits", "state"]], "done")
    })

    it("shows a failed test as an error box in the report on request", {
        pips <- demo_test_pipelines()
        pipeflow::pip_replace(pips$Water, "fit", \(data = ~data) {
            stop("no trend")
        })
        for (p in pips) {
            suppressWarnings(
                run_quietly(p, on_error = "continue"),
                classes = "pipeflow_run_failed"
            )
        }

        expect_error(
            demo_test_parts(pips),
            "Step 'fit' failed: no trend",
            class = "pubflow_not_done"
        )
        parts <- lapply(pips, pub_out, step = "content", on_error = "item")
        doc <- pub_doc(parts)

        error <- doc$children[[2L]]$children[[1L]]
        expect_identical(error$type, "error")
        expect_identical(error$object$pipeline, "test Water")
        expect_identical(error$object$failed_step, "fit")
        expect_error(
            pub_render(doc, "md", file = withr::local_tempfile()),
            "step 'fit' of pipeline 'test Water' failed: no trend",
            fixed = TRUE
        )
    })

    it("places the failures of a report run with on_error = \"continue\"", {
        doc <- demo_failed_report_doc()

        expect_snapshot(print(doc))
        criteria <- doc$children[[4L]]
        expect_identical(criteria$title, "Criteria")
        error <- criteria$children[[2L]]
        expect_identical(error$type, "error")
        # 'check' failed, so 'check_text' was not run
        expect_identical(error$object$step, "check_text")
        expect_identical(error$object$failed_step, "check")
        expect_identical(error$object$message, "check failed on request")
        expect_false(reaches_pipeline(doc))
    })

    it("places a failed partition as an error box in its own section", {
        # pipeflow fails a mapped step per key (0.5.0.9015): the batches that succeeded
        # keep their tables, the failed one gets the box
        p <- demo_split_report_pipeline()
        pipeflow::pip_set_params(p, list(failBatch = "B"))

        expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )

        expect_identical(p[["partition_table", "state"]], "failed")
        expect_identical(p[["doc", "state"]], "done")
        doc <- p[["doc", "out"]]
        expect_s3_class(doc, "pub_doc")
        batches <- doc$children[[2L]]$children
        types <- vapply(batches, \(b) b$children[[1L]]$type, character(1))
        expect_identical(types, c("table", "error", "table"))
        expect_identical(
            batches[[2L]]$children[[1L]]$object$message,
            "key 'B': no table for batch B"
        )
    })

    it("reduces per-partition layouts with a failed partition", {
        # 'section' runs per key and gets the failure of key 'b' only
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("split", \(x = 1) list(a = 1, b = 2), exec = "split") |>
            pipeflow::pip_add("calc", \(v = ~split) {
                if (v > 1) stop("too big") else pub_text(paste("Value", v))
            }) |>
            pipeflow::pip_add("section", \(v = ~ try(calc)) {
                pub_section("Value", v)
            }) |>
            pipeflow::pip_add(
                "doc",
                \(s = ~ try(section)) pub_doc(unname(s)),
                exec = "reduce"
            )

        expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )

        expect_identical(p[["doc", "state"]], "done")
        sections <- p[["doc", "out"]]$children
        types <- vapply(sections, \(s) s$children[[1L]]$type, character(1))
        expect_identical(types, c("text", "error"))
        error <- sections[[2L]]$children[[1L]]
        expect_identical(error$object$failed_step, "calc")
        expect_identical(error$object$message, "key 'b': too big")
    })

    it("places a failed partition in a reduce layout step", {
        # the reduce step gets the partitioned output with the failure in key 'b' (one
        # sub-section per key)
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("split", \(x = 1) list(a = 1, b = 2), exec = "split") |>
            pipeflow::pip_add("calc", \(v = ~split) {
                if (v > 1) stop("too big") else pub_text(paste("Value", v))
            }) |>
            pipeflow::pip_add(
                "doc",
                \(v = ~ try(calc)) {
                    pub_doc(pub_section("Values", v))
                },
                exec = "reduce"
            )

        expect_warning(
            run_quietly(p, on_error = "continue"),
            class = "pipeflow_run_failed"
        )

        doc <- p[["doc", "out"]]
        expect_s3_class(doc, "pub_doc")
        keys <- doc$children[[1L]]$children
        expect_identical(vapply(keys, \(k) k$title, character(1)), c("a", "b"))
        expect_identical(keys[[1L]]$children[[1L]]$type, "text")
        error <- keys[[2L]]$children[[1L]]
        expect_identical(error$type, "error")
        expect_identical(error$object$failed_step, "calc")
        expect_identical(error$object$message, "key 'b': too big")
    })

    it("fails a layout step that places a pipeline, with the hint", {
        p <- pipeflow::pip_new("p") |>
            pipeflow::pip_add("pips", \() list(A = demo_inner_pipeline())) |>
            pipeflow::pip_add("doc", \(pips = ~pips) pub_doc(pips))

        expect_error(run_quietly(p), "Place the outputs of its steps instead")
    })

    it("builds documents that survive saveRDS() and readRDS()", {
        docs <- list(
            demo_report_doc(),
            demo_split_doc(),
            demo_nested_doc(),
            demo_tests_doc(),
            demo_tests_report_doc(),
            demo_failed_report_doc()
        )

        for (doc in docs) {
            restored <- roundtrip(doc)

            expect_identical(
                utils::capture.output(print(restored)),
                utils::capture.output(print(doc))
            )
            expect_identical(
                lapply(restored$children, without_figures),
                lapply(doc$children, without_figures)
            )
            # ggplots hold environments (compared by reference): compare the rest of the
            # item and the rendered image
            before <- figure_items(doc$children)
            after <- figure_items(restored$children)
            expect_identical(lapply(after, \(x) x[-2L]), lapply(before, \(x) x[-2L]))
            expect_identical(
                lapply(after, \(x) render_png(x$object)),
                lapply(before, \(x) render_png(x$object))
            )
        }
    })
})
