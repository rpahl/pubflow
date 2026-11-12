# Tables. pub_table() builds a plain huxtable (never a subclass) from a data.frame, or
# finishes a huxtable: header rows (an optional spanner row and the label row,
# huxtable's header_rows()), body and footnote rows, styled by a theme. Cells hold
# huxtable's text (numbers as as.character()) and their formats live in huxtable's
# number_format and na_string (see R/table_format.R). Styling, binding and subsetting
# use huxtable's own functions; pub_strikeout() adds strikeout as huxtable Markdown
# cells. The only table structure pubflow stores is the role of each row (attribute
# `pub_table_rows`, see pub_table_rows()), which binding and subsetting invalidate.

# ======================================================================================
# Building tables
# ======================================================================================

# ------
# Tables
# ------
#' Create a pubflow table
#'
#' Builds a styled [huxtable][huxtable::huxtable()] from a data.frame or matrix, or
#' finishes an existing huxtable.
#'
#' @details
#' Compared with [huxtable::huxtable()], `pub_table()` sets up labels, spanner headers,
#' footnotes, merged cells and a theme in one call, and its number formatting (rounded
#' half away from zero, see [pub_round()]) gives the same text in every output format.
#'
#' ## Structure
#'
#' A table built from a data.frame or matrix has
#'
#' * header rows: an optional spanner row above the label row;
#' * the body;
#' * optional footnote rows,
#'
#' and is styled by a table theme (see [pub_table_theme()]).
#'
#' Given a huxtable, `pub_table()` finishes it instead: it applies theme, borders,
#' labels, digits, footnotes etc. to its header and body rows, e.g. after you combined
#' tables with huxtable's `rbind()`.
#'
#' ## Number formats
#'
#' Rounding and formatting happen only when the table is rendered, by one formatter that
#' is used for all output formats, so the cells show the same text everywhere (see
#' [pub_cell_text()]). Until then the cells hold the unrounded values as text, and the
#' format of numbers is stored in huxtable's `number_format` (from `digits`, otherwise
#' the theme's default for numeric columns) and `na_string` (from `na`).
#'
#' ## Styling
#'
#' Style tables with huxtable's functions, e.g. [huxtable::set_text_color()] or
#' [huxtable::map_text_color()]. Keep in mind:
#'
#' * Their rows include the header rows: [pub_table_rows()] gives the table rows of
#'   the header, body and footnotes (see Examples).
#' * Use integer rows: huxtable recycles short logical vectors, also into the footnote
#'   rows.
#' * Strike cells through with [pub_strikeout()].
#'
#' ## Combining tables
#'
#' The simplest way is to combine the data and build one table (see Examples). You can
#' also combine finished tables with huxtable's `rbind()`, `cbind()` and `[`. They
#' preserve cell properties (styles, number formats, merges, struck-through cells), but
#'
#' * bind by position;
#' * keep the borders of each part;
#' * drop pubflow's metadata (`pub_meta()`), except `rbind()`, which keeps that of the
#'   first table.
#'
#' So finish the combined table with `pub_table()` and set footnotes, widths, metadata
#' and strikeout on the final table.
#'
#' @param x A data.frame or matrix, or a huxtable to finish.
#' @param caption `character(1)` table caption or `NULL` (as is a blank string).
#' @param labels Named character vector: column name -> header label. Columns not named
#'   keep their name (or label) as label.
#' @param digits Named vector: column name -> number of decimal places (0 to 324) of a
#'   numeric column (rounded half away from zero, see [pub_round()]).
#' @param align Named character vector: column name -> `"left"`, `"right"` or
#'   `"center"`. Default: numeric columns right, others left.
#' @param widths Named vector: column name -> relative width (a positive number),
#'   absolute width (`"<n>cm"`) or `"auto"` (as if not given). Absolute columns keep
#'   their width, relative widths share the rest of the table width. Usually not needed:
#'   without widths, columns are sized by their content and text wraps to fit the page.
#'   (In PDF via LaTeX pubflow computes the widths from the cell texts, and a table
#'   whose longest words don't fit gets a smaller font.)
#' @param header Named character vector: column name -> spanner label shown above the
#'   labels. Consecutive equal labels are merged; columns without a spanner get an empty
#'   cell. Data.frames and matrices only.
#' @param footnotes Named character vector: column name -> footnote. The label gets a
#'   numbered marker (superscript digit), the footnotes are listed below the body (equal
#'   texts share one number). Give all footnotes in one call, for the final table:
#'   a table that has footnotes keeps them when it is finished again, but after
#'   binding or subsetting they become body rows.
#' @param merge Character vector of column names whose consecutive equal body cells are
#'   merged vertically.
#' @param na `character(1)` text shown for missing values.
#' @param font_size Font size in points (default: the theme's).
#' @param theme A [pub_table_theme()]. Default: option `pubflow.table_theme`, otherwise
#'   `pub_table_theme()`.
#' @return A huxtable.
#' @seealso [pub_table_rows()], [pub_cell_text()], [pub_strikeout()],
#'   [pub_table_theme()], [pub_params_table()]
#' @examples
#' df <- airquality[c(1, 2, 32, 33), c("Month", "Day", "Ozone", "Wind")]
#' df$Month <- month.name[df$Month]
#' ht <- pub_table(
#'     df,
#'     caption = "First days of May and June",
#'     labels = c(Ozone = "Ozone (ppb)", Wind = "Wind (mph)"),
#'     digits = c(Wind = 0),
#'     header = c(Ozone = "Measured", Wind = "Measured"),
#'     footnotes = c(Ozone = "Mean from 1 to 3 pm."),
#'     merge = "Month",
#'     na = "-"
#' )
#' pub_cell_text(ht)
#'
#' # Style with huxtable: body row i is table row pub_table_rows(ht)$body[i]
#' body <- pub_table_rows(ht)$body
#' ht <- huxtable::set_text_color(ht, body[df$Wind > 9], "Wind", "red")
#'
#' # Combine the data, then build one table
#' more <- rbind(df, data.frame(Month = "July", Day = 1L, Ozone = 135L, Wind = 4.1))
#' pub_cell_text(pub_table(more, digits = c(Wind = 0), merge = "Month"))
#'
#' # A matrix works like a data.frame
#' m <- as.matrix(airquality[1:2, c("Wind", "Temp")])
#' pub_cell_text(pub_table(m, digits = c(Wind = 1, Temp = 0)))
#'
#' # Layout: alignment, column widths and font size
#' pub_table(
#'     df,
#'     align = c(Month = "center"),
#'     widths = c(Month = "2cm", Ozone = 1),
#'     font_size = 9
#' )
#'
#' # Combined tables: `[` and `cbind()` drop the metadata, `rbind()` keeps the first
#' ht <- pub_set_meta(pub_table(df), id = "first-days")
#' pub_meta(ht[1:2, ], "id")
#' pub_meta(rbind(ht, ht), "id")
#' @export
pub_table <- function(
    x,
    caption = NULL,
    labels = NULL,
    digits = NULL,
    align = NULL,
    widths = NULL,
    header = NULL,
    footnotes = NULL,
    merge = NULL,
    na = "",
    font_size = NULL,
    theme = getOption("pubflow.table_theme", pub_table_theme())
) {
    .check_table_args(caption, na, font_size, theme)
    old <- .recorded_roles(x)
    nOldNotes <- old$nNotes %||% 0L
    ht <- if (huxtable::is_huxtable(x)) {
        if (!is.null(header)) {
            rlang::abort(
                "`header` needs a data.frame or matrix; `x` is a huxtable."
            )
        }
        .finish_table(x, labels, digits, old)
    } else {
        .new_table(x, labels, digits, header, theme)
    }
    cols <- names(ht)
    widths <- .check_widths(
        .column_spec(widths, cols, "widths", default = NA_character_)
    )
    merge <- .check_merge(merge, cols)
    notes <- .check_notes(footnotes, cols)
    ht <- .add_footnotes(ht, notes, nOldNotes)
    marks <- old$marks %||% .footnote_marks(notes)
    rows <- .table_rows(ht, nOldNotes + length(.unique_notes(notes)))
    ht <- .apply_theme(ht, rows, theme, font_size)
    ht <- .apply_align(ht, rows, align)
    ht <- .apply_na(ht, rows, na)
    ht <- .merge_body(ht, rows, merge)
    ht <- .apply_borders(ht, rows, theme)
    ht <- .apply_widths(ht, widths)
    if (!is.null(caption)) {
        # a blank caption removes the one of a huxtable being finished
        huxtable::caption(ht) <- if (grepl("[^[:space:]]", caption)) caption else NA
    }
    huxtable::caption_pos(ht) <- "top"
    ht <- .apply_style(ht, rows, theme$style)
    .record_rows(ht, rows, marks)
}

