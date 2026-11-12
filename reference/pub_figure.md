# Figure output

Marks a plot or image files as a figure and sets its caption, size and
other metadata.

## Usage

``` r
pub_figure(
  x,
  caption = NULL,
  width = NULL,
  height = NULL,
  out_width = NULL,
  ...,
  render = FALSE
)
```

## Arguments

- x:

  A ggplot, a recorded plot
  ([`grDevices::recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html))
  or the paths of existing image files of one figure (see Details). A
  rendered figure (`render = TRUE`) can be passed again to set its
  metadata.

- caption:

  `character(1)` caption (figures are numbered) or `NULL`.

- width, height:

  Size of the plot in inches (default 8 x 6).

- out_width:

  Width in the document relative to the text width, e.g. `"90%"`
  (default).

- ...:

  Further metadata, e.g. `title`, `id` (to refer to the figure as
  `@fig:<id>` in texts, see
  [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)),
  `landscape` or `locked` (see
  [`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)).

- render:

  `TRUE`: draw a ggplot or recorded plot now, as a png image (see
  Details, "Rendered figures"); must be named.

## Value

`x` with metadata; with `render = TRUE` the png image (class `pub_png`)
of the plot, with the same metadata.

## Details

### When do you need it?

Plots in a document
([`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
are figures even without `pub_figure()`; use it only to set a caption or
a size. Image files, however, always need it, as otherwise their paths
would be read as text:

|  |  |
|----|----|
| Input | `pub_figure()` |
| ggplot | optional |
| recorded base plot ([`grDevices::recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html)) | optional |
| image files (png, jpg, svg, pdf) | required |

### One figure in several formats

You can pass several image files of the same plot, e.g. a png and a pdf.
Each output format then picks the file that suits it best:

- HTML and DOCX show the png (or jpg), as they can't show pdf images;

- a PDF report made with LaTeX can use the vector graphic if you ask for
  it with `figure = list(device = "pdf")` (see
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md)
  and
  [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)).

Always provide at least a png or jpg.

### Rendered figures

With `render = TRUE` the plot is drawn where the step runs and the step
returns the png image (200 dpi, class `pub_png`) instead of the plot.
Use it:

- in steps that run in other R processes (workers) and for pipelines
  saved with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html): a
  ggplot holds environments, so a copy of it differs from the original,
  and the document renders it again even though nothing changed. The
  image has no environments and survives copying unchanged, so the
  document uses it as it is;

- for recorded plots, which can't be replayed in another R session.

Note that once rendered, a figure can't be changed in later steps, so
the rendering step should be the last that touches it. In addition, even
if a report spec has `figure = list(device = "pdf")` it still shows the
png.

A rendered figure takes `caption`, `id` etc. like any other; changing
them later (also with
[`pub_set_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md))
only affects the metadata, not the image. `width` and `height` are the
exception: they are the size the plot was rendered at, so `pub_figure()`
refuses them (use `out_width` to scale the figure in the document).
[`pub_set_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)
accepts them, but then they no longer match the pixels.

## See also

[`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md),
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)

## Examples

``` r
# A recorded base plot is a figure already; pub_figure() adds a caption and size
grDevices::pdf(NULL)
grDevices::dev.control("enable")
plot(1:10)
p <- grDevices::recordPlot()
grDevices::dev.off()
#> agg_record_1e057d10a43c 
#>                       2 
pub_type(p)
#> [1] "figure"

fig <- pub_figure(p, caption = "Ten points", width = 5, height = 4, id = "points")
pub_type(fig)
#> [1] "figure"
pub_meta(fig)
#> $caption
#> [1] "Ten points"
#> 
#> $width
#> [1] 5
#> 
#> $height
#> [1] 4
#> 
#> $id
#> [1] "points"
#> 

# The same holds for a ggplot
if (requireNamespace("ggplot2", quietly = TRUE)) {
    gg <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
        ggplot2::geom_point()
    print(pub_type(gg))
    pub_meta(pub_figure(gg, caption = "Weight and mileage"))
}
#> [1] "figure"
#> $caption
#> [1] "Weight and mileage"
#> 

# Image files must be marked, otherwise their paths are text
file <- tempfile(fileext = ".png")
ragg::agg_png(file)
plot(1:10)
grDevices::dev.off()
#> agg_record_1e057d10a43c 
#>                       2 
pub_type(file)
#> [1] "text"
pub_type(pub_figure(file, caption = "Ten points from a file"))
#> [1] "figure"

# One figure in several formats: a renderer picks the best file
files <- file.path(tempdir(), c("points.png", "points.pdf"))
ragg::agg_png(files[1])
plot(1:10)
grDevices::dev.off()
#> agg_record_1e057d10a43c 
#>                       2 
grDevices::pdf(files[2])
plot(1:10)
grDevices::dev.off()
#> agg_record_1e057d10a43c 
#>                       2 
fig <- pub_figure(files, caption = "Ten points as png and pdf")
html <- pub_html(pub_doc(fig))  # HTML picks the png
grepl("data:image/png", html)
#> [1] TRUE

# Render the figure in the step: the result is a png image with the metadata
png <- pub_figure(p, caption = "Ten points", width = 4, height = 3, render = TRUE)
png
#> <pubflow figure> PNG 800 x 600 px (4 x 3 in, 200 dpi), 18 KB
#> Caption: Ten points
pub_type(png)
#> [1] "figure"
identical(png, unserialize(serialize(png, NULL)))
#> [1] TRUE
```
