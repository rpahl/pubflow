# HTML renderer: a document to one HTML fragment for the viewer and HTML files, with
# htmltools only (no pandoc). The fragment is built as a string (fast, and stable for
# snapshots); a render context collects the numbering, the table of contents and the
# HTML dependencies on the way.

# ======================================================================================
# HTML documents
# ======================================================================================

# ------
# Render
# ------
#' Render a document to HTML
#'
#' Renders a document (see [pub_doc()]) to an HTML fragment, which can be used in Shiny
#' UIs directly. [pub_render()] writes a standalone HTML file instead.
#'
#' @details
#' ## Contents
#'
#' The result has:
#'
#' * a header with the title, subtitle and metadata, or the front matter of the
#'   document instead (see [pub_doc()]);
#' * an optional table of contents;
#' * one `<section>` per section, with numbered headings.
#'
#' Tables are rendered with huxtable (see [pub_table()]), figures as inline PNG (or SVG)
#' images, text as Markdown (CommonMark), math with MathJax and error items (failed
#' steps, see [pub_doc()]) as error boxes. Raw HTML in texts is shown as text; use
#' [pub_raw()] to insert HTML.
#'
#' ## Dependencies
#'
#' The result carries its CSS (`pubflow-doc.css`) and, if the document has math, MathJax
#' 3 (from a CDN) as HTML dependencies.
#'
#' ## Caching
#'
#' Rendering a figure takes about 0.1 s and the HTML of a table several milliseconds.
#' With a `cache`, both are rendered once and reused while they are unchanged:
#'
#' * Use one cache per Shiny session (or R process) and pass it to the viewer and to
#'   every render call. They then share the figures (with the same device settings, a
#'   figure is rendered once).
#' * Only figures made by pipeline steps are cached. pubflow stamps each figure that a
#'   step returns (also in plain lists) with the step, its partition key and the time of
#'   the run. So whenever the step runs again (e.g. because a step parameter changed),
#'   its figures are re-rendered.
#' * Figures without a stamp are rendered every time. These can be figures made outside
#'   a pipeline or inside the step that builds the document (the layout step).
#'   To have a figure cached, create it in a pipeline step of its own and pass it to
#'   the layout step as an input (e.g. `plot = ~plot_step`).
#' * Figures rendered in their step (`pub_figure(render = TRUE)`) are not cached: the
#'   document uses their png as it is.
#'
#' ## Cross-references
#'
#' Cross-references in texts (see [pub_text()]) link to their figure or table. A
#' reference that can't be resolved is marked in the HTML and gives a
#' `pubflow_render_warning`, so a draft still displays. On the other hand,
#' [pub_render()] never allows undefined references and stops with an error instead.
#'
#' @param doc A `pub_doc`.
#' @param cache A [pub_cache()] or `NULL` (render every figure and table).
#' @param toc `TRUE`: add a table of contents (headings up to level 3).
#' @param math `"mathjax"`: attach MathJax if the document has math; `"none"`: math
#'   stays as `\(...\)` and `\[...\]`.
#' @param figure Device settings of figures: `device` (`"png"` or `"svg"`) and `res`
#'   (resolution of PNG images in dpi; 200 as in the viewer and every format of
#'   [pub_render()], so they share the cached figures).
#' @return HTML (an [htmltools::HTML()] string with dependencies).
#' @seealso [pub_render()], [pub_cache()], [pub_doc()]
#' @examples
#' doc <- pub_doc(
#'     pub_section(
#'         "Results",
#'         pub_text("Mean ozone peaks in **August** ($x_8 = 60$ ppb)."),
#'         pub_table(aggregate(Ozone ~ Month, data = airquality, FUN = mean),
#'                   caption = "Mean ozone", digits = c(Ozone = 1L))
#'     ),
#'     title = "Demo"
#' )
#' html <- pub_html(doc)
#' cat(substr(html, 1, 300))
#' @export
pub_html <- function(
    doc,
    cache = NULL,
    toc = TRUE,
    math = c("mathjax", "none"),
    figure = list(device = "png", res = 200)
) {
    .check_doc(doc)
    .check_cache(cache)
    if (!rlang::is_bool(toc)) {
        rlang::abort("`toc` must be `TRUE` or `FALSE`.")
    }
    math <- rlang::arg_match(math)
    .html_doc(
        doc,
        cache,
        toc = toc,
        math = math,
        figure = .check_figure_settings(figure),
        front = doc$front_matter
    )
}

