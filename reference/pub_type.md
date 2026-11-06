# Type of an output

Returns how pubflow treats an output, e.g. `"table"` for a data.frame. A
document
([`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
shows each output according to its type.

## Usage

``` r
pub_type(x)
```

## Arguments

- x:

  A step output.

## Value

`character(1)`, one of the types in Details.

## Details

Call `pub_type()` to check what pubflow makes of an object, e.g. if an
output does not appear in the document as expected, or to test an
[`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md)
method for a class of your own.

|  |  |
|----|----|
| Type | Outputs |
| `"section"` | a section ([`pub_section()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) |
| `"list"` | a plain list (also a split pipeflow output), holding further outputs |
| `"table"` | a huxtable, data.frame or matrix (see [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)) |
| `"figure"` | a plot, image files or a rendered plot ([`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md)) |
| `"text"` | a character vector, also e.g. `glue` (Markdown, see [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)) |
| `"widget"` | an htmlwidget |
| `"raw"`, `"pagebreak"`, `"toc"` | see [`pub_raw()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md), [`pub_pagebreak()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md), [`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md) |
| `"error"` | a failed step or an error item of [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md) (an error box) |
| `"null"` | `NULL`, skipped |

Objects of any other class are converted with
[`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md)
first.

## See also

[`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md),
[`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)

## Examples

``` r
pub_type("Some *Markdown* text")
#> [1] "text"
pub_type(data.frame(a = 1))
#> [1] "table"
pub_type(list(a = "text", b = data.frame(a = 1)))
#> [1] "list"
pub_type(pub_pagebreak())
#> [1] "pagebreak"
pub_type(NULL)
#> [1] "null"
```
