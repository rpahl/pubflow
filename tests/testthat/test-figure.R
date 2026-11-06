recorded_plot <- function(n = 10L) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off())
    grDevices::dev.control("enable")
    graphics::plot(seq_len(n))
    grDevices::recordPlot()
}

demo_ggplot <- function() {
    data <- data.frame(x = 1:5, y = c(2, 4, 3, 5, 6))
    ggplot2::ggplot(data, ggplot2::aes(x, y)) + # nolint: object_usage_linter.
        ggplot2::geom_point()
}

# Width and height of a png file in pixels (IHDR chunk)
png_size <- function(file) {
    con <- file(file, "rb")
    on.exit(close(con))
    header <- readBin(con, "raw", 24L)
    c(
        readBin(header[17:20], "integer", size = 4L, endian = "big"),
        readBin(header[21:24], "integer", size = 4L, endian = "big")
    )
}


# ======================================================================================
# Figure outputs
# ======================================================================================

# -----------
# Image files
# -----------

describe("pub_figure()", {
    it("adds figure metadata to a recorded plot", {
        fig <- pub_figure(
            recorded_plot(),
            caption = "Points",
            width = 5,
            height = 4,
            out_width = "80%",
            title = "Fit"
        )

        expect_s3_class(fig, "recordedplot")
        expect_identical(
            pub_meta(fig),
            list(
                caption = "Points",
                width = 5,
                height = 4,
                out_width = "80%",
                title = "Fit"
            )
        )
        expect_identical(pub_type(fig), "figure")
    })

    it("keeps existing metadata for arguments not given", {
        fig <- pub_figure(recorded_plot(), caption = "A")

        expect_identical(
            pub_meta(pub_figure(fig, width = 3)),
            list(caption = "A", width = 3)
        )
    })

    it("recognises ggplot objects (ggplot2 3.x and S7-based 4.x)", {
        skip_if_not_installed("ggplot2")
        p <- demo_ggplot()

        fig <- pub_figure(p, caption = "Points")

        expect_true(inherits(fig, "ggplot"))
        expect_identical(pub_type(fig), "figure")
        expect_identical(pub_meta(fig, "caption"), "Points")
        if (utils::packageVersion("ggplot2") >= "4.0.0") {
            expect_true(inherits(fig, "S7_object"))
        } else {
            expect_false(inherits(fig, "S7_object"))
        }
    })

    it("marks image files as figure", {
        dir <- withr::local_tempdir()
        files <- file.path(dir, c("a.png", "a.pdf"))
        file.create(files)

        fig <- pub_figure(files, caption = "Files")

        expect_identical(as.vector(fig), files)
        expect_identical(pub_meta(fig), list(type = "figure", caption = "Files"))
    })

    it("validates its input", {
        dir <- withr::local_tempdir()
        txt <- file.path(dir, "a.txt")
        file.create(txt)

        expect_error(pub_figure(1), "must be a ggplot, a recorded plot")
        expect_error(pub_figure(file.path(dir, "missing.png")), "not found")
        expect_error(pub_figure(txt), "Unsupported image files")
        expect_error(pub_figure(character(0)), "at least one image")
        expect_error(pub_figure(recorded_plot(), width = 0), "`width` must be")
        expect_error(pub_figure(recorded_plot(), out_width = 1), "percentage")
    })

    it("rejects NA paths and names the class of other inputs", {
        expect_error(pub_figure(NA_character_), "at least one image")
        expect_error(pub_figure(c("a.png", NA)), "at least one image")
        expect_error(pub_figure(list()), "not <list>.", fixed = TRUE)
        expect_error(pub_figure(NULL), "not <NULL>.", fixed = TRUE)
    })

    it("reports the errors of image files as errors of pub_figure()", {
        cnd <- rlang::catch_cnd(pub_figure("missing.png"), "error")

        expect_identical(rlang::call_name(cnd$call), "pub_figure")
    })

    it("accepts the supported extensions in any case", {
        dir <- withr::local_tempdir()
        files <- file.path(dir, c("a.PNG", "a.jpeg", "a.Svg", "a.JPG"))
        file.create(files)

        expect_identical(as.vector(pub_figure(files)), files)
    })

    it("lists unsupported files before missing ones", {
        expect_error(
            pub_figure(c("missing.png", "a.gif", "b")),
            "Unsupported image files .*: a.gif, b."
        )
    })
})


# ---------
# Rendering
# ---------

