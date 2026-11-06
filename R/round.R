# Rounding half away from zero. GMP reports round as USP General Notices 7.20 does: the
# first digit after the last one shown decides, and if it is 5 or more the number is
# rounded up in magnitude. pubflow rounds the decimal text of a number (the 15
# significant digits of as.character() that table cells store) digit by digit, so ties
# need no fuzz factor and carries are exact (9.995 -> "10.00"). The result goes back to
# a double, which formatC() and sprintf() only lay out. The table formatter
# (R/table_format.R) uses the same helpers.

# ======================================================================================
# Exported API
# ======================================================================================

# -----------------------
# Rounding and formatting
# -----------------------
#' Round numbers half away from zero
#'
#' Rounds as pubflow's tables do, and as SAS's `ROUND()` does: if the first digit after
#' the last one kept is 5 or more, the number is rounded up in magnitude.
#'
#' @details
#' ## Functions
#'
#' * `pub_round()` returns the rounded numbers, e.g. to compare a result with a
#'   threshold.
#' * `pub_format_num()` returns the text that a table cell with this number format
#'   shows (see [pub_cell_text()]), e.g. for numbers in a text.
#'
#' ## Why not `round()`?
#'
#' [round()], [formatC()] and [sprintf()] round the number as the computer stores it
#' (in binary), and exact ties go to the even digit. As most decimals can't be stored
#' exactly, this often looks wrong: 2.675 is stored as 2.67499999999999982, so they
#' give 2.67.
#'
#' pub_round() and pub_format_num() use the digits of the number's decimal text
#' instead (the 15 significant digits that [as.character()] shows and a table cell
#' stores), so ties round as expected. A result of zero has no sign.
#'
#' | `x` | `pub_round(x, 2)` | `round(x, 2)` |
#' |---|---|---|
#' | 0.125 | 0.13 | 0.12 |
#' | 2.675 | 2.68 | 2.67 |
#' | -2.675 | -2.68 | -2.67 |
#' | 9.995 | 10 | 9.99 |
#' | -0.001 | 0 | 0 |
#'
#' @param x A numeric vector.
#' @param digits A whole number >= 0: the number of decimal places.
#' @param format A number format as in tables: either a whole number of decimal places
#'   (at most 324) or a [sprintf()] format with exactly one `%.nf`, `%.ne` or `%.ng`
#'   conversion and any other text, e.g. `"%.1f %%"` or `"Mean: %.2f"`. The number is
#'   rounded to `n` decimal places (`f`), `n + 1` significant digits (`e`) or `n`
#'   significant digits, at least 1 (`g`). Flags and widths as in `"%+.2f"` or `"%5.2f"`
#'   are not supported.
#' @return `pub_round()`: a double vector with the attributes of `x` (`NA`, `NaN` and
#'   infinite values stay as they are).
#'
#'   `pub_format_num()`: a character vector with the names and dimensions
#'   of `x`; `NA` and `NaN` give `NA`, infinite values `"Inf"` or `"-Inf"`.
#' @seealso [pub_cell_text()], [pub_table()]
#' @examples
#' x <- c(0.125, 2.675, 1.005, 0.285, -2.675, -0.001, 9.995)
#' round(x, 2)
#' pub_round(x, 2)
#' pub_format_num(x, 2)
#' formatC(x, format = "f", digits = 2)  # the binary value, ties to even
#'
#' pub_format_num(c(0.5, 2.5, -0.5), 0)
#' pub_format_num(c(0.125, 999.5), "%.2g")
#' pub_format_num(12.25, "%.1f %%")
#'
#' # Numbers in text
#' pub_format_num(mean(c(98.25, 99.1)), "Mean assay: %.2f %%")
#' @export
pub_round <- function(x, digits = 0) {
    .check_numbers(x)
    isDigits <- rlang::is_scalar_integerish(digits, finite = TRUE) &&
        digits >= 0
    if (!isDigits) {
        rlang::abort("`digits` must be a single whole number >= 0.")
    }
    # more decimal places than the 15-digit text of a double has (at most 338) don't
    # change it; the cap keeps the digit positions in the integer range
    digits <- as.integer(min(digits, 400))
    storage.mode(x) <- "double"
    todo <- is.finite(x)
    x[todo] <- .round_decimal(as.character(x[todo]), digits) |>
        .within_range(x[todo])
    x
}

#' @rdname pub_round
#' @export
pub_format_num <- function(x, format) {
    .check_numbers(x)
    kind <- .number_format_kind(format)
    if (!kind %in% c("digits", "sprintf")) {
        rlang::abort(paste(
            "`format` must be a whole number from 0 to 324 or a sprintf() format",
            "with one %.nf, %.ne or %.ng conversion."
        ))
    }
    res <- rep(NA_character_, length(x))
    ok <- !is.na(x)
    res[ok] <- .format_decimal(as.character(x[ok]), format, kind, x[ok])
    dim(res) <- dim(x)
    dimnames(res) <- dimnames(x)
    names(res) <- names(x)
    res
}

