# Escape text for Markdown

Escapes text so that it shows as it is in a
[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md) or
a Markdown table cell, e.g. a name, a label or a model formula from
data. Without escaping, a label `*new*` would come out in italics, the
formula `airquality$Ozone ~ airquality$Temp` partly as math, and a line
starting with `1.` as a numbered list.

## Usage

``` r
pub_md_escape(x)
```

## Arguments

- x:

  Character vector or factor of plain text.

## Value

`x` as Markdown, a character vector of the same length; `NA` stays `NA`.

## Details

Every character with a meaning in pubflow's Markdown gets a backslash:
the inline syntax (emphasis, code, links, math, superscript,
cross-references, raw HTML) and what starts a block at the beginning of
a line (lists, quotes). The text comes out on one line: line breaks and
other runs of whitespace become one space. For several lines, escape
each line and join them with `" \n"` (a line break) or `"\n\n"` (a new
paragraph).

## See also

[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)

## Examples

``` r
model <- "airquality$Ozone ~ airquality$Temp"
txt <- pub_text(paste("The model", pub_md_escape(model), "fits the data well."))
writeLines(txt)
#> The model airquality\$Ozone \~ airquality\$Temp fits the data well.

# several lines: escape each, then join
address <- c("1. Main Street", "<Building B>")
writeLines(paste(pub_md_escape(address), collapse = "  \n"))
#> 1\. Main Street  
#> \<Building B\>
```
