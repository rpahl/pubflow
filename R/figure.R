# Figures: ggplot objects (ggplot2 3.x and the S7-based 4.x), recorded base plots or
# existing image files, plus metadata. Rendering to files (.render_figure()) is used by
# the HTML and Pandoc renderers.

# ======================================================================================
# Figure outputs
# ======================================================================================

# -----------
# Image files
# -----------
#' Figure output
#'
#' Marks a plot or image files as a figure and sets its caption, size and other
#' metadata.
#'
#' @details
#' ## When do you need it?
#'
#' Plots in a document ([pub_doc()]) are figures even without `pub_figure()`; use it
#' only to set a caption or a size. Image files, however, always need it, as otherwise
#' their paths would be read as text:
#'
#' | Input | `pub_figure()` |
#' |---|---|
#' | ggplot | optional |
#' | recorded base plot ([grDevices::recordPlot()]) | optional |
#' | image files (png, jpg, svg, pdf) | required |
#'
#' ## One figure in several formats
#'
#' You can pass several image files of the same plot, e.g. a png and a pdf. Each
#' output format then picks the file that suits it best:
#'
#' * HTML and DOCX show the png (or jpg), as they can't show pdf images;
#' * a PDF report made with LaTeX can use the vector graphic if you ask for it with
#'   `figure = list(device = "pdf")` (see [pub_html()] and [pub_report_spec()]).
#'
#' Always provide at least a png or jpg.
#'
#' ## Rendered figures
#'
#' With `render = TRUE` the plot is drawn where the step runs and the step returns
#' the png image (200 dpi, class `pub_png`) instead of the plot. Use it:
#'
#' * in steps that run in other R processes (workers) and for pipelines saved with
#'   [saveRDS()]: a ggplot holds environments, so a copy of it differs from the
#'   original, and the document renders it again even though nothing changed. The
#'   image has no environments and survives copying unchanged, so the document uses
#'   it as it is;
#' * for recorded plots, which can't be replayed in another R session.
#'
#' Note that once rendered, a figure can't be changed in later steps, so the rendering
#' step should be the last that touches it. In addition, even if a report spec has
#' `figure = list(device = "pdf")` it still shows the png.
#'
#' A rendered figure takes `caption`, `id` etc. like any other; changing them later
#' (also with [pub_set_meta()]) only affects the metadata, not the image. `width` and
#' `height` are the exception: they are the size the plot was rendered at, so
#' `pub_figure()` refuses them (use `out_width` to scale the figure in the document).
#' [pub_set_meta()] accepts them, but then they no longer match the pixels.
#'
#' @param x A ggplot, a recorded plot ([grDevices::recordPlot()]) or the paths of
#'   existing image files of one figure (see Details). A rendered figure (`render =
#'   TRUE`) can be passed again to set its metadata.
#' @param caption `character(1)` caption (figures are numbered) or `NULL`.
#' @param width,height Size of the plot in inches (default 8 x 6).
#' @param out_width Width in the document relative to the text width, e.g. `"90%"`
#'   (default).
#' @param ... Further metadata, e.g. `title`, `id` (to refer to the figure as
#'   `@fig:<id>` in texts, see [pub_text()]), `landscape` or `locked` (see
#'   [pub_meta()]).
#' @param render `TRUE`: draw a ggplot or recorded plot now, as a png image (see
#'   Details, "Rendered figures"); must be named.
#' @return `x` with metadata; with `render = TRUE` the png image (class `pub_png`)
#'   of the plot, with the same metadata.
#' @seealso [pub_meta()], [pub_type()]
#' @examples
#' # A recorded base plot is a figure already; pub_figure() adds a caption and size
#' grDevices::pdf(NULL)
#' grDevices::dev.control("enable")
#' plot(1:10)
#' p <- grDevices::recordPlot()
#' grDevices::dev.off()
#' pub_type(p)
#'
#' fig <- pub_figure(p, caption = "Ten points", width = 5, height = 4, id = "points")
#' pub_type(fig)
#' pub_meta(fig)
#'
#' # The same holds for a ggplot
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'     gg <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'         ggplot2::geom_point()
#'     print(pub_type(gg))
#'     pub_meta(pub_figure(gg, caption = "Weight and mileage"))
#' }
#'
#' # Image files must be marked, otherwise their paths are text
#' file <- tempfile(fileext = ".png")
#' ragg::agg_png(file)
#' plot(1:10)
#' grDevices::dev.off()
#' pub_type(file)
#' pub_type(pub_figure(file, caption = "Ten points from a file"))
#'
#' # One figure in several formats: a renderer picks the best file
#' files <- file.path(tempdir(), c("points.png", "points.pdf"))
#' ragg::agg_png(files[1])
#' plot(1:10)
#' grDevices::dev.off()
#' grDevices::pdf(files[2])
#' plot(1:10)
#' grDevices::dev.off()
#' fig <- pub_figure(files, caption = "Ten points as png and pdf")
#' html <- pub_html(pub_doc(fig))  # HTML picks the png
#' grepl("data:image/png", html)
#'
#' # Render the figure in the step: the result is a png image with the metadata
#' png <- pub_figure(p, caption = "Ten points", width = 4, height = 3, render = TRUE)
#' png
#' pub_type(png)
#' identical(png, unserialize(serialize(png, NULL)))
#' @export
pub_figure <- function(
    x,
    caption = NULL,
    width = NULL,
    height = NULL,
    out_width = NULL,
    ...,
    render = FALSE
) {
    .check_figure_input(x, width, height, render)
    meta <- list(
        type = if (is.character(x)) "figure",
        caption = caption,
        width = width,
        height = height,
        out_width = out_width
    )
    meta <- meta[!vapply(meta, is.null, logical(1))]
    x <- do.call(pub_set_meta, c(list(x), meta, list(...)))
    if (render && !inherits(x, "pub_png")) {
        x <- .render_png(x)
    }
    x
}

