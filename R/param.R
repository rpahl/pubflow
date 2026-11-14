# Parameter objects: a value plus attributes that describe it (label, description,
# validity checks, UI hints). The class order matters: "param" comes first, so
# `print.param()` dispatches without S3 methods for base classes.

# ======================================================================================
# Param objects
# ======================================================================================

# ------------
# Constructors
# ------------
#' Parameter objects
#'
#' A param is a value (a number, a text, a choice, ...) together with information that
#' describes it: a label, a help text and rules that tell whether the value is valid.
#' Parameter UIs and reports read this information, while the functions of a pipeline
#' always get the plain value (see [param_value()]).
#'
#' @details
#' ## Constructors
#'
#' * `param()` creates a param of any type. The type is that of `x` (see
#'   [param_type()]), e.g. a logical becomes a switch in the UI.
#'
#' The other constructors are shortcuts for common cases:
#'
#' * `numeric_param()`: a number (or numbers) between `min` and `max`;
#' * `numeral_param()`: a number entered as text that keeps its decimal places, e.g.
#'   `"1.50"`;
#' * `choice_param()`: one of a fixed set of choices;
#' * `param_group()`: several params shown side by side and checked together, e.g. a
#'   lower and an upper limit.
#'
#' ## Numerals
#'
#' A number like `1.50` loses its trailing zero as soon as it is a number. A
#' `numeral_param()` therefore holds the text and checks it as a number
#' (`as.numeric()`, without rounding).
#'
#' ## Choices
#'
#' The initial value of a `choice_param()` must be one of the `choices` (or `NA`).
#' Setting a value outside the choices with `param_value<-` gives `NA`, which the
#' validity check reports. For a simple yes/no question, a logical param
#' (`param(TRUE)`, shown as a switch) is often easier.
#'
#' ## Groups
#'
#' The children of a `param_group()` are checked on their own and the group as a
#' whole. Add rules for the whole group with [add_validity()], e.g. that a lower limit
#' is below an upper limit (see Examples). The name `"group"` can't be used for a
#' child, as it is reserved.
#'
#' ## Validity
#'
#' Each constructor comes with a default rule (see [param_validity()] to apply it):
#'
#' | Constructor | The value is invalid if it is ... |
#' |---|---|
#' | `param()` | empty or `NA` |
#' | `numeric_param()` | empty, `NA`, below `min` or above `max` |
#' | `numeral_param()` | as above, or not readable as a number |
#' | `choice_param()` | empty or not one of the `choices` |
#'
#' Pass `validity` to replace the default rule (see Examples), or add further rules
#' to an existing param with [add_validity()].
#'
#' ## Working with params
#'
#' Base functions such as arithmetic, comparisons, `as.character()`, `levels()` or
#' `format()` work on a param as on its value. Keep in mind that arithmetic keeps the
#' attributes and that `identical(param("a"), "a")` is `FALSE`. Pass [param_value()] to
#' code that expects plain values.
#'
#' ## Attributes
#'
#' pubflow knows the following attributes. Any other named argument in `...` is stored
#' as well.
#'
#' | Attribute | Meaning |
#' |---|---|
#' | `label`, `description` | display name; help text (tooltip) |
#' | `validity` | list of validity functions |
#' | `source` | origin, e.g. `"user"` (set in the UI), `"data"` (derived from data) |
#' | `area` | grouping, e.g. `"analysis"`, `"criteria"` |
#' | `order` | position in the UI, set by [param_config()] |
#' | `min`, `max`, `step` | bounds and step of numeric inputs |
#' | `advanced` | `TRUE`: shown in a collapsed "Advanced" block of the UI |
#' | `locked` | `TRUE`: shown as a disabled input, can't be changed in the UI |
#' | `ui_widget`, `ui_args`, `ui_style` | input widget, its arguments and CSS |
#'
#' @param x The value (not `NULL`). For `choice_param()` the selected choice; for
#'   `param_group()` a named list of params.
#' @param label `character(1)` display name.
#' @param description `character(1)` help text; defaults to `label`.
#' @param validity A validity function or a list of them. Each function takes the plain
#'   value and returns `""` if it is valid, otherwise a message (see
#'   [param_validity()]). See Validity for the default rules.
#' @param ... Further optional attributes as named arguments, e.g. `source = "user"` or
#'   `advanced = TRUE` (see Attributes below). Passed on to `param()` by the other
#'   constructors.
#' @param min,max Inclusive bounds of the (numeric) value.
#' @param choices The allowed values (no duplicates or `NA`), in the order they are
#'   shown.
#' @return A param object: `x` with class `c("param", class(x))` and the attributes.
#'   `param_group()` returns an object of class `c("param_group", "param", "list")`.
#' @seealso [param_value()], [param_validity()], [param_config()]
#' @examples
#' # A param is its value plus information about it
#' p <- param("abc", label = "Name", source = "user")
#' p
#' param_value(p)
#'
#' # Numbers within bounds; params can be used like their values
#' alpha <- numeric_param(0.05, label = "Significance level", min = 0, max = 1)
#' alpha < 0.1
#' param_validity(alpha, value = 1.5)
#'
#' # A number as text keeps its trailing zero
#' limit <- numeral_param("80.0", label = "Ozone limit (ppb)")
#' param_value(limit)
#'
#' # One of several choices
#' trans <- choice_param("log", choices = c("none", "log", "sqrt"),
#'                       label = "Transformation")
#' levels(trans)
#' trans == "log"
#' param_validity(trans, value = "exp")
#'
#' # Own constructors: wrap one of the above and fix some of its arguments
#' yes_no_param <- function(x = c("yes", "no"), label = "Yes/No", ...) {
#'     choice_param(match.arg(x), choices = c("yes", "no"), label = label, ...)
#' }
#' show <- yes_no_param("no", label = "Show points?")
#' as.character(show)
#'
#' bound_param <- function(..., side = c("lower", "upper")) {
#'     numeral_param(..., side = match.arg(side))
#' }
#'
#' # Own validity: a positive whole number. Wrap numeric_param() and pass your own
#' # rule; it replaces the default one, so it has to check everything it needs.
#' pos_integer_param <- function(
#'     x,
#'     label = "positive integer",
#'     description = label,
#'     max = .Machine$integer.max,
#'     validity = \(x) {
#'         if (length(x) == 0) return("value cannot be empty")
#'         if (anyNA(x)) return("value cannot be NA")
#'         if (any(x != round(x))) return("value must be a whole number")
#'         if (any(x < 1)) return("value must be positive")
#'         if (any(x > max)) return(paste("value must not exceed", max))
#'         ""
#'     },
#'     ...
#' ) {
#'     numeric_param(
#'         x, label = label, description = description, min = 1, max = max,
#'         validity = validity, ...
#'     )
#' }
#' n <- pos_integer_param(3L, label = "Sample size")
#' param_validity(n, value = 2.5)
#' param_validity(n, value = 0)
#' param_validity(n)
#'
#' # Params shown and checked together
#' limits <- param_group(
#'     list(
#'         lower = bound_param("1.0", label = "Lower", side = "lower"),
#'         upper = bound_param("2.0", label = "Upper", side = "upper")
#'     ),
#'     label = "Limits"
#' ) |>
#'     add_validity(\(x) {
#'         if (as.numeric(x$lower) < as.numeric(x$upper)) "" else
#'             "lower must be below upper"
#'     })
#' param_validity(limits, value = list(lower = "3", upper = "2"))
#' @export
param <- function(
    x,
    label = "parameter",
    description = label,
    validity = default_param_validity,
    ...
) {
    if (is.null(x)) {
        rlang::abort("Parameter value cannot be NULL")
    }
    if (!rlang::is_string(label)) {
        rlang::abort("label must be a single string")
    }
    if (!rlang::is_string(description)) {
        rlang::abort("description must be a single string")
    }
    dots <- list(...)
    if (!rlang::is_named2(dots)) {
        rlang::abort("all arguments in `...` must be named")
    }

    attr(x, "label") <- label
    attr(x, "description") <- description
    attr(x, "validity") <- .as_validity_list(validity)
    for (which in names(dots)) {
        attr(x, which) <- dots[[which]]
    }
    class(x) <- c("param", setdiff(class(x), c("param_group", "param")))
    x
}

