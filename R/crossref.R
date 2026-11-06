# Cross-references in texts (D44): `@fig:<id>` and `@tab:<id>` refer to the
# captioned figure or table with that metadata `id`. Before a walk, the targets of the
# document are collected; the text converters replace each reference by a token (as
# math and placeholders). LaTeX and Typst number their captions themselves, so they get
# engine references to the items' labels; HTML, DOCX and md get a marker that is
# replaced after the walk by the number the walk gave the caption, so a reference may
# come before its target. Problems (unknown id, wrong prefix, no caption, duplicate
# ids) are errors in reports and warnings in the HTML of `pub_html()` and the viewer.

# ======================================================================================
# Cross-references
# ======================================================================================

# -------
# Targets
# -------
#' Pattern of an id: valid as HTML id and as LaTeX and Typst label
#' @noRd
.ref_id_pattern <- function() {
    "[A-Za-z](?:[A-Za-z0-9_-]*[A-Za-z0-9])?"
}

#' Cross-reference state of a document: its targets, the caption numbers given in the
#' walk and the problems found
#'
#' @param nodes list of nodes: front matter and body.
#' @param labels words for numbered captions (`list(table, figure)`).
#' @return an environment with `targets` (named by id: `list(type, captioned, index)`,
#'   only ids used once), `numbers` (named `integer`), `labels` and `problems`.
#' @noRd
.ref_state <- function(nodes, labels) {
    found <- .ref_targets(nodes)
    ids <- vapply(found, `[[`, character(1), "id")
    counts <- table(ids)
    state <- new.env(parent = emptyenv())
    state$labels <- labels
    state$numbers <- integer()
    state$problems <- sprintf(
        "The id '%s' is used by %d items; ids must be unique in a document.",
        names(counts)[counts > 1L],
        counts[counts > 1L]
    )
    unique <- !ids %in% names(counts)[counts > 1L]
    state$targets <- rlang::set_names(
        lapply(which(unique), \(i) {
            list(type = found[[i]]$type, captioned = found[[i]]$captioned, index = i)
        }),
        ids[unique]
    )
    state$duplicated <- names(counts)[counts > 1L]
    state
}

#' Tables and figures with an id, in document order
#' @param nodes list of nodes (sections are searched).
#' @return list of `list(id, type, captioned)`.
#' @noRd
.ref_targets <- function(nodes) {
    found <- lapply(nodes, \(x) {
        if (inherits(x, "pub_section")) {
            .ref_targets(x$children)
        } else if (x$type %in% c("table", "figure") && !is.null(x$meta[["id"]])) {
            list(list(
                id = x$meta[["id"]],
                type = x$type,
                captioned = !is.null(x$meta[["caption"]])
            ))
        }
    })
    .unlist1(found)
}

#' The target of an item's metadata, if the item is one that references can reach
#' @param state the cross-reference state (`NULL`: none).
#' @param meta the item's metadata.
#' @param type `"table"` or `"figure"`.
#' @return the target (`list(type, captioned, index)`) or `NULL`.
#' @noRd
.ref_anchor <- function(state, meta, type) {
    id <- meta[["id"]]
    target <- if (!is.null(state) && !is.null(id)) state$targets[[id]]
    if (!is.null(target) && target$type == type && target$captioned) target
}

#' Label of an item that is a target (LaTeX and Typst)
#' @param ctx the render context (`refs`: the cross-reference state).
#' @param meta the item's metadata.
#' @param type `"table"` or `"figure"`.
#' @return `character(1)` the id or `NULL`.
#' @noRd
.ref_label <- function(ctx, meta, type) {
    if (!is.null(.ref_anchor(ctx$refs, meta, type))) meta[["id"]]
}

#' Record the caption number of an item that is a target
#' @param state the cross-reference state (`NULL`: none).
#' @param meta the item's metadata.
#' @param type `"table"` or `"figure"`.
#' @param number `integer(1)` the caption number.
#' @noRd
.ref_number <- function(state, meta, type, number) {
    if (!is.null(.ref_anchor(state, meta, type))) {
        state$numbers[[meta[["id"]]]] <- number
    }
    invisible(state)
}


