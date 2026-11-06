# Param configs: ordered named lists of params. The config order drives the order of the
# parameter UI (attribute `order`).

# -------
# Configs
# -------
#' Parameter configs
#'
#' A config is a named list of params that defines all parameters of a pipeline.
#'
#' @details
#' ## Functions
#'
#' * `param_config()` collects params into a config. It checks that all elements are
#'   params with unique names and numbers them (attribute `order`), which sets their
#'   order in the parameter UI.
#' * `c()` combines configs (and further params or lists of params) and numbers the
#'   params anew.
#' * `[` selects params and keeps the class. Unknown names and indices are an error.
#'
#' Duplicate names are an error, unless you set `.duplicates = "first"`: then the first
#' definition wins. This is useful to merge the configs of combined pipelines, where the
#' more specific definition comes first (see Examples).
#'
#' @param ... Params (named arguments), lists of params or configs. `NULL` arguments are
#'   ignored. The names of list arguments are not used, only those of the params in
#'   them.
#' @param .duplicates `"error"` (default) or `"first"`: what to do with params of the
#'   same name.
#' @param x A param config.
#' @param i Index of the elements to keep.
#' @return A named list of params with class `c("param_config", "list")`.
#' @seealso [param()], [pub_get_params()]
#' @examples
#' prep <- param_config(
#'     yUnit = param("%", label = "Unit of y"),
#'     alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1)
#' )
#' stats <- param_config(
#'     alpha = numeric_param(0.01, label = "Alpha", min = 0, max = 1),
#'     list(showPoints = param(TRUE, label = "Show points?"))
#' )
#' names(prep)
#' param_attr(stats$showPoints, "order")
#'
#' # Merge configs: the first definition of 'alpha' wins
#' full <- c(prep, stats, .duplicates = "first")
#' param_value(full$alpha)
#' vapply(full, param_attr, numeric(1), which = "order")
#'
#' # By default, duplicate names are an error
#' try(c(prep, stats))
#' @export
param_config <- function(..., .duplicates = c("error", "first")) {
    .duplicates <- rlang::arg_match(.duplicates)
    .new_param_config(list(...), .duplicates)
}

#' @rdname param_config
#' @export
c.param_config <- function(..., .duplicates = c("error", "first")) {
    .duplicates <- rlang::arg_match(.duplicates)
    .new_param_config(list(...), .duplicates)
}

#' Config of the params in `args`, numbered in their order
#' @param args `list` of the arguments of `param_config()`.
#' @param duplicates `"error"` or `"first"`.
#' @param call the environment of the caller, for the error message.
#' @noRd
.new_param_config <- function(args, duplicates, call = rlang::caller_env()) {
    params <- .flatten_params(args, call)
    dup <- duplicated(names(params))
    if (any(dup) && duplicates == "error") {
        rlang::abort(
            c(
                sprintf(
                    "Duplicate param names: %s.",
                    toString(unique(names(params)[dup]))
                ),
                i = "Use `.duplicates = \"first\"` to keep the first definition."
            ),
            call = call
        )
    }
    params <- params[!dup]
    for (i in seq_along(params)) {
        attr(params[[i]], "order") <- i
    }
    class(params) <- c("param_config", "list")
    params
}

#' @rdname param_config
#' @export
`[.param_config` <- function(x, i) {
    res <- unclass(x)[i]
    # base lists give NULL elements named NA for unknown names and indices
    if (anyNA(names(res))) {
        rlang::abort(
            if (is.character(i)) {
                sprintf("Unknown params: %s.", toString(setdiff(i, names(x))))
            } else {
                "Can't select params beyond the end of the config or by `NA`."
            }
        )
    }
    class(res) <- class(x)
    res
}


# ----------
# Flattening
# ----------
#' Flatten the arguments of `param_config()` into a named list of params
#'
#' @param args `list` of the arguments: params (named), lists of params, or `NULL`.
#' @param call see `rlang::abort()`.
#' @return named `list` of params (plain list, possibly with duplicate names).
#' @noRd
.flatten_params <- function(args, call = rlang::caller_env()) {
    argNames <- names(args)
    if (is.null(argNames)) {
        argNames <- rep("", length(args))
    }
    pieces <- Map(
        \(arg, name) .config_piece(arg, name, call = call),
        args,
        argNames
    )
    params <- do.call(c, unname(pieces))
    if (is.null(params)) {
        params <- list()
    }
    if (!rlang::is_named2(params)) {
        rlang::abort("all params must be named", call = call)
    }
    notParam <- !vapply(params, is_param, logical(1))
    if (any(notParam)) {
        rlang::abort(
            sprintf(
                "all elements must be params, not: %s",
                toString(names(params)[notParam])
            ),
            call = call
        )
    }
    params
}

#' One argument of `param_config()` as a plain list
#'
#' @param arg one argument: a param, a list or config of params, or `NULL`.
#' @param name name of the argument (`""` if unnamed).
#' @param call see `rlang::abort()`.
#' @return named `list` of params (`list()` for `NULL`).
#' @noRd
.config_piece <- function(arg, name, call) {
    if (is.null(arg)) {
        return(list())
    }
    if (is_param(arg)) {
        if (!nzchar(name)) {
            rlang::abort(
                "params passed as arguments must be named",
                call = call
            )
        }
        return(rlang::set_names(list(arg), name))
    }
    if (!is.list(arg) || is.data.frame(arg)) {
        rlang::abort(
            "arguments must be params or lists of params",
            call = call
        )
    }
    unclass(arg)
}
