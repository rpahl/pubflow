# Render a document to HTML

Renders a document (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) to
an HTML fragment, which can be used in Shiny UIs directly.
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
writes a standalone HTML file instead.

## Usage

``` r
pub_html(
  doc,
  cache = NULL,
  toc = TRUE,
  math = c("mathjax", "none"),
  figure = list(device = "png", res = 200)
)
```

## Arguments

- doc:

  A `pub_doc`.

- cache:

  A
  [`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md)
  or `NULL` (render every figure and table).

- toc:

  `TRUE`: add a table of contents (headings up to level 3).

- math:

  `"mathjax"`: attach MathJax if the document has math; `"none"`: math
  stays as `\(...\)` and `\[...\]`.

- figure:

  Device settings of figures: `device` (`"png"` or `"svg"`) and `res`
  (resolution of PNG images in dpi; 200 as in the viewer and every
  format of
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
  so they share the cached figures).

## Value

HTML (an
[`htmltools::HTML()`](https://rstudio.github.io/htmltools/reference/HTML.html)
string with dependencies).

## Details

### Contents

The result has:

- a header with the title, subtitle and metadata;

- an optional table of contents;

- one `<section>` per section, with numbered headings.

Tables are rendered with huxtable (see
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)),
figures as inline PNG (or SVG) images, text as Markdown (CommonMark),
math with MathJax and error items (failed steps, see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) as
error boxes. Raw HTML in texts is shown as text; use
[`pub_raw()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
to insert HTML.

### Dependencies

The result carries its CSS (`pubflow-doc.css`) and, if the document has
math, MathJax 3 (from a CDN) as HTML dependencies.

### Caching

Rendering a figure takes about 0.1 s and the HTML of a table several
milliseconds. With a `cache`, both are rendered once and reused while
they are unchanged:

- Use one cache per Shiny session (or R process) and pass it to the
  viewer and to every render call. They then share the figures (with the
  same device settings, a figure is rendered once).

- Only figures made by pipeline steps are cached. pubflow stamps each
  figure that a step returns (also in plain lists) with the step, its
  partition key and the time of the run. So whenever the step runs again
  (e.g. because a step parameter changed), its figures are re-rendered.

- Figures without a stamp are rendered every time. These can be figures
  made outside a pipeline or inside the step that builds the document
  (the layout step). To have a figure cached, create it in a pipeline
  step of its own and pass it to the layout step as an input (e.g.
  `plot = ~plot_step`).

- Figures rendered in their step (`pub_figure(render = TRUE)`) are not
  cached: the document uses their png as it is.

### Cross-references

Cross-references in texts (see
[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md))
link to their figure or table. A reference that can't be resolved is
marked in the HTML and gives a `pubflow_render_warning`, so a draft
still displays. On the other hand,
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
never allows undefined references and stops with an error instead.

## See also

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md),
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)

## Examples

``` r
doc <- pub_doc(
    pub_section(
        "Results",
        pub_text("Mean ozone peaks in **August** ($x_8 = 60$ ppb)."),
        pub_table(aggregate(Ozone ~ Month, data = airquality, FUN = mean),
                  caption = "Mean ozone", digits = c(Ozone = 1L))
    ),
    title = "Demo"
)
html <- pub_html(doc)
cat(substr(html, 1, 300))
#> <div class="pubflow-doc">
#> <header class="pubflow-doc-header">
#> <h1 class="pubflow-title">Demo</h1>
#> </header>
#> <nav class="pubflow-toc">
#> <ul>
#> <li><a href="#pubflow-sec-1"><span class="pubflow-section-number">1</span> Results</a>
#> </li>
#> </ul>
#> </nav>
#> <section class="pubflow-section pubflow-level-1" id="pu
```