# ------------------
# References in text
# ------------------
#' Replace the references in the text of Markdown by tokens
#'
#' Only in text nodes (commonmark's parser) outside links and images: not in links'
#' texts and targets, autolinks and images' descriptions. Code spans, math and
#' placeholders are tokens already.
#' @param text `character(1)` Markdown.
#' @param store the token store of the conversion.
#' @param convert `function(match)` (`.ref_converter()`) or `NULL` (references stay
#'   text).
#' @param context `character(1)` the text around `text` (without fenced code), whose
#'   link reference definitions apply to `text` too, or `NULL`.
#' @return `text` with tokens.
#' @noRd
.protect_refs <- function(text, store, convert, context = NULL) {
    if (is.null(convert) || !grepl("@(fig|tab):", text, perl = TRUE)) {
        return(text)
    }
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    # the context after the text: same line numbers
    nodes <- .markdown_text_nodes(paste(c(text, context), collapse = "\n\n"))
    if (is.null(nodes)) {
        return(text)
    }
    keep <- nodes[, "link"] == 0L &
        nodes[, "image"] == 0L &
        nodes[, 1L] == nodes[, 3L] &
        nodes[, 1L] <= length(lines)
    nodes <- nodes[keep, , drop = FALSE]
    for (i in unique(nodes[, 1L])) {
        lines[[i]] <- .protect_ref_line(
            lines[[i]],
            nodes[nodes[, 1L] == i, c(2L, 4L), drop = FALSE],
            store,
            convert
        )
    }
    # strsplit() drops the last newline
    paste0(paste(lines, collapse = "\n"), if (endsWith(text, "\n")) "\n")
}

#' Pattern of a reference
#' @noRd
.ref_pattern <- function() {
    paste0("@(fig|tab):(", .ref_id_pattern(), ")")
}

#' Replace the references in text nodes of a line by tokens
#'
#' A reference after a backslash or a letter, digit, `_` or `@` (`\@fig:x`,
#' `a@fig:x`) is text.
#' @param line `character(1)` a line of Markdown.
#' @param nodes integer matrix of the text nodes on the line: first and last byte
#'   column.
#' @param store the token store of the conversion.
#' @param convert `function(match)`.
#' @return `line` with tokens.
#' @noRd
.protect_ref_line <- function(line, nodes, store, convert) {
    matches <- gregexpr(.ref_pattern(), line, perl = TRUE, useBytes = TRUE)[[1L]]
    bytes <- charToRaw(line)
    for (k in rev(seq_along(matches[matches > 0L]))) {
        first <- matches[[k]]
        last <- first + attr(matches, "match.length")[[k]] - 1L
        node <- which(first >= nodes[, 1L] & last <= nodes[, 2L])
        before <- rawToChar(bytes[seq_len(first - 1L)])
        Encoding(before) <- "UTF-8"
        if (
            length(node) == 0L ||
                .is_escaped(bytes, nodes[node[[1L]], 1L], first) ||
                grepl("[\\p{L}\\p{N}_@]$", before, perl = TRUE)
        ) {
            next
        }
        token <- .tokenize(
            rawToChar(bytes[first:last]),
            .ref_pattern(),
            "ref",
            store,
            convert
        )
        bytes <- c(bytes[seq_len(first - 1L)], charToRaw(token), bytes[-seq_len(last)])
    }
    res <- rawToChar(bytes)
    Encoding(res) <- "UTF-8"
    res
}

#' Resolve a reference; a problem is recorded in the state
#' @param match `character(1)` the reference, e.g. `"@fig:trend"`.
#' @param state the cross-reference state.
#' @return `list(id, type)` or `NULL` if it doesn't resolve.
#' @noRd
.ref_resolve <- function(match, state) {
    type <- c(fig = "figure", tab = "table")[[sub("^@(fig|tab):.*", "\\1", match)]]
    id <- sub("^@(fig|tab):", "", match)
    target <- state$targets[[id]]
    problem <- if (id %in% state$duplicated) {
        sprintf("`%s`: the id '%s' is not unique.", match, id)
    } else if (is.null(target)) {
        sprintf("`%s`: no table or figure has the id '%s'.", match, id)
    } else if (target$type != type) {
        sprintf("`%s`: '%s' is a %s.", match, id, target$type)
    } else if (!target$captioned) {
        sprintf(
            "`%s`: the %s '%s' has no caption, so it has no number.",
            match,
            type,
            id
        )
    }
    if (!is.null(problem)) {
        state$problems <- c(state$problems, problem)
        return(NULL)
    }
    list(id = id, type = type)
}

#' Converter of references for `.protect_markdown()`
#' @param state the cross-reference state.
#' @param target `"html"`, `"docx"`, `"latex"`, `"typst"` or `"md"`.
#' @return `function(match)` giving the replacement of a reference.
#' @noRd
.ref_converter <- function(state, target) {
    function(match) {
        ref <- .ref_resolve(match, state)
        if (is.null(ref)) {
            return(switch(
                target,
                html = sprintf(
                    "<span class=\"pubflow-ref-unresolved\">%s</span>",
                    .esc(match)
                ),
                .escape_inline(match)
            ))
        }
        name <- switch(ref$type, table = "\\tablename", figure = "\\figurename")
        switch(
            target,
            latex = .md_raw_inline(
                sprintf("\\hyperref[%s]{%s~\\ref*{%s}}", ref$id, name, ref$id),
                "latex"
            ),
            typst = .md_raw_inline(sprintf("#ref(<%s>)", ref$id), "typst"),
            .ref_marker(ref$id)
        )
    }
}

#' Marker of a reference whose number is filled in after the walk
#' @param id `character(1)` the target's id.
#' @noRd
.ref_marker <- function(id) {
    paste0(.token_mark(), "pubflow-ref:", id, .token_mark())
}