#' Validate the scalar arguments of pub_table()
#' @param caption,na,font_size,theme the arguments of pub_table().
#' @param call the environment of the caller, for the error message.
#' @return `TRUE`, invisibly.
#' @noRd
.check_table_args <- function(
    caption,
    na,
    font_size,
    theme,
    call = rlang::caller_env()
) {
    if (!is.null(caption) && !rlang::is_string(caption)) {
        rlang::abort("`caption` must be a single string or `NULL`.", call = call)
    }
    if (!rlang::is_string(na)) {
        rlang::abort("`na` must be a single string.", call = call)
    }
    if (!is.null(font_size) && !.is_positive_number(font_size)) {
        rlang::abort("`font_size` must be a positive number or `NULL`.", call = call)
    }
    if (!inherits(theme, "pub_table_theme")) {
        rlang::abort("`theme` must be created by `pub_table_theme()`.", call = call)
    }
    invisible(TRUE)
}


# ----
# Data
# ----
#' Build a table from a data.frame or matrix
#'
#' huxtable stores the cells as text below the label row
#' (`as_hux(add_colnames = TRUE)`); date-times are converted to UTC text first.
#' @param x a data.frame or matrix.
#' @param labels,digits,header the specs of pub_table() (`NULL` or named by column).
#' @param theme a `pub_table_theme`.
#' @param call the environment of the caller, for the error message.
#' @return huxtable with header rows, number formats and spanner merges.
#' @noRd
.new_table <- function(x, labels, digits, header, theme, call = rlang::caller_env()) {
    x <- .check_table_data(x, call)
    cols <- names(x)
    for (arg in c("labels", "header")) {
        spec <- list(labels = labels, header = header)[[arg]]
        if (!is.null(spec)) {
            .check_text_spec(spec, arg, call)
        }
    }
    labels <- .column_spec(labels, cols, "labels", default = cols, call)
    digits <- .column_spec(digits, cols, "digits", default = NA, call)
    header <- .column_spec(header, cols, "header", default = "", call)
    .check_digits(digits, call)

    isTime <- vapply(x, inherits, logical(1), what = "POSIXt")
    data <- x
    data[isTime] <- lapply(x[isTime], .text_of)
    ht <- huxtable::as_hux(data, add_colnames = TRUE)
    for (j in seq_along(cols)) {
        ht[1L, j] <- labels[[j]]
    }
    ht <- .init_formats(ht, x, digits, theme)
    if (any(nzchar(header))) {
        # rbind() of a one-row huxtable: ~10x faster than insert_row()
        spanner <- huxtable::as_hux(matrix(unname(header), 1L), add_colnames = FALSE)
        ht <- rbind(spanner, ht)
        names(ht) <- cols
        huxtable::header_rows(ht)[1L] <- TRUE
        huxtable::number_format(ht)[1L, ] <- NA
        for (run in .runs(unname(header), nzchar)) {
            ht <- huxtable::merge_cells(ht, 1L, run)
        }
    }
    ht
}

#' Validate the data of a new table (a matrix becomes a data.frame)
#' @param x a data.frame or matrix.
#' @param call the environment of the caller, for the error message.
#' @return `x` as a data.frame.
#' @noRd
.check_table_data <- function(x, call) {
    if (is.matrix(x)) {
        x <- as.data.frame(x, stringsAsFactors = FALSE)
    }
    if (!is.data.frame(x) || ncol(x) == 0L) {
        rlang::abort("`x` must be a data.frame or matrix with columns.", call = call)
    }
    cols <- names(x)
    if (anyDuplicated(cols) > 0L || anyNA(cols) || !all(nzchar(cols))) {
        rlang::abort("The columns of `x` need unique, non-empty names.", call = call)
    }
    if (any(vapply(x, is.list, logical(1)))) {
        rlang::abort("List columns are not supported.", call = call)
    }
    x
}

