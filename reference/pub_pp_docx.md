# DOCX post-processors

Post-processors of DOCX reports (see `post_process` in
[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md))
that write the header and footer lines and lock them.

## Usage

``` r
pub_pp_docx_header_footer(header = NULL, footer = NULL)

pub_pp_docx_lock()
```

## Arguments

- header, footer:

  Named character vector of lines like the document's metadata `header`
  and `footer` (names `left`, `center`, `right`), or `NULL` (use the
  document's lines). A vector replaces the document's lines as a whole;
  [`character()`](https://rdrr.io/r/base/character.html) writes none.

## Value

A post-processor: `function(path, doc, spec)` that changes the DOCX file
`path` in place (`doc` is the document with the render-time metadata).

## Details

### Functions

- `pub_pp_docx_header_footer()` writes the header and footer lines of
  the document into the header and footer of the file, as the PDF report
  shows them.

- `pub_pp_docx_lock()` locks the headers and footers against accidental
  editing and deletion.

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
applies both to every DOCX report (the lock if the spec's `lock` is
`TRUE`), before the spec's own post-processors. To give one of them
other arguments or another place among the others, list it in the spec's
`post_process`. It is then not added again (see Examples).

### Header and footer lines

The lines are the entries `header` and `footer` of the document's
metadata (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
each with the parts `left`, `center` and `right`. A part goes into the
bookmark of the same name in the file: `header_left`, `header_center`,
`header_right`, `footer_left`, `footer_center` or `footer_right`.

- `{trace}` becomes the trace stamp (see
  [`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md))
  and line breaks become spaces.

- The text takes the format of the first run in the bookmark that has
  one.

- It goes into every header and footer of the file that has the
  bookmark. Settings of the reference document (e.g. different first or
  even pages) are kept.

- A part that isn't empty is an error if no header or footer has its
  bookmark.

- In pubflow's reference document, `footer_right` holds "Page x / N". So
  a right footer line replaces the page number, as in PDF (an empty one
  removes it).

### Locks

`pub_pp_docx_lock()` locks everything in every header and footer, also
the content of the reference document such as "Page x / N". Tables and
figures are locked by
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
itself: with the spec's `lock = TRUE` all but those with
`pub_set_meta(locked = FALSE)`, otherwise those with
`pub_set_meta(locked = TRUE)`. Applying the post-processor twice changes
nothing.

The locks only guard against accidental changes: Word lets users remove
them in the properties of a content control.

## See also

[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md),
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)

## Examples

``` r
doc <- pub_doc(meta = list(
    author = "Jane Doe",
    time = as.POSIXct("2026-10-08 12:00:00", tz = "UTC"),
    footer = c(left = "{trace}")
))
# A DOCX file with the bookmarks: a copy of pubflow's reference document
path <- tempfile(fileext = ".docx")
file.copy(system.file("templates", "reference.docx", package = "pubflow"),
          path)
#> [1] TRUE
fill <- pub_pp_docx_header_footer(header = c(left = "Draft",
                                             right = "Batch A"))
fill(path, doc, pub_report_spec("docx"))

# In a spec: another header in DOCX reports, the lock after the spec's
# own post-processor
log_file <- function(path, doc, spec) message("Rendered ", path)
spec <- pub_report_spec("docx", post_process = list(
    pub_pp_docx_header_footer(header = c(left = "Draft")),
    log_file,
    pub_pp_docx_lock()
))
spec
#> <pubflow report spec: docx>
#>   reference_docx    default
#>   front_matter      title block
#>   toc               depth 3
#>   number_sections   yes
#>   page              reference document
#>   figure            default
#>   labels            Table, Figure
#>   lock              marked items
#>   error_items       refuse
#>   post_process      3 function(s)
#>   pandoc_args       none
```
