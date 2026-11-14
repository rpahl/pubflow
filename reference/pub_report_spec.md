# Report specs and pages

A report spec describes how a document becomes a report in one format:
templates, front matter, table of contents, page, figures, caption
labels and more.

## Usage

``` r
pub_report_spec(
  format = c("html", "docx", "pdf", "md"),
  reference_docx = NULL,
  latex_preamble = NULL,
  typst_template = NULL,
  front_matter = NULL,
  toc = TRUE,
  toc_depth = 3L,
  number_sections = TRUE,
  labels = list(table = "Table", figure = "Figure"),
  page = NULL,
  figure = NULL,
  placeholder_color = NULL,
  lock = NULL,
  error_items = c("refuse", "show"),
  post_process = list(),
  pandoc_args = character()
)

pub_page(
  size = c("a4", "letter"),
  orientation = c("portrait", "landscape"),
  margins = NULL
)
```

## Arguments

- format:

  Output format: `"html"`, `"docx"`, `"pdf"` or `"md"`.

- reference_docx:

  Path of the reference document of DOCX reports, or `NULL` (pubflow's).

- latex_preamble:

  Path of a LaTeX file included in the preamble of PDF reports made with
  xelatex, or `NULL`.

- typst_template:

  Path of the pandoc template of PDF reports made with Typst, or `NULL`
  (pubflow's).

- front_matter:

  `function(doc, format)` returning the front matter, or `NULL` (the
  title block: title, subtitle, author and time; shown only with a
  title, subtitle or author).

- toc:

  `TRUE`: add a table of contents (see Details).

- toc_depth:

  `integer(1)` deepest heading level in it (1-6).

- number_sections:

  `TRUE`: number the sections.

- labels:

  Named list of the caption words `table` and `figure`.

- page:

  A `pub_page()` or `NULL`.

- figure:

  Device settings of figures (see Details) or `NULL`.

- placeholder_color:

  Colour of placeholders (`"#rrggbb"`) or `NULL`.

- lock:

  `TRUE`, `FALSE` or `NULL` (see Details).

- error_items:

  `"refuse"` or `"show"`.

- post_process:

  List of post-processors (see Details).

- pandoc_args:

  `character` extra arguments of pandoc.

- size:

  Paper size: `"a4"` or `"letter"`.

- orientation:

  `"portrait"` or `"landscape"`.

- margins:

  Named numeric margins in cm (`top`, `bottom`, `left`, `right`; missing
  ones are 2.5, at the bottom 2), or `NULL`.

## Value

A `pub_report_spec` or `pub_page` object.

## Details

### Functions

- `pub_report_spec()` creates a spec. Pass it as `spec` to
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  or
  [`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md).

- `pub_page()` describes the page (size, orientation, margins) of DOCX
  and PDF reports.

All arguments except `format` and `error_items` are optional: `NULL`
means the default (for `figure` and `labels`, an empty list does too).

### Which argument acts where

Every argument acts in every format that can show it. Setting an
argument that the format can't use is an error, e.g. `placeholder_color`
for DOCX, where the reference document's "Placeholder" style sets the
colour.

|  |  |  |  |  |
|----|----|----|----|----|
| Argument | html | docx | pdf (LaTeX / Typst) | md |
| `reference_docx` | \- | template | \- | \- |
| `latex_preamble`, `typst_template` | \- | \- | templates | \- |
| `front_matter` replaces | header | title block | title block | YAML |
| `toc`, `toc_depth` | navigation | TOC field | contents | ignored |
| `number_sections` | numbers | heading styles | numbers | numbers |
| `labels` | captions | captions | captions | captions |
| `page` | \- | every section | page | \- |
| `figure` devices | png, svg | png | png, pdf / png, svg | png, svg |
| `placeholder_color` | CSS colour | \- | text colour | \- |
| `lock` | \- | tables, figures, header, footer | \- | \- |
| `pandoc_args` | \- | added | added | \- |

### Variants of a spec

To make variants (e.g. one per report and format, sharing the front
matter), call `pub_report_spec()` again, e.g. from a helper function of
your app. A value that you edit afterwards (`spec$toc <- FALSE`) is
checked only when the spec is used.

### The arguments in detail

- `front_matter`: a `function(doc, format)` that returns the front
  matter, e.g. a title page with a signature table. It replaces the
  title block (in HTML the header) in every format; the title and author
  stay in the file's properties.

  - It returns what a document can hold: sections, outputs or lists of
    them (see
    [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)).

  - `doc` is the document with the render-time metadata (see
    [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md))
    and `format` the output format.

  - Its sections are unnumbered (the numbers of the body start at 1),
    while its tables and figures count in the caption numbers.

  - End it with
    [`pub_pagebreak()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
    to start the table of contents on a new page.

- `toc`: `TRUE` adds a table of contents of the headings up to level
  `toc_depth` after the front matter (or title block).

  - It is left out if the document has no sections, or if the document
    or the front matter places a
    [`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
    itself.

  - Word fills it in when its fields are updated.

  - For lists of figures and tables, place `pub_toc(what = "figures")`
    or `pub_toc(what = "tables")`, e.g. in the front matter.

- `number_sections`: `FALSE` leaves every heading unnumbered (in Word
  the "Heading n Unnumbered" styles).

- `labels`: the words before the caption numbers, `list(table, figure)`.

- `page`: a `pub_page()`.

  - By default, DOCX keeps the page of the reference document and PDF is
    A4 portrait with margins of 2.5 cm (2 cm at the bottom).

  - An explicit page applies to every section of a DOCX file.

  - A landscape page turns the whole document, so landscape sections and
    items in it stay on the same pages.

- `figure`: `list(device, res)`, the image format and the resolution of
  PNG images in dpi. It is merged over the default: PNG with 200 dpi, as
  in the viewer, so a report after viewing reuses the cached figures and
  shows them as the viewer did. `"svg"` (HTML, Markdown and PDF via
  Typst) and `"pdf"` (PDF via LaTeX) give vector images.

- `placeholder_color`: colour of `[text]{.placeholder}` spans, e.g.
  `"#0083c0"` (the default of PDF; HTML uses `#0077b0` for better
  contrast).

- `lock`: DOCX only. `TRUE` locks the header, the footer and every table
  and figure that isn't `pub_set_meta(locked = FALSE)` against
  accidental editing and deletion (see
  [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)).
  `NULL` (default) locks only the tables and figures with
  `pub_set_meta(locked = TRUE)`, and the header and footer if
  `post_process` lists
  [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md).
  `FALSE` locks nothing, and `post_process` can't list
  [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md).

- `error_items`: what
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  does with error items (failed steps placed by a layout step run with
  `on_error = "continue"`, see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)):

  - `"refuse"` (default) signals a `pubflow_render_error`;

  - `"show"` writes their error boxes and warns
    (`pubflow_render_warning`), naming the failed steps.

- `post_process`: a list of functions `function(path, doc, spec)` that
  change the rendered file before it is copied to its destination.

  - They are called in order. `path` is the file, `doc` the document
    with the render-time metadata and `spec` this spec.

  - They change the file in place; their value is ignored. A failing one
    is a `pubflow_render_error` and no file is written.

  - DOCX reports first get
    [`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
    and (with `lock`)
    [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md).
    List one of them to give it arguments or another place.

  - [`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
    and
    [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
    can't be used for other formats.

- `pandoc_args`: pandoc options added after pubflow's (so they override
  them), one argument per element.

### Custom templates

Start from pubflow's template and keep what pubflow writes into it:

- `reference_docx` (start from
  `system.file("templates", "reference.docx", package = "pubflow")`):

  - paragraph styles "Heading 1"-"Heading 5", "Heading 1
    Unnumbered"-"Heading 5 Unnumbered", "Item Title", "Table Caption",
    "Image Caption", "Figure" and "Error", and the character style
    "Placeholder" (missing styles are added unformatted);

  - for header and footer lines, the bookmarks `header_left`,
    `header_center`, `header_right`, `footer_left`, `footer_center` and
    `footer_right` in its header and footer (only those of the lines you
    use, see
    [`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)).

- `latex_preamble`: a file included after pubflow's header (which loads
  the packages for tables, landscape pages, header and footer, and the
  frame of error items) and before the document's header and footer
  lines.

- `typst_template` (start from
  `system.file("templates", "pubflow.typ", package = "pubflow")`): a
  pandoc template that

  - writes `$header-includes$` (page orientation and caption labels);

  - shows the title block only if `$title-block$` is set;

  - takes the header and footer lines from `$header-left$` to
    `$footer-right$` (an empty part also sets `$footer-right-empty$`
    etc.).

## See also

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md),
[`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)

## Examples

``` r
# A spec for one format; printing it shows what it uses
spec <- pub_report_spec(
    "pdf",
    page = pub_page("letter", margins = c(left = 3)),
    labels = list(table = "Tab.", figure = "Fig."),
    front_matter = function(doc, format) {
        list(pub_text(paste("Prepared by", doc$meta$author)),
             pub_pagebreak())
    }
)
spec
#> <pubflow report spec: pdf>
#>   latex_preamble    none
#>   typst_template    default
#>   front_matter      function
#>   toc               depth 3
#>   number_sections   yes
#>   page              Letter portrait, margins top 2.5, bottom 2, left 3, right 2.5 cm
#>   figure            default
#>   labels            Tab., Fig.
#>   placeholder_color default
#>   error_items       refuse
#>   post_process      none
#>   pandoc_args       none
pub_report_spec("docx", toc = FALSE, error_items = "show")
#> <pubflow report spec: docx>
#>   reference_docx    default
#>   front_matter      title block
#>   toc               no
#>   number_sections   yes
#>   page              reference document
#>   figure            default
#>   labels            Table, Figure
#>   lock              marked items
#>   error_items       show
#>   post_process      none
#>   pandoc_args       none

# Landscape page and vector figures
pub_report_spec("pdf", page = pub_page("a4", "landscape"),
                figure = list(device = "pdf"))
#> <pubflow report spec: pdf>
#>   latex_preamble    none
#>   typst_template    default
#>   front_matter      title block
#>   toc               depth 3
#>   number_sections   yes
#>   page              A4 landscape, margins top 2.5, bottom 2, left 2.5, right 2.5 cm
#>   figure            device = pdf
#>   labels            Table, Figure
#>   placeholder_color default
#>   error_items       refuse
#>   post_process      none
#>   pandoc_args       none

# Use a spec to render (HTML needs nothing but pubflow)
doc <- pub_doc(
    pub_section("Results", pub_text("Ozone is highest in July and August.")),
    meta = list(title = "Demo report", author = "Jane Doe")
)
html <- pub_report_spec("html", toc = FALSE, number_sections = FALSE)
path <- pub_render(doc, "html", file = tempfile(fileext = ".html"), spec = html)

# A post-processor changes the finished file, here by appending a comment
add_note <- function(path, doc, spec) {
    writeLines(c(readLines(path), "<!-- checked -->"), path)
}
html <- pub_report_spec("html", post_process = add_note)
path <- pub_render(doc, "html", file = tempfile(fileext = ".html"), spec = html)
tail(readLines(path), 1)
#> [1] "<!-- checked -->"

# Variants: one spec per format that share the front matter and the labels
title_page <- function(doc, format) {
    list(pub_text(paste("Prepared by", doc$meta$author)), pub_pagebreak())
}
my_report_spec <- function(format) {
    pub_report_spec(
        format,
        front_matter = title_page,
        labels = list(table = "Tab.", figure = "Fig.")
    )
}
my_report_spec("docx")
#> <pubflow report spec: docx>
#>   reference_docx    default
#>   front_matter      function
#>   toc               depth 3
#>   number_sections   yes
#>   page              reference document
#>   figure            default
#>   labels            Tab., Fig.
#>   lock              marked items
#>   error_items       refuse
#>   post_process      none
#>   pandoc_args       none
my_report_spec("md")
#> <pubflow report spec: md>
#>   front_matter      function
#>   toc               no
#>   number_sections   yes
#>   figure            default
#>   labels            Tab., Fig.
#>   error_items       refuse
#>   post_process      none

# An argument that the format can't use is refused
try(pub_report_spec("docx", placeholder_color = "#0083c0"))
#> Error in pub_report_spec("docx", placeholder_color = "#0083c0") : 
#>   `placeholder_color` can't be used for docx reports, only for html and pdf.
```