#' Number formats of the body cells of numeric columns
#' @param ht the huxtable built from `x` (one label row).
#' @param x the data (typed columns).
#' @param digits decimal places per column (`NA`: not given).
#' @param theme a `pub_table_theme`.
#' @return `ht` with number formats.
#' @noRd
.init_formats <- function(ht, x, digits, theme) {
    huxtable::number_format(ht) <- NA
    rows <- seq_len(nrow(x)) + 1L
    if (nrow(x) == 0L) {
        return(ht)
    }
    for (j in which(vapply(x, is.numeric, logical(1)))) {
        fmt <- if (!is.na(digits[[j]])) {
            as.integer(digits[[j]])
        } else if (is.integer(x[[j]])) {
            0L
        } else {
            theme$number_format
        }
        huxtable::number_format(ht)[rows, j] <- list(.numeric_format(fmt))
    }
    ht
}

#' Number format that keeps a cell numeric: `NA` marks text cells, so it becomes
#' `as.character` (the same text, no formatting)
#' @param fmt a number format.
#' @return `fmt` or `as.character`.
#' @noRd
.numeric_format <- function(fmt) {
    if (.has_number_format(list(fmt))) fmt else as.character
}

#' Runs of consecutive equal values (length > 1) that pass `keep`
#' @param x an atomic vector (`NA` values never form a run).
#' @param keep function of the run values returning a logical vector.
#' @return list of integer index vectors.
#' @noRd
.runs <- function(x, keep = \(v) rep(TRUE, length(v))) {
    if (length(x) < 2L) {
        return(list())
    }
    r <- rle(x)
    ends <- cumsum(r$lengths)
    starts <- ends - r$lengths + 1L
    ok <- r$lengths > 1L & !is.na(r$values)
    ok[ok] <- keep(r$values[ok])
    Map(seq.int, starts[ok], ends[ok])
}


# -----------------
# Labels and digits
# -----------------
#' Finish a huxtable: typed columns as text, labels and digits
#'
#' Still-typed columns become text first (as huxtable stores them below a header row),
#' so that merges cannot reformat them.
#' @param x a huxtable.
#' @param labels,digits the specs of pub_table() (`NULL` or named by column).
#' @param old the row roles recorded on `x` (.recorded_roles()) or `NULL`: labels
#'   keep their footnote markers, footnote rows get no digits.
#' @param call the environment of the caller, for the error message.
#' @return `x` with text columns, labels and number formats.
#' @noRd
.finish_table <- function(x, labels, digits, old, call = rlang::caller_env()) {
    cols <- names(x)
    for (j in seq_along(cols)) {
        if (is.character(x[[j]])) {
            next
        }
        # numbers stay numeric; labels, dates etc. become text cells
        huxtable::number_format(x)[, j] <- if (is.numeric(x[[j]])) {
            lapply(huxtable::number_format(x)[, j], .numeric_format)
        } else {
            NA
        }
        x[[j]] <- .cell_text(x[[j]], call = call)
    }
    labels <- .column_spec(labels, cols, "labels", default = NA, call)
    digits <- .column_spec(digits, cols, "digits", default = NA, call)
    .check_digits(digits, call)
    hasLabel <- !is.na(labels)
    if (any(hasLabel)) {
        labelRow <- .label_row(x)
        if (length(labelRow) == 0L) {
            rlang::abort("`labels` need a huxtable with a header row.", call = call)
        }
        .check_text_spec(labels[hasLabel], "labels", call)
        for (j in which(hasLabel)) {
            x[labelRow, j] <- paste0(labels[[j]], old$marks[j])
        }
    }
    rows <- .table_rows(x, old$nNotes %||% 0L)$body
    for (j in which(!is.na(digits))) {
        huxtable::number_format(x)[rows, j] <- as.integer(digits[[j]])
    }
    x
}

#' Text of the cells of one column (`NA` stays `NA`)
#' @param x a column of a huxtable.
#' @param call the environment of the caller, for the error message.
#' @return character vector.
#' @noRd
.cell_text <- function(x, call = rlang::caller_env()) {
    if (is.list(x)) {
        rlang::abort("List columns are not supported.", call = call)
    }
    .text_of(x)
}

#' The label row: the last header row (`integer(0)` without header rows)
#' @param ht a huxtable.
#' @noRd
.label_row <- function(ht) {
    header <- which(huxtable::header_rows(ht))
    if (length(header) == 0L) integer(0) else max(header)
}


# ---------
# Footnotes
# ---------
#' Validate footnotes
#' @param footnotes the footnotes of pub_table() (`NULL` or named by column).
#' @param cols the column names.
#' @param call the environment of the caller, for the error message.
#' @return character vector, one note per column (`NA`: none).
#' @noRd
.check_notes <- function(footnotes, cols, call = rlang::caller_env()) {
    if (!is.null(footnotes)) {
        .check_text_spec(footnotes, "footnotes", call)
        if (!all(grepl("[^[:space:]]", footnotes))) {
            rlang::abort("`footnotes` must not be blank.", call = call)
        }
    }
    unname(.column_spec(
        footnotes,
        cols,
        "footnotes",
        default = NA_character_,
        call = call
    ))
}

#' Footnote markers in the label row and footnote rows below the table
#' @param ht a huxtable.
#' @param notes footnotes from .check_notes(), one per column.
#' @param nOld number of footnotes the table already has.
#' @param call the environment of the caller, for the error message.
#' @return `ht` with the markers and footnote rows.
#' @noRd
.add_footnotes <- function(ht, notes, nOld, call = rlang::caller_env()) {
    texts <- .footnote_text(notes)
    if (length(texts) == 0L) {
        return(ht)
    }
    if (nOld > 0L) {
        rlang::abort(
            "The table has footnotes; give all footnotes in one `pub_table()` call.",
            call = call
        )
    }
    labelRow <- .label_row(ht)
    if (length(labelRow) == 0L) {
        rlang::abort("`footnotes` need a table with a header row.", call = call)
    }
    marks <- .footnote_marks(notes)
    for (j in which(nzchar(marks))) {
        label <- .text_of(ht[[j]][[labelRow]])
        ht[labelRow, j] <- paste0(label, marks[[j]])
    }
    for (text in texts) {
        ht <- huxtable::add_footnote(ht, text, border = NULL)
    }
    ht
}