#' @rdname param
#' @export
numeric_param <- function(
    x,
    label = "numeric parameter",
    description = label,
    min = -Inf,
    max = Inf,
    validity = .numeric_validity(min, max),
    ...
) {
    if (!is.numeric(x)) {
        rlang::abort("x must be numeric")
    }
    .check_min_max(min, max)
    param(
        x = x,
        label = label,
        description = description,
        min = min,
        max = max,
        validity = validity,
        ...
    )
}

#' @rdname param
#' @export
numeral_param <- function(
    x,
    label = "numeral parameter",
    description = label,
    min = -Inf,
    max = Inf,
    validity = .numeral_validity(min, max),
    ...
) {
    if (!is.character(x)) {
        rlang::abort("x must be a character vector")
    }
    .check_min_max(min, max)
    param(
        x = x,
        label = label,
        description = description,
        min = min,
        max = max,
        validity = validity,
        ...
    )
}

#' @rdname param
#' @export
choice_param <- function(
    x,
    choices,
    label = "choice parameter",
    description = label,
    validity = .choice_validity(choices),
    ...
) {
    if (is.null(x)) {
        rlang::abort("Parameter value cannot be NULL")
    }
    choices <- .check_choices(choices)
    unknown <- setdiff(as.character(x[!is.na(x)]), choices)
    if (length(unknown) > 0) {
        rlang::abort(sprintf(
            "x must be one of the choices (%s), not: %s",
            toString(choices),
            toString(unknown)
        ))
    }
    param(
        x = factor(x, levels = choices),
        label = label,
        description = description,
        validity = validity,
        ...
    )
}

