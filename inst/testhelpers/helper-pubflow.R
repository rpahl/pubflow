# Test helpers for pubflow outputs, to copy into an app's tests/testthat/ folder
# (testthat sources helper-*.R before the tests). Find the file of the installed
# package with system.file("testhelpers", "helper-pubflow.R", package = "pubflow").
# The helpers use pubflow's exported functions and read the nodes of a document
# (fields title, children, type and meta), so they follow pubflow's document structure.
# Tables must be built by pubflow::pub_table(). Needs huxtable and testthat, and zip
# and xml2 for docx_xml().

# ======================================================================================
# Tables
# ======================================================================================

# Displayed text of the body cells: a data.frame of character columns
table_cells <- function(ht) {
    rows <- pubflow::pub_table_rows(ht)
    text <- pubflow::pub_cell_text(ht)[rows$body, , drop = FALSE]
    colnames(text) <- names(ht)
    as.data.frame(text, stringsAsFactors = FALSE)
}

# Column labels (the last header row): a character vector named by column
table_labels <- function(ht) {
    labelRow <- max(pubflow::pub_table_rows(ht)$header)
    stats::setNames(pubflow::pub_cell_text(ht)[labelRow, ], names(ht))
}

# Labels of the first spanner row ("" where a column has none), or NULL without one
table_spanners <- function(ht) {
    rows <- pubflow::pub_table_rows(ht)
    if (length(rows$spanner) == 0L) {
        return(NULL)
    }
    stats::setNames(pubflow::pub_cell_text(ht)[rows$spanner[[1L]], ], names(ht))
}

# Text of the footnote rows (character(0) without footnotes)
table_footnotes <- function(ht) {
    rows <- pubflow::pub_table_rows(ht)$footnote
    as.character(pubflow::pub_cell_text(ht)[rows, 1L])
}

# A style of the body cells, e.g. fun = huxtable::bold: a matrix named by column
table_style <- function(ht, fun = huxtable::text_color) {
    body <- pubflow::pub_table_rows(ht)$body
    style <- fun(ht)[body, , drop = FALSE]
    dimnames(style) <- list(NULL, names(ht))
    style
}

# The distinct numbers of decimal places in the body cells of a column, ignoring
# cells without a number (NA marks, text)
table_decimals <- function(ht, col) {
    cells <- table_cells(ht)[[col]]
    numbers <- cells[grepl("^[-+\u2212]?[0-9]*[.,]?[0-9]+$", cells)]
    unique(nchar(sub("^[^.,]*[.,]?", "", numbers)))
}

# ======================================================================================
# Documents
# ======================================================================================

# Titles of the sections directly below a document or section
section_titles <- function(node) {
    sections <- Filter(\(x) inherits(x, "pub_section"), node[["children"]])
    vapply(sections, \(x) x[["title"]], character(1L))
}

# Types of the children of a document or section, e.g. c("table", "section")
child_types <- function(node) {
    vapply(
        node[["children"]],
        \(x) {
            if (inherits(x, "pub_item")) x[["type"]] else "section"
        },
        character(1L)
    )
}

# Subsection by the path of its titles: section_of(doc, "Study", "Deviations")
section_of <- function(node, ...) {
    for (title in c(...)) {
        node <- Find(
            \(x) inherits(x, "pub_section") && identical(x[["title"]], title),
            node[["children"]]
        )
        if (is.null(node)) {
            stop("No section \"", title, "\".", call. = FALSE)
        }
    }
    node
}

# The items (outputs) of a document or section, in order, also those of subsections,
# optionally only of the given types (e.g. c("table", "figure"))
doc_items <- function(node, types = NULL) {
    items <- lapply(node[["children"]], \(child) {
        if (inherits(child, "pub_section")) {
            doc_items(child, types)
        } else if (is.null(types) || pubflow::pub_type(child[["object"]]) %in% types) {
            list(child)
        }
    })
    unlist(items, recursive = FALSE)
}

# Expect at least one item and all of them marked locked (meta locked = TRUE, which
# locks them in DOCX; see doc_items())
expect_all_locked <- function(items) {
    locked <- vapply(
        items,
        \(x) isTRUE(x[["meta"]][["locked"]]),
        logical(1L)
    )
    testthat::expect(
        length(items) > 0L && all(locked),
        if (length(items) == 0L) {
            "There are no items."
        } else {
            paste0(sum(!locked), " of ", length(items), " items are not locked.")
        }
    )
}

# ======================================================================================
# Word files
# ======================================================================================

# A part of a DOCX file as an xml2 document (word/document.xml by default)
docx_xml <- function(path, part = "word/document.xml") {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, files = part, exdir = dir)
    xml2::read_xml(file.path(dir, part))
}