#' Validate figure settings; fill in defaults
#' @param figure the `figure` argument of `pub_html()`.
#' @param call the environment of the caller, for the error message.
#' @return `list(device, res)`.
#' @noRd
.check_figure_settings <- function(figure, call = rlang::caller_env()) {
    if (
        !is.list(figure) ||
            !rlang::is_named2(figure) ||
            !all(names(figure) %in% c("device", "res"))
    ) {
        rlang::abort("`figure` must be a list with `device` and `res`.", call = call)
    }
    device <- figure$device %||% "png"
    res <- figure$res %||% .figure_default$res
    if (!rlang::is_string(device) || !device %in% c("png", "svg")) {
        rlang::abort("`figure$device` must be \"png\" or \"svg\".", call = call)
    }
    if (!.is_positive_number(res)) {
        rlang::abort("`figure$res` must be a positive number.", call = call)
    }
    list(device = device, res = res)
}

#' Render a checked document
#'
#' @param doc a checked `pub_doc`.
#' @param cache a `pub_cache` or `NULL`.
#' @param toc `TRUE`: add a table of contents.
#' @param math `"mathjax"` or `"none"`.
#' @param figure `list(device, res)` device settings.
#' @param prefix prefix of the generated element ids (the viewer makes them unique per
#'   module).
#' @param labels words for numbered captions.
#' @param toc_depth deepest heading level of the table of contents.
#' @param numbered `FALSE`: no section numbers.
#' @param front nodes of front matter, which replace the header, or `NULL`.
#' @param refs what problems of cross-references do: `"warn"` or `"error"` (reports).
#' @return HTML with dependencies.
#' @noRd
.html_doc <- function(
    doc,
    cache,
    toc,
    math,
    figure,
    prefix = "pubflow",
    labels = list(table = "Table", figure = "Figure"),
    toc_depth = 3L,
    numbered = TRUE,
    front = NULL,
    refs = "warn"
) {
    parts <- .html_parts(
        doc,
        cache,
        math = math,
        figure = figure,
        prefix = prefix,
        labels = labels,
        numbered = numbered,
        front = front,
        refs = refs
    )
    html <- .wrap_doc(c(
        parts$header,
        if (toc) .html_toc(parts$outline, depth = toc_depth),
        parts$body
    ))
    htmltools::attachDependencies(htmltools::HTML(html), parts$deps)
}


