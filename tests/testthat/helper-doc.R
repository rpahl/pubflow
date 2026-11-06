# Checks of documents: no pipeline reachable from them.

# TRUE if serialising `x` (as saveRDS() does) would include a pipeline. serialize()
# calls `refhook` for every environment it writes (closure environments, promise
# environments, ggplot internals, ...), so this finds pipelines however deeply they are
# captured, without forcing promises.
reaches_pipeline <- function(x) {
    found <- FALSE
    hook <- function(env) {
        if (is.environment(env) && is_pipeline_env(env)) {
            found <<- TRUE
        }
        NULL
    }
    without_package_env_warning(serialize(x, NULL, refhook = hook))
    found
}

# Figures made by the test helpers keep the helper environment, which reaches the
# package environment attached by load_all(); serialize() warns that it "may not be
# available when loading" (tests only).
without_package_env_warning <- function(expr) {
    withCallingHandlers(expr, warning = function(w) {
        if (grepl("may not be available when loading", conditionMessage(w))) {
            invokeRestart("muffleWarning")
        }
    })
}

# The environment of a pipeflow pipeline holds its step table as `data`
is_pipeline_env <- function(env) {
    if (!exists("data", envir = env, inherits = FALSE)) {
        return(FALSE)
    }
    if (rlang::env_binding_are_lazy(env, "data")) {
        return(FALSE)
    }
    dat <- env[["data"]]
    inherits(dat, "data.table") && all(c("step", "nodeId") %in% names(dat))
}

# A recorded base plot (a figure that needs no ggplot2)
recorded_plot <- function(n = 5L) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off())
    grDevices::dev.control("enable")
    graphics::plot(seq_len(n))
    grDevices::recordPlot()
}

# HTML with inline images shortened (for snapshots and comparisons of the structure)
without_images <- function(html) {
    gsub(
        "data:image/([a-z+]+);base64,[A-Za-z0-9+/=]+",
        "data:image/\\1;...",
        as.character(html)
    )
}

# A widget for tests: an htmlwidget class whose as.tags() method (registered for the
# test only) returns a div with a dependency
local_fake_widget <- function(frame = parent.frame()) {
    cls <- "pubflow_fake_widget"
    registerS3method(
        "as.tags",
        cls,
        function(x, ...) {
            htmltools::attachDependencies(
                htmltools::tags$div(class = "fake-widget"),
                htmltools::htmlDependency(
                    "fake",
                    "1.0",
                    src = c(href = "https://example.org/fake"),
                    script = "fake.js"
                )
            )
        },
        envir = asNamespace("htmltools")
    )
    table <- asNamespace("htmltools")[[".__S3MethodsTable__."]]
    withr::defer(rm(list = paste0("as.tags.", cls), envir = table), envir = frame)
    structure(list(), class = c(cls, "htmlwidget"))
}

# Path of pandoc; skips the test if there is none (>= 3.6)
skip_if_no_pandoc <- function() {
    pandoc <- tryCatch(.find_pandoc(), pubflow_tool_missing = function(e) NULL)
    testthat::skip_if(is.null(pandoc), "pandoc (>= 3.6) not found")
    pandoc
}

# Path of a PDF engine ("xelatex" or "typst") that really runs; skips the test otherwise
# (a typst snap is found but can't start in some sandboxes)
skip_if_no_pdf_engine <- function(engine) {
    skip_if_no_pandoc()
    path <- if (engine == "typst") {
        tryCatch(.find_typst(), pubflow_tool_missing = function(e) character())
    } else {
        .which(engine)
    }
    runs <- length(path) == 1L && !is.null(.tool_version(path))
    testthat::skip_if(!runs, sprintf("%s does not run", engine))
    path
}

# Which pages of a PDF file are landscape (as shown: pdflscape turns portrait pages)
pdf_landscape <- function(path) {
    pages <- pdftools::pdf_info(path)$pages
    vapply(
        seq_len(pages),
        \(i) {
            bitmap <- pdftools::pdf_render_page(path, page = i, dpi = 3)
            dim(bitmap)[[2L]] > dim(bitmap)[[3L]]
        },
        logical(1)
    )
}