#' Footnote lines ("<marker> <text>"), one per distinct footnote
#' @param notes footnotes from .check_notes(), one per column.
#' @return character vector.
#' @noRd
.footnote_text <- function(notes) {
    texts <- .unique_notes(notes)
    if (length(texts) == 0L) {
        return(character(0))
    }
    paste(.superscript(seq_along(texts)), texts)
}

#' Distinct footnotes in column order
#' @param notes footnotes from .check_notes(), one per column.
#' @return character vector without `NA`.
#' @noRd
.unique_notes <- function(notes) {
    unique(notes[!is.na(notes)])
}

#' Superscript digits (Unicode) for footnote markers
#' @param n whole numbers >= 0.
#' @return character vector, one marker per number.
#' @noRd
.superscript <- function(n) {
    digits <- c(
        "\u2070",
        "\u00b9",
        "\u00b2",
        "\u00b3",
        "\u2074",
        "\u2075",
        "\u2076",
        "\u2077",
        "\u2078",
        "\u2079"
    )
    vapply(
        strsplit(as.character(n), ""),
        \(d) paste(digits[as.integer(d) + 1L], collapse = ""),
        character(1)
    )
}

#' Footnote marker of each column (`""` without footnote)
#' @param notes footnotes from .check_notes(), one per column.
#' @return character vector, one per column.
#' @noRd
.footnote_marks <- function(notes) {
    marks <- rep("", length(notes))
    has <- !is.na(notes)
    marks[has] <- .superscript(match(notes[has], .unique_notes(notes)))
    marks
}


# ======================================================================================
# Styling tables
# ======================================================================================

# ----
# Rows
# ----
#' Rows of a table by role
#'
#' Gives the rows of a table built by [pub_table()]: header, spanner, body and
#' footnote rows. Use them to style rows by role with huxtable's functions, whose rows
#' count from the first header row.
#'
#' `pub_table()` records the roles. huxtable's `rbind()`, `cbind()`, `[` and functions
#' that add rows make them unknown: finish the combined table with `pub_table()`
#' again before asking for its rows. A table with footnotes that is finished again
#' keeps them as footnotes, unless it was bound or subset since.
#' @param ht A huxtable returned by [pub_table()].
#' @return A list of integer row numbers: `header` (spanner and label rows),
#'   `spanner`, `body` and `footnote`. The same list is passed to the `style` function
#'   of a [pub_table_theme()].
#' @seealso [pub_table()]
#' @examples
#' df <- aggregate(Ozone ~ Month, data = airquality, FUN = mean)
#' ht <- pub_table(df, digits = c(Ozone = 1), footnotes = c(Ozone = "Mean in ppb."))
#' rows <- pub_table_rows(ht)
#' rows
#'
#' # body row i is table row rows$body[i]
#' ht <- huxtable::set_bold(ht, rows$body[df$Ozone > 40], "Ozone")
#'
#' # binding makes the roles unknown until the table is finished again
#' parts <- pub_table(df, digits = c(Ozone = 1))
#' both <- rbind(parts, parts[-1, ])
#' try(pub_table_rows(both))
#' pub_table_rows(pub_table(both, footnotes = c(Ozone = "Mean in ppb.")))
#' @export
pub_table_rows <- function(ht) {
    .assert_huxtable(ht)
    roles <- .recorded_roles(ht)
    if (is.null(roles)) {
        rlang::abort(c(
            "The row roles of `ht` are unknown.",
            i = paste(
                "Build it with `pub_table()`, or finish it with `pub_table()` again",
                "after binding or subsetting it."
            )
        ))
    }
    .table_rows(ht, roles$nNotes)
}

#' Row roles recorded by pub_table(), if the record still fits
#'
#' With the number of footnote rows, .table_rows() gives all roles. The record fits
#' if the table has the number of rows and the header rows it had: `[` and `cbind()`
#' drop the attribute, `rbind()` and added rows change the number of rows (a
#' best-effort check: changes of cells in place are not noticed).
#' @param x any object.
#' @return `NULL` or a list: `nNotes`, the number of footnote rows, and `marks`, the
#'   footnote marker of each column (`""` without footnote).
#' @noRd
.recorded_roles <- function(x) {
    recorded <- attr(x, "pub_table_rows", exact = TRUE)
    if (is.null(recorded) || !huxtable::is_huxtable(x)) {
        return(NULL)
    }
    header <- which(unname(huxtable::header_rows(x)))
    fits <- identical(recorded$nRows, nrow(x)) &&
        identical(recorded$header, header) &&
        length(recorded$marks) == ncol(x)
    if (fits) recorded[c("nNotes", "marks")]
}

#' Record the row roles on a table (see pub_table_rows())
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param marks the footnote marker of each column (`""` without footnote).
#' @return `ht` with attribute `pub_table_rows`.
#' @noRd
.record_rows <- function(ht, rows, marks) {
    attr(ht, "pub_table_rows") <- list(
        nNotes = length(rows$footnote),
        marks = marks,
        nRows = nrow(ht),
        header = rows$header
    )
    ht
}

#' Rows of a table being built: header, spanner, body and footnote rows
#' @param ht a huxtable.
#' @param nNotes number of footnote rows (the last rows).
#' @noRd
.table_rows <- function(ht, nNotes) {
    n <- nrow(ht)
    isHeader <- unname(huxtable::header_rows(ht))
    header <- which(isHeader)
    footnote <- seq_len(nNotes) + n - nNotes
    list(
        header = header,
        spanner = setdiff(header, .label_row(ht)),
        body = setdiff(which(!isHeader), footnote),
        footnote = footnote
    )
}


