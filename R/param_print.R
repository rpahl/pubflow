# Printing of param objects. Because "param" is the first class, print() dispatches to
# print.param() for every param type; pubflow registers no print methods for base
# classes.

# --------
# Printing
# --------
#' Print a param object
#'
#' Prints the type and value of a param and its attributes, one per line. The
#' `description` is left out if it equals the `label`, and the validity functions are
#' only counted (`param_attr(x, "validity")` shows their code). The children of a
#' [param_group()] are printed recursively.
#'
#' @param x A param object.
#' @param ... Not used.
#' @return `x`, invisibly.
#' @examples
#' numeric_param(0.05, label = "Significance level", min = 0, max = 1)
#' param(FALSE, label = "Show points?")
#' @export
print.param <- function(x, ...) {
    .print_param(x)
    invisible(x)
}

#' Print one param with the given indentation
#'
#' @param x A param object.
#' @param indent `character(1)` prefix of every line.
#' @param name `character(1)` name printed in a header line, or `NULL`.
#' @return `NULL`, invisibly.
#' @noRd
.print_param <- function(x, indent = "", name = NULL) {
    if (!is.null(name)) {
        cat(sprintf("%s%s:\n", indent, name))
    }
    .cat_line(sprintf(
        "%sparam<%s>: %s",
        indent,
        param_type(x),
        .format_param_value(param_value(x))
    ))
    attrs <- attributes(x)
    skip <- c("class", "names", "row.names", "dim", "dimnames", "validity")
    if (identical(attrs[["description"]], attrs[["label"]])) {
        skip <- c(skip, "description")
    }
    for (attrName in setdiff(names(attrs), skip)) {
        .cat_line(sprintf(
            "%s  %s: %s",
            indent,
            attrName,
            .format_param_value(attrs[[attrName]])
        ))
    }
    nValidity <- length(attrs[["validity"]])
    if (nValidity > 0) {
        .cat_line(sprintf(
            "%s  validity: <%s>",
            indent,
            if (nValidity == 1) "function" else paste(nValidity, "functions")
        ))
    }
    if (inherits(x, "param_group")) {
        .print_param_children(x, indent = paste0(indent, "  "))
    }
    invisible(NULL)
}

#' Print the children of a param group
#'
#' @param x A `param_group` object.
#' @param indent `character(1)` prefix of every line.
#' @return `NULL`, invisibly.
#' @noRd
.print_param_children <- function(x, indent) {
    children <- unclass(x)
    if (length(children) > 0) {
        cat(sprintf("%schildren:\n", indent))
    }
    childIndent <- paste0(indent, "  ")
    for (childName in names(children)) {
        child <- children[[childName]]
        if (is_param(child)) {
            .print_param(child, indent = childIndent, name = childName)
        } else {
            .cat_line(sprintf(
                "%s%s: %s",
                childIndent,
                childName,
                .format_param_value(child)
            ))
        }
    }
    invisible(NULL)
}

#' Print lines without trailing whitespace
#' @param lines `character` lines.
#' @return `NULL`, invisibly.
#' @noRd
.cat_line <- function(lines) {
    cat(paste0(sub("[[:space:]]+$", "", lines), "\n"), sep = "")
}


# ----------------
# Printing configs
# ----------------
#' Print a param config
#'
#' Prints an overview of a [param_config()] as a table: one row per param with its
#' name, type, value and label, in the config order. The children of a
#' [param_group()] follow their group, indented. Print a single param (e.g.
#' `print(cfg$alpha)`) to see all its attributes.
#'
#' @param x A param config.
#' @param ... Not used.
#' @return `x`, invisibly.
#' @examples
#' param_config(
#'     alpha = numeric_param(0.05, label = "Significance level", min = 0, max = 1),
#'     showPoints = param(FALSE, label = "Show points?")
#' )
#' @export
print.param_config <- function(x, ...) {
    n <- length(x)
    cat(sprintf("<param_config: %d param%s>\n", n, if (n == 1) "" else "s"))
    if (n > 0) {
        print(.config_rows(unclass(x), indent = ""), row.names = FALSE, right = FALSE)
    }
    invisible(x)
}

#' One row per param (and group child) of a config
#'
#' @param params named `list` of params (group children may be plain values).
#' @param indent `character(1)` prefix of the names.
#' @return `data.frame` with the character columns `name`, `type`, `value`, `label`,
#'   `NULL` for an empty list.
#' @noRd
.config_rows <- function(params, indent) {
    rows <- lapply(names(params), \(name) {
        p <- params[[name]]
        isParam <- is_param(p)
        value <- .format_param_value(if (isParam) param_value(p) else p)
        row <- data.frame(
            name = paste0(indent, name),
            type = if (isParam) param_type(p) else "",
            # one line, so that a multi-line text doesn't look like its first line
            value = .first_line(gsub("\\s*\n\\s*", " ", value), width = 30L),
            label = if (isParam) param_attr(p, "label", default = "") else ""
        )
        if (inherits(p, "param_group")) {
            row <- rbind(row, .config_rows(unclass(p), paste0(indent, "  ")))
        }
        row
    })
    do.call(rbind, rows)
}

# -----------------
# Formatting values
# -----------------
#' Format a value for printing in one line
#'
#' @param value A plain value or attribute value.
#' @return `character(1)`.
#' @noRd
.format_param_value <- function(value) {
    if (inherits(value, "POSIXlt")) {
        value <- as.POSIXct(value)
    }
    if (is.data.frame(value)) {
        return(sprintf("<data.frame %d x %d>", nrow(value), ncol(value)))
    }
    if (is.list(value)) {
        return(.format_param_list(value))
    }
    if (is.null(value)) {
        # is.atomic(NULL) is TRUE before R 4.4.0
        return("<NULL>")
    }
    if (is.factor(value)) {
        shown <- as.character(value[seq_len(min(length(value), 5L))])
        suffix <- if (length(value) > length(shown)) ", ..." else ""
        return(sprintf(
            "<factor[%d]: %s%s>",
            length(value),
            paste(shown, collapse = ", "),
            suffix
        ))
    }
    if (is.atomic(value)) {
        txt <- .format_atomic(value)
        if (nchar(txt) > 80L) {
            txt <- paste0(substr(txt, 1L, 77L), "...")
        }
        return(txt)
    }
    sprintf("<%s>", paste(class(value), collapse = "/"))
}

#' Format an atomic value in one line (date-times in UTC)
#'
#' @param value an atomic vector.
#' @return `character(1)`.
#' @noRd
.format_atomic <- function(value) {
    txt <- if (inherits(value, "POSIXt")) {
        format(value, tz = "UTC", usetz = TRUE)
    } else {
        format(value, trim = TRUE, justify = "none")
    }
    paste(txt, collapse = ", ")
}

#' Format a list for printing in one line (first three elements)
#'
#' @param value a list.
#' @return `character(1)`.
#' @noRd
.format_param_list <- function(value) {
    nms <- names(value)
    shown <- vapply(
        seq_len(min(length(value), 3L)),
        FUN = \(i) {
            key <- if (!is.null(nms) && nzchar(nms[[i]])) {
                nms[[i]]
            } else {
                sprintf("[[%d]]", i)
            }
            paste0(key, "=", .format_param_value(value[[i]]))
        },
        FUN.VALUE = character(1)
    )
    suffix <- if (length(value) > length(shown)) ", ..." else ""
    sprintf(
        "<list[%d]: %s%s>",
        length(value),
        paste(shown, collapse = ", "),
        suffix
    )
}