describe(".render_figure()", {
    it("rejects unknown devices", {
        file <- withr::local_tempfile(fileext = ".png")

        expect_error(.render_figure(recorded_plot(), file, "jpg"), "should be one of")
    })

    it("names the size of a figure that can't be drawn", {
        file <- withr::local_tempfile(fileext = ".png")

        err <- expect_error(
            .render_figure(recorded_plot(), file, "png", width = 1, height = 1),
            "Can't draw the figure at 1 x 1 inches"
        )
        expect_match(conditionMessage(err), "too small for its margins", fixed = TRUE)
        local_mocked_bindings(.draw_figure = \(x) stop("no data"))
        err <- expect_error(
            .render_figure(recorded_plot(), file, "png"),
            "Can't draw the figure at 8 x 6 inches"
        )
        expect_no_match(conditionMessage(err), "too small")
        expect_identical(conditionMessage(err$parent), "no data")
    })

    it("renders png files with ragg at the requested size", {
        file <- withr::local_tempfile(fileext = ".png")

        res <- .render_figure(
            recorded_plot(),
            file,
            "png",
            width = 4,
            height = 3,
            res = 100
        )

        expect_identical(res, file)
        expect_identical(png_size(file), c(400L, 300L))
    })

    it("takes the size from the metadata, else 8 x 6 inches", {
        dir <- withr::local_tempdir()
        fig <- pub_figure(recorded_plot(), width = 4, height = 3)

        .render_figure(fig, file.path(dir, "meta.png"), res = 25)
        .render_figure(recorded_plot(), file.path(dir, "default.png"), res = 10)

        expect_identical(png_size(file.path(dir, "meta.png")), c(100L, 75L))
        expect_identical(png_size(file.path(dir, "default.png")), c(80L, 60L))
    })

    it("renders svg files with svglite", {
        skip_if_not_installed("svglite")
        file <- withr::local_tempfile(fileext = ".svg")

        .render_figure(recorded_plot(), file, "svg", width = 4, height = 3)

        svg <- xml2::read_xml(file)
        expect_identical(xml2::xml_attr(svg, "width"), "288.00pt")
        expect_identical(xml2::xml_attr(svg, "height"), "216.00pt")
    })

    it("renders pdf files with cairo_pdf", {
        skip_if_not_installed("pdftools")
        skip_if_not(capabilities("cairo"))
        file <- withr::local_tempfile(fileext = ".pdf")

        .render_figure(recorded_plot(), file, "pdf", width = 4, height = 3)

        size <- pdftools::pdf_pagesize(file)
        expect_identical(c(size$width, size$height), c(288, 216))
    })

    it("renders ggplot objects to every device", {
        skip_if_not_installed("ggplot2")
        skip_if_not_installed("svglite")
        dir <- withr::local_tempdir()
        fig <- pub_figure(demo_ggplot(), width = 3, height = 2)

        for (device in c("png", "svg", "pdf")) {
            file <- file.path(dir, paste0("plot.", device))
            .render_figure(fig, file, device, res = 72)
            expect_gt(file.size(file), 1000)
        }
        expect_identical(png_size(file.path(dir, "plot.png")), c(216L, 144L))
    })

    it("closes the device when plotting fails", {
        file <- withr::local_tempfile(fileext = ".png")
        devices <- grDevices::dev.list()
        local_mocked_bindings(.draw_figure = \(x) stop("plot failed"))

        expect_error(.render_figure(recorded_plot(), file, "png"), "plot failed")
        expect_identical(grDevices::dev.list(), devices)
    })

    it("copies the image file matching the device, else a raster image", {
        dir <- withr::local_tempdir()
        src <- file.path(dir, c("fig.jpg", "fig.pdf"))
        writeLines("jpg", src[[1]])
        writeLines("pdf", src[[2]])
        fig <- pub_figure(src)
        out <- file.path(dir, "out")
        dir.create(out)

        png <- .render_figure(fig, file.path(out, "f.png"), "png")
        pdf <- .render_figure(fig, file.path(out, "f.pdf"), "pdf")
        svg <- .render_figure(fig, file.path(out, "g.svg"), "svg")

        expect_identical(png, file.path(out, "f.jpg"))
        expect_identical(readLines(png), "jpg")
        expect_identical(readLines(pdf), "pdf")
        expect_identical(readLines(svg), "jpg")
        expect_error(
            .render_figure(pub_figure(src[[2]]), file.path(out, "h.png"), "png"),
            "No png image",
            class = "pubflow_render_error"
        )
    })

    it("falls back to the other formats that the target shows", {
        src <- c("fig.pdf", "fig.svg")
        latex <- c("png", "pdf")

        # a raster image comes first, as the png device asks for
        expect_identical(.pick_image_file(c(src, "fig.jpg"), "png", latex), "fig.jpg")
        expect_identical(.pick_image_file(src, "png", latex), "fig.pdf")
        expect_identical(.pick_image_file(src, "png", c("png", "svg")), "fig.svg")
        expect_error(
            .pick_image_file("fig.pdf", "png", c("png", "svg")),
            "No png image",
            class = "pubflow_render_error"
        )
    })

    it("matches extensions in any case and takes the first of equal rank", {
        expect_identical(.pick_image_file(c("a.PDF", "b.Png"), "png"), "b.Png")
        expect_identical(.pick_image_file(c("a.jpg", "b.png"), "png"), "b.png")
        expect_identical(.pick_image_file(c("a.jpg", "b.jpeg"), "svg"), "a.jpg")
        expect_identical(.pick_image_file(c("a.svg", "b.svg"), "svg"), "a.svg")
        expect_error(
            .pick_image_file(c("a", "b.gif"), "pdf"),
            "No pdf image among the figure files: a, b.gif.",
            class = "pubflow_render_error"
        )
    })

    it("signals a render error if the image file can't be copied", {
        src <- withr::local_tempfile(fileext = ".png")
        writeLines("png", src)
        dest <- file.path(withr::local_tempdir(), "missing-dir", "f.png")

        expect_no_warning(
            err <- expect_error(
                .copy_image_file(src, dest, "png"),
                "Can't copy image file",
                class = "pubflow_render_error"
            )
        )
        expect_match(conditionMessage(err), "reason '", fixed = TRUE)
    })

    it("signals a render error for pdf figures if R has no cairo", {
        file <- withr::local_tempfile(fileext = ".pdf")
        devices <- grDevices::dev.list()
        openDevice <- .open_device
        mockery::stub(openDevice, "capabilities", \(...) FALSE)

        expect_error(
            openDevice("pdf", file, 4, 3, 72),
            "built without cairo",
            class = "pubflow_render_error"
        )
        expect_identical(grDevices::dev.list(), devices)
    })
})