# -----
# Theme
# -----
#' Theme: font size, extra properties, bold header rows
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param theme a `pub_table_theme`.
#' @param font_size font size in points or `NULL` (the theme's).
#' @return the styled `ht`.
#' @noRd
.apply_theme <- function(ht, rows, theme, font_size) {
    if (length(theme$properties) > 0L) {
        ht <- do.call(
            huxtable::style_cells,
            c(list(ht, seq_len(nrow(ht)), seq_len(ncol(ht))), theme$properties)
        )
    }
    huxtable::font_size(ht) <- if (is.null(font_size)) {
        theme$font_size
    } else {
        font_size
    }
    huxtable::bold(ht)[rows$header, ] <- TRUE
    ht
}

#' Alignment: by column, centred spanners, left-aligned footnote rows
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param align the alignment spec of pub_table() (`NULL` or named by column).
#' @param call the environment of the caller, for the error message.
#' @return the aligned `ht`.
#' @noRd
.apply_align <- function(ht, rows, align, call = rlang::caller_env()) {
    cols <- names(ht)
    isNumeric <- vapply(
        seq_along(cols),
        \(j) {
            any(.has_number_format(huxtable::number_format(ht)[rows$body, j]))
        },
        logical(1)
    )
    align <- .column_spec(
        align,
        cols,
        "align",
        default = ifelse(isNumeric, "right", "left"),
        call = call
    )
    if (!all(align %in% c("left", "right", "center"))) {
        rlang::abort("`align` must be \"left\", \"right\" or \"center\".", call = call)
    }
    for (j in seq_along(cols)) {
        huxtable::align(ht)[, j] <- align[[j]]
    }
    huxtable::align(ht)[rows$spanner, ] <- "center"
    huxtable::align(ht)[rows$footnote, ] <- "left"
    ht
}

#' NA text of the body cells
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param na `character(1)` text of missing body values.
#' @noRd
.apply_na <- function(ht, rows, na) {
    huxtable::na_string(ht) <- ""
    huxtable::na_string(ht)[rows$body, ] <- na
    ht
}

#' Merge runs of equal body cells in the given columns
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param merge names of the columns to merge.
#' @noRd
.merge_body <- function(ht, rows, merge) {
    for (col in merge) {
        j <- match(col, names(ht))
        for (run in .runs(ht[[j]][rows$body])) {
            ht <- huxtable::merge_cells(ht, rows$body[run], j)
        }
    }
    ht
}

#' Borders by the theme's border style
#'
#' "booktabs": rules above the table, below spanners and the header and below the body;
#' "grid": borders around every header and body cell. Footnote rows have no borders.
#' Rules are 0.4 pt (booktabs: 0.8 pt above and below the table) unless the theme sets
#' `border_width` (the theme's `border_color` is a cell property, see .apply_theme()).
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param theme a `pub_table_theme`.
#' @noRd
.apply_borders <- function(ht, rows, theme) {
    thin <- theme$border_width %||% 0.4
    thick <- theme$border_width %||% 0.8
    ht <- huxtable::set_all_borders(ht, 0)
    framed <- sort(c(rows$header, rows$body))
    if (length(framed) == 0L) {
        return(ht)
    }
    if (identical(theme$borders, "grid")) {
        return(huxtable::set_all_borders(ht, framed, huxtable::everywhere, thin))
    }
    huxtable::top_border(ht)[framed[[1L]], ] <- thick
    for (i in rows$spanner) {
        hasSpanner <- nzchar(.text_of(unlist(ht[i, ])), keepNA = FALSE)
        huxtable::bottom_border(ht)[i, hasSpanner] <- thin
    }
    huxtable::bottom_border(ht)[.label_row(ht), ] <- thin
    huxtable::bottom_border(ht)[max(framed), ] <- thick
    ht
}

#' Column widths in huxtable's `col_width`
#'
#' Numbers only: a numeric `col_width` (huxtable proportions). With `"<n>cm"` or
#' `"auto"` a character `col_width`, in which plain numbers stay relative widths (the
#' writers translate it). Columns not given keep their width.
#' @param ht a huxtable.
#' @param widths character vector from .check_widths() (`NA`: not given).
#' @noRd
.apply_widths <- function(ht, widths) {
    given <- !is.na(widths)
    if (!any(given)) {
        return(ht)
    }
    values <- as.character(huxtable::col_width(ht))
    values[given] <- widths[given]
    numbers <- suppressWarnings(as.numeric(values))
    huxtable::col_width(ht) <- if (identical(is.na(values), is.na(numbers))) {
        numbers
    } else {
        values
    }
    ht
}

#' Run the theme's style function on the finished table
#' @param ht a huxtable.
#' @param rows the rows from .table_rows().
#' @param style the theme's `style`: `NULL` or a function(ht, rows).
#' @param call the environment of the caller, for the error message.
#' @return the styled `ht`.
#' @noRd
.apply_style <- function(ht, rows, style, call = rlang::caller_env()) {
    if (is.null(style)) {
        return(ht)
    }
    styled <- style(ht, rows)
    if (!huxtable::is_huxtable(styled) || !identical(dim(styled), dim(ht))) {
        rlang::abort(
            paste(
                "The theme's `style` function must return the table it was given,",
                "with the same rows and columns."
            ),
            call = call
        )
    }
    # keep the header rows and metadata (pub_meta(), with the caption) if the
    # function rebuilt the table
    huxtable::header_rows(styled) <- huxtable::header_rows(ht)
    .set_meta(styled, pub_meta(ht))
}


# ------
# Checks
# ------
#' Validate a named character spec (labels, header, footnotes)
#' @param x the spec.
#' @param arg the name of the argument, for the error message.
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_text_spec <- function(x, arg, call) {
    if (!is.character(x) || anyNA(x)) {
        rlang::abort(sprintf("`%s` must be a character vector.", arg), call = call)
    }
}

#' Validate digits: whole numbers from 0 to `.max_digits` (or `NA`: not given)
#' @param digits decimal places per column from .column_spec().
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_digits <- function(digits, call) {
    values <- digits[!is.na(digits)]
    isWhole <- \(v) is.finite(v) & v >= 0 & v == round(v) & v <= .max_digits
    ok <- length(values) == 0L || (is.numeric(values) && all(isWhole(values)))
    if (!ok) {
        rlang::abort("`digits` must be whole numbers from 0 to 324.", call = call)
    }
}