# -------
# Writers
# -------
#' Replace the markers of references by the targets' numbers
#'
#' HTML: a link to the item; DOCX: a `REF` field to the caption's bookmark, with the
#' number as its result (`.ref_field()`); md: the text.
#' @param text `character` HTML or Markdown with markers.
#' @param state the cross-reference state.
#' @param target `"html"`, `"docx"` or `"md"`.
#' @param prefix prefix of the HTML element ids (`target = "html"`).
#' @return `text` with the references.
#' @noRd
.insert_refs <- function(text, state, target, prefix = NULL) {
    mark <- .token_mark()
    pattern <- paste0(mark, "pubflow-ref:([^", mark, "]+)", mark)
    markers <- unique(unlist(regmatches(text, gregexpr(pattern, text, perl = TRUE))))
    for (marker in markers) {
        id <- sub(pattern, "\\1", marker, perl = TRUE)
        item <- state$targets[[id]]
        words <- sprintf("%s %d", state$labels[[item$type]], state$numbers[[id]])
        ref <- switch(
            target,
            html = sprintf(
                "<a class=\"pubflow-ref\" href=\"#%s\">%s</a>",
                .html_item_id(prefix, item$type, id),
                .esc(words)
            ),
            docx = .ref_field(item$index, words),
            .escape_literal(words)
        )
        text <- gsub(marker, ref, text, fixed = TRUE)
    }
    text
}

#' Word `REF` field to the bookmark of a target, with the number as its result
#'
#' The result is Markdown between the raw field characters, so it gets the formatting
#' of the text around it (`**See @fig:x**`); `\* MERGEFORMAT` keeps it when Word
#' updates the field.
#' @param index `integer(1)` position of the target among the document's ids.
#' @param words `character(1)` the label and number.
#' @return `character(1)` Markdown.
#' @noRd
.ref_field <- function(index, words) {
    instr <- sprintf(" REF %s \\h \\* MERGEFORMAT ", .ref_bookmark(index))
    paste0(
        .md_raw_inline(
            paste0(
                "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r>",
                "<w:instrText xml:space=\"preserve\">",
                .esc(instr),
                "</w:instrText></w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>"
            ),
            "openxml"
        ),
        .escape_literal(words),
        .md_raw_inline("<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>", "openxml")
    )
}

#' HTML element id of an item with a metadata id: `<prefix>-<type>-<id>`
#'
#' The prefix keeps the ids of the viewers on a page apart, the type those of items
#' that share an id.
#' @param prefix prefix of the element ids (`"pubflow"`, the viewer's namespace).
#' @param type the item's type (`"figure"`, `"table"`, ...).
#' @param id `character(1)` the metadata id.
#' @noRd
.html_item_id <- function(prefix, type, id) {
    paste(prefix, type, id, sep = "-")
}

#' Name of the Word bookmark around a target's caption number
#' @param index `integer(1)` position of the target among the document's ids.
#' @noRd
.ref_bookmark <- function(index) {
    sprintf("_Ref_pubflow_%d", index)
}

#' Word bookmark around the label and number of a caption
#' @param target the item's target (`.ref_anchor()`) or `NULL`.
#' @param content `character(1)` Markdown of the label and the `SEQ` field.
#' @return `content`, inside the bookmark if the item is a target.
#' @noRd
.ref_bookmarked <- function(target, content) {
    if (is.null(target)) {
        return(content)
    }
    # ids above those of pandoc's bookmarks and the reference document's
    id <- 90000L + target$index
    paste0(
        .md_raw_inline(
            sprintf(
                "<w:bookmarkStart w:id=\"%d\" w:name=\"%s\"/>",
                id,
                .ref_bookmark(target$index)
            ),
            "openxml"
        ),
        content,
        .md_raw_inline(sprintf("<w:bookmarkEnd w:id=\"%d\"/>", id), "openxml")
    )
}

#' Signal the problems of the references: an error in reports, a warning otherwise
#'
#' The condition's field `problems` holds the messages of the problems.
#' @param state the cross-reference state.
#' @param mode `"error"` or `"warn"`.
#' @param format format named in the error.
#' @noRd
.ref_signal <- function(state, mode, format) {
    problems <- unique(state$problems)
    if (length(problems) == 0L) {
        return(invisible())
    }
    msg <- c(
        "Can't resolve the cross-references of the document.",
        rlang::set_names(problems, rep("x", length(problems))),
        i = "References (`@fig:<id>`, `@tab:<id>`) need one captioned item with the id."
    )
    if (mode == "error") {
        rlang::cnd_signal(.render_error(msg, format = format, problems = problems))
    }
    rlang::warn(
        paste(c(msg[[1L]], rlang::format_error_bullets(msg[-1L])), collapse = "\n"),
        class = "pubflow_render_warning",
        problems = problems
    )
}