# --------------
# Document parts
# --------------
#' The parts of a rendered document
#'
#' Front matter replaces the header: its sections are unnumbered and get the ids
#' `<prefix>-sec-0-<n>`; its tables and figures count in the caption numbers.
#' Cross-references get their numbers after the walk.
#' @param doc a checked `pub_doc`.
#' @param cache a `pub_cache` or `NULL`.
#' @param math `"mathjax"` or `"none"`.
#' @param figure `list(device, res)` device settings.
#' @param prefix prefix of the generated element ids.
#' @param labels words for numbered captions (`list(table, figure)`).
#' @param numbered `FALSE`: no section numbers.
#' @param front nodes of front matter, which replace the header, or `NULL`.
#' @param refs what problems of cross-references do: `"warn"` or `"error"` (reports).
#' @return `list(header, body, deps, outline)`: the lines of the document header (or
#'   front matter) and of the body, the HTML dependencies, and the sections in document
#'   order (`list(id, number, title, level)`, for a table of contents).
#' @noRd
.html_parts <- function(
    doc,
    cache,
    math,
    figure,
    prefix,
    labels = list(table = "Table", figure = "Figure"),
    numbered = TRUE,
    front = NULL,
    refs = "warn"
) {
    ctx <- new.env(parent = emptyenv())
    ctx$cache <- cache
    ctx$figure <- figure
    ctx$prefix <- prefix
    ctx$labels <- labels
    ctx$tables <- 0L
    ctx$figures <- 0L
    ctx$math <- FALSE
    ctx$deps <- list()
    ctx$outline <- list()
    ctx$tocs <- integer()
    ctx$refs <- .ref_state(c(front, doc$children), labels)
    header <- if (is.null(front)) {
        .html_header(doc$meta)
    } else {
        .html_nodes(
            front,
            ctx,
            level = 1L,
            number = integer(),
            numbered = FALSE,
            path = 0L
        )
    }
    body <- .html_nodes(
        doc$children,
        ctx,
        level = 1L,
        number = integer(),
        numbered = numbered,
        path = integer()
    )
    .ref_signal(ctx$refs, refs, format = "html")
    list(
        header = .insert_refs(.insert_tocs(header, ctx), ctx$refs, "html", ctx$prefix),
        body = .insert_refs(.insert_tocs(body, ctx), ctx$refs, "html", ctx$prefix),
        deps = c(
            list(.pubflow_doc_dependency()),
            if (ctx$math && math == "mathjax") list(.mathjax_dependency()),
            ctx$deps
        ),
        outline = ctx$outline
    )
}

#' The document element around the lines of a document
#' @param lines `character` lines of the document.
#' @return `character(1)` HTML.
#' @noRd
.wrap_doc <- function(lines) {
    paste(c("<div class=\"pubflow-doc\">", lines, "</div>"), collapse = "\n")
}

#' Document header: title, subtitle and a line of metadata
#' @param meta the metadata of the document (`title`, `subtitle`, `author`, `time`,
#'   `app`, `version`).
#' @return `character` lines or `NULL` without metadata.
#' @noRd
.html_header <- function(meta) {
    time <- meta[["time"]]
    app <- paste(c(meta[["app"]], meta[["version"]]), collapse = " ")
    info <- c(
        meta[["author"]],
        if (!is.null(time)) .format_utc(time),
        if (nzchar(app)) app
    )
    lines <- c(
        if (!is.null(meta[["title"]])) {
            sprintf("<h1 class=\"pubflow-title\">%s</h1>", .esc(meta[["title"]]))
        },
        if (!is.null(meta[["subtitle"]])) {
            sprintf("<p class=\"pubflow-subtitle\">%s</p>", .esc(meta[["subtitle"]]))
        },
        if (length(info) > 0L) {
            sprintf(
                "<p class=\"pubflow-doc-meta\">%s</p>",
                paste(.esc(info), collapse = " &middot; ")
            )
        }
    )
    if (length(lines) == 0L) {
        return(NULL)
    }
    c("<header class=\"pubflow-doc-header\">", lines, "</header>")
}

#' HTML dependency with the document stylesheet (inst/www)
#' @noRd
.pubflow_doc_dependency <- function() {
    htmltools::htmlDependency(
        name = "pubflow-doc",
        version = unname(getNamespaceVersion("pubflow")),
        src = "www",
        package = "pubflow",
        stylesheet = "pubflow-doc.css",
        all_files = FALSE
    )
}

#' MathJax 3 from a CDN
#' @noRd
.mathjax_dependency <- function() {
    htmltools::htmlDependency(
        name = "mathjax",
        version = "3.2.2",
        src = c(href = "https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5"),
        script = "tex-chtml.js"
    )
}