#' Signal an error unless `x` is numeric
#' @param x the argument to check.
#' @param call the environment of the call to report in the error.
#' @noRd
.check_numbers <- function(x, call = rlang::caller_env()) {
    if (!is.numeric(x)) {
        rlang::abort("`x` must be a numeric vector.", call = call)
    }
}


# ======================================================================================
# Formatting
# ======================================================================================

# --------------
# Number formats
# --------------
#' Format numbers by a digits or sprintf() number format
#' @param text character vector of numbers as `.is_number_text()` accepts them (not `NA`
#'   or `NaN`).
#' @param f the number format.
#' @param kind its kind: `"digits"` or `"sprintf"` (see `.number_format_kind()`).
#' @param x the numbers of `text`.
#' @return character vector, one string per number.
#' @noRd
.format_decimal <- function(text, f, kind, x) {
    if (kind == "digits") {
        digits <- as.integer(f)
        value <- .round_decimal(text, digits) |> .within_range(x)
        finite <- is.finite(value)
        res <- character(length(value))
        res[finite] <- formatC(
            value[finite],
            format = "f",
            digits = digits,
            decimal.mark = "."
        )
        # formatC() would pad "Inf" to the width of "-Inf"
        res[!finite] <- as.character(value[!finite])
        return(res)
    }
    spec <- .sprintf_spec(f)
    if (spec$type == "f") {
        value <- .round_decimal(text, spec$precision) |> .within_range(x)
        return(sprintf(f, value))
    }
    digits <- switch(spec$type, e = spec$precision + 1L, g = max(spec$precision, 1L))
    value <- .round_signif(text, digits)
    res <- sprintf(f, value)
    over <- which(!is.finite(value) & is.finite(x))
    res[over] <- .sprintf_over(f, spec, text[over], digits)
    res
}

#' Numbers rounded beyond the double range, by a %.ne or %.ng format
#'
#' Rounding up can exceed the largest double (`1.795e308` by `"%.2e"` gives 1.80e308).
#' The number one decade lower is laid out instead and the exponent raised: the rounded
#' number is below 1e309, so it is e+308.
#' @param f the `%.ne` or `%.ng` format.
#' @param spec its conversion, as `.sprintf_spec()` returns it.
#' @param text,digits as for `.round_signif()`.
#' @return character vector, one string per number.
#' @noRd
.sprintf_over <- function(f, spec, text, digits) {
    value <- .round_signif(text, digits, shift = 1L)
    conversion <- sprintf(substr(f, spec$from, spec$to), value)
    paste0(
        sprintf(substr(f, 1L, spec$from - 1L)),
        sub("e+307", "e+308", conversion, fixed = TRUE),
        sprintf(substring(f, spec$to + 1L))
    )
}

#' Rounded numbers, finite where the numbers are
#'
#' Near the largest double the 15-digit text can exceed the double range:
#' `.Machine$double.xmax` is "1.79769313486232e+308". Rounding to decimal places doesn't
#' change these texts (no decimals), so the numbers keep their value.
#' @param value rounded numbers.
#' @param x the numbers before rounding.
#' @noRd
.within_range <- function(value, x) {
    over <- !is.finite(value) & is.finite(x)
    value[over] <- x[over]
    value
}

#' Conversion of a supported sprintf() number format
#'
#' Supported: exactly one `%.nf`, `%.ne` or `%.ng` conversion (no flags, no width) and
#' any other text, with `%%` for a percent sign.
#' @param f `character(1)`.
#' @return `list(type, precision, from, to)` (`from` and `to`: position of the
#'   conversion in `f`), or `NULL` if `f` is not supported.
#' @noRd
.sprintf_spec <- function(f) {
    pattern <- "^(?:[^%]|%%)*%\\.([0-9]+)([feg])(?:[^%]|%%)*$"
    match <- regexpr(pattern, f, perl = TRUE)
    if (match < 0L) {
        return(NULL)
    }
    start <- attr(match, "capture.start")
    stop <- start + attr(match, "capture.length") - 1L
    list(
        type = substr(f, start[[2L]], stop[[2L]]),
        precision = as.integer(substr(f, start[[1L]], stop[[1L]])),
        from = start[[1L]] - 2L,
        to = stop[[2L]]
    )
}


# ======================================================================================
# Rounding
# ======================================================================================

# -------------------
# Half away from zero
# -------------------
#' Numbers rounded half away from zero to decimal places
#' @param text character vector of numbers as `.is_number_text()` accepts them (not `NA`
#'   or `NaN`).
#' @param digits `integer(1)` >= 0: decimal places.
#' @return double vector (infinite values as they are, no negative zero).
#' @noRd
.round_decimal <- function(text, digits) {
    res <- .number_of(text)
    todo <- .is_rounded(text, res)
    parts <- .decimal_parts(text[todo])
    kept <- .round_digits(parts$digits, parts$point + digits)
    res[todo] <- .as_double(parts$neg, kept, -digits)
    res
}