#' @rdname param
#' @export
param_group <- function(
    x,
    label = "Parameter group",
    description = label,
    ...
) {
    if (!is.list(x) || is.data.frame(x)) {
        rlang::abort("x must be a list")
    }
    if (!all(vapply(x, is_param, logical(1)))) {
        rlang::abort("all elements of x must be 'param' objects")
    }
    if (!rlang::is_named(x)) {
        rlang::abort("param_group input list must be named")
    }
    if (anyDuplicated(names(x)) > 0) {
        rlang::abort("param_group input list must have unique names")
    }
    if ("group" %in% names(x)) {
        rlang::abort(
            "param_group input list cannot contain an element named 'group'"
        )
    }
    res <- param(
        x = unclass(x),
        label = label,
        description = description,
        ...
    )
    class(res) <- c("param_group", class(res))
    res
}


# --------------------------
# Default validity functions
# --------------------------
#' Validity function of a numeric param
#' @param min,max the bounds.
#' @return a validity function (see [param_validity()]).
#' @noRd
.numeric_validity <- function(min, max) {
    force(min)
    force(max)
    \(x) {
        msg <- default_param_validity(x)
        if (nzchar(msg)) msg else .range_validity(x, min, max)
    }
}

#' Validity function of a numeral param
#' @param min,max the bounds.
#' @return a validity function (see [param_validity()]).
#' @noRd
.numeral_validity <- function(min, max) {
    force(min)
    force(max)
    \(x) {
        msg <- default_param_validity(x)
        if (nzchar(msg)) {
            return(msg)
        }
        num <- suppressWarnings(as.numeric(x))
        if (anyNA(num)) {
            return("value was not coercible to numeric")
        }
        .range_validity(num, min, max)
    }
}

#' Validity function of a choice param
#' @param choices the allowed values.
#' @return a validity function (see [param_validity()]).
#' @noRd
.choice_validity <- function(choices) {
    force(choices)
    \(x) {
        if (length(x) == 0) {
            return("value cannot be empty")
        }
        if (!all(as.character(x) %in% choices)) {
            return(paste("value must be one of:", toString(choices)))
        }
        ""
    }
}

#' Message for a number outside its bounds
#' @param x numeric vector without `NA`.
#' @param min,max the inclusive bounds.
#' @return `character(1)`, `""` if all of `x` is within the bounds.
#' @noRd
.range_validity <- function(x, min, max) {
    if (any(x < min)) {
        return(paste0("value must be greater than or equal to min (", min, ")"))
    }
    if (any(x > max)) {
        return(paste0("value must be less than or equal to max (", max, ")"))
    }
    ""
}