#' Validate widths: positive numbers, "<n>cm" or "auto"
#' @param widths widths per column from .column_spec() (`NA`: not given).
#' @param call the environment of the caller, for the error message.
#' @return character vector (`NA`: no width).
#' @noRd
.check_widths <- function(widths, call = rlang::caller_env()) {
    res <- vapply(
        widths,
        \(w) {
            isScalar <- length(w) == 1L && (is.character(w) || is.numeric(w))
            if (!isScalar) {
                return("invalid")
            }
            if (is.na(w)) {
                return(NA_character_)
            }
            if (is.character(w) && grepl("^([0-9]*\\.)?[0-9]+cm$|^auto$", w)) {
                return(w)
            }
            num <- suppressWarnings(as.numeric(w))
            if (is.finite(num) && num > 0) format(num) else "invalid"
        },
        character(1),
        USE.NAMES = FALSE
    )
    if (any(res == "invalid", na.rm = TRUE)) {
        rlang::abort(
            paste(
                "`widths` must be finite positive numbers (relative widths),",
                "\"<n>cm\" or \"auto\"."
            ),
            call = call
        )
    }
    res
}

#' Validate merge columns
#' @param merge `NULL` or column names.
#' @param cols the column names.
#' @param call the environment of the caller, for the error message.
#' @return character vector of column names.
#' @noRd
.check_merge <- function(merge, cols, call = rlang::caller_env()) {
    if (is.null(merge)) {
        return(character(0))
    }
    if (!is.character(merge) || anyNA(merge)) {
        rlang::abort("`merge` must be a character vector of column names.", call = call)
    }
    unknown <- setdiff(merge, cols)
    if (length(unknown) > 0L) {
        rlang::abort(
            sprintf("`merge` names unknown columns: %s.", toString(unknown)),
            call = call
        )
    }
    merge
}

#' Complete a per-column specification
#' @param spec `NULL` or a named vector or list (column -> value).
#' @param cols the column names.
#' @param arg the name of the argument, for the error message.
#' @param default value(s) for columns not in `spec`.
#' @param call the environment of the caller, for the error message.
#' @return vector (or list, if `spec` is a list) with one element per column in `cols`.
#' @noRd
.column_spec <- function(spec, cols, arg, default, call = rlang::caller_env()) {
    res <- rep_len(default, length(cols))
    names(res) <- cols
    if (is.null(spec)) {
        return(res)
    }
    if (!rlang::is_named2(spec)) {
        rlang::abort(sprintf("`%s` must be named by column.", arg), call = call)
    }
    unknown <- setdiff(names(spec), cols)
    if (length(unknown) > 0L) {
        rlang::abort(
            sprintf("`%s` names unknown columns: %s.", arg, toString(unknown)),
            call = call
        )
    }
    dup <- unique(names(spec)[duplicated(names(spec))])
    if (length(dup) > 0L) {
        rlang::abort(
            sprintf("`%s` names columns more than once: %s.", arg, toString(dup)),
            call = call
        )
    }
    if (is.list(spec)) {
        res <- as.list(res)
    }
    res[names(spec)] <- spec
    res
}


# ======================================================================================
# Strikeout
# ======================================================================================

# ------------
# Struck cells
# ------------
#' Strike table cells through
#'
#' Strikes cells through, e.g. excluded measurements or superseded values. Every output
#' format shows them struck through. Like other cell properties, this survives
#' huxtable's `rbind()`, `cbind()` and `[`.
#'
#' @details
#' huxtable has no strikeout property, so the cells become Markdown cells
#' ([huxtable::markdown()]) that hold their display text (see [pub_cell_text()]) between
#' `~~`. Therefore:
#'
#' * The text is fixed when the cells are struck through (a later change of their
#'   number format does not apply), so strike through last.
#' * Empty cells stay unchanged.
#' * Markdown characters in the text are escaped.
#' * In cells that are Markdown already, each line is struck through as a whole after
#'   its block markers: `~~A~~ and B` becomes `~~A and B~~` and `"# A\n\n- b"` becomes
#'   `"# ~~A~~\n\n- ~~b~~"`.
#'
#' @param ht A huxtable, e.g. from [pub_table()].
#' @param row,col Rows and columns as in huxtable's setters such as
#'   [huxtable::set_bold()]: indices, names, logical vectors, [huxtable::everywhere] or
#'   [huxtable::final()]. Rows include the header rows (see [pub_table()]). Default:
#'   all.
#' @return `ht` with the cells struck through.
#' @seealso [pub_table()]
#' @examples
#' df <- airquality[1:3, c("Day", "Ozone", "Wind")]
#' excluded <- c(FALSE, TRUE, FALSE)
#' ht <- pub_table(df, digits = c(Wind = 1))
#' rows <- pub_table_rows(ht)$body[excluded]
#' ht <- huxtable::set_text_color(ht, rows, huxtable::everywhere, "grey")
#' ht <- pub_strikeout(ht, rows)
#' pub_cell_text(ht)
#' @export
pub_strikeout <- function(ht, row, col) {
    .assert_huxtable(ht)
    if (missing(row)) {
        row <- seq_len(nrow(ht))
    }
    if (missing(col)) {
        col <- seq_len(ncol(ht))
    }
    ht <- huxtable::map_contents(ht, row, col, .strike_cells)
    ht <- huxtable::set_markdown(ht, row, col, TRUE)
    huxtable::set_number_format(ht, row, col, NA)
}

#' New contents of struck-through cells (a huxtable mapping function)
#' @param ht the huxtable.
#' @param rows,cols the selected rows and columns (indices).
#' @param current the current contents of the selected cells (unused).
#' @return character matrix of the new contents.
#' @noRd
.strike_cells <- function(ht, rows, cols, current) {
    text <- .format_cells(ht)
    dimnames(text) <- dimnames(ht)
    text <- trimws(text[rows, cols, drop = FALSE])
    isMarkdown <- huxtable::markdown(ht)[rows, cols, drop = FALSE]
    for (i in which(nzchar(text))) {
        text[[i]] <- if (isMarkdown[[i]]) {
            .strike_markdown(text[[i]])
        } else {
            paste0("~~", .escape_markdown(text[[i]]), "~~")
        }
    }
    text
}