#' Numbers rounded half away from zero to significant digits
#' @param text as for `.round_decimal()`.
#' @param digits `integer(1)` >= 1: significant digits.
#' @param shift `integer(1)`: the result is divided by `10^shift`.
#' @return double vector (infinite values as they are, no negative zero).
#' @noRd
.round_signif <- function(text, digits, shift = 0L) {
    res <- .number_of(text)
    todo <- .is_rounded(text, res)
    parts <- .decimal_parts(text[todo])
    lead <- attr(regexpr("^0*", parts$digits, perl = TRUE), "match.length")
    kept <- .round_digits(substring(parts$digits, lead + 1L), digits)
    expo <- parts$point - lead - digits - shift
    res[todo] <- .as_double(parts$neg, kept, expo)
    res
}

#' Which number texts to round: not zero and not infinite
#'
#' Also the texts of the largest doubles, which are above the double range (see
#' `.within_range()`); all of them have the exponent 308.
#' @param text number texts as for `.round_decimal()`.
#' @param res the numbers of `text`.
#' @return logical vector.
#' @noRd
.is_rounded <- function(text, res) {
    nearMax <- is.infinite(res) & grepl("e\\+308\\s*$", text, perl = TRUE)
    (is.finite(res) | nearMax) & res != 0
}

#' Numbers of number texts, zeros without sign
#' @param text number texts as for `.round_decimal()`.
#' @noRd
.number_of <- function(text) {
    res <- as.numeric(text)
    res[which(res == 0)] <- 0
    res
}


# ------
# Digits
# ------
#' Parts of numerals: value = 0.<digits> x 10^point
#' @param text character vector of finite, non-zero numbers as `.is_number_text()`
#'   accepts them (sign, surrounding spaces, ".5", "5.", exponents).
#' @return list of `neg` (a minus sign), `digits` (all digits, with leading and trailing
#'   zeros: they don't change the rounding to decimal places) and `point` (integer: the
#'   decimal point follows the first `point` digits).
#' @noRd
.decimal_parts <- function(text) {
    if (any(grepl("\\s", text, perl = TRUE))) {
        text <- gsub("\\s", "", text, perl = TRUE)
    }
    neg <- startsWith(text, "-")
    signed <- neg | startsWith(text, "+")
    text[signed] <- substring(text[signed], 2L)
    e <- regexpr("[eE]", text, perl = TRUE)
    hasExp <- e > 0L
    expo <- integer(length(text))
    expo[hasExp] <- as.integer(substring(text[hasExp], e[hasExp] + 1L))
    text[hasExp] <- substr(text[hasExp], 1L, e[hasExp] - 1L)
    dot <- regexpr(".", text, fixed = TRUE)
    hasDot <- dot > 0L
    nInt <- nchar(text)
    nInt[hasDot] <- dot[hasDot] - 1L
    text[hasDot] <- paste0(
        substr(text[hasDot], 1L, nInt[hasDot]),
        substring(text[hasDot], dot[hasDot] + 1L)
    )
    list(neg = neg, digits = text, point = nInt + expo)
}

#' The first `keep` digits, rounded half up
#'
#' Rounds up if the next digit is 5 or more: trailing 9s become 0s and the digit before
#' them goes up by one; if all digits are 9s, a "1" goes in front (one digit more). Pads
#' with zeros to `keep` digits. `keep <= 0` keeps no digit (`""`), except a "1" if
#' `keep` is 0 and the first digit is 5 or more.
#' @param digits character vector of digit strings.
#' @param keep integer: the number of digits to keep.
#' @noRd
.round_digits <- function(digits, keep) {
    kept <- substr(digits, 1L, pmax(keep, 0L))
    nxt <- substr(digits, keep + 1L, keep + 1L)
    up <- keep >= 0L & nxt %in% c("5", "6", "7", "8", "9")
    k <- kept[up]
    nNines <- nchar(k) - nchar(sub("9+$", "", k, perl = TRUE))
    pos <- nchar(k) - nNines
    raised <- chartr("012345678", "123456789", substr(k, pos, pos))
    raised[!nzchar(raised)] <- "1"
    kept[up] <- paste0(substr(k, 1L, pos - 1L), raised, strrep("0", nNines))
    paste0(kept, strrep("0", pmax(keep - nchar(kept), 0L)))
}

#' Doubles of signed digit strings times a power of ten (zero has no sign)
#' @param neg logical: a minus sign.
#' @param kept character vector of digit strings.
#' @param expo integer: the power of ten.
#' @noRd
.as_double <- function(neg, kept, expo) {
    zero <- !grepl("[1-9]", kept, perl = TRUE)
    kept[zero] <- "0"
    sign <- character(length(kept))
    sign[neg & !zero] <- "-"
    as.numeric(paste0(sign, kept, "e", expo, recycle0 = TRUE))
}
