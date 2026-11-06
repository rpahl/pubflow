# DOCX and Markdown files: pub_markdown() writes the Markdown and the figures into the
# work directory, pandoc makes the DOCX with the reference document in one call, and the
# section breaks of landscape parts are completed from the reference's page setup (or
# the spec's page). pandoc's options go into a defaults file (YAML), so the document
# header reaches pandoc as literal metadata strings and nothing depends on shell
# quoting.

# ======================================================================================
# DOCX files
# ======================================================================================

# ------
# Render
# ------
#' Render a document to DOCX in a work directory
#'
#' Front matter replaces pandoc's title block: the title and author then go into the
#' file's properties only.
#' @param doc a `pub_doc`.
#' @param settings settings of the target (`.render_settings()`).
#' @param cache a `pub_cache` or `NULL`.
#' @param work work directory: the Markdown, the figures and the DOCX go there.
#' @param quiet `TRUE` to hide pandoc's messages.
#' @param front nodes of the front matter or `NULL`.
#' @param call the environment of the caller, for error messages.
#' @return path of the DOCX file.
#' @noRd
.render_docx <- function(doc, settings, cache, work, quiet, front, call) {
    input <- file.path(work, "document.md")
    md <- .markdown_doc(doc, settings, file.path(work, "document_files"), cache, front)
    writeLines(enc2utf8(md), input, useBytes = TRUE)
    output <- file.path(work, "document.docx")
    .run_pandoc(
        list(
            from = .pandoc_reader(),
            to = "docx",
            `input-files` = input,
            `output-file` = output,
            `reference-doc` = settings$reference_docx,
            `resource-path` = work,
            metadata = if (is.null(front)) .pandoc_metadata(doc$meta)
        ),
        work,
        format = "docx",
        quiet = quiet,
        call = call,
        args = settings$pandoc_args
    )
    properties <- if (!is.null(front)) {
        list(title = doc$meta[["title"]], creator = doc$meta[["author"]])
    }
    .docx_complete_sections(output, page = settings$page, properties = properties)
    output
}


# ======================================================================================
# Page setup and properties
# ======================================================================================