#' Check the arguments of `pub_figure()`
#' @param x,width,height,render the arguments of `pub_figure()`.
#' @param call the environment of the caller, for the error message.
#' @noRd
.check_figure_input <- function(x, width, height, render, call = rlang::caller_env()) {
    if (is.character(x)) {
        .check_image_files(x, call = call)
    } else if (!inherits(x, c("ggplot", "recordedplot", "pub_png"))) {
        rlang::abort(
            paste(
                "`x` must be a ggplot, a recorded plot, a rendered figure or paths",
                "of image files,",
                sprintf("not <%s>.", paste(class(x), collapse = "/"))
            ),
            call = call
        )
    }
    if (!rlang::is_bool(render)) {
        rlang::abort("`render` must be `TRUE` or `FALSE`.", call = call)
    }
    if (render && is.character(x)) {
        rlang::abort("`render = TRUE` needs a plot, not image files.", call = call)
    }
    if (inherits(x, "pub_png") && !(is.null(width) && is.null(height))) {
        rlang::abort(
            "`width` and `height` can't change a rendered figure (its size is fixed).",
            call = call
        )
    }
    invisible(x)
}

#' File extensions of supported image files
#' @noRd
.image_extensions <- function() {
    c("png", "jpg", "jpeg", "svg", "pdf")
}

#' Check that `x` names existing image files of a supported format
#' @param x `character` paths of the image files.
#' @param call the environment of the caller, for the error message.
#' @return `x`, invisibly.
#' @noRd
.check_image_files <- function(x, call = rlang::caller_env()) {
    if (length(x) == 0L || anyNA(x)) {
        rlang::abort("`x` must name at least one image file.", call = call)
    }
    ext <- tolower(tools::file_ext(x))
    bad <- x[!ext %in% .image_extensions()]
    if (length(bad) > 0L) {
        rlang::abort(
            sprintf(
                "Unsupported image files (use %s): %s.",
                toString(.image_extensions()),
                toString(bad)
            ),
            call = call
        )
    }
    missing <- x[!file.exists(x)]
    if (length(missing) > 0L) {
        rlang::abort(
            sprintf("Image files not found: %s.", toString(missing)),
            call = call
        )
    }
    invisible(x)
}