# ------------------
# Constructor checks
# ------------------
#' Check numeric bounds
#' @param min,max the bounds: non-empty numeric vectors without `NA`.
#' @param call see `rlang::abort()`.
#' @return `NULL`, invisibly.
#' @noRd
.check_min_max <- function(min, max, call = rlang::caller_env()) {
    isBound <- \(b) is.numeric(b) && length(b) > 0 && !anyNA(b)
    if (!isBound(min) || !isBound(max)) {
        rlang::abort(
            "min and max must be non-empty numeric vectors without NA",
            call = call
        )
    }
    if (!all(min < max)) {
        rlang::abort(
            sprintf("min (%s) is not less than max (%s)", min, max),
            call = call
        )
    }
    invisible(NULL)
}

#' Check the choices of a choice param
#' @param choices the allowed values.
#' @param call see `rlang::abort()`.
#' @return `choices` as character vector.
#' @noRd
.check_choices <- function(choices, call = rlang::caller_env()) {
    ok <- is.atomic(choices) && length(choices) > 0 && !anyNA(choices)
    if (!ok) {
        rlang::abort(
            "choices must be a non-empty vector without NA",
            call = call
        )
    }
    choices <- as.character(choices)
    if (anyDuplicated(choices) > 0) {
        rlang::abort("choices must be unique", call = call)
    }
    choices
}


# --------------
# Type and class
# --------------
#' Type and class of param objects
#'
#' Test whether an object is a param and get the type of the value of a param.
#'
#' @details
#' ## Functions
#'
#' * `is_param()` tests whether `x` is a param.
#' * `param_type()` returns the type of the value of a param, e.g. `"numeric"` for a
#'   number. pubflow uses it to choose the input widget. (`class()` of a param is no
#'   help here, as it starts with `"param"`.)
#'
#' @param x A param object (`param_type()` also accepts plain values).
#' @return
#' * `is_param()`: `TRUE` or `FALSE`.
#' * `param_type()`: the type of the value, one of
#'   * `"character"`
#'   * `"factor"` (also ordered factors)
#'   * `"logical"`
#'   * `"numeric"` (double and integer)
#'   * `"list"` (also param groups)
#'   * `"data.frame"`
#'   * or else the first class of the value, e.g. `"Date"`.
#' @examples
#' is_param(param(1))
#' is_param(1)
#'
#' param_type(param(1L))
#' param_type(choice_param("b", c("a", "b")))
#' param_type(param(Sys.Date()))
#' param_type(param_group(list(a = param("x"))))
#' @export
is_param <- function(x) {
    inherits(x, "param")
}

#' @rdname is_param
#' @export
param_type <- function(x) {
    if (is.factor(x)) {
        return("factor")
    }
    if (is.data.frame(x)) {
        return("data.frame")
    }
    type <- .value_class(x)[[1]]
    if (type == "integer") "numeric" else type
}

#' Signal an error if `x` is not a param
#'
#' @param x object to check.
#' @param arg `character(1)` argument name used in the message.
#' @param call see `rlang::abort()`.
#' @return `NULL`, invisibly.
#' @noRd
.assert_param <- function(x, arg = "x", call = rlang::caller_env()) {
    if (!is_param(x)) {
        rlang::abort(sprintf("%s must be a 'param' object", arg), call = call)
    }
    invisible(NULL)
}

#' The classes of the value of a param (or a plain value)
#' @param x a param or plain value.
#' @return `class(x)` without the param classes; the implicit class of the value if
#'   no other class is left.
#' @noRd
.value_class <- function(x) {
    cls <- setdiff(class(x), c("param_group", "param"))
    if (length(cls) == 0) class(unclass(x)) else cls
}


# ======================================================================================
# Attributes and values
# ======================================================================================

# ----------
# Attributes
# ----------
#' Retrieve an attribute of a param
#'
#' Unlike [attr()], `param_attr()` does no partial matching of the attribute name and
#' returns a default if the attribute is not set.
#'
#' @param x A param object.
#' @param which `character(1)` name of the attribute.
#' @param default Value returned if the attribute is not set.
#' @return The attribute's value, or `default` if it is not set.
#' @examples
#' p <- param(1, label = "my label", source = "user")
#' param_attr(p, "label")
#' param_attr(p, "source")
#' param_attr(p, "lab")
#' param_attr(p, "area", default = NA_character_)
#' @export
param_attr <- function(x, which, default = NULL) {
    res <- attr(x, which, exact = TRUE)
    if (is.null(res)) default else res
}