# -----------------
# Table of contents
# -----------------
#' Table of contents of the sections up to level `depth`
#' @param outline `list` of `list(id, number, title, level)` in document order.
#' @param depth `integer(1)` deepest heading level.
#' @return `character` lines or `NULL` without sections.
#' @noRd
.html_toc <- function(outline, depth) {
    outline <- Filter(\(x) x$level <= depth, outline)
    if (length(outline) == 0L) {
        return(NULL)
    }
    out <- "<nav class=\"pubflow-toc\">"
    current <- 0L
    for (entry in outline) {
        if (entry$level > current) {
            out <- c(out, "<ul>")
        } else {
            out <- c(out, "</li>", rep("</ul></li>", current - entry$level))
        }
        out <- c(
            out,
            sprintf(
                "<li><a href=\"#%s\">%s%s</a>",
                entry$id,
                .number_span(entry$number),
                .esc(entry$title)
            )
        )
        current <- entry$level
    }
    c(out, "</li>", rep("</ul></li>", current - 1L), "</ul>", "</nav>")
}

#' Marker for a table of contents item, replaced once the outline is known (lists of
#' figures and tables are for reports only)
#' @param x a `pub_toc` object (with `depth` and `what`).
#' @param ctx the render context.
#' @return `character(1)` HTML comment or `NULL` (a list of figures or tables).
#' @noRd
.html_toc_marker <- function(x, ctx) {
    if (x$what != "sections") {
        return(NULL)
    }
    ctx$tocs <- c(ctx$tocs, x$depth)
    sprintf("<!--pubflow-toc-%d-->", length(ctx$tocs))
}

#' Replace the table of contents markers by the tables of contents
#' @param body `character` lines with markers.
#' @param ctx the render context (with the complete outline).
#' @return `body` with the markers replaced.
#' @noRd
.insert_tocs <- function(body, ctx) {
    for (i in seq_along(ctx$tocs)) {
        toc <- .html_toc(ctx$outline, depth = ctx$tocs[[i]])
        body <- sub(
            sprintf("<!--pubflow-toc-%d-->", i),
            paste(toc, collapse = "\n"),
            body,
            fixed = TRUE
        )
    }
    body
}


# ======================================================================================
# Nodes
# ======================================================================================

# --------
# Sections
# --------
#' HTML of a list of nodes (sections and items)
#'
#' @param nodes `list` of sections and items.
#' @param ctx the render context.
#' @param level `integer(1)` section level of the nodes (1 = top).
#' @param number `integer` section number of the parent (empty at the top).
#' @param numbered `TRUE` if the parent is numbered.
#' @param path `integer` positions of the parent among its sibling sections (for ids).
#' @return `character` lines.
#' @noRd
.html_nodes <- function(nodes, ctx, level, number, numbered, path) {
    out <- character()
    nSections <- 0L
    nNumbered <- 0L
    for (node in nodes) {
        if (inherits(node, "pub_item")) {
            out <- c(out, .html_item(node, ctx))
            next
        }
        nSections <- nSections + 1L
        isNumbered <- numbered && node$numbered
        if (isNumbered) {
            nNumbered <- nNumbered + 1L
        }
        out <- c(
            out,
            .html_section(
                node,
                ctx,
                level = level,
                number = if (isNumbered) c(number, nNumbered),
                path = c(path, nSections)
            )
        )
    }
    out
}

#' HTML of a section: heading and children; adds the section to the outline
#' @param x a `pub_section`.
#' @param ctx the render context.
#' @param level `integer(1)` section level (1 = top).
#' @param number `integer` section number, `NULL` if unnumbered.
#' @param path `integer` positions of the section and its ancestors (for the id).
#' @return `character` lines.
#' @noRd
.html_section <- function(x, ctx, level, number, path) {
    id <- paste(c(ctx$prefix, "sec", path), collapse = "-")
    numberText <- if (!is.null(number)) paste(number, collapse = ".")
    ctx$outline[[length(ctx$outline) + 1L]] <- list(
        id = id,
        number = numberText,
        title = x$title,
        level = level
    )
    tag <- paste0("h", min(level + 1L, 6L))
    heading <- sprintf(
        "<%s>%s%s</%s>",
        tag,
        .number_span(numberText),
        .esc(x$title),
        tag
    )
    c(
        sprintf(
            "<section class=\"pubflow-section pubflow-level-%d\" id=\"%s\">",
            level,
            id
        ),
        heading,
        .html_nodes(
            x$children,
            ctx,
            level = level + 1L,
            number = if (!is.null(number)) number else integer(),
            numbered = !is.null(number),
            path = path
        ),
        "</section>"
    )
}

