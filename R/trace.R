# GMP trace stamp: who rendered a report, when, with which application. The `{trace}`
# token in the header and footer lines of a document expands to it when the document is
# rendered.

#' Trace stamp of a report
#'
#' Makes a line that says who made a report, when and with which application, e.g.
#' `"Jane Doe at 07-Oct-2026 12:00:00 UTC (myapp v1.2.0)"`.
#'
#' @details
#' ## Parts
#'
#' The stamp consists of
#'
#' * the author;
#' * the time of the document (`time` in its metadata, else now) in UTC, with English
#'   month names whatever the locale;
#' * the application and its version in parentheses. Without `app`, the parentheses
#'   are left out, without `version`, the version.
#'
#' The token `{trace}` in the `header` and `footer` lines of a document (see
#' [pub_doc()]) becomes the trace stamp when the document is rendered to DOCX or PDF.
#' [pub_render()] adds its `meta` (e.g. the author of the current session) first.
#'
#' @param meta Document metadata (`doc$meta`, see [pub_doc()]) or a document. It must
#'   have an `author`, which pubflow doesn't guess (on a server the system user is the
#'   service account).
#' @return `character(1)` trace stamp.
#' @seealso [pub_render()], [pub_report_spec()]
#' @examples
#' meta <- list(author = "Jane Doe", app = "myapp", version = "1.2.0",
#'              time = as.POSIXct("2026-10-07 12:00:00", tz = "UTC"))
#' pub_trace_stamp(meta)
#' pub_trace_stamp(meta[c("author", "time")])
#'
#' # In a footer line
#' doc <- pub_doc(meta = list(footer = c(left = "{trace}")))
#' @export
pub_trace_stamp <- function(meta) {
    if (inherits(meta, "pub_doc")) {
        meta <- meta$meta
    }
    if (!is.list(meta)) {
        rlang::abort("`meta` must be a list of document metadata.")
    }
    meta <- .check_doc_meta(meta)
    author <- meta[["author"]]
    if (is.null(author)) {
        rlang::abort(c(
            "A trace stamp needs the metadata `author`.",
            i = "Pass it to `pub_render(meta = list(author = ...))`."
        ))
    }
    stamp <- sprintf(
        "%s at %s",
        author,
        .trace_time(meta[["time"]] %||% Sys.time())
    )
    app <- meta[["app"]]
    if (is.null(app)) {
        return(stamp)
    }
    version <- meta[["version"]]
    sprintf(
        "%s (%s%s)",
        stamp,
        app,
        if (is.null(version)) "" else paste0(" v", version)
    )
}

#' Time of a trace stamp, `dd-Mon-YYYY HH:MM:SS UTC`, English month names
#' @param time `POSIXct(1)` time, in any time zone; seconds are truncated.
#' @return `character(1)` time in UTC.
#' @noRd
.trace_time <- function(time) {
    lt <- as.POSIXlt(time, tz = "UTC")
    sprintf(
        "%02d-%s-%04d %02d:%02d:%02d UTC",
        lt$mday,
        month.abb[[lt$mon + 1L]],
        lt$year + 1900L,
        lt$hour,
        lt$min,
        as.integer(floor(lt$sec))
    )
}

#' Expand `{trace}` in header or footer lines
#'
#' The stamp is only made when a line has the token.
#' @param values named `character` lines (or `NULL`).
#' @param meta named `list` of document metadata (see [pub_trace_stamp()]).
#' @param format output format, for the render error (`"pdf"` or `"docx"`).
#' @return `values` with `{trace}` replaced; a `pubflow_render_error` without `author`.
#' @noRd
.expand_trace <- function(values, meta, format) {
    hits <- grepl("{trace}", values, fixed = TRUE)
    if (!any(hits)) {
        return(values)
    }
    if (is.null(meta[["author"]])) {
        rlang::cnd_signal(.render_error(
            c(
                "Can't expand `{trace}` without the metadata `author`.",
                i = "Pass it to `pub_render(meta = list(author = ...))`."
            ),
            format = format
        ))
    }
    values[hits] <- gsub("{trace}", pub_trace_stamp(meta), values[hits], fixed = TRUE)
    values
}
