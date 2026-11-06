# Trace stamp of a report

Makes a line that says who made a report, when and with which
application, e.g.
`"Jane Doe at 07-Oct-2026 12:00:00 UTC (myapp v1.2.0)"`.

## Usage

``` r
pub_trace_stamp(meta)
```

## Arguments

- meta:

  Document metadata (`doc$meta`, see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
  or a document. It must have an `author`, which pubflow doesn't guess
  (on a server the system user is the service account).

## Value

`character(1)` trace stamp.

## Details

### Parts

The stamp consists of

- the author;

- the time of the document (`time` in its metadata, else now) in UTC,
  with English month names whatever the locale;

- the application and its version in parentheses. Without `app`, the
  parentheses are left out, without `version`, the version.

The token `{trace}` in the `header` and `footer` lines of a document
(see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
becomes the trace stamp when the document is rendered to DOCX or PDF.
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
adds its `meta` (e.g. the author of the current session) first.

## See also

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)

## Examples

``` r
meta <- list(author = "Jane Doe", app = "myapp", version = "1.2.0",
             time = as.POSIXct("2026-10-07 12:00:00", tz = "UTC"))
pub_trace_stamp(meta)
#> [1] "Jane Doe at 07-Oct-2026 12:00:00 UTC (myapp v1.2.0)"
pub_trace_stamp(meta[c("author", "time")])
#> [1] "Jane Doe at 07-Oct-2026 12:00:00 UTC"

# In a footer line
doc <- pub_doc(meta = list(footer = c(left = "{trace}")))
```