#' Section number for headings and the table of contents
#' @param number `character(1)` section number or `NULL`.
#' @return `character(1)` HTML (`""` without number).
#' @noRd
.number_span <- function(number) {
    if (is.null(number)) {
        return("")
    }
    sprintf("<span class=\"pubflow-section-number\">%s</span> ", number)
}


# -----
# Items
# -----
#' HTML of an item: optional title line and the content
#' @param x a `pub_item`.
#' @param ctx the render context.
#' @return `character(1)`, or nothing for items without HTML content.
#' @noRd
.html_item <- function(x, ctx) {
    content <- switch(
        x$type,
        text = .html_text(x$object, ctx),
        table = .html_table(x$object, x$meta, ctx),
        figure = .html_figure(x$object, x$meta, ctx),
        widget = .html_widget(x$object, ctx),
        raw = x$object$html,
        toc = .html_toc_marker(x$object, ctx),
        error = .html_error(x$object),
        NULL
    )
    if (is.null(content)) {
        return(character())
    }
    title <- x$meta[["title"]]
    titleLine <- if (!is.null(title)) {
        sprintf("<div class=\"pubflow-item-title\">%s</div>\n", .esc(title))
    } else {
        ""
    }
    id <- x$meta[["id"]]
    idAttr <- if (!is.null(id)) {
        sprintf(" id=\"%s\"", .esc(.html_item_id(ctx$prefix, x$type, id), TRUE))
    } else {
        ""
    }
    sprintf(
        "<div class=\"pubflow-item pubflow-%s\"%s>\n%s%s\n</div>",
        x$type,
        idAttr,
        titleLine,
        content
    )
}

#' Markdown text as HTML; notes math for MathJax
#' @param x a `pub_text`.
#' @param ctx the render context.
#' @return `character(1)` HTML.
#' @noRd
.html_text <- function(x, ctx) {
    res <- .markdown_html(x, ref = .ref_converter(ctx$refs, "html"))
    ctx$math <- ctx$math || res$math
    sub("\n$", "", res$html)
}

#' Widget: its HTML; its dependencies go to the document
#' @param x an htmltools tag or widget.
#' @param ctx the render context.
#' @return `character(1)` HTML.
#' @noRd
.html_widget <- function(x, ctx) {
    rendered <- htmltools::renderTags(x)
    ctx$deps <- c(ctx$deps, rendered$dependencies)
    as.character(rendered$html)
}

#' Error box of a failed step
#' @param x a `pub_error`.
#' @return `character(1)` HTML.
#' @noRd
.html_error <- function(x) {
    detail <- if (!identical(x$step, x$failed_step)) {
        sprintf(
            paste0(
                "\n<div class=\"pubflow-error-detail\">Step '%s' was ",
                "not run.</div>"
            ),
            .esc(x$step)
        )
    }
    sprintf(
        paste0(
            "<div class=\"pubflow-error-title\">Step %s failed</div>\n",
            "<div class=\"pubflow-error-message\">%s</div>%s"
        ),
        .esc(.failed_label(x)),
        .esc(x$message),
        detail %||% ""
    )
}