# ----------------
# Rendered figures
# ----------------

describe("pub_figure(render = TRUE)", {
    render <- function(...) pub_figure(recorded_plot(), ..., render = TRUE)

    it("returns png bytes with the metadata", {
        fig <- render(caption = "Points", id = "pts")

        expect_s3_class(fig, "pub_png")
        expect_type(fig, "raw")
        expect_identical(as.vector(fig[1:4]), as.raw(c(0x89, 0x50, 0x4e, 0x47)))
        expect_identical(pub_type(fig), "figure")
        expect_identical(
            pub_meta(fig),
            list(caption = "Points", id = "pts", width = 8, height = 6)
        )
    })

    it("renders a ggplot", {
        skip_if_not_installed("ggplot2")
        fig <- pub_figure(demo_ggplot(), render = TRUE)

        expect_s3_class(fig, "pub_png")
        expect_identical(.png_pixels(fig), c(1600L, 1200L))
    })

    it("takes the size from the arguments, else from the metadata", {
        expect_identical(.png_pixels(render(width = 4, height = 3)), c(800L, 600L))
        plot <- pub_set_meta(recorded_plot(), width = 3, height = 2)

        fig <- pub_figure(plot, render = TRUE)

        expect_identical(.png_pixels(fig), c(600L, 400L))
        expect_identical(pub_meta(fig, c("width")), 3)
    })

    it("drops the stamp and removes its temporary file", {
        files <- list.files(tempdir(), "^pubflow-png-")
        plot <- pub_set_meta(recorded_plot(), stamp = list(step = "s"))

        fig <- pub_figure(plot, render = TRUE)

        expect_null(pub_meta(fig, "stamp"))
        expect_identical(list.files(tempdir(), "^pubflow-png-"), files)
    })

    it("rejects image files and invalid values", {
        file <- withr::local_tempfile(fileext = ".png")
        writeBin(as.raw(1:3), file)

        expect_error(pub_figure(file, render = TRUE), "needs a plot")
        expect_error(pub_figure(recorded_plot(), render = NA), "`render` must be")
        expect_error(pub_figure(recorded_plot(), TRUE, render = "yes"), "`render` must")
    })

    it("only sets metadata of a rendered figure", {
        fig <- render()

        again <- pub_figure(fig, caption = "New", render = TRUE)

        expect_identical(.png_bytes(again), .png_bytes(fig))
        expect_identical(pub_meta(again, "caption"), "New")
        expect_error(pub_figure(fig, width = 4), "size is fixed")
        expect_error(pub_figure(fig, height = 4), "size is fixed")
    })

    it("survives saveRDS() unchanged", {
        fig <- render(caption = "Points")
        file <- withr::local_tempfile(fileext = ".rds")

        saveRDS(fig, file)
        back <- readRDS(file)

        expect_identical(back, fig)
    })

    it("is not stamped by the output hook, also in lists", {
        fig <- render()
        ctx <- list(step = "s", key = NULL, time = Sys.time())

        expect_identical(pipeflow::pip_output_value(fig, ctx), fig)
        expect_identical(pipeflow::pip_output_value(list(a = fig, b = "x"), ctx)$a, fig)
        p <- pipeflow::pip_new("pip") |>
            pipeflow::pip_add("plot", \(n = 3) {
                pub_figure(recorded_plot(n), render = TRUE)
            })
        out <- run_quietly(p)[["plot", "out"]]
        expect_s3_class(out, "pub_png")
        expect_null(pub_meta(out, "stamp"))
    })
})