# Parts of a DOCX file as xml2 documents (word/document.xml by default)
docx_xml <- function(path, part = "word/document.xml") {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, files = part, exdir = dir)
    xml2::read_xml(file.path(dir, part))
}

# REF fields of DOCX XML: instruction, result text and if the result is bold
docx_ref_fields <- function(xml) {
    ns <- xml2::xml_ns(xml)
    instr <- xml2::xml_find_all(xml, "//w:instrText[starts-with(., ' REF')]", ns)
    result <- xml2::xml_find_first(
        instr,
        "../following-sibling::w:r[w:t][1]",
        ns
    )
    data.frame(
        instr = xml2::xml_text(instr),
        result = xml2::xml_text(result),
        bold = !is.na(xml2::xml_find_first(result, "w:rPr/w:b", ns))
    )
}

# Text of a part of a DOCX file as written
docx_part_text <- function(path, part = "word/document.xml") {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, files = part, exdir = dir)
    paste(
        readLines(file.path(dir, part), warn = FALSE, encoding = "UTF-8"),
        collapse = "\n"
    )
}

# Number of namespace declarations in a part of a DOCX file
docx_xmlns_count <- function(path, part = "word/document.xml") {
    text <- docx_part_text(path, part)
    lengths(regmatches(text, gregexpr("xmlns(:[A-Za-z0-9]+)?=", text)))
}

# XML parts of a DOCX file that are not well-formed (none: character())
docx_bad_parts <- function(path) {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, exdir = dir)
    parts <- list.files(dir, "\\.(xml|rels)$", recursive = TRUE, all.files = TRUE)
    ok <- vapply(
        parts,
        \(part) {
            tryCatch(
                {
                    xml2::read_xml(file.path(dir, part))
                    TRUE
                },
                error = function(e) FALSE
            )
        },
        logical(1)
    )
    parts[!ok]
}

# A copy of a DOCX file (default: pubflow's reference document) in a temporary file,
# deleted with `frame`
local_docx_copy <- function(from = NULL, frame = parent.frame()) {
    if (is.null(from)) {
        from <- system.file("templates", "reference.docx", package = "pubflow")
    }
    path <- withr::local_tempfile(fileext = ".docx", .local_envir = frame)
    file.copy(from, path)
    path
}

# A minimal DOCX file (`[Content_Types].xml` and `word/document.xml`) whose body holds
# `body` (WordprocessingML), deleted with `frame`
local_docx_body <- function(body, frame = parent.frame()) {
    dir <- withr::local_tempdir(.local_envir = frame)
    dir.create(file.path(dir, "word"))
    w <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    writeLines(
        c(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            sprintf(
                "<w:document xmlns:w=\"%s\"><w:body>%s</w:body></w:document>",
                w,
                body
            )
        ),
        file.path(dir, "word", "document.xml")
    )
    writeLines("<Types/>", file.path(dir, "[Content_Types].xml"))
    path <- withr::local_tempfile(fileext = ".docx", .local_envir = frame)
    .zip_dir(dir, path)
    path
}

# Move a part of a DOCX file (e.g. "word/header1.xml") to another name (e.g.
# "word/parts/top.xml"), updating its relationship and content type
docx_move_part <- function(path, from, to) {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, exdir = dir)
    dir.create(dirname(file.path(dir, to)), recursive = TRUE, showWarnings = FALSE)
    file.rename(file.path(dir, from), file.path(dir, to))
    # relationship targets are relative to word/, part names absolute
    targets <- sub("^word/", "", c(from, to))
    edits <- list(
        "word/_rels/document.xml.rels" = sprintf("Target=\"%s\"", targets),
        "[Content_Types].xml" = sprintf("PartName=\"/%s\"", c(from, to))
    )
    for (part in names(edits)) {
        file <- file.path(dir, part)
        text <- readLines(file, warn = FALSE, encoding = "UTF-8")
        stopifnot(any(grepl(edits[[part]][[1L]], text, fixed = TRUE)))
        writeLines(
            gsub(edits[[part]][[1L]], edits[[part]][[2L]], text, fixed = TRUE),
            file,
            useBytes = TRUE
        )
    }
    .zip_dir(dir, path)
    invisible(path)
}

