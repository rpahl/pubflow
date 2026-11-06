# Render cache: rendering a figure costs ~80-100 ms and huxtable's HTML of a table 6-9
# ms, so the results are kept per session and reused by the viewer and the reports. A
# figure is cached only if a step made it: pipeflow's output hook stamps it (step,
# partition key, run time), and the key combines that stamp with rlang::hash() of the
# figure, its metadata and the device settings. rlang::hash() alone is not safe for
# figures (it hashes environments by address, and freed addresses are reused); the stamp
# changes whenever the step re-runs. Tables hold data, so their key is rlang::hash() of
# the table. Figures are files, table HTML is kept in memory; both count towards
# `max_entries`.

# -------------
# Cache objects
# -------------
#' Define cache for figures and tables
#'
#' Holds rendered figures and tables for reuse by the render functions that get it as
#' their `cache` argument ([pub_html()], [pub_render()], [pub_markdown()] and the
#' viewer).
#'
#' @details
#' ## What is cached
#'
#' Two kinds of entries are cached:
#'
#' * figures: image files in `dir`, used by every output format. The key combines the
#'   figure's stamp (step, partition key and run time, see [pub_meta()]), a hash of the
#'   figure and its metadata and the device settings.
#' * tables: their HTML (in memory), used by HTML output. The key is a hash of the
#'   table and its font size.
#'
#' Beyond `max_entries` entries the least recently used ones (and their files) are
#' removed.
#'
#' @param dir Directory for the image files, or `NULL` for a new temporary directory of
#'   the R session.
#' @param max_entries Maximum number of cached figures and tables.
#' @return A `pub_cache` object (an environment, so it is updated in place).
#' @seealso [pub_html()], [pub_render()]
#' @examples
#' cache <- pub_cache()
#' cache
#' @export
pub_cache <- function(dir = NULL, max_entries = 500L) {
    if (!is.null(dir) && !rlang::is_string(dir)) {
        rlang::abort("`dir` must be a single string or `NULL`.")
    }
    isCount <- rlang::is_scalar_integerish(max_entries) &&
        !is.na(max_entries) &&
        max_entries >= 1
    if (!isCount) {
        rlang::abort("`max_entries` must be a positive whole number.")
    }
    if (is.null(dir)) {
        dir <- tempfile("pubflow-cache-")
    }
    if (!dir.exists(dir)) {
        res <- .file_op(dir.create(dir, recursive = TRUE))
        if (!res$ok) {
            rlang::abort(c(
                sprintf("Can't create the cache directory '%s'.", dir),
                i = res$reason
            ))
        }
    }
    cache <- new.env(parent = emptyenv())
    cache$dir <- normalizePath(dir, winslash = "/")
    cache$max_entries <- as.integer(max_entries)
    cache$entries <- new.env(parent = emptyenv())
    cache$used <- new.env(parent = emptyenv())
    cache$tick <- 0L
    structure(cache, class = "pub_cache")
}

#' @export
print.pub_cache <- function(x, ...) {
    cat(sprintf(
        "<pubflow render cache> %d of at most %d entries, files in '%s'\n",
        length(x$entries),
        x$max_entries,
        x$dir
    ))
    invisible(x)
}

#' Check that `cache` is a `pub_cache` or `NULL`
#' @param cache the value to check.
#' @param call the environment of the caller, for the error message.
#' @return `cache`, invisibly.
#' @noRd
.check_cache <- function(cache, call = rlang::caller_env()) {
    if (!is.null(cache) && !inherits(cache, "pub_cache")) {
        rlang::abort("`cache` must be made by `pub_cache()` or `NULL`.", call = call)
    }
    invisible(cache)
}


# ----
# Keys
# ----
#' Key of a figure in the cache, or `NULL` if it can't be cached
#'
#' @param x a figure (ggplot or recorded plot).
#' @param device `list` of device settings (device, size, resolution).
#' @return `character(1)` hash or `NULL` if `x` has no stamp.
#' @noRd
.cache_key <- function(x, device) {
    meta <- pub_meta(x)
    if (is.null(meta[["stamp"]])) {
        return(NULL)
    }
    rlang::hash(list(meta[["stamp"]], rlang::hash(x), meta, device))
}

#' Key of a table in the cache
#' @param x a huxtable.
#' @param settings what else changes its HTML (e.g. the font size).
#' @return `character(1)` hash.
#' @noRd
.cache_table_key <- function(x, settings) {
    rlang::hash(list("table", x, settings))
}


# -------
# Entries
# -------
#' A cached value: the file of a figure or the HTML of a table, or `NULL`
#'
#' An entry whose file was deleted is removed, so it no longer counts towards
#' `max_entries`.
#' @param cache a `pub_cache`.
#' @param key `character(1)` key from `.cache_key()` or `.cache_table_key()`.
#' @return the path of the file, the HTML or `NULL` if `key` is not cached.
#' @noRd
.cache_get <- function(cache, key) {
    entry <- cache$entries[[key]]
    if (is.null(entry)) {
        return(NULL)
    }
    if (entry$is_file && !file.exists(entry$value)) {
        rm(list = key, envir = cache$entries)
        rm(list = key, envir = cache$used)
        return(NULL)
    }
    .cache_touch(cache, key)
    entry$value
}

#' Path for a new cache entry (the figure is rendered there)
#' @param cache a `pub_cache`.
#' @param key `character(1)` key of the figure.
#' @param ext file extension without the dot (e.g. `"png"`).
#' @return `character(1)` path in the cache directory.
#' @noRd
.cache_path <- function(cache, key, ext) {
    file.path(cache$dir, paste0(key, ".", ext))
}

#' Add a value; removes the least recently used entries beyond `max_entries` (and their
#' files)
#' @param cache a `pub_cache`.
#' @param key `character(1)` key of the value.
#' @param value the path of a rendered file (`is_file = TRUE`) or HTML.
#' @param is_file `TRUE` if `value` is a file to delete when the entry is removed.
#' @return `value`, invisibly.
#' @noRd
.cache_set <- function(cache, key, value, is_file = TRUE) {
    cache$entries[[key]] <- list(value = value, is_file = is_file)
    .cache_touch(cache, key)
    n <- length(cache$entries)
    if (n > cache$max_entries) {
        used <- unlist(as.list(cache$used))
        old <- names(sort(used))[seq_len(n - cache$max_entries)]
        for (entry in mget(old, envir = cache$entries)) {
            if (entry$is_file) {
                unlink(entry$value)
            }
        }
        rm(list = old, envir = cache$entries)
        rm(list = old, envir = cache$used)
    }
    invisible(value)
}

#' Mark an entry as the most recently used one
#' @param cache a `pub_cache`.
#' @param key `character(1)` key of the entry.
#' @return `NULL`, invisibly.
#' @noRd
.cache_touch <- function(cache, key) {
    cache$tick <- cache$tick + 1L
    cache$used[[key]] <- cache$tick
    invisible(NULL)
}