# ------
# Values
# ------
#' Get or set the value of a param
#'
#' Get the plain value of a param or replace it, keeping the rest of the param.
#'
#' @details
#' ## Functions
#'
#' * `param_value()` returns the plain value: the value without label, validity and the
#'   other attributes of the param, but with its class (e.g. `factor`, `Date`) and
#'   structure (e.g. `names`, `dim`). For a [param_group()] it returns a named list of
#'   the plain values of its children.
#' * `param_value<-` replaces the value and keeps everything else (label, validity,
#'   ...).
#'
#' ## Setting a value
#'
#' The new value is converted to the type of the current one, e.g. a text `"2"` becomes
#' the number 2 for a numeric param. Also:
#'
#' * The names or dimensions of the new value replace those of the current one.
#' * A factor param keeps its levels: values outside them become `NA`, which the
#'   validity check of [choice_param()] reports. A new factor brings its own levels.
#' * A date-time param reads texts in its own time zone. ISO 8601 texts with `T` and a
#'   trailing `Z` (UTC) work too.
#' * A param as new value contributes its plain value.
#' * A param group takes a named list with (at least) the names of its children.
#'
#' @param x A param object.
#' @param value The new value.
#' @return `param_value()`: the plain value. `param_value<-`: the updated param object.
#' @examples
#' p <- choice_param("yes", c("yes", "no"), label = "Question")
#' param_value(p)
#' param_value(p) <- "no"
#' p
#'
#' g <- param_group(list(a = param("x"), b = numeric_param(1)))
#' param_value(g)
#' param_value(g) <- list(a = "y", b = 2)
#' param_value(g)
#'
#' # Date-times: texts are read in the time zone of the param
#' start <- param(
#'     as.POSIXct("2026-10-05 12:00:00", tz = "Europe/Berlin"),
#'     label = "Start"
#' )
#' param_value(start) <- "2026-10-06 08:30:00"
#' param_value(start)
#'
#' # ISO 8601 texts with a trailing Z are UTC (08:30 UTC is 10:30 in Berlin)
#' param_value(start) <- "2026-10-06T08:30:00Z"
#' param_value(start)
#' @export
param_value <- function(x) {
    .assert_param(x)
    value <- .strip_param(x)
    if (inherits(x, "param_group")) {
        value <- lapply(value, .plain)
    }
    value
}

#' @rdname param_value
#' @export
`param_value<-` <- function(x, value) {
    .assert_param(x)
    value <- .plain(value)
    if (inherits(x, "param_group")) {
        return(.set_group_value(x, value))
    }
    new <- .coerce_like(value, x)
    oldAttrs <- attributes(x)
    oldAttrs$class <- NULL
    keep <- setdiff(
        names(oldAttrs),
        c(names(attributes(new)), names(attributes(value)))
    )
    for (name in keep) {
        attr(new, name) <- oldAttrs[[name]]
    }
    for (name in setdiff(names(attributes(value)), "class")) {
        attr(new, name) <- attr(value, name)
    }
    class(new) <- c("param", setdiff(class(new), "param"))
    new
}

# Attributes that belong to the value (not to the param), kept by `param_value()`: for
# every value, and for values of the given classes (their class needs them; a param of
# such a class can't use the names for metadata anyway, as attributes share one
# namespace).
.value_attrs <- c("names", "dim", "dimnames", "levels", "row.names")
.class_value_attrs <- list(
    POSIXct = "tzone",
    POSIXlt = c("tzone", "balanced"),
    difftime = "units",
    ts = "tsp"
)

#' Remove the param class and attributes from a param (not recursive)
#' @param x a param.
#' @noRd
.strip_param <- function(x) {
    cls <- .value_class(x)
    attrs <- attributes(x)
    keep <- c(
        .value_attrs,
        unlist(.class_value_attrs[intersect(
            cls,
            names(.class_value_attrs)
        )])
    )
    attributes(x) <- attrs[intersect(names(attrs), keep)]
    if (!identical(class(x), cls)) {
        class(x) <- cls
    }
    x
}

