# Strike table cells through

Strikes cells through, e.g. excluded measurements or superseded values.
Every output format shows them struck through. Like other cell
properties, this survives huxtable's
[`rbind()`](https://rdrr.io/r/base/cbind.html),
[`cbind()`](https://rdrr.io/r/base/cbind.html) and `[`.

## Usage

``` r
pub_strikeout(ht, row, col)
```

## Arguments

- ht:

  A huxtable, e.g. from
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md).

- row, col:

  Rows and columns as in huxtable's setters such as
  [`huxtable::set_bold()`](https://hughjonesd.github.io/huxtable/reference/bold.html):
  indices, names, logical vectors,
  [huxtable::everywhere](https://hughjonesd.github.io/huxtable/reference/stripe.html)
  or
  [`huxtable::final()`](https://hughjonesd.github.io/huxtable/reference/final.html).
  Rows include the header rows (see
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)).
  Default: all.

## Value

`ht` with the cells struck through.

## Details

huxtable has no strikeout property, so the cells become Markdown cells
([`huxtable::markdown()`](https://hughjonesd.github.io/huxtable/reference/markdown.html))
that hold their display text (see
[`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md))
between `~~`. Therefore:

- The text is fixed when the cells are struck through (a later change of
  their number format does not apply), so strike through last.

- Empty cells stay unchanged.

- Markdown characters in the text are escaped.

- In cells that are Markdown already, each line is struck through as a
  whole after its block markers: `~~A~~ and B` becomes `~~A and B~~` and
  `"# A\n\n- b"` becomes `"# ~~A~~\n\n- ~~b~~"`.

## See also

[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
df <- airquality[1:3, c("Day", "Ozone", "Wind")]
excluded <- c(FALSE, TRUE, FALSE)
ht <- pub_table(df, digits = c(Wind = 1))
rows <- pub_table_rows(ht)$body[excluded]
ht <- huxtable::set_text_color(ht, rows, huxtable::everywhere, "grey")
ht <- pub_strikeout(ht, rows)
pub_cell_text(ht)
#>      [,1]    [,2]     [,3]     
#> [1,] "Day"   "Ozone"  "Wind"   
#> [2,] "1"     "41"     "7.4"    
#> [3,] "~~2~~" "~~36~~" "~~8.0~~"
#> [4,] "3"     "12"     "12.6"   
```