describe("print.pub_png()", {
    it("shows size, resolution, file size and caption", {
        fig <- pub_figure(
            recorded_plot(),
            caption = "Points",
            width = 4,
            height = 3,
            render = TRUE
        )

        expect_output(
            print(fig),
            "<pubflow figure> PNG 800 x 600 px (4 x 3 in, 200 dpi), ",
            fixed = TRUE
        )
        expect_output(print(fig), "KB\nCaption: Points")
        expect_invisible(withr::with_output_sink(nullfile(), print(fig)))
    })
})

describe("rendering a pub_png", {
    fig <- pub_figure(recorded_plot(), width = 4, height = 3, render = TRUE)

    it("writes the bytes as png whatever the device, without the cache", {
        cache <- pub_cache()
        for (device in c("png", "svg", "pdf")) {
            figure <- list(device = device, res = 200)

            res <- .figure_file(fig, pub_meta(fig), figure, cache)
            withr::defer(unlink(res$file))

            expect_true(res$temporary)
            expect_identical(tools::file_ext(res$file), "png")
            expect_identical(readBin(res$file, "raw", length(fig)), .png_bytes(fig))
        }
        expect_length(cache$entries, 0L)
    })

    it("reports a file that can't be written", {
        file <- file.path(withr::local_tempdir(), "no", "dir", "f.png")

        expect_error(.write_png(fig, file), class = "pubflow_render_error")
    })

    it("is shown as png in HTML", {
        html <- pub_html(pub_doc(fig))

        expect_match(html, "data:image/png;base64,", fixed = TRUE)
    })

    it("is written as png for any device of the report spec", {
        doc <- pub_doc(fig)
        for (case in list(c("md", "svg"), c("latex", "pdf"))) {
            dir <- withr::local_tempdir()
            spec <- pub_report_spec(
                .target_format(case[[1L]]),
                figure = list(device = case[[2L]])
            )

            md <- pub_markdown(
                doc,
                case[[1L]],
                file.path(dir, "doc_files"),
                spec = spec
            )

            expect_match(md, "doc_files/figure-1.png", fixed = TRUE)
            expect_true(file.exists(file.path(dir, "doc_files", "figure-1.png")))
        }
    })

    it("renders like a ggplot with landscape, locked, id and a reference", {
        skip_if_not_installed("ggplot2")
        gg <- pub_figure(demo_ggplot(), caption = "Plot", id = "pl", landscape = TRUE)
        pub <- pub_figure(gg, locked = TRUE, render = TRUE)
        mk <- \(f) {
            pub_markdown(
                pub_doc(f, pub_text("See @fig:pl.")),
                "docx",
                file.path(withr::local_tempdir(), "doc_files")
            )
        }

        pngMd <- mk(pub)
        ggMd <- mk(pub_set_meta(gg, locked = TRUE))

        expect_identical(
            gsub("figure-1\\.png|width=\"[^\"]*\"", "", pngMd),
            gsub("figure-1\\.png|width=\"[^\"]*\"", "", ggMd)
        )
        expect_match(pngMd, "locked-figure", fixed = TRUE)
    })

    it("is a valid widget fallback", {
        widget <- pub_set_meta(local_fake_widget(), fallback = fig, caption = "W")
        dir <- withr::local_tempdir()

        md <- pub_markdown(pub_doc(widget), "md", file.path(dir, "doc_files"))

        expect_match(md, "doc_files/figure-1.png", fixed = TRUE)
    })
})


# ======================================================================================
# Figure stamps
# ======================================================================================

# ------------
# Output hooks
# ------------

