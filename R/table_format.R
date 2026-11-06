# Cell formatting.
#
# pubflow tables keep every cell as text, as huxtable stores them below a header row
# (numbers via as.character()): header rows are data rows, and any span makes huxtable
# rewrite still-numeric columns with format(), so numeric cells would not survive
# anyway. A non-NA `number_format` marks a cell as numeric. One formatter,
# .format_cells(), turns cells into display strings at render time; every writer uses
# it, so a table shows the same text in every output format.

# ---------
# Cell text
# ---------
#' Display text of table cells
#'
#' Returns the text that pubflow shows for each cell of a table, which is the same in
#' every output format (HTML, Word, PDF, Markdown). Use it to check the exact text of a
#' table in tests.
#'
#' @details
#' ## Numbers
#'
#' Numeric cells are formatted by their `number_format` (see [pub_table()]):
#'
#' | `number_format` | Result |
#' |---|---|
#' | whole number `n` (at most 324) | `n` decimal places |
#' | [sprintf()] format, e.g. `"%.1f %%"` | text around one `%.nf`, `%.ne` or `%.ng` |
#' | function | must return one string per value (`NA`: the cell's `na_string`) |
#' | `NA` | [as.character()] |
#'
#' Numbers are rounded half away from zero, as by [pub_round()] (0.125 -> "0.13",
#' 2.675 -> "2.68", -0.001 -> "0.00"). [pub_format_num()] gives the same text for
#' numbers in steps. A function format rounds as it likes.
#'
#' Numbers in text cells (as huxtable and [pub_table()] store them) are only formatted
#' if their `number_format` is not `NA`; text cells have none.
#'
#' ## Other cells
#'
#' * Missing values show the cell's `na_string`.
#' * Factors show their labels, dates and times are shown in UTC.
#' * Numbers inside text are never reformatted.
#' * Markdown cells ([huxtable::markdown()]) are text, whatever their `number_format`.
#' * Struck-through cells (see [pub_strikeout()]) show their Markdown, e.g.
#'   `"~~2.71~~"`.
#'
#' @param ht A huxtable, e.g. from [pub_table()].
#' @return A character matrix with one element per cell (also for cells hidden by merged
#'   cells).
#' @seealso [pub_table()]
#' @examples
#' ht <- pub_table(
#'     data.frame(x = c(0.125, 2.675, NA), n = c(1L, 2L, NA)),
#'     digits = c(x = 2), na = "-"
#' )
#' pub_cell_text(ht)
#'
#'
#' # Different number formats - define small helper first
#' fmt_helper <- function(ht, format) {
#'     pub_cell_text(huxtable::set_number_format(ht, -1, "x", format))[, 1]
#' }
#' fmt_helper(ht, "%.1f %%")                                # like sprintf()
#' fmt_helper(ht, list(\(v) sprintf("<%s>", format(v))))    # custom function
#' fmt_helper(ht, NA)                                       # as.character() via NA
#'
#'
#' # Factors, times (UTC) and struck-through cells
#' df <- data.frame(
#'     group = factor(c("low", "high", NA)),
#'     time = as.POSIXct(c("2026-01-05 13:30:00", NA, NA), tz = "UTC"),
#'     x = c(2.71, 3.1, 4)
#' )
#' ht <- pub_table(df, digits = c(x = 2), na = "-")
#' pub_cell_text(pub_strikeout(ht, 2, "x"))
#' @export
pub_cell_text <- function(ht) {
    .assert_huxtable(ht)
    .format_cells(ht)
}

