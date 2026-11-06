# DOCX post-processors: the header and footer lines of the document at the bookmarks of
# the reference document, and locked content controls around the headers and footers
# (pub_markdown() writes those of the tables and figures). Both edit the parts of the
# file with xml2 (no officer): nodes are moved, not copied, so no namespace declarations
# are added, and the parts are written as read (`as_xml`). pub_render() applies both to
# DOCX reports.

# ======================================================================================
# Post-processors
# ======================================================================================

# ------------
# Constructors
# ------------
#' DOCX post-processors
#'
#' Post-processors of DOCX reports (see `post_process` in [pub_report_spec()]) that
#' write the header and footer lines and lock them.
#'
#' @details
#' ## Functions
#'
#' * `pub_pp_docx_header_footer()` writes the header and footer lines of the document
#'   into the header and footer of the file, as the PDF report shows them.
#' * `pub_pp_docx_lock()` locks the headers and footers against accidental editing and
#'   deletion.
#'
#' [pub_render()] applies both to every DOCX report (the lock if the spec's `lock` is
#' `TRUE`), before the spec's own post-processors. To give one of them other
#' arguments or another place among the others, list it in the spec's `post_process`.
#' It is then not added again (see Examples).
#'
#' ## Header and footer lines
#'
#' The lines are the entries `header` and `footer` of the document's metadata (see
#' [pub_doc()]), each with the parts `left`, `center` and `right`. A part goes into the
#' bookmark of the same name in the file: `header_left`, `header_center`,
#' `header_right`, `footer_left`, `footer_center` or `footer_right`.
#'
#' * `{trace}` becomes the trace stamp (see [pub_trace_stamp()]) and line breaks become
#'   spaces.
#' * The text takes the format of the first run in the bookmark that has one.
#' * It goes into every header and footer of the file that has the bookmark. Settings of
#'   the reference document (e.g. different first or even pages) are kept.
#' * A part that isn't empty is an error if no header or footer has its bookmark.
#' * In pubflow's reference document, `footer_right` holds "Page x / N". So a right
#'   footer line replaces the page number, as in PDF (an empty one removes it).
#'
#' ## Locks
#'
#' `pub_pp_docx_lock()` locks everything in every header and footer, also the content of
#' the reference document such as "Page x / N". Tables and figures are locked by
#' [pub_markdown()] itself: with the spec's `lock = TRUE` all but those with
#' `pub_set_meta(locked = FALSE)`, otherwise those with `pub_set_meta(locked = TRUE)`.
#' Applying the post-processor twice changes nothing.
#'
#' The locks only guard against accidental changes: Word lets users remove them in the
#' properties of a content control.
#'
#' @param header,footer Named character vector of lines like the document's metadata
#'   `header` and `footer` (names `left`, `center`, `right`), or `NULL` (use the
#'   document's lines). A vector replaces the document's lines as a whole;
#'   `character()` writes none.
#' @return A post-processor: `function(path, doc, spec)` that changes the DOCX file
#'   `path` in place (`doc` is the document with the render-time metadata).
#' @seealso [pub_report_spec()], [pub_render()], [pub_trace_stamp()]
#' @examples
#' doc <- pub_doc(meta = list(
#'     author = "Jane Doe",
#'     time = as.POSIXct("2026-10-08 12:00:00", tz = "UTC"),
#'     footer = c(left = "{trace}")
#' ))
#' # A DOCX file with the bookmarks: a copy of pubflow's reference document
#' path <- tempfile(fileext = ".docx")
#' file.copy(system.file("templates", "reference.docx", package = "pubflow"),
#'           path)
#' fill <- pub_pp_docx_header_footer(header = c(left = "Draft",
#'                                              right = "Batch A"))
#' fill(path, doc, pub_report_spec("docx"))
#'
#' # In a spec: another header in DOCX reports, the lock after the spec's
#' # own post-processor
#' log_file <- function(path, doc, spec) message("Rendered ", path)
#' spec <- pub_report_spec("docx", post_process = list(
#'     pub_pp_docx_header_footer(header = c(left = "Draft")),
#'     log_file,
#'     pub_pp_docx_lock()
#' ))
#' spec
#' @name pub_pp_docx
NULL

