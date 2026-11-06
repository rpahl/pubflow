# Page break, table of contents and raw content

Outputs for the structure of a document: page breaks, tables of contents
and raw content.

## Usage

``` r
pub_pagebreak()

pub_toc(depth = 3L, what = c("sections", "figures", "tables"))

pub_raw(html = NULL, docx = NULL, latex = NULL, typst = NULL, md = NULL)
```

## Arguments

- depth:

  `integer(1)` deepest heading level listed (1-6); only for
  `what = "sections"`.

- what:

  `"sections"` (table of contents), `"figures"` or `"tables"`.

- html, docx, latex, typst, md:

  Raw content for the format (character; several strings are joined by
  line breaks), or `NULL` for none. `docx` takes OpenXML.

## Value

- `pub_pagebreak()`: an object of class `pub_pagebreak`.

- `pub_toc()`: an object of class `pub_toc`.

- `pub_raw()`: an object of class `pub_raw`.

## Details

### Functions

- `pub_pagebreak()` starts a new page;

- `pub_toc()` adds a table of contents, or a list of figures or tables;

- `pub_raw()` inserts your own code for one or more output formats.

|  |  |  |  |
|----|----|----|----|
| Output | HTML | Markdown | DOCX, PDF |
| `pub_pagebreak()` | ignored | ignored | page break |
| `pub_toc()` (sections) | table of contents | ignored | table of contents |
| `pub_toc(what = "figures")`, `"tables"` | ignored | ignored | list |
| `pub_raw()` | `html` | `md` | `docx`, `latex`, `typst` |

A format without raw content shows nothing for that output.

In DOCX, Word fills in tables of contents and lists when it updates
fields. The lists of figures and tables come without a title there, like
the table of contents, while in PDF they are titled "List of Figures"
and "List of Tables".

## See also

[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md),
[`pub_session_info()`](https://rpahl.github.io/pubflow/reference/pub_session_info.md)

## Examples

``` r
pub_type(pub_pagebreak())
#> [1] "pagebreak"
pub_toc(depth = 2)
#> <pubflow table of contents, depth 2>
pub_toc(what = "figures")
#> <pubflow list of figures>
pub_raw(html = "<hr>", latex = "\\hrule", md = "---")
#> <pubflow raw content for html, latex, md>
```