#' Display strings of all cells (the common formatter)
#'
#' The numbers of all columns are formatted together, in one call per number format
#' (half the time of one call per column, as rounding has a fixed cost per call).
#' @param ht a huxtable.
#' @return character matrix `nrow(ht)` x `ncol(ht)`.
#' @noRd
.format_cells <- function(ht) {
    numberFormat <- huxtable::number_format(ht)
    isMarkdown <- huxtable::markdown(ht)
    text <- matrix(NA_character_, nrow(ht), ncol(ht))
    value <- matrix(NA_real_, nrow(ht), ncol(ht))
    for (j in seq_len(ncol(ht))) {
        cells <- .column_cells(ht[[j]], numberFormat[, j], isMarkdown[, j], col = j)
        text[, j] <- cells$text
        value[, j] <- cells$value
    }
    isValue <- which(!is.na(value))
    if (length(isValue) > 0L) {
        text[isValue] <- .format_numbers(
            text[isValue],
            value[isValue],
            numberFormat[isValue],
            rows = row(text)[isValue],
            cols = col(text)[isValue]
        )
    }
    missing <- is.na(text)
    text[missing] <- huxtable::na_string(ht)[missing]
    text
}

#' Text and values of the cells of one column
#' @param x the column vector.
#' @param numberFormat list of number formats per cell.
#' @param isMarkdown logical vector: Markdown cells (always text).
#' @param col the column's position (for error messages).
#' @return list of `text` (`NA` for missing values, also for numeric cells whose value
#'   is `NA` or `NaN`) and `value` (the value of numeric cells, otherwise `NA`).
#' @noRd
.column_cells <- function(x, numberFormat, isMarkdown, col) {
    if (is.list(x)) {
        rlang::abort(sprintf(
            "Can't format column %d: list columns are not supported.",
            col
        ))
    }
    text <- .text_of(x)
    isNumber <- if (is.character(x)) {
        .has_number_format(numberFormat) & .is_number_text(x)
    } else {
        rep(is.numeric(x), length(x))
    }
    isNumber <- isNumber & !isMarkdown
    value <- rep(NA_real_, length(x))
    value[isNumber] <- as.numeric(x[isNumber])
    text[isNumber & is.na(value)] <- NA_character_
    list(text = text, value = value)
}

#' Text of non-numeric values (`NA` for missing values)
#' @param x the column vector.
#' @return character vector as long as `x`.
#' @noRd
.text_of <- function(x) {
    res <- if (inherits(x, "POSIXt")) {
        format(x, tz = "UTC", usetz = TRUE)
    } else if (inherits(x, "Date")) {
        format(x)
    } else {
        as.character(x)
    }
    res[is.na(x)] <- NA_character_
    res
}

#' Which cells have a number format (not `NA`)
#' @param numberFormat list of number formats per cell.
#' @return logical vector, one element per cell.
#' @noRd
.has_number_format <- function(numberFormat) {
    !vapply(
        numberFormat,
        \(f) is.atomic(f) && length(f) == 1L && is.na(f),
        logical(1)
    )
}

#' Which strings are a number in decimal notation (or Inf/NaN)
#' @param x character vector.
#' @return logical vector as long as `x` (`FALSE` for `NA`).
#' @noRd
.is_number_text <- function(x) {
    pattern <- paste0(
        "^\\s*[-+]?(([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?",
        "|Inf|NaN)\\s*$"
    )
    !is.na(x) & grepl(pattern, x)
}


# --------------
# Number formats
# --------------
#' Format numbers by their number formats
#'
#' Cells with equal formats are formatted together; the kind of a format is checked
#' once.
#' @param text the cells' text (rounded by digits and sprintf() formats).
#' @param x numeric values of the cells (not `NA`).
#' @param numberFormat list of formats, one per value.
#' @param rows,cols table positions of the values (for error messages).
#' @noRd
.format_numbers <- function(text, x, numberFormat, rows, cols) {
    key <- .format_keys(numberFormat)
    first <- which(!duplicated(key))
    kind <- vapply(numberFormat[first], .number_format_kind, character(1))
    bad <- first[kind == "invalid"]
    if (length(bad) > 0L) {
        .abort_cell(
            rows[[bad[[1L]]]],
            cols[[bad[[1L]]]],
            "unsupported number format (use a whole number from 0 to 324, a sprintf()",
            "format with one %.nf, %.ne or %.ng conversion, a function or NA)"
        )
    }
    res <- character(length(x))
    for (g in seq_along(first)) {
        idx <- which(key == key[[first[[g]]]])
        res[idx] <- .apply_number_format(
            text[idx],
            x[idx],
            numberFormat[[first[[g]]]],
            kind[[g]],
            rows = rows[idx],
            cols = cols[idx]
        )
    }
    res
}

