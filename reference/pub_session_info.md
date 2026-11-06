# Session info section

A section with the output of
[`utils::sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) as a
code block, e.g. for the annex of a report to document the R version and
packages used. Place it in a document like any other output (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)).

## Usage

``` r
pub_session_info(title = "Session info")
```

## Arguments

- title:

  `character(1)` section title.

## Value

A named list with the `title` as name and the session info as text (a
code block), which a document turns into a section.

## See also

[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)

## Examples

``` r
x <- pub_session_info()
names(x)
#> [1] "Session info"
cat(substr(x[[1]], 1, 60))
#> ```
#> R version 4.6.2 (2026-10-29)
#> Platform: x86_64-pc-linux-g
```