#' @rdname pub_pp_docx
#' @export
pub_pp_docx_header_footer <- function(header = NULL, footer = NULL) {
    .check_pp_lines(header, "header")
    .check_pp_lines(footer, "footer")
    pp <- function(path, doc, spec) {
        lines <- list(
            header = header %||% doc$meta[["header"]],
            footer = footer %||% doc$meta[["footer"]]
        )
        values <- .docx_bookmark_values(lines, doc$meta)
        if (length(values) > 0L) {
            .docx_edit(path, \(dir) .docx_fill_bookmarks(dir, values))
        }
        invisible(path)
    }
    structure(pp, class = c("pub_pp_docx_header_footer", "function"))
}

#' @rdname pub_pp_docx
#' @export
pub_pp_docx_lock <- function() {
    pp <- function(path, doc, spec) {
        .docx_edit(path, .docx_lock_dir)
        invisible(path)
    }
    structure(pp, class = c("pub_pp_docx_lock", "function"))
}

#' Check the `header` or `footer` argument of `pub_pp_docx_header_footer()`
#' @param x `NULL`, `character()` or named header or footer lines.
#' @param arg name of the argument, for the error message.
#' @param call the environment of the caller, for the error message.
#' @return `x`, invisibly.
#' @noRd
.check_pp_lines <- function(x, arg, call = rlang::caller_env()) {
    ok <- is.null(x) || identical(x, character()) || .is_head_foot(x)
    if (!ok) {
        rlang::abort(
            sprintf(
                paste(
                    "`%s` must be `NULL` or a character vector named by \"left\",",
                    "\"center\" and \"right\"."
                ),
                arg
            ),
            call = call
        )
    }
    invisible(x)
}


# ------------------
# Editing DOCX files
# ------------------
#' Namespace of WordprocessingML
#' @noRd
.w_ns <- c(
    w = paste0("http://schemas.openxmlformats.org/", "wordprocessingml/2006/main")
)