# ---------
# Rendering
# ---------
#' Render a figure to a file
#'
#' @param x A figure output: ggplot, recorded plot or image file paths.
#' @param file Path of the output file (its extension is replaced by the source's for
#'   image files).
#' @param device `"png"` (`ragg::agg_png()`), `"svg"` (svglite, Suggests) or `"pdf"`
#'   (`grDevices::cairo_pdf()`).
#' @param width,height Size in inches; default from the metadata, else 8 x 6.
#' @param res Resolution of png files in dpi.
#' @return The path of the written file, invisibly.
#' @noRd
.render_figure <- function(
    x,
    file,
    device = c("png", "svg", "pdf"),
    width = NULL,
    height = NULL,
    res = 200
) {
    device <- match.arg(device)
    if (is.character(x)) {
        return(invisible(.copy_image_file(x, file, device)))
    }
    width <- width %||% pub_meta(x, "width") %||% 8
    height <- height %||% pub_meta(x, "height") %||% 6
    .open_device(device, file, width, height, res)
    dev <- grDevices::dev.cur()
    on.exit(grDevices::dev.off(dev), add = TRUE)
    tryCatch(.draw_figure(x), error = \(e) .abort_draw(e, width, height))
    invisible(file)
}

#' Write the bytes of a rendered figure to a png file
#' @param x a `pub_png`.
#' @param dest path of the png file.
#' @return `dest`; a `pubflow_render_error` if writing fails.
#' @noRd
.write_png <- function(x, dest) {
    reason <- tryCatch(
        {
            writeBin(.png_bytes(x), dest)
            NULL
        },
        error = conditionMessage,
        warning = conditionMessage
    )
    if (!is.null(reason)) {
        rlang::cnd_signal(.render_error(
            c(sprintf("Can't write the figure file '%s'.", dest), i = reason),
            format = "png"
        ))
    }
    dest
}

#' Error for a figure that can't be drawn, with its size
#' @param e the drawing error.
#' @param width,height size in inches.
#' @noRd
.abort_draw <- function(e, width, height) {
    small <- grepl("invalid graphics state|margins too large", conditionMessage(e))
    rlang::abort(
        c(
            sprintf("Can't draw the figure at %g x %g inches.", width, height),
            i = if (small) "Is the figure too small for its margins?"
        ),
        parent = e,
        call = NULL
    )
}

#' Draw a ggplot or recorded plot on the current device
#' @param x a ggplot or a recorded plot.
#' @return `x`, invisibly.
#' @noRd
.draw_figure <- function(x) {
    if (inherits(x, "recordedplot")) {
        grDevices::replayPlot(x)
    } else {
        print(x)
    }
    invisible(x)
}

#' Open the graphics device of a figure file
#' @param device `"png"`, `"svg"` or `"pdf"`.
#' @param file path of the output file.
#' @param width,height size in inches.
#' @param res resolution of png files in dpi.
#' @noRd
.open_device <- function(device, file, width, height, res) {
    switch(
        device,
        png = ragg::agg_png(
            file,
            width = width,
            height = height,
            units = "in",
            res = res
        ),
        svg = {
            rlang::check_installed("svglite", reason = "to render SVG figures.")
            svglite::svglite(file, width = width, height = height)
        },
        pdf = {
            if (!capabilities("cairo")) {
                rlang::cnd_signal(.render_error(
                    "Can't render PDF figures: R was built without cairo.",
                    format = "pdf"
                ))
            }
            grDevices::cairo_pdf(file, width = width, height = height)
        }
    )
}