# Replace the first `old` in the text of a part of a DOCX file by `new`
docx_edit_part <- function(path, part, old, new) {
    dir <- tempfile("docx-")
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    zip::unzip(path, exdir = dir)
    file <- file.path(dir, part)
    text <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    stopifnot(grepl(old, text, fixed = TRUE))
    writeLines(enc2utf8(sub(old, new, text, fixed = TRUE)), file, useBytes = TRUE)
    .zip_dir(dir, path)
    invisible(path)
}

# Plain text of a DOCX file as pandoc's docx reader sees it (an error if pandoc can't
# read it)
docx_pandoc_text <- function(path) {
    out <- suppressWarnings(system2(
        skip_if_no_pandoc(),
        c("-f", "docx", "-t", "plain", shQuote(path)),
        stdout = TRUE,
        stderr = TRUE
    ))
    if (!is.null(attr(out, "status"))) {
        stop("pandoc can't read the file: ", paste(out, collapse = "\n"))
    }
    paste(out, collapse = "\n")
}

# A reference document: even, default and first-page headers and footers,
# bookmarks `header_left` and `footer_left` in the default ones only
headers_template <- function() {
    testthat::test_path("fixtures", "headers-template.docx")
}

# A document with every node type for the Pandoc path: placeholders, math and hostile
# text, raw content, page break, table of contents, a widget (with a fallback figure if
# given), locked and unlocked tables, an unnumbered section, landscape items and
# sections, cross-references to a later table and figure and, if given, an error item
# (`failure`, e.g. demo_failures()$table)
markdown_node_doc <- function(widget = NULL, failure = NULL) {
    pub_doc(
        pub_section(
            "Text",
            pub_text(
                c(
                    "Some **bold** text, $x^2$ and [todo]{.placeholder}.",
                    "",
                    "<b>not bold</b> and `x`{=latex}",
                    "",
                    "See @tab:ab and @fig:points, not `@fig:points`.",
                    "",
                    "$$",
                    "\\frac{a}{b}",
                    "$$"
                ),
                title = "Note"
            ),
            pub_raw(docx = "<w:p><w:r><w:t>raw</w:t></w:r></w:p>", md = "Raw *md*"),
            pub_raw(html = "<hr>"),
            pub_pagebreak(),
            pub_toc(depth = 2L),
            widget
        ),
        pub_section(
            "Tables",
            pub_set_meta(
                pub_table(
                    data.frame(a = c(1.25, NA), b = c("x", "<y>")),
                    caption = "A & B",
                    digits = c(a = 1L)
                ),
                id = "ab"
            ),
            pub_set_meta(data.frame(z = 1L), title = "Unlocked", locked = FALSE)
        ),
        pub_section(
            "Figures",
            pub_figure(
                recorded_plot(),
                caption = "Points",
                width = 3,
                height = 2,
                out_width = "50%",
                id = "points"
            ),
            pub_figure(recorded_plot(3L), width = 2, height = 2, landscape = TRUE),
            pub_section("Nested", "Text of an unnumbered section."),
            numbered = FALSE
        ),
        pub_section(
            "Wide",
            pub_table(data.frame(w = 1), caption = "Wide"),
            landscape = TRUE
        ),
        pub_section("Results", pub_section("Check", "Checked.", failure)),
        title = "Every node",
        subtitle = "Subtitle & \"more\"",
        meta = list(
            author = "A. User",
            time = as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
        )
    )
}

# A widget with a fallback figure (see local_fake_widget())
fallback_widget <- function(widget) {
    pub_set_meta(
        widget,
        caption = "Widget",
        fallback = pub_figure(recorded_plot(2L), width = 2, height = 2)
    )
}