#' Unpack a DOCX file, change its parts and pack it again
#'
#' @param path path of the DOCX file (changed in place).
#' @param fun `function(dir)` changing the files of the unpacked directory; returns
#'   `TRUE` if it changed any (else the file is left as-is).
#' @noRd
.docx_edit <- function(path, fun) {
    dir <- tempfile("pubflow-docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, exdir = dir)
    changed <- fun(dir)
    if (isTRUE(changed)) {
        .zip_dir(dir, path)
    }
    invisible(changed)
}

#' Paths of the header and footer parts of an unpacked DOCX file
#'
#' The targets of the document's header and footer relationships: pandoc keeps the part
#' names of the reference document, which need not be `header1.xml`. A file without
#' relationships (pandoc always writes them) has none.
#' @param dir directory of the unpacked DOCX file.
#' @return `character` named by the kind of part (`header` or `footer`).
#' @noRd
.docx_header_footer_parts <- function(dir) {
    relsFile <- file.path(dir, "word", "_rels", "document.xml.rels")
    if (!file.exists(relsFile)) {
        return(rlang::set_names(character(), character()))
    }
    rels <- xml2::read_xml(relsFile)
    nodes <- xml2::xml_find_all(rels, "/*/*[local-name() = 'Relationship']")
    kind <- basename(xml2::xml_attr(nodes, "Type"))
    target <- xml2::xml_attr(nodes, "Target")
    keep <- kind %in% c("header", "footer") & !duplicated(target)
    # a target is relative to word/, or to the package if it starts with /
    paths <- ifelse(
        startsWith(target, "/"),
        file.path(dir, target),
        file.path(dir, "word", target)
    )
    rlang::set_names(paths[keep], kind[keep])
}

#' Content control ids of the parts of an unpacked DOCX file other than `skip` (e.g. the
#' body, footnotes, comments, the glossary)
#' @param dir directory of the unpacked DOCX file.
#' @param skip paths of the parts to leave out.
#' @return `numeric` ids.
#' @noRd
.docx_other_sdt_ids <- function(dir, skip) {
    files <- list.files(
        file.path(dir, "word"),
        "\\.xml$",
        recursive = TRUE,
        full.names = TRUE
    )
    files <- files[!normalizePath(files) %in% normalizePath(skip)]
    unlist(lapply(files, \(file) .docx_sdt_ids(xml2::read_xml(file))))
}


# ======================================================================================
# Header and footer
# ======================================================================================

# ---------
# Bookmarks
# ---------
#' Text per bookmark (`header_left`, ...): lines with `{trace}` expanded, each on one
#' line
#' @param lines `list(header, footer)` of named character lines.
#' @param meta metadata of the document (for the trace stamp).
#' @return named `character`: text per bookmark name.
#' @noRd
.docx_bookmark_values <- function(lines, meta) {
    values <- character()
    for (part in names(lines)) {
        x <- .expand_trace(lines[[part]], meta, format = "docx")
        if (length(x) > 0L) {
            values <- c(
                values,
                rlang::set_names(
                    .one_line(x),
                    paste(part, names(x), sep = "_")
                )
            )
        }
    }
    values
}

#' Set the text of bookmarks in the header and footer parts
#'
#' @param dir directory of the unpacked DOCX file.
#' @param values named `character`: text per bookmark name.
#' @return `TRUE`; an error naming the bookmarks of non-empty values that no part has.
#' @noRd
.docx_fill_bookmarks <- function(dir, values) {
    found <- character()
    for (file in .docx_header_footer_parts(dir)) {
        xml <- xml2::read_xml(file)
        hits <- vapply(
            names(values),
            \(name) {
                .docx_set_bookmark(xml, name, values[[name]])
            },
            logical(1)
        )
        if (any(hits)) {
            xml2::write_xml(xml, file, options = "as_xml")
        }
        found <- c(found, names(values)[hits])
    }
    missing <- setdiff(names(values)[nzchar(values)], found)
    if (length(missing) > 0L) {
        rlang::abort(c(
            paste(
                "The header and footer of the reference document have no",
                "bookmark for these lines:"
            ),
            rlang::set_names(missing, rep("x", length(missing))),
            i = paste(
                "Add the bookmarks to the reference document's header",
                "or footer, or leave these lines out."
            )
        ))
    }
    TRUE
}

#' Replace the runs of a bookmark by one run with `text`
#'
#' The new run keeps the run properties of the first old one. The bookmark must start
#' and end in the same paragraph.
#' @param xml a header or footer part (changed in place).
#' @param name name of the bookmark.
#' @param text `character(1)` new text.
#' @return `TRUE` if the part has the bookmark.
#' @noRd
.docx_set_bookmark <- function(xml, name, text) {
    start <- xml2::xml_find_first(
        xml,
        sprintf("//w:bookmarkStart[@w:name = '%s']", name),
        .w_ns
    )
    if (inherits(start, "xml_missing")) {
        return(FALSE)
    }
    id <- xml2::xml_attr(start, "w:id", ns = .w_ns)
    # all content up to the end (runs, also in hyperlinks or simple fields), except the
    # marks of other bookmarks
    old <- xml2::xml_find_all(
        start,
        sprintf(
            paste0(
                "following-sibling::*[not(self::w:bookmarkStart or ",
                "self::w:bookmarkEnd)][following-sibling::",
                "w:bookmarkEnd[@w:id = '%s']]"
            ),
            id
        ),
        .w_ns
    )
    run <- xml2::xml_add_sibling(start, "w:r", .where = "after")
    rPr <- xml2::xml_find_first(old, "descendant-or-self::w:r/w:rPr", .w_ns)
    rPr <- Find(\(x) !inherits(x, "xml_missing"), as.list(rPr))
    if (!is.null(rPr)) {
        xml2::xml_remove(rPr, free = FALSE)
        xml2::xml_add_child(run, rPr, .copy = FALSE)
    }
    t <- xml2::xml_add_child(run, "w:t", text)
    xml2::xml_set_attr(t, "xml:space", "preserve")
    xml2::xml_remove(old)
    TRUE
}


# ======================================================================================
# Lock
# ======================================================================================

# ----------------
# Content controls
# ----------------
#' Lock the headers and footers of an unpacked DOCX file
#'
#' The ids of the new content controls follow the largest id in the parts of the file
#' (e.g. those of controls in raw content).
#' @param dir directory of the unpacked DOCX file.
#' @return `TRUE` if a part changed.
#' @noRd
.docx_lock_dir <- function(dir) {
    partFiles <- .docx_header_footer_parts(dir)
    parts <- lapply(partFiles, xml2::read_xml)
    last <- max(c(
        0,
        unlist(lapply(parts, .docx_sdt_ids)),
        .docx_other_sdt_ids(dir, partFiles)
    ))
    changed <- FALSE
    for (i in seq_along(parts)) {
        tag <- paste0("locked-", names(partFiles)[[i]])
        if (.docx_lock_part(parts[[i]], tag, last + 1)) {
            last <- last + 1
            xml2::write_xml(parts[[i]], partFiles[[i]], options = "as_xml")
            changed <- TRUE
        }
    }
    changed
}

#' Wrap the content of a header or footer part into one locked content control
#' @param xml a header or footer part (changed in place).
#' @param tag tag of the content control (`locked-header` or `locked-footer`).
#' @param id id of the content control.
#' @return `TRUE` if wrapped; `FALSE` for an empty part or one whose content is locked
#'   already.
#' @noRd
.docx_lock_part <- function(xml, tag, id) {
    children <- xml2::xml_children(xml2::xml_root(xml))
    locked <- xml2::xml_find_first(
        xml,
        sprintf(
            "/*[count(*) = 1]/w:sdt[w:sdtPr/w:tag/@w:val = '%s']",
            tag
        ),
        .w_ns
    )
    if (length(children) == 0L || !inherits(locked, "xml_missing")) {
        return(FALSE)
    }
    .docx_wrap_sdt(children, tag, id)
    TRUE
}

#' Ids of the content controls of a part
#' @param xml a part of a DOCX file.
#' @return `numeric` ids; ids that aren't numbers are left out.
#' @noRd
.docx_sdt_ids <- function(xml) {
    ids <- xml2::xml_attr(
        xml2::xml_find_all(xml, "//w:sdtPr/w:id", .w_ns),
        "w:val",
        ns = .w_ns
    )
    ids <- suppressWarnings(as.numeric(ids))
    ids[!is.na(ids)]
}

#' Wrap blocks (the content of a header or footer) into one locked content control
#'
#' The `w:sdt` is built in place before the first node, and the nodes are then moved
#' into it: copies would get their own namespace declarations.
#' @param nodes sibling nodes (`xml_nodeset`).
#' @param tag tag of the content control.
#' @param id id of the content control.
#' @return the `w:sdt` node, invisibly.
#' @noRd
.docx_wrap_sdt <- function(nodes, tag, id) {
    sdt <- xml2::xml_add_sibling(nodes[[1L]], "w:sdt", .where = "before")
    pr <- xml2::xml_add_child(sdt, "w:sdtPr")
    xml2::xml_set_attr(xml2::xml_add_child(pr, "w:tag"), "w:val", tag)
    xml2::xml_set_attr(
        xml2::xml_add_child(pr, "w:id"),
        "w:val",
        format(id, scientific = FALSE)
    )
    xml2::xml_set_attr(xml2::xml_add_child(pr, "w:lock"), "w:val", "sdtContentLocked")
    content <- xml2::xml_add_child(sdt, "w:sdtContent")
    for (node in nodes) {
        xml2::xml_remove(node, free = FALSE)
        xml2::xml_add_child(content, node, .copy = FALSE)
    }
    invisible(sdt)
}