#' Copy the image file matching a device (png also takes jpg)
#' @param x `character` paths of the image files of one figure.
#' @param file path of the output file (its extension is replaced by the source's).
#' @param device `"png"`, `"svg"` or `"pdf"`.
#' @return `character(1)` path of the copy; a `pubflow_render_error` if copying fails.
#' @noRd
.copy_image_file <- function(x, file, device) {
    src <- .pick_image_file(x, device)
    dest <- paste0(tools::file_path_sans_ext(file), ".", tools::file_ext(src))
    res <- .file_op(file.copy(src, dest, overwrite = TRUE))
    if (!res$ok) {
        rlang::cnd_signal(.render_error(
            c(
                sprintf("Can't copy image file '%s' to '%s'.", src, dest),
                i = res$reason
            ),
            format = device
        ))
    }
    dest
}

#' The image file matching a device: its own format, else a raster image (png, jpg),
#' which every target shows, else one of the other `devices` that the target shows (e.g.
#' a pdf-only figure in LaTeX)
#' @param x `character` paths of the image files of one figure.
#' @param device `"png"`, `"svg"` or `"pdf"`.
#' @param devices further formats that the target shows.
#' @return `character(1)` path; a `pubflow_render_error` if none matches.
#' @noRd
.pick_image_file <- function(x, device, devices = device) {
    accepted <- unique(c(device, "png", "jpg", "jpeg", devices))
    rank <- match(tolower(tools::file_ext(x)), accepted)
    hit <- which(rank == min(c(rank, Inf), na.rm = TRUE))
    if (length(hit) == 0L) {
        rlang::cnd_signal(.render_error(
            sprintf(
                "No %s image among the figure files: %s.",
                device,
                toString(basename(x))
            ),
            format = device
        ))
    }
    x[[hit[[1L]]]]
}


# ----------------
# Rendered figures
# ----------------
#' Render a plot to a `pub_png`
#' @param x a ggplot or recorded plot; the size comes from its metadata, else 8 x 6.
#' @return the png bytes with the metadata of `x` (without `stamp`, plus the size) as
#'   class `pub_png`.
#' @noRd
.render_png <- function(x) {
    meta <- pub_meta(x)
    meta[["stamp"]] <- NULL
    meta[["width"]] <- meta[["width"]] %||% 8
    meta[["height"]] <- meta[["height"]] %||% 6
    file <- tempfile("pubflow-png-", fileext = ".png")
    on.exit(unlink(file), add = TRUE)
    .render_figure(
        x,
        file,
        device = .figure_default$device,
        width = meta[["width"]],
        height = meta[["height"]],
        res = .figure_default$res
    )
    bytes <- readBin(file, "raw", file.size(file))
    .new_pub_png(bytes, meta)
}

#' A rendered figure
#' @param bytes `raw` png file content.
#' @param meta named `list` of metadata.
#' @return `bytes` with class `pub_png` and the metadata.
#' @noRd
.new_pub_png <- function(bytes, meta) {
    structure(bytes, class = "pub_png", pubflow = meta)
}

#' The bytes of a `pub_png` without class and metadata
#' @param x a `pub_png`.
#' @return `raw` vector.
#' @noRd
.png_bytes <- function(x) {
    attributes(x) <- NULL
    x
}

#' Print a rendered figure
#' @param x a `pub_png`.
#' @param ... unused.
#' @return `x`, invisibly.
#' @export
#' @noRd
print.pub_png <- function(x, ...) {
    size <- .png_pixels(x)
    inches <- c(pub_meta(x, "width"), pub_meta(x, "height"))
    info <- sprintf("%d x %d px", size[[1L]], size[[2L]])
    if (length(inches) == 2L) {
        info <- sprintf(
            "%s (%g x %g in, %g dpi)",
            info,
            inches[[1L]],
            inches[[2L]],
            round(size[[1L]] / inches[[1L]])
        )
    }
    cat(
        "<pubflow figure> PNG ",
        paste0(c(info, sprintf("%.0f KB", length(x) / 1024)), collapse = ", "),
        "\n",
        sep = ""
    )
    caption <- pub_meta(x, "caption")
    if (!is.null(caption)) {
        cat("Caption: ", caption, "\n", sep = "")
    }
    invisible(x)
}