#' The plain value of `x` if it is a param, else `x`
#' @param x any object.
#' @noRd
.plain <- function(x) {
    if (is_param(x)) param_value(x) else x
}

#' Convert a plain value to the class of the value of param `x`
#' @param value the plain value.
#' @param x the param whose value class to convert to.
#' @noRd
.coerce_like <- function(value, x) {
    if (is.factor(x)) {
        if (is.factor(value)) {
            return(value)
        }
        return(factor(
            as.character(value),
            levels = levels(x),
            ordered = is.ordered(x)
        ))
    }
    cls <- .value_class(x)[[1]]
    if (inherits(value, cls)) {
        return(value)
    }
    if (cls %in% c("POSIXct", "POSIXlt")) {
        return(.coerce_date_time(value, x, cls))
    }
    asFun <- get0(paste0("as.", cls), mode = "function")
    if (is.null(asFun)) {
        rlang::abort(
            sprintf("Can't convert the value to class '%s'.", cls),
            call = rlang::caller_env()
        )
    }
    asFun(value)
}

#' Convert a plain value to a date-time in the time zone of param `x`
#'
#' Strings may use the ISO 8601 form with `T` and a trailing `Z` (UTC), as Shiny's
#' JSON sends date-times.
#' @param value the plain value.
#' @param x a date-time param.
#' @param cls `"POSIXct"` or `"POSIXlt"`.
#' @noRd
.coerce_date_time <- function(value, x, cls) {
    tz <- attr(x, "tzone")[1L]
    if (is.null(tz)) {
        tz <- ""
    }
    if (is.character(value)) {
        isUtc <- grepl("Z$", value)
        value <- sub("Z$", "", sub("^(\\d{4}-\\d{2}-\\d{2})T", "\\1 ", value))
        new <- as.POSIXct(value, tz = tz)
        if (any(isUtc)) {
            new[isUtc] <- as.POSIXct(value[isUtc], tz = "UTC")
        }
    } else {
        new <- as.POSIXct(value, tz = tz)
    }
    if (cls == "POSIXlt") as.POSIXlt(new, tz = tz) else new
}

#' Set the values of the children of a param group
#' @param x a param group.
#' @param value named list with (at least) the names of the children.
#' @param call see `rlang::abort()`.
#' @return The updated group.
#' @noRd
.set_group_value <- function(x, value, call = rlang::caller_env()) {
    if (!is.list(value) || !all(names(x) %in% names(value))) {
        rlang::abort(
            paste(
                "value for param_group must be a named list with names:",
                toString(names(x))
            ),
            call = call
        )
    }
    for (name in names(x)) {
        param_value(x[[name]]) <- value[[name]]
    }
    x
}


# ======================================================================================
# Validity
# ======================================================================================