#' Strike Markdown text through line by line
#'
#' Strikethrough can't span paragraphs or contain block markers, so each line's inline
#' content is struck, after its block markers (headings, block quotes, list items):
#' `"# A\n\n- b"` -> `"# ~~A~~\n\n- ~~b~~"`.
#' @param text `character(1)` Markdown text.
#' @noRd
.strike_markdown <- function(text) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    paste(vapply(lines, .strike_line, character(1), USE.NAMES = FALSE), collapse = "\n")
}

#' Strike one line of Markdown through after its block markers
#'
#' A hard line break at its end (two or more spaces, or a backslash) stays after the
#' closing `~~`; other trailing whitespace is dropped.
#' @param line `character(1)` a line of Markdown.
#' @noRd
.strike_line <- function(line) {
    marker <- "^([ \t]*(?:(?:#{1,6}|>|[-+*]|[0-9]{1,9}[.)])(?:[ \t]+|$))*)(.*)$"
    parts <- regmatches(line, regexec(marker, line, perl = TRUE))[[1L]]
    content <- parts[[3L]]
    space <- regmatches(content, regexpr("[ \t]*$", content))
    content <- substr(content, 1L, nchar(content) - nchar(space))
    hardBreak <- if (grepl("^ {2,}$", space)) space else ""
    # a backslash at the end that isn't escaped itself
    if (
        !nzchar(hardBreak) && grepl("(^|[^\\\\])(\\\\\\\\)*\\\\$", content, perl = TRUE)
    ) {
        content <- substr(content, 1L, nchar(content) - 1L)
        hardBreak <- "\\"
    }
    if (!nzchar(content)) {
        return(line)
    }
    paste0(parts[[2L]], .strike_inline(content), hardBreak)
}

#' Strike inline Markdown through as a whole
#'
#' Strikethrough can't be nested, so the `~~` delimiters of partly struck text are
#' removed first (`~~A~~ and B` -> `~~A and B~~`); text that is struck through as a
#' whole stays unchanged.
#' @param text `character(1)` inline Markdown (one line).
#' @noRd
.strike_inline <- function(text) {
    if (.is_struck(text)) {
        return(text)
    }
    paste0("~~", gsub("(?<!\\\\)~~", "", text, perl = TRUE), "~~")
}

#' TRUE if Markdown text is one paragraph struck through as a whole
#' @param text `character(1)` Markdown text.
#' @noRd
.is_struck <- function(text) {
    xml <- commonmark::markdown_xml(text, extensions = "strikethrough") |>
        xml2::read_xml() |>
        xml2::xml_ns_strip()
    blocks <- xml2::xml_children(xml)
    if (length(blocks) != 1L || xml2::xml_name(blocks) != "paragraph") {
        return(FALSE)
    }
    identical(xml2::xml_name(xml2::xml_children(blocks[[1L]])), "strikethrough")
}

#' Escape the characters with a meaning in CommonMark inline text
#' @param x character vector.
#' @noRd
.escape_markdown <- function(x) {
    gsub("([][\\\\`*_<>&~#|])", "\\\\\\1", x)
}

#' Check that `ht` is a huxtable
#' @param ht the value to check.
#' @param call the environment of the caller, for the error message.
#' @noRd
.assert_huxtable <- function(ht, call = rlang::caller_env()) {
    if (!huxtable::is_huxtable(ht)) {
        rlang::abort("`ht` must be a huxtable.", call = call)
    }
}


# ======================================================================================
# Themes and parameter tables
# ======================================================================================