# ----------
# Page setup
# ----------
#' Page setup of a DOCX file's last section (in twips)
#'
#' Missing values default to A4 with 2.5 cm margins.
#' @param path path of the DOCX file.
#' @return `list(width, height, left, right)`.
#' @noRd
.docx_page <- function(path) {
    dir <- tempfile("pubflow-docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, files = "word/document.xml", exdir = dir)
    xml <- xml2::read_xml(file.path(dir, "word", "document.xml"))
    ns <- xml2::xml_ns(xml)
    sect <- xml2::xml_find_first(xml, "/w:document/w:body/w:sectPr", ns)
    value <- function(node, attr, default) {
        x <- suppressWarnings(as.numeric(xml2::xml_attr(
            xml2::xml_find_first(sect, node, ns),
            attr,
            ns = ns
        )))
        if (length(x) == 1L && is.finite(x)) x else default
    }
    list(
        width = value("w:pgSz", "w:w", 11906),
        height = value("w:pgSz", "w:h", 16838),
        left = value("w:pgMar", "w:left", 1417),
        right = value("w:pgMar", "w:right", 1417)
    )
}

#' Text width of portrait and landscape pages (twips; margins as on portrait pages)
#'
#' @param path reference document, whose page is used without `page`.
#' @param page page settings in cm (`.render_settings()`): the widths come from the
#'   rounded twips that `.docx_complete_sections()` writes. A turned page's width is its
#'   normal width ("portrait").
#' @noRd
.docx_text_width <- function(path, page = NULL) {
    if (!is.null(page)) {
        tw <- .docx_twips(page)
        margins <- tw[["left"]] + tw[["right"]]
        return(c(
            portrait = as.integer(tw[["width"]] - margins),
            landscape = as.integer(tw[["height"]] - margins)
        ))
    }
    page <- .docx_page(path)
    margins <- page$left + page$right
    c(
        portrait = as.integer(min(page$width, page$height) - margins),
        landscape = as.integer(max(page$width, page$height) - margins)
    )
}

#' Page size and margins in whole twips (1 cm = 1440 / 2.54 twips)
#' @param page page settings in cm (`.render_settings()`).
#' @return named numeric: `width`, `height`, `top`, `bottom`, `left`, `right`.
#' @noRd
.docx_twips <- function(page) {
    cm <- unlist(page[c("width", "height", "top", "bottom", "left", "right")])
    round(cm * 1440 / 2.54)
}


# --------------
# Section breaks
# --------------
#' Complete the section breaks of a DOCX file written by pandoc
#'
#' `pub_markdown()` ends each part of one orientation with a section break (`w:sectPr`
#' in a paragraph) that only gives the orientation. Each gets the properties of the
#' document's last section, which pandoc copies from the reference document (page size,
#' margins, header and footer), with width and height swapped for landscape parts. A
#' different first page (`w:titlePg`) stays with the first section only. A break at the
#' end of the document makes the last section landscape instead.
#'
#' @param path path of the DOCX file, changed in place.
#' @param page page settings of a spec (`.render_settings()`) or `NULL`: they replace
#'   the page size and margins of the last section first (header and footer distances
#'   and the gutter are kept), so they reach every section; a turned page makes it
#'   landscape.
#' @param properties `list(title, creator)` for `docProps/core.xml` (the document's
#'   title and author when front matter replaces the title block) or `NULL`.
#' @return `path`, invisibly.
#' @noRd
.docx_complete_sections <- function(path, page = NULL, properties = NULL) {
    dir <- tempfile("pubflow-docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, files = "word/document.xml", exdir = dir)
    file <- file.path(dir, "word", "document.xml")
    xml <- xml2::read_xml(file)
    ns <- xml2::xml_ns(xml)
    body <- xml2::xml_find_first(xml, "/w:document/w:body", ns)
    breaks <- xml2::xml_find_all(body, "w:p/w:pPr/w:sectPr", ns)
    properties <- Filter(Negate(is.null), properties)
    if (length(breaks) == 0L && is.null(page) && length(properties) == 0L) {
        return(invisible(path))
    }
    last <- xml2::xml_find_first(body, "w:sectPr", ns)
    if (!is.null(page)) {
        .docx_set_page(last, page, ns)
    }
    .docx_copy_sections(body, breaks, last, ns)
    zip::unzip(path, exdir = dir)
    xml2::write_xml(xml, file, options = "as_xml")
    if (length(properties) > 0L) {
        .docx_set_properties(file.path(dir, "docProps", "core.xml"), properties)
    }
    .zip_dir(dir, path)
    invisible(path)
}

#' Copy the last section's properties into the section breaks (see
#' `.docx_complete_sections()`)
#' @param body the `w:body` node.
#' @param breaks the `w:sectPr` nodes of the section breaks (in paragraphs).
#' @param last the body's `w:sectPr` (the last section).
#' @param ns namespaces of the document.
#' @noRd
.docx_copy_sections <- function(body, breaks, last, ns) {
    if (length(breaks) == 0L) {
        return(invisible())
    }
    lastBreak <- breaks[[length(breaks)]]
    paragraph <- xml2::xml_parent(xml2::xml_parent(lastBreak))
    following <- xml2::xml_find_all(paragraph, "following-sibling::*")
    if (length(following) == 1L) {
        # only the body's w:sectPr follows
        .set_orientation(last, .is_landscape(lastBreak, ns), ns)
        xml2::xml_remove(paragraph)
        breaks <- breaks[-length(breaks)]
    }
    for (i in seq_along(breaks)) {
        landscape <- .is_landscape(breaks[[i]], ns)
        xml2::xml_remove(xml2::xml_children(breaks[[i]]))
        for (child in xml2::xml_children(last)) {
            xml2::xml_add_child(breaks[[i]], child)
        }
        .set_orientation(breaks[[i]], landscape, ns)
        if (i > 1L) {
            xml2::xml_remove(xml2::xml_find_all(breaks[[i]], "w:titlePg", ns))
        }
    }
    if (length(breaks) > 0L) {
        xml2::xml_remove(xml2::xml_find_all(last, "w:titlePg", ns))
    }
    invisible()
}

#' Set the page size and margins of a section (twips, see `.docx_twips()`)
#' @param sectPr a `w:sectPr` node, changed in place.
#' @param page page settings in cm (`.render_settings()`); `page$turn` makes it
#'   landscape.
#' @param ns namespaces of the document.
#' @return `sectPr`, invisibly.
#' @noRd
.docx_set_page <- function(sectPr, page, ns) {
    tw <- format(.docx_twips(page), scientific = FALSE, trim = TRUE)
    .set_orientation(sectPr, page$turn, ns)
    pgSz <- xml2::xml_find_first(sectPr, "w:pgSz", ns)
    xml2::xml_set_attr(pgSz, "w:w", tw[["width"]])
    xml2::xml_set_attr(pgSz, "w:h", tw[["height"]])
    pgMar <- xml2::xml_find_first(sectPr, "w:pgMar", ns)
    if (inherits(pgMar, "xml_missing")) {
        # all seven attributes are required
        pgMar <- xml2::xml_add_sibling(pgSz, "w:pgMar", .where = "after")
        for (attr in c("w:header", "w:footer")) {
            xml2::xml_set_attr(pgMar, attr, "708")
        }
        xml2::xml_set_attr(pgMar, "w:gutter", "0")
    }
    for (side in c("top", "right", "bottom", "left")) {
        xml2::xml_set_attr(pgMar, paste0("w:", side), tw[[side]])
    }
    invisible(sectPr)
}

#' Whether a section is landscape (`w:orient` of its page size)
#' @param sectPr a `w:sectPr` node.
#' @param ns namespaces of the document.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_landscape <- function(sectPr, ns) {
    orient <- xml2::xml_attr(
        xml2::xml_find_first(sectPr, "w:pgSz", ns),
        "w:orient",
        ns = ns
    )
    identical(orient, "landscape")
}

#' Set the page size of a section to portrait or landscape (A4 if it has none)
#' @param sectPr a `w:sectPr` node, changed in place.
#' @param landscape `TRUE` for landscape, `FALSE` for portrait.
#' @param ns namespaces of the document.
#' @return `sectPr`, invisibly.
#' @noRd
.set_orientation <- function(sectPr, landscape, ns) {
    pgSz <- xml2::xml_find_first(sectPr, "w:pgSz", ns)
    dims <- suppressWarnings(as.numeric(c(
        xml2::xml_attr(pgSz, "w:w", ns = ns),
        xml2::xml_attr(pgSz, "w:h", ns = ns)
    )))
    if (anyNA(dims)) {
        dims <- c(11906, 16838)
    }
    dims <- sort(dims, decreasing = landscape)
    if (inherits(pgSz, "xml_missing")) {
        # schema order: w:pgSz follows the header and footer references, w:footnotePr,
        # w:endnotePr and w:type, and comes before all other children
        before <- c(
            "headerReference",
            "footerReference",
            "footnotePr",
            "endnotePr",
            "type"
        )
        children <- xml2::xml_children(sectPr)
        last <- max(which(xml2::xml_name(children) %in% before), 0L)
        pgSz <- if (last > 0L) {
            xml2::xml_add_sibling(children[[last]], "w:pgSz", .where = "after")
        } else if (length(children) > 0L) {
            xml2::xml_add_sibling(children[[1L]], "w:pgSz", .where = "before")
        } else {
            xml2::xml_add_child(sectPr, "w:pgSz")
        }
    }
    xml2::xml_set_attr(pgSz, "w:w", format(dims[[1L]], scientific = FALSE))
    xml2::xml_set_attr(pgSz, "w:h", format(dims[[2L]], scientific = FALSE))
    # removing a prefixed attribute needs `ns`
    xml2::xml_set_attr(pgSz, "w:orient", if (landscape) "landscape", ns = ns)
    invisible(sectPr)
}


# ---------------
# Core properties
# ---------------
#' Set `dc:title` and `dc:creator` of a DOCX file's core properties
#' @param file path of `docProps/core.xml`.
#' @param properties named list of strings (names `title`, `creator`).
#' @return `file`, invisibly.
#' @noRd
.docx_set_properties <- function(file, properties) {
    xml <- xml2::read_xml(file)
    dc <- c(dc = "http://purl.org/dc/elements/1.1/")
    for (name in names(properties)) {
        node <- xml2::xml_find_first(xml, paste0("/*/dc:", name), dc)
        if (inherits(node, "xml_missing")) {
            # pandoc declares the prefix on the root
            node <- xml2::xml_add_child(xml, paste0("dc:", name))
        }
        xml2::xml_text(node) <- properties[[name]]
    }
    xml2::write_xml(xml, file, options = "as_xml")
    invisible(file)
}


# -------
# Packing
# -------
#' Write the files of a directory into a zip archive (an Office document:
#' `[Content_Types].xml` first)
#' @param dir directory whose files (also hidden ones) are written.
#' @param path path of the archive; an existing file is replaced.
#' @return `path`, invisibly.
#' @noRd
.zip_dir <- function(dir, path) {
    files <- list.files(dir, recursive = TRUE, all.files = TRUE)
    files <- c(
        intersect("[Content_Types].xml", files),
        setdiff(files, "[Content_Types].xml")
    )
    unlink(path)
    zip::zip(.absolute_path(path), files = files, root = dir, mode = "mirror")
    invisible(path)
}
