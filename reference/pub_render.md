# Render a document to a file

Writes a document (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) as
a report file and returns its path. The *report spec* (see
[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md))
sets the details, such as the templates, front matter, table of
contents, page, figure settings and post-processors.

## Usage

``` r
pub_render(
  doc,
  format = c("html", "docx", "pdf", "md"),
  file = NULL,
  spec = pub_report_spec(format),
  meta = list(),
  cache = NULL,
  pdf_engine = c("xelatex", "typst"),
  quiet = TRUE
)
```

## Arguments

- doc:

  A `pub_doc`.

- format:

  Output format: `"html"`, `"docx"`, `"pdf"` or `"md"`.

- file:

  Path of the output file; default (`NULL`):
  [`pub_output_filename()`](https://rpahl.github.io/pubflow/reference/pub_output_filename.md)
  in the session's temporary directory.

- spec:

  A
  [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  for `format`. The default, `pub_report_spec(format)`, gives what is
  described in Details.

- meta:

  Named list of render-time metadata (see Details and
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
  e.g. `list(author = session$user, app = "myapp", version = "1.2.0")`.

- cache:

  A
  [`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md)
  or `NULL` (render every figure). Figures are cached as in
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md).

- pdf_engine:

  Engine of PDF files: `"xelatex"` or `"typst"`.

- quiet:

  `FALSE`: pandoc's warnings (e.g. about missing fonts or images) become
  R warnings.

## Value

The path of the written file, invisibly.

## Details

### Formats

|          |                   |                             |
|----------|-------------------|-----------------------------|
| `format` | Result            | Needs                       |
| `"html"` | a standalone page | nothing                     |
| `"docx"` | a Word document   | pandoc (\>= 3.6)            |
| `"pdf"`  | a PDF             | pandoc and xelatex or Typst |
| `"md"`   | a Markdown file   | nothing                     |

**HTML**

- The page is self-contained: stylesheet, images and the scripts and
  stylesheets of widgets are inlined.

- Math (MathJax) is loaded from a CDN, so it needs an internet
  connection.

- Files that widgets load by relative URLs (fonts, images or data
  referenced in their stylesheets, attachments) are not included, so
  such widgets may miss them.

**DOCX** (via
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
and pandoc)

- A4 with numbered headings, tables as native Word tables, math as Word
  equations, figures as PNG images (200 dpi) and landscape sections for
  items that need them.

- Tables of contents and caption numbers are Word fields: Word updates
  them when you agree to it as the file is opened.

- With `lock = TRUE` in the spec, the header, the footer and the tables
  and figures are locked against accidental editing and deletion (single
  tables and figures opt out with `pub_set_meta(locked = FALSE)`). By
  default (`lock = NULL`), only tables and figures with
  `pub_set_meta(locked = TRUE)` are locked; `lock = FALSE` locks
  nothing. See
  [`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
  and
  [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md),
  which run automatically before the spec's own post-processors unless
  the spec lists them.

**PDF** (via
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
and pandoc) with the `pdf_engine`:

- `"xelatex"` (default): needs a TeX distribution such as TinyTeX with
  the LaTeX packages that huxtable needs (see
  [`huxtable::install_latex_dependencies()`](https://hughjonesd.github.io/huxtable/reference/report_latex_dependencies.html))
  plus pdflscape, fancyhdr, lastpage, float and newunicodechar.

- `"typst"`: needs Typst (see "Finding Typst" below).

With either engine, the PDF has A4 pages, figures as PNG images (200
dpi; the spec's `figure` argument allows vector images) and tables that
break across pages and repeat their header rows. Table cells, table
captions, headers and footers show as typed, while other text gets the
typography of LaTeX or Typst (e.g. in LaTeX `"` becomes a curly quote).

**Markdown**

A Markdown file (see
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md))
that needs no pandoc. Its figures go to the directory `<name>_files`
next to it (files of the same name there are overwritten).

### Header and footer lines

DOCX and PDF files show the `header` and `footer` lines of the document
(see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)):

- `{trace}` in a line is replaced by a line that says who rendered the
  report and when, e.g. "Jane Doe at 07-Oct-2026 12:00:00 UTC (myapp
  v1.2.0)" (see
  [`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)).

- The footer gets "Page x / N" at the right unless the `footer` has a
  `right` part.

### Title block and table of contents

The title block appears only if the document has a title, subtitle or
author. A table of contents follows it if the document has sections,
unless the document places one itself.

### Render-time metadata

`meta` holds information about the act of rendering, e.g. the author of
the current session, the application and its version:

- It is merged over the document's own metadata: its entries win and
  `NULL` removes an entry.

- `time` is the render time unless one of them has a time.

- File name, title block, `{trace}`, front matter and post-processors
  all see the merged result.

Passing this here instead of to the pipeline keeps the layout step from
becoming outdated with every render.

### Error items

With `on_error = "continue"`, a failed step doesn't stop the pipeline. A
layout step then receives the failure and may place it in the document
as an *error item* (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)). By
default, `pub_render()` refuses such a document, so that a report never
contains errors. For a final report, therefore, run the pipeline with
the default `on_error = "stop"`.

For drafts, you can instead run the pipeline with
`on_error = "continue"` and set `pub_report_spec(error_items = "show")`.
The document is then rendered, with the error items shown as error boxes
and a warning.

### Good to know

- Rendering needs neither the pipeline nor a Shiny session.

- Every call works in a fresh temporary directory. The file is only
  written if everything (including post-processors) succeeded.

### Finding Typst

Typst is taken from the environment variable `PUBFLOW_TYPST` (the typst
executable or its directory), else from the PATH, else from Quarto's
installation (found by `QUARTO_PATH` or on the PATH).

## See also

[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md),
[`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md),
[`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md),
[`pub_output_filename()`](https://rpahl.github.io/pubflow/reference/pub_output_filename.md)

## Examples

``` r
doc <- pub_doc(
    pub_section("Results", pub_text("Ozone is highest in July and August.")),
    title = "Demo report"
)
noon <- as.POSIXct("2026-10-05 12:00:00", tz = "UTC")
path <- pub_render(doc, file = tempfile(fileext = ".html"),
                   meta = list(author = "Jane Doe", time = noon))
file.exists(path)
#> [1] TRUE
basename(pub_output_filename(list(title = "Demo report", time = noon),
                             "html"))
#> [1] "20261005T120000Z_demo_report.html"
```