# -----------
# Table theme
# -----------
#' Table theme
#'
#' The styling that [pub_table()] applies when it builds or finishes a table: font
#' size, borders, number format and other cell properties. To use a theme for all
#' tables, set it as default with `options(pubflow.table_theme = pub_table_theme(...))`.
#'
#' @param ... Further huxtable cell properties applied to every cell, e.g.
#'   `font = "Arial"`, `top_padding = 2` or `valign = "middle"` (see
#'   [huxtable::style_cells()]).
#' @param font_size Font size in points.
#' @param borders `"booktabs"`: horizontal rules above and below the header (and below
#'   spanners) and below the body; `"grid"`: borders around all header and body cells.
#' @param border_color Colour of the borders, e.g. `"#D9E2F3"`, or `NULL`: the cells
#'   keep their colour (black in a new table).
#' @param border_width Width of all borders in points, or `NULL`: 0.4 pt, with booktabs
#'   0.8 pt above and below the table.
#' @param style `NULL` or a function `function(ht, rows)` that styles the table after
#'   `pub_table()` has applied the rest of the theme. `rows` is a list of row numbers
#'   by role: `header` (spanner and label rows), `spanner`, `body` and `footnote`. The
#'   function returns the styled huxtable, with the same rows and columns; its metadata
#'   ([pub_meta()], with the caption) stays as before. Use it for a look that depends
#'   on the role of a row, e.g. a coloured header. It runs on every call of
#'   `pub_table()`, also when a table is finished again, so set properties
#'   (`bold(ht)[rows$header, ] <- TRUE`) rather than change them relative to their
#'   value.
#' @param number_format Format of numeric (non-integer) columns without `digits`
#'   (integer columns get 0 decimal places), one of
#'   * a whole number of decimal places;
#'   * a [sprintf()] format with one `%.nf`, `%.ne` or `%.ng` conversion;
#'   * a function returning one string per value;
#'   * `NA`: [as.character()].
#'
#'   See [pub_cell_text()].
#' @details The arguments after `...` must be named in full, so that `font = "Arial"`
#'   reaches huxtable instead of being taken for `font_size`.
#' @return An object of class `pub_table_theme`.
#' @seealso [pub_table()]
#' @examples
#' theme <- pub_table_theme(font_size = 8, borders = "grid", font = "Arial")
#' ht <- pub_table(data.frame(x = c(1.5, 2)), theme = theme)
#' pub_cell_text(ht)
#' huxtable::font(ht)[1, 1]
#'
#' pub_table(data.frame(x = 1 / 3), theme = pub_table_theme(
#'     number_format = "%.2e"
#' )) |>
#'     pub_cell_text()
#'
#' # A house style: light blue grid, bold centred header on a grey background
#' house <- pub_table_theme(
#'     borders = "grid",
#'     border_color = "#D9E2F3",
#'     border_width = 0.5,
#'     valign = "middle",
#'     style = function(ht, rows) {
#'         huxtable::align(ht)[rows$header, ] <- "center"
#'         huxtable::background_color(ht)[rows$header, ] <- "grey90"
#'         ht
#'     }
#' )
#' ht <- pub_table(data.frame(x = 1:2, y = c("a", "b")), theme = house)
#' huxtable::background_color(ht)[, 1]
#' @export
pub_table_theme <- function(
    ...,
    font_size = 9,
    borders = c("booktabs", "grid"),
    border_color = NULL,
    border_width = NULL,
    style = NULL,
    number_format = 4L
) {
    if (!.is_positive_number(font_size)) {
        rlang::abort("`font_size` must be a positive number.")
    }
    borders <- rlang::arg_match(borders)
    .check_theme_borders(border_color, border_width)
    if (!is.null(style) && !is.function(style)) {
        rlang::abort("`style` must be a function(ht, rows) or `NULL`.")
    }
    if (.number_format_kind(number_format) == "invalid") {
        rlang::abort(paste(
            "`number_format` must be a whole number from 0 to 324, a sprintf()",
            "format with one %.nf, %.ne or %.ng conversion, a function or NA."
        ))
    }
    properties <- list(...)
    if (!rlang::is_named2(properties)) {
        rlang::abort("Cell properties in `...` must be named.")
    }
    reserved <- c(
        "number_format",
        "na_string",
        "rowspan",
        "colspan",
        paste0(c("top", "bottom", "left", "right"), "_border")
    )
    if (any(names(properties) %in% reserved)) {
        rlang::abort(sprintf(
            "`...` can't set %s (pubflow manages them).",
            toString(reserved)
        ))
    }
    if (!is.null(border_color)) {
        sides <- paste0(c("top", "bottom", "left", "right"), "_border_color")
        colors <- rlang::set_names(rep(list(border_color), 4L), sides)
        properties <- c(colors[setdiff(sides, names(properties))], properties)
    }
    if (length(properties) > 0L) {
        do.call(huxtable::style_cells, c(list(huxtable::hux(1), 1L, 1L), properties))
    }
    structure(
        list(
            font_size = font_size,
            borders = borders,
            border_width = border_width,
            style = style,
            number_format = number_format,
            properties = properties
        ),
        class = "pub_table_theme"
    )
}

#' Check the border colour and width of a theme
#' @param color,width the arguments of pub_table_theme().
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_theme_borders <- function(color, width, call = rlang::caller_env()) {
    if (!is.null(color) && !(rlang::is_string(color) && nzchar(color))) {
        rlang::abort("`border_color` must be a colour string or `NULL`.", call = call)
    }
    if (!is.null(width) && !.is_positive_number(width)) {
        rlang::abort("`border_width` must be a positive number or `NULL`.", call = call)
    }
}


# ----------------
# Parameter tables
# ----------------
#' Table of parameters
#'
#' Makes a table (see [pub_table()]) that lists params, e.g. for a parameter section in
#' a report. By default it shows their labels, values and descriptions. Values are
#' shown as `toString(param_value(p))` (date-times in UTC).
#'
#' @param params Named list of params, e.g. from [pub_get_params()]. Plain values are
#'   shown with their name as label.
#' @param caption `character(1)` table caption or `NULL`.
#' @param columns Named character vector: field -> column header. The fields are
#'   `"name"` (the param name), `"value"` or any param attribute such as `"label"`,
#'   `"description"` or `"area"`.
#' @return A huxtable.
#' @seealso [pub_get_params()]
#' @examples
#' params <- param_config(
#'     alpha = numeric_param(0.05, label = "Alpha", description = "Level"),
#'     trans = choice_param("log", c("none", "log"), label = "Transformation")
#' )
#' ht <- pub_params_table(params, caption = "Parameters")
#' pub_cell_text(ht)
#'
#' pub_params_table(params, columns = c(name = "Name", value = "Value")) |>
#'     pub_cell_text()
#' @export
pub_params_table <- function(
    params,
    caption = NULL,
    columns = c(
        label = "Parameter",
        value = "Value",
        description = "Description"
    )
) {
    if (!is.list(params) || !rlang::is_named2(params)) {
        rlang::abort("`params` must be a named list.")
    }
    isNamedChr <- is.character(columns) && rlang::is_named(columns)
    if (!isNamedChr) {
        rlang::abort("`columns` must be a named character vector.")
    }
    fields <- names(columns)
    data <- lapply(
        fields,
        FUN = \(field) {
            vapply(
                seq_along(params),
                FUN = \(i) .param_field(params[[i]], names(params)[[i]], field),
                FUN.VALUE = character(1),
                USE.NAMES = FALSE
            )
        }
    )
    data <- as.data.frame(
        rlang::set_names(data, fields),
        stringsAsFactors = FALSE,
        optional = TRUE
    )
    pub_table(data, caption = caption, labels = columns)
}

#' One field of a param as display string
#' @param p a param or a plain value.
#' @param name the name of the param.
#' @param field `"name"`, `"value"` or a param attribute.
#' @return `character(1)`.
#' @noRd
.param_field <- function(p, name, field) {
    if (field == "name") {
        return(name)
    }
    if (field == "value") {
        return(.field_text(if (is_param(p)) param_value(p) else p))
    }
    default <- if (field == "label") name else ""
    value <- if (is_param(p)) param_attr(p, field, default) else default
    .field_text(value)
}

#' A value as one string (`toString()`; date-times in UTC)
#' @param value any value.
#' @noRd
.field_text <- function(value) {
    if (inherits(value, "POSIXt")) {
        value <- format(value, tz = "UTC", usetz = TRUE)
    }
    toString(value)
}