# ---------------
# Validity checks
# ---------------
#' Validity checks of params
#'
#' Each param carries rules that tell whether its value is valid. A rule is a *validity
#' function*: it takes the plain value and returns `""` if the value is valid,
#' otherwise a message that says what is wrong.
#'
#' @details
#' ## Functions
#'
#' * `param_validity()` checks a value against all rules of a param and returns their
#'   messages. By default it checks the param's current value; pass `value` to check
#'   another one.
#' * `param_validity_assert()` does the same but signals an error if any rule reports
#'   a problem.
#' * `add_validity()` adds rules to a param.
#' * `default_param_validity()` is the default rule of [param()]: the value must be
#'   neither empty nor `NA`.
#'
#' A message can be any text (other results are converted with [toString()]).
#'
#' If a rule itself fails with an error (e.g. because of unexpected input), the error
#' is caught and reported as the message `"validity check failed: <error message>"`.
#' The value then counts as invalid. So `param_validity()` itself never fails because of
#' a rule, which keeps a parameter UI from crashing on a faulty rule (see Examples).
#'
#' For a [param_group()], the rules of the group get the named list of the child values
#' and each child is checked with its own rules. The result has one element for the
#' group (named `group`) and one per child. Each element holds the messages of that
#' part, joined by `", "`:
#'
#' ```
#' c(group = "lower must be below upper", lower = "", upper = "")
#' ```
#'
#' @param x A param (`default_param_validity()`: a plain value).
#' @param value The value to check; defaults to the param's own value. Params are
#'   treated as their plain values.
#' @param f A validity function or a list of them.
#' @return
#' * `param_validity()`: a character vector with one message per validity function
#'   (`""`: valid). For groups, a named vector (see Details).
#' * `param_validity_assert()`: `value`, invisibly, if it is valid.
#' * `add_validity()`: the updated param.
#' * `default_param_validity()`: `character(1)`, `""` if valid.
#' @examples
#' # Numeric params check their bounds; "" means valid
#' p <- numeric_param(0.5, min = 0, max = 1)
#' param_validity(p)
#' param_validity(p, value = 2)
#' param_validity_assert(p, value = 0.7)
#' try(param_validity_assert(p, value = 2))
#'
#' # A rule that fails with an error is reported as a message
#' bad <- add_validity(p, \(x) if (log(x) > -5) "" else "too small")
#' param_validity(bad, value = "a")
#'
#' # Add a rule of your own
#' p <- add_validity(p, \(x) if (x != 0.25) "" else "must not be 0.25")
#' param_validity(p, value = 0.25)
#'
#' default_param_validity(NA)
#' @export
param_validity <- function(x, value = x) {
    .assert_param(x)
    validity <- .as_validity_list(
        param_attr(x, "validity", default = default_param_validity)
    )
    plainValue <- .plain(value)
    infos <- vapply(
        validity,
        FUN = \(f) .run_validity(f, plainValue),
        FUN.VALUE = character(1),
        USE.NAMES = FALSE
    )
    if (!inherits(x, "param_group")) {
        return(infos)
    }
    childInfos <- vapply(
        names(x),
        FUN = \(name) {
            childValue <- if (name %in% names(plainValue)) {
                plainValue[[name]]
            }
            param_validity(x[[name]], value = childValue) |>
                .collapse_validity()
        },
        FUN.VALUE = character(1)
    )
    c(group = .collapse_validity(infos), childInfos)
}

#' @rdname param_validity
#' @export
param_validity_assert <- function(x, value = x) {
    info <- Filter(nzchar, param_validity(x, value = value))
    if (length(info) > 0) {
        if (inherits(x, "param_group")) {
            info <- paste(names(info), info, sep = ": ")
        }
        rlang::abort(toString(info))
    }
    invisible(value)
}

#' @rdname param_validity
#' @export
add_validity <- function(x, f) {
    .assert_param(x)
    existing <- param_attr(x, "validity", default = list())
    attr(x, "validity") <- c(
        .as_validity_list(existing),
        .as_validity_list(f)
    )
    x
}

#' @rdname param_validity
#' @export
default_param_validity <- function(x) {
    if (length(x) == 0) {
        return("value cannot be empty")
    }
    if ((is.atomic(x) || is.list(x)) && anyNA(x)) {
        return("value cannot be NA")
    }
    ""
}

#' Normalise a validity argument to a list of functions
#' @param validity `NULL`, a function or a list of functions.
#' @param call see `rlang::abort()`.
#' @return A list of functions.
#' @noRd
.as_validity_list <- function(validity, call = rlang::caller_env()) {
    if (is.null(validity)) {
        return(list())
    }
    if (is.function(validity)) {
        return(list(validity))
    }
    if (!is.list(validity) || !all(vapply(validity, is.function, TRUE))) {
        rlang::abort(
            "validity must be a function or list of functions",
            call = call
        )
    }
    validity
}

#' Run one validity function; errors become a message
#' @param f a validity function.
#' @param value the plain value to check.
#' @return `character(1)`.
#' @noRd
.run_validity <- function(f, value) {
    tryCatch(
        toString(f(value)),
        error = \(e) paste("validity check failed:", .cnd_message(e))
    )
}

#' Join the non-empty validity messages with ", "
#' @param info character vector of validity messages.
#' @return `character(1)`.
#' @noRd
.collapse_validity <- function(info) {
    toString(Filter(nzchar, unname(info)))
}