# ------
# Tables
# ------
#' Table: huxtable's HTML of the display table with a numbered caption
#'
#' huxtable puts the same `<style>` block before every table; its rules are in
#' pubflow-doc.css instead. The caption is pubflow's (escaped; the table's `<caption>`,
#' so assistive technologies announce it with the table); the cached HTML has no
#' caption, because its number depends on the position in the document.
#' @param x a huxtable (a `pub_table`).
#' @param meta the metadata of the item (`caption`, `font_size`).
#' @param ctx the render context.
#' @return `character(1)` HTML.
#' @noRd
.html_table <- function(x, meta, ctx) {
    fontSize <- meta[["font_size"]]
    key <- if (!is.null(ctx$cache)) .cache_table_key(x, fontSize)
    html <- if (!is.null(key)) .cache_get(ctx$cache, key)
    if (is.null(html)) {
        html <- .huxtable_html(x, fontSize)
        if (!is.null(key)) {
            .cache_set(ctx$cache, key, html, is_file = FALSE)
        }
    }
    caption <- meta[["caption"]]
    if (is.null(caption)) {
        return(html)
    }
    ctx$tables <- ctx$tables + 1L
    .ref_number(ctx$refs, meta, "table", ctx$tables)
    caption <- sprintf(
        "<caption>%s %d: %s</caption>",
        .esc(ctx$labels$table),
        ctx$tables,
        .esc(caption)
    )
    sub("(<table[^>]*>)", paste0("\\1\n", .escape_backrefs(caption)), html)
}

#' Escape `\\` for use as replacement in `sub()`
#' @param x `character` replacement text.
#' @return `x` with every backslash doubled.
#' @noRd
.escape_backrefs <- function(x) {
    gsub("\\", "\\\\", x, fixed = TRUE)
}

#' huxtable's HTML of the display table, without caption and style block
#' @param x a huxtable (a `pub_table`).
#' @param font_size font size in points or `NULL` (the table's own).
#' @return `character(1)` HTML.
#' @noRd
.huxtable_html <- function(x, font_size) {
    ht <- .display_huxtable(x)
    huxtable::caption(ht) <- NA
    ht <- .html_widths(ht)
    if (!is.null(font_size)) {
        huxtable::font_size(ht) <- font_size
    }
    html <- huxtable::to_html(ht)
    html <- sub("(?s)^\\s*<style>.*?</style>\\s*", "", html, perl = TRUE)
    sub("\n+$", "", html)
}

#' Column widths for HTML, as in DOCX and PDF
#'
#' Numbers become percentages (automatic columns count as one share, as in DOCX) of
#' the table width: `huxtable::width()`, else the page width unless all columns are
#' absolute. `"<n>cm"` columns also get a `min-width`, so that browsers take their
#' width from the other columns (they ignore `calc()` mixing `%` and `cm` in columns).
#' @param ht a huxtable.
#' @return `ht` with CSS widths in `col_width()` and `width()`.
#' @noRd
.html_widths <- function(ht) {
    w <- .width_kinds(huxtable::col_width(ht))
    if (all(w$auto)) {
        return(ht)
    }
    widths <- paste0(signif(100 * w$share / sum(w$share[!w$cm]), 6), "%")
    # huxtable writes the value as is into the column's `style="width: ..."`
    widths[w$cm] <- paste0(w$value[w$cm], "; min-width: ", w$value[w$cm])
    huxtable::col_width(ht) <- widths
    if (!all(w$cm) && is.na(huxtable::width(ht))) {
        huxtable::width(ht) <- 1
    }
    ht
}


