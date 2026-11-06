# Builds inst/templates/reference.docx, pubflow's default reference document
# for DOCX output. Starts from pandoc's default reference docx and
# adds:
# - numbered "Heading 1"-"Heading 5" (a multilevel list linked to the styles:
#   1, 1.1, 1.1.1, ...);
# - "Heading 1 Unnumbered"-"Heading 5 Unnumbered" (no number, outline level
#   kept, so they appear in the table of contents);
# - "Item Title", "Error" and the character style "Placeholder"; pandoc's
#   "Table Caption", "Image Caption" and "Figure" are kept ("Figure" keeps
#   with its caption);
# - "Header" and "Footer" styles (tab stops at the centre and the right), a
#   header with the bookmarks `header_left`, `header_center` and
#   `header_right`, and a footer with `footer_left`, `footer_center` and
#   `footer_right` around "Page x / N";
# - A4 pages with 2.5 cm margins left and right.
#
# Run from the package root (needs pandoc):
#   Rscript data-raw/reference_docx.R

local({
    out <- "inst/templates/reference.docx"
    dir <- tempfile("reference-docx-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)

    src <- file.path(dir, "default.docx")
    status <- system2("pandoc", c("-o", shQuote(src),
                                  "--print-default-data-file",
                                  "reference.docx"))
    stopifnot(status == 0L)
    parts <- file.path(dir, "parts")
    zip::unzip(src, exdir = parts)
    part <- function(name) file.path(parts, name)
    read <- function(name) {
        paste(readLines(part(name), encoding = "UTF-8", warn = FALSE),
              collapse = "\n")
    }
    write <- function(text, name) {
        writeLines(enc2utf8(text), part(name), useBytes = TRUE)
    }
    insert_before <- function(text, anchor, value) {
        stopifnot(grepl(anchor, text, fixed = TRUE))
        sub(anchor, paste0(value, anchor), text, fixed = TRUE)
    }

    # Styles ------------------------------------------------------------------
    styles <- read("word/styles.xml")
    for (n in 1:5) {
        # numPr goes after keepLines (schema order of w:pPr)
        pattern <- sprintf(
            "(?s)(<w:style [^>]*w:styleId=\"Heading%d\">.*?<w:keepLines />)",
            n
        )
        numPr <- sprintf(
            "<w:numPr><w:ilvl w:val=\"%d\" /><w:numId w:val=\"1\" /></w:numPr>",
            n - 1L
        )
        stopifnot(grepl(pattern, styles, perl = TRUE))
        styles <- sub(pattern, paste0("\\1", numPr), styles, perl = TRUE)
    }
    unnumbered <- vapply(1:5, function(n) {
        sprintf(paste0(
            "<w:style w:type=\"paragraph\" w:customStyle=\"1\" ",
            "w:styleId=\"Heading%dUnnumbered\">",
            "<w:name w:val=\"Heading %d Unnumbered\" />",
            "<w:basedOn w:val=\"Heading%d\" />",
            "<w:next w:val=\"BodyText\" /><w:qFormat />",
            "<w:pPr><w:numPr><w:ilvl w:val=\"0\" /><w:numId w:val=\"0\" />",
            "</w:numPr><w:outlineLvl w:val=\"%d\" /></w:pPr>",
            "</w:style>"
        ), n, n, n, n - 1L)
    }, character(1))
    tabs <- paste0(
        "<w:tabs><w:tab w:val=\"center\" w:pos=\"4536\" />",
        "<w:tab w:val=\"right\" w:pos=\"9072\" /></w:tabs>"
    )
    added <- c(
        unnumbered,
        paste0(
            "<w:style w:type=\"paragraph\" w:customStyle=\"1\" ",
            "w:styleId=\"ItemTitle\"><w:name w:val=\"Item Title\" />",
            "<w:basedOn w:val=\"BodyText\" /><w:next w:val=\"BodyText\" />",
            "<w:qFormat /><w:pPr><w:keepNext />",
            "<w:spacing w:before=\"240\" w:after=\"60\" /></w:pPr>",
            "<w:rPr><w:b /><w:bCs /></w:rPr></w:style>"
        ),
        paste0(
            "<w:style w:type=\"character\" w:customStyle=\"1\" ",
            "w:styleId=\"Placeholder\"><w:name w:val=\"Placeholder\" />",
            "<w:basedOn w:val=\"DefaultParagraphFont\" /><w:qFormat />",
            "<w:rPr><w:color w:val=\"0083C0\" /></w:rPr></w:style>"
        ),
        paste0(
            "<w:style w:type=\"paragraph\" w:customStyle=\"1\" ",
            "w:styleId=\"Error\"><w:name w:val=\"Error\" />",
            "<w:basedOn w:val=\"BodyText\" /><w:qFormat />",
            "<w:pPr><w:pBdr><w:left w:val=\"single\" w:sz=\"24\" ",
            "w:space=\"4\" w:color=\"C00000\" /></w:pBdr>",
            "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"FDECEA\" />",
            "<w:spacing w:before=\"60\" w:after=\"60\" />",
            "<w:ind w:left=\"144\" w:right=\"144\" /></w:pPr>",
            "<w:rPr><w:color w:val=\"C00000\" /></w:rPr></w:style>"
        ),
        paste0(
            "<w:style w:type=\"paragraph\" w:styleId=\"Header\">",
            "<w:name w:val=\"header\" /><w:basedOn w:val=\"Normal\" />",
            "<w:unhideWhenUsed /><w:pPr>", tabs,
            "<w:spacing w:before=\"0\" w:after=\"0\" /></w:pPr>",
            "<w:rPr><w:sz w:val=\"18\" /><w:szCs w:val=\"18\" /></w:rPr>",
            "</w:style>"
        ),
        paste0(
            "<w:style w:type=\"paragraph\" w:styleId=\"Footer\">",
            "<w:name w:val=\"footer\" /><w:basedOn w:val=\"Normal\" />",
            "<w:unhideWhenUsed /><w:pPr>", tabs,
            "<w:spacing w:before=\"0\" w:after=\"0\" /></w:pPr>",
            "<w:rPr><w:sz w:val=\"18\" /><w:szCs w:val=\"18\" /></w:rPr>",
            "</w:style>"
        )
    )
    styles <- insert_before(styles, "</w:styles>",
                            paste0(added, collapse = "\n"))
    # the figure paragraph keeps with its caption (which follows it)
    figure <- paste0("(?s)(<w:style [^>]*w:styleId=\"Figure\">.*?",
                     "<w:basedOn w:val=\"Normal\" />)")
    stopifnot(grepl(figure, styles, perl = TRUE))
    styles <- sub(figure, "\\1<w:pPr><w:keepNext /></w:pPr>", styles,
                  perl = TRUE)
    write(styles, "word/styles.xml")

    # Heading numbering -------------------------------------------------------
    # the hanging indent (where the title starts after the number's tab)
    # holds two-digit numbers ("10.10.10") in the heading's font size (20,
    # 16, 14, 12, 12 pt; digits about 0.55 em, dots 0.3 em) plus a gap of
    # 0.1 inch; with less, "10" fills it and the tab has no width
    points <- c(20, 16, 14, 12, 12)
    levels <- vapply(0:4, function(k) {
        text <- paste0("%", seq_len(k + 1L), collapse = ".")
        em <- 2 * (k + 1L) * 0.55 + k * 0.3
        indent <- as.integer(ceiling((em * points[[k + 1L]] * 20 + 144) /
                                         72) * 72)
        sprintf(paste0(
            "<w:lvl w:ilvl=\"%d\"><w:start w:val=\"1\" />",
            "<w:numFmt w:val=\"decimal\" /><w:pStyle w:val=\"Heading%d\" />",
            "<w:lvlText w:val=\"%s\" /><w:lvlJc w:val=\"left\" />",
            "<w:pPr><w:ind w:left=\"%d\" w:hanging=\"%d\" /></w:pPr></w:lvl>"
        ), k, k + 1L, text, indent, indent)
    }, character(1))
    abstract <- paste0(
        "<w:abstractNum w:abstractNumId=\"1\"><w:nsid w:val=\"5042464C\" />",
        "<w:multiLevelType w:val=\"multilevel\" />",
        paste0(levels, collapse = ""), "</w:abstractNum>"
    )
    numbering <- read("word/numbering.xml")
    # abstractNum elements come before num elements
    first <- regexpr("<w:abstractNum ", numbering, fixed = TRUE)
    numbering <- paste0(substr(numbering, 1L, first - 1L), abstract,
                        substring(numbering, first))
    numbering <- insert_before(
        numbering, "</w:numbering>",
        "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"1\" /></w:num>"
    )
    write(numbering, "word/numbering.xml")

    # Header and footer -------------------------------------------------------
    ns <- paste0(
        "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/",
        "2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/",
        "officeDocument/2006/relationships\""
    )
    field <- function(code) {
        paste0(
            "<w:r><w:fldChar w:fldCharType=\"begin\" /></w:r>",
            "<w:r><w:instrText xml:space=\"preserve\"> ", code,
            " </w:instrText></w:r>",
            "<w:r><w:fldChar w:fldCharType=\"separate\" /></w:r>",
            "<w:r><w:t>1</w:t></w:r>",
            "<w:r><w:fldChar w:fldCharType=\"end\" /></w:r>"
        )
    }
    # a bookmark around `content` (default: an empty run)
    empty <- "<w:r><w:t xml:space=\"preserve\"></w:t></w:r>"
    bookmark <- function(id, name, content = empty) {
        sprintf(paste0(
            "<w:bookmarkStart w:id=\"%d\" w:name=\"%s\" />%s",
            "<w:bookmarkEnd w:id=\"%d\" />"
        ), id, name, content, id)
    }
    tab <- "<w:r><w:tab /></w:r>"
    xml <- "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
    write(paste0(
        xml, "\n<w:hdr ", ns, "><w:p><w:pPr><w:pStyle w:val=\"Header\" />",
        "</w:pPr>", bookmark(9001L, "header_left"), tab,
        bookmark(9002L, "header_center"), tab,
        bookmark(9003L, "header_right"), "</w:p></w:hdr>"
    ), "word/header1.xml")
    page <- paste0(
        "<w:r><w:t xml:space=\"preserve\">Page </w:t></w:r>",
        field("PAGE"),
        "<w:r><w:t xml:space=\"preserve\"> / </w:t></w:r>",
        field("NUMPAGES")
    )
    write(paste0(
        xml, "\n<w:ftr ", ns, "><w:p><w:pPr><w:pStyle w:val=\"Footer\" />",
        "</w:pPr>", bookmark(9004L, "footer_left"), tab,
        bookmark(9005L, "footer_center"), tab,
        bookmark(9006L, "footer_right", page), "</w:p></w:ftr>"
    ), "word/footer1.xml")
    rel <- paste0(
        "<Relationship Id=\"%s\" Type=\"http://schemas.openxmlformats.org/",
        "officeDocument/2006/relationships/%s\" Target=\"%s\" />"
    )
    rels <- read("word/_rels/document.xml.rels")
    rels <- insert_before(rels, "</Relationships>", paste0(
        sprintf(rel, "rId9001", "header", "header1.xml"),
        sprintf(rel, "rId9002", "footer", "footer1.xml")
    ))
    write(rels, "word/_rels/document.xml.rels")
    override <- paste0(
        "<Override PartName=\"/word/%s.xml\" ContentType=\"application/",
        "vnd.openxmlformats-officedocument.wordprocessingml.%s+xml\" />"
    )
    types <- read("[Content_Types].xml")
    types <- insert_before(types, "</Types>", paste0(
        sprintf(override, "header1", "header"),
        sprintf(override, "footer1", "footer")
    ))
    write(types, "[Content_Types].xml")

    # Page setup: A4, 2.5 cm left and right ----------------------------------
    document <- read("word/document.xml")
    sectPr <- paste0(
        "<w:sectPr>",
        "<w:headerReference w:type=\"default\" r:id=\"rId9001\" />",
        "<w:footerReference w:type=\"default\" r:id=\"rId9002\" />",
        "<w:footnotePr><w:numRestart w:val=\"eachSect\" /></w:footnotePr>",
        "<w:pgSz w:w=\"11906\" w:h=\"16838\" />",
        "<w:pgMar w:top=\"1417\" w:right=\"1417\" w:bottom=\"1134\" ",
        "w:left=\"1417\" w:header=\"708\" w:footer=\"708\" w:gutter=\"0\" />",
        "<w:cols w:space=\"708\" /><w:docGrid w:linePitch=\"360\" />",
        "</w:sectPr>"
    )
    stopifnot(lengths(regmatches(
        document, gregexpr("<w:sectPr>", document, fixed = TRUE)
    )) == 1L)
    document <- sub("(?s)<w:sectPr>.*</w:sectPr>", sectPr, document,
                    perl = TRUE)
    write(document, "word/document.xml")

    # Archive -----------------------------------------------------------------
    files <- list.files(parts, recursive = TRUE, all.files = TRUE)
    files <- c("[Content_Types].xml", setdiff(files, "[Content_Types].xml"))
    dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
    unlink(out)
    zip::zip(file.path(normalizePath(dirname(out)), basename(out)),
             files = files, root = parts, mode = "mirror")
    for (name in c("word/styles.xml", "word/numbering.xml",
                   "word/document.xml", "word/header1.xml",
                   "word/footer1.xml")) {
        xml2::read_xml(part(name))
    }
    message("Wrote ", out)
})
