# Placeholder for a missing part

`pub_missing()` stands in for a part of a document that doesn't exist
yet, e.g. the results of an analysis that has not been run. It is
neither content nor an error: the viewer shows the message as a neutral
placeholder, while
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
refuses a document with missing parts, like one with error items.
[`pub_problems()`](https://rpahl.github.io/pubflow/reference/pub_problems.md)
finds both before rendering.

## Usage

``` r
pub_missing(message)
```

## Arguments

- message:

  `character(1)` what is missing and how to get it, as plain text on one
  line (line breaks become spaces in documents).

## Value

An object of class `pub_missing`.

## Details

Place it like any other output (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
e.g. in a layout step for a part whose input is not available. For
drafts, `pub_report_spec(problems = "show")` renders missing parts as an
italic paragraph.

## See also

[`pub_problems()`](https://rpahl.github.io/pubflow/reference/pub_problems.md),
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)

## Examples

``` r
x <- pub_missing("Run the analysis first.")
pub_type(x)
#> [1] "missing"

doc <- pub_doc(pub_section("Results", x))
pub_problems(doc)[[1]]$message
#> [1] "Run the analysis first."
```