describe("figure stamps", {
    stamp_of <- function(x) pub_meta(x, "stamp")

    it("stamps the figures a step returns, also in plain lists", {
        p <- pipeflow::pip_new("pip") |>
            pipeflow::pip_add("plot", \(n = 5) recorded_plot(n)) |>
            pipeflow::pip_add("plots", \(m = 3) {
                list(
                    a = recorded_plot(m),
                    b = list(
                        gg = demo_trend_plot(
                            demo_data(),
                            "Time",
                            "y"
                        )
                    ),
                    c = "x"
                )
            })
        run_quietly(p)

        stamp <- stamp_of(p[["plot", "out"]])
        expect_named(stamp, c("step", "key", "time"))
        expect_identical(stamp$step, "plot")
        expect_null(stamp$key)
        expect_equal(stamp$time, p[["plot", "time"]], ignore_attr = "tzone")
        out <- p[["plots", "out"]]
        expect_identical(stamp_of(out$a)$step, "plots")
        expect_identical(stamp_of(out$b$gg)$step, "plots")
        expect_identical(out$c, "x")
    })

    it("keeps the stamp of a figure passed on by a later step", {
        p <- pipeflow::pip_new("pip") |>
            pipeflow::pip_add("plot", \(n = 5) recorded_plot(n)) |>
            pipeflow::pip_add("results", \(plot = ~plot) list(plot))
        run_quietly(p)

        expect_identical(
            stamp_of(p[["results", "out"]][[1L]]),
            stamp_of(p[["plot", "out"]])
        )
    })

    it("gives every run and partition a new stamp", {
        p <- pipeflow::pip_new("pip") |>
            pipeflow::pip_add("split", \(x = 1) list(a = 3, b = 4), exec = "split") |>
            pipeflow::pip_add("plot", \(n = ~split) recorded_plot(n))
        run_quietly(p)
        first <- lapply(p[["plot", "out"]], stamp_of)

        expect_identical(c(first$a$key, first$b$key), c("a", "b"))
        Sys.sleep(0.01)
        run_quietly(p, force = TRUE)
        again <- lapply(p[["plot", "out"]], stamp_of)
        expect_false(identical(again$a, first$a))
    })

    it("gives the figures of the inner pipelines of a nested one own stamps", {
        p <- demo_nested_report_pipeline()
        run_quietly(p)

        res <- p[["inner_run", "out"]]
        stamps <- lapply(res, \(r) stamp_of(r$content[[2L]]))

        expect_identical(unique(vapply(stamps, `[[`, "", "step")), "trend_plot")
        expect_identical(anyDuplicated(lapply(stamps, `[[`, "time")), 0L)
    })

    it("leaves other outputs alone", {
        out <- list(1, data.frame(a = 1), list(pub_text("x")))
        ctx <- list(step = "s", key = NULL, time = Sys.time())

        expect_identical(pipeflow::pip_output_value(out, ctx), out)
        sec <- pub_section("S", recorded_plot(3))
        expect_identical(pipeflow::pip_output_value(sec, ctx), sec)
        fig <- pipeflow::pip_output_value(recorded_plot(3), ctx)
        expect_identical(stamp_of(fig), ctx)
    })

    it("leaves empty lists alone and keeps the names and class of lists", {
        ctx <- list(step = "s", key = "a", time = Sys.time())
        plot <- recorded_plot(3)
        parts <- structure(
            list(a = plot, b = list(plot), c = list()),
            class = c("list", "pipeflow_partitioned")
        )

        expect_identical(pipeflow::pip_output_value(list(), ctx), list())
        expect_identical(.stamp_figures(list(), ctx), list())
        res <- .stamp_figures(parts, .figure_stamp(ctx))
        expect_s3_class(res, "pipeflow_partitioned")
        expect_named(res, c("a", "b", "c"))
        expect_identical(stamp_of(res$a), ctx)
        expect_identical(stamp_of(res$b[[1L]]), ctx)
        expect_identical(res$c, list())
    })

    it("finds figures only at the top level and in plain lists", {
        plot <- recorded_plot(3)

        expect_true(.has_figures(plot))
        expect_true(.has_figures(list(1, list(list(plot)))))
        expect_false(.has_figures(list()))
        expect_false(.has_figures(list(list(), "x")))
        expect_false(.has_figures(pub_section("S", plot)))
        expect_false(.has_figures(structure(list(plot), class = "foo")))
    })

    it("gives the figures a stamp without the missing ctx entries", {
        fig <- pipeflow::pip_output_value(recorded_plot(3), list(step = "s"))

        expect_identical(stamp_of(fig), list(step = "s", key = NULL, time = NULL))
    })
})
