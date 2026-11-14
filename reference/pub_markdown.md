# Render a document to Pandoc Markdown

Writes a document (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) as
Markdown for pandoc, and its figures as image files.
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
uses it for DOCX, PDF and Markdown files. It can also be used to see or
post-process the Markdown that pandoc gets.

## Usage

``` r
pub_markdown(
  doc,
  target = c("docx", "latex", "typst", "md"),
  assets_dir,
  cache = NULL,
  spec = NULL
)
```

## Arguments

- doc:

  A `pub_doc`.

- target:

  `"docx"`, `"latex"`, `"typst"` or `"md"`.

- assets_dir:

  Directory for the figure files (created if needed). The Markdown
  refers to them as `<basename(assets_dir)>/figure-<n>.<ext>`, so the
  Markdown file belongs in the parent of `assets_dir`.

- cache:

  A
  [`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md)
  or `NULL` (render every figure). Figures are cached as in
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md).

- spec:

  A
  [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  of the target's format (`"pdf"` for LaTeX and Typst), or `NULL` (the
  default spec of the format).

## Value

`character(1)` Markdown.

## Details

### Targets

- `"docx"`: Markdown for pandoc's Word writer. Tables become native Word
  tables, and caption numbers and the table of contents Word fields.
  Landscape parts get their own sections and, if the spec locks, tables
  and figures are locked.

- `"latex"`, `"typst"`: Markdown for a PDF via xelatex or Typst. Tables
  are written as LaTeX or Typst code that breaks across pages and
  repeats the header rows. Figures are PNG images unless the spec's
  `figure` asks for `"pdf"` (LaTeX) or `"svg"` (Typst).

- `"md"`: a plain Markdown document with a YAML front matter that holds
  the header, numbered headings, tables as Pandoc multiline tables and
  images. Page breaks, landscape parts and tables of contents are left
  out.

The document header (title, subtitle, author, time) of DOCX is not part
of the Markdown.
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
passes it to pandoc as metadata.

### Texts, widgets and errors

- Texts are CommonMark (see
  [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)).
  Raw HTML and pandoc's own syntax in them show as text, as in HTML.

- Widgets are replaced by their `fallback` figure (see
  [`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md))
  or skipped with a warning.

- Error items (failed steps) are written as marked paragraphs.
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  refuses them unless the spec shows them.

- Cross-references in texts (see
  [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md))
  become Word cross-reference fields, LaTeX or Typst references or, for
  `"md"`, the label and number.

### Math in PDFs

LaTeX runs TeX commands, so for the `"latex"` target pandoc's math
parser checks every formula first. A formula it can't read, or one that
defines macros, is an error.

### Report spec

The report spec (see
[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md))
adds the front matter, table of contents, section numbers, caption
labels, figure devices and page.
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
calls `pub_markdown()` with its spec. The document's metadata is used
as-is (no render-time metadata), so the Markdown of a document is always
the same.

## See also

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)

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
cat(pub_markdown(doc, "md", assets_dir = tempfile()))
#> ---
#> title: "Demo"
#> ---
#> 
#> # 1 Results
#> 
#> Mean ozone peaks in **August** ($x_8 = 60$ ppb).
#> 
#> Table 1: Mean ozone
#> 
#> -----------------------
#>   **Month**  **Ozone** 
#> ----------- -----------
#>           5       23.6 
#>                        
#>           6       29.4 
#>                        
#>           7       59.1 
#>                        
#>           8       60.0 
#>                        
#>           9       31.4 
#> -----------------------
```