#' Pixel size of a png (IHDR chunk)
#' @param x a `pub_png`.
#' @return `integer(2)` width and height.
#' @noRd
.png_pixels <- function(x) {
    bytes <- .png_bytes(x)
    c(
        readBin(bytes[17:20], "integer", size = 4L, endian = "big"),
        readBin(bytes[21:24], "integer", size = 4L, endian = "big")
    )
}


# ======================================================================================
# Figure stamps
# ======================================================================================

# pipeflow's output hook pip_output_value() stamps the figures a step returns, so that
# the render cache can tell them apart.

# ------------
# Output hooks
# ------------
#' Stamp the figures a step returns
#'
#' pipeflow applies [pipeflow::pip_output_value()] to every step output (to each
#' partition in case of a partitioned step). pubflow's methods give figures (ggplots,
#' recorded plots, also in plain lists) the metadata entry `stamp`:
#' - the step
#' - the partition key (`NULL` if none)
#' - the time of the step's run
#'
#' A figure that has a stamp keeps it, e.g. one passed on by a later step. The list
#' method walks unclassed lists only, so data.frames and pubflow's classed outputs are
#' left alone. The render cache ([pub_cache()]) keys figures by their stamp.
#'
#' @param x a step output.
#' @param ctx `list(step, key, time)` given by pipeflow.
#' @param ... unused.
#' @return `x` with stamped figures.
#' @exportS3Method pipeflow::pip_output_value
#' @noRd
pip_output_value.ggplot <- function(x, ctx = list(), ...) {
    .stamp_figures(x, .figure_stamp(ctx))
}

#' @describeIn pip_output_value.ggplot recorded plots.
#' @exportS3Method pipeflow::pip_output_value
#' @noRd
pip_output_value.recordedplot <- function(x, ctx = list(), ...) {
    .stamp_figures(x, .figure_stamp(ctx))
}

#' @describeIn pip_output_value.ggplot unclassed lists.
#' @exportS3Method pipeflow::pip_output_value
#' @noRd
pip_output_value.list <- function(x, ctx = list(), ...) {
    if (!.has_figures(x)) {
        return(x)
    }
    .stamp_figures(x, .figure_stamp(ctx))
}


# ------
# Stamps
# ------
#' Stamp of the figures of a step output
#' @param ctx see `pip_output_value.ggplot()`.
#' @return `list(step, key, time)`.
#' @noRd
.figure_stamp <- function(ctx) {
    list(step = ctx[["step"]], key = ctx[["key"]], time = ctx[["time"]])
}

#' Stamp the figures of a step output
#'
#' Figures at the top level or in plain lists get the metadata entry `stamp` unless they
#' have one. Other outputs (sections, tables, ...) are left alone.
#' @param x a step output.
#' @param stamp see `.figure_stamp()`.
#' @return `x` with stamped figures.
#' @noRd
.stamp_figures <- function(x, stamp) {
    if (.is_plot(x)) {
        if (is.null(pub_meta(x, "stamp"))) {
            x <- pub_set_meta(x, stamp = stamp)
        }
        return(x)
    }
    if (.is_plain_list(x) && length(x) > 0L) {
        x[] <- lapply(x, .stamp_figures, stamp = stamp)
    }
    x
}

#' Does a step output hold a figure (top level or in plain lists)?
#' @param x a step output.
#' @return `TRUE` or `FALSE`.
#' @noRd
.has_figures <- function(x) {
    if (.is_plot(x)) {
        return(TRUE)
    }
    .is_plain_list(x) && any(vapply(x, .has_figures, logical(1)))
}

#' A ggplot or a recorded plot
#' @param x any value.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_plot <- function(x) {
    inherits(x, c("ggplot", "recordedplot"))
}

#' A plain list (also a partitioned output), not a classed object
#' @param x any value.
#' @return `TRUE` or `FALSE`.
#' @noRd
.is_plain_list <- function(x) {
    is.list(x) && (!is.object(x) || inherits(x, "pipeflow_partitioned"))
}