#' Keys that group equal number formats
#'
#' Functions and other non-scalar formats get one key per cell (closures with equal code
#' may differ in their environment).
#' @param numberFormat list of number formats.
#' @return character vector, one key per format.
#' @noRd
.format_keys <- function(numberFormat) {
    key <- vapply(
        numberFormat,
        \(f) {
            if (!is.atomic(f) || length(f) != 1L) {
                NA_character_
            } else if (is.na(f)) {
                "na"
            } else {
                paste(typeof(f), f)
            }
        },
        character(1),
        USE.NAMES = FALSE
    )
    perCell <- which(is.na(key))
    key[perCell] <- paste("cell", perCell)
    key
}

#' Kind of a number format: "digits", "sprintf", "fun", "na" or "invalid"
#'
#' "sprintf" only for the supported formats (see `.sprintf_spec()`).
#' @param f a number format.
#' @noRd
.number_format_kind <- function(f) {
    if (is.function(f)) {
        return("fun")
    }
    if (rlang::is_string(f)) {
        return(if (is.null(.sprintf_spec(f))) "invalid" else "sprintf")
    }
    if (!is.atomic(f) || length(f) != 1L) {
        return("invalid")
    }
    if (is.na(f)) {
        return("na")
    }
    isDigits <- is.numeric(f) && is.finite(f) && f >= 0 && f == round(f)
    if (isDigits && f <= .max_digits) "digits" else "invalid"
}

# Most decimal places of a number format: formatC()'s limit, enough for the smallest
# double
.max_digits <- 324L

#' Apply one number format to values
#'
#' Digits and sprintf() formats round the cells' text half away from zero; functions get
#' the values.
#' @param text the cells' text.
#' @param x numeric values of the cells (not `NA`).
#' @param f the number format.
#' @param kind its kind, from `.number_format_kind()` (not "invalid").
#' @param rows,cols table positions of the values (for error messages).
#' @return character vector as long as `x`.
#' @noRd
.apply_number_format <- function(text, x, f, kind, rows, cols) {
    switch(
        kind,
        digits = ,
        sprintf = .format_decimal(text, f, kind, x),
        na = as.character(x),
        fun = vapply(
            seq_along(x),
            \(i) {
                res <- tryCatch(
                    f(x[[i]]),
                    error = \(e) {
                        .abort_cell(
                            rows[[i]],
                            cols[[i]],
                            "number format function failed",
                            parent = e
                        )
                    }
                )
                # NA shows the cell's na_string
                if (!(is.character(res) && length(res) == 1L)) {
                    .abort_cell(
                        rows[[i]],
                        cols[[i]],
                        "number format function must return one string"
                    )
                }
                res
            },
            character(1)
        )
    )
}

#' Error naming a table cell
#' @param row,col the cell's position.
#' @param ... parts of the message, pasted with spaces.
#' @param parent the error that caused it, or `NULL`.
#' @noRd
.abort_cell <- function(row, col, ..., parent = NULL) {
    rlang::abort(
        sprintf(
            "Can't format table cell [%d, %d]: %s.",
            row,
            col,
            paste(..., collapse = " ")
        ),
        parent = parent,
        call = NULL
    )
}


# --------------
# Display tables
# --------------
#' Copy of a table for the huxtable writers
#'
#' Cells are replaced by their display strings and number formatting is switched off, so
#' neither huxtable's number formatting nor its options can change the text.
#' Struck-through cells stay huxtable Markdown cells.
#' @param ht a huxtable.
#' @noRd
.display_huxtable <- function(ht) {
    text <- .format_cells(ht)
    for (j in seq_len(ncol(ht))) {
        ht[[j]] <- text[, j]
    }
    huxtable::number_format(ht) <- NA
    huxtable::na_string(ht) <- ""
    ht
}