# -------
# Figures
# -------
#' Figure: inline image and numbered caption
#' @param x a recorded plot, ggplot or image file paths.
#' @param meta the metadata of the item (`caption`, `title`, `out_width`, size).
#' @param ctx the render context.
#' @return `character(1)` HTML.
#' @noRd
.html_figure <- function(x, meta, ctx) {
    src <- .figure_src(x, meta, ctx)
    caption <- meta[["caption"]]
    alt <- caption %||% meta[["title"]] %||% "Figure"
    if (!is.null(caption)) {
        ctx$figures <- ctx$figures + 1L
        .ref_number(ctx$refs, meta, "figure", ctx$figures)
        caption <- sprintf(
            "\n<figcaption>%s %d: %s</figcaption>",
            .esc(ctx$labels$figure),
            ctx$figures,
            .esc(caption)
        )
    } else {
        caption <- ""
    }
    sprintf(
        paste0(
            "<figure>\n<img src=\"%s\" alt=\"%s\" style=\"width: %s;\">",
            "%s\n</figure>"
        ),
        src,
        .esc(alt, TRUE),
        meta[["out_width"]] %||% "90%",
        caption
    )
}

#' Data URI of a figure, rendered (or taken from the cache)
#' @param x a recorded plot, ggplot or image file paths.
#' @param meta the metadata of the item (`width`, `height`).
#' @param ctx the render context.
#' @return `character(1)` data URI.
#' @noRd
.figure_src <- function(x, meta, ctx) {
    res <- .figure_file(x, meta, ctx$figure, ctx$cache, devices = c("png", "svg"))
    if (res$temporary) {
        on.exit(unlink(res$file), add = TRUE)
    }
    .data_uri(res$file)
}

#' Image file of a figure: rendered, taken from the cache or (image files) the matching
#' source file
#'
#' @param x a recorded plot, ggplot, `pub_png` or image file paths.
#' @param meta the metadata of the item (`width`, `height` in inches).
#' @param figure `list(device, res)` device settings.
#' @param cache a `pub_cache` or `NULL`.
#' @param devices the devices the target shows: image files of these formats are used if
#'   there is none of `figure$device` or a raster one.
#' @return `list(file, temporary)`: the path, and `TRUE` if the caller must delete the
#'   file (rendered without a cache, or the bytes of a `pub_png`).
#' @noRd
.figure_file <- function(x, meta, figure, cache, devices = figure$device) {
    device <- figure$device
    if (is.character(x)) {
        file <- .pick_image_file(x, device, devices)
        return(list(file = file, temporary = FALSE))
    }
    if (inherits(x, "pub_png")) {
        file <- .write_png(x, tempfile("pubflow-figure-", fileext = ".png"))
        return(list(file = file, temporary = TRUE))
    }
    settings <- list(
        device = device,
        res = figure$res,
        width = meta[["width"]] %||% 8,
        height = meta[["height"]] %||% 6
    )
    key <- if (!is.null(cache)) .cache_key(x, settings)
    file <- if (!is.null(key)) .cache_get(cache, key)
    if (!is.null(file)) {
        return(list(file = file, temporary = FALSE))
    }
    file <- if (!is.null(key)) {
        .cache_path(cache, key, device)
    } else {
        tempfile("pubflow-figure-", fileext = paste0(".", device))
    }
    .render_figure(
        x,
        file,
        device = device,
        width = settings$width,
        height = settings$height,
        res = settings$res
    )
    if (!is.null(key)) {
        .cache_set(cache, key, file)
    }
    list(file = file, temporary = is.null(key))
}

#' Base64 data URI of an image file
#' @param file path of the image file.
#' @return `character(1)` data URI.
#' @noRd
.data_uri <- function(file) {
    ext <- tolower(tools::file_ext(file))
    mime <- switch(
        ext,
        svg = "image/svg+xml",
        jpg = ,
        jpeg = "image/jpeg",
        paste0("image/", ext)
    )
    paste0("data:", mime, ";base64,", base64enc::base64encode(file))
}


# ======================================================================================
# Helpers
# ======================================================================================

# --------
# Escaping
# --------
#' Escape text (and attribute values) for HTML
#' @param x `character` text.
#' @param attribute `TRUE`: also escape quotes (for attribute values).
#' @return `character` escaped text.
#' @noRd
.esc <- function(x, attribute = FALSE) {
    as.character(htmltools::htmlEscape(x, attribute = attribute))
}
