# Display text of table cells

Returns the text that pubflow shows for each cell of a table, which is
the same in every output format (HTML, Word, PDF, Markdown). Use it to
check the exact text of a table in tests.

## Usage

``` r
pub_cell_text(ht)
```

## Arguments

- ht:

  A huxtable, e.g. from
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md).

## Value

A character matrix with one element per cell (also for cells hidden by
merged cells).

## Details

### Numbers

Numeric cells are formatted by their `number_format` (see
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)):

|  |  |
|----|----|
| `number_format` | Result |
| whole number `n` (at most 324) | `n` decimal places |
| [`sprintf()`](https://rdrr.io/r/base/sprintf.html) format, e.g. `"%.1f %%"` | text around one `%.nf`, `%.ne` or `%.ng` |
| function | must return one string per value (`NA`: the cell's `na_string`) |
| `NA` | [`as.character()`](https://rdrr.io/r/base/character.html) |

Numbers are rounded half away from zero, as by
[`pub_round()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
(0.125 -\> "0.13", 2.675 -\> "2.68", -0.001 -\> "0.00").
[`pub_format_num()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
gives the same text for numbers in steps. A function format rounds as it
likes.

Numbers in text cells (as huxtable and
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
store them) are only formatted if their `number_format` is not `NA`;
text cells have none.

### Other cells

- Missing values show the cell's `na_string`.

- Factors show their labels, dates and times are shown in UTC.

- Numbers inside text are never reformatted.

- Markdown cells
  ([`huxtable::markdown()`](https://hughjonesd.github.io/huxtable/reference/markdown.html))
  are text, whatever their `number_format`.

- Struck-through cells (see
  [`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md))
  show their Markdown, e.g. `"~~2.71~~"`.

## See also

[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
ht <- pub_table(
    data.frame(x = c(0.125, 2.675, NA), n = c(1L, 2L, NA)),
    digits = c(x = 2), na = "-"
)
pub_cell_text(ht)
#>      [,1]   [,2]
#> [1,] "x"    "n" 
#> [2,] "0.13" "1" 
#> [3,] "2.68" "2" 
#> [4,] "-"    "-" 


# Different number formats - define small helper first
fmt_helper <- function(ht, format) {
    pub_cell_text(huxtable::set_number_format(ht, -1, "x", format))[, 1]
}
fmt_helper(ht, "%.1f %%")                                # like sprintf()
#> [1] "x"     "0.1 %" "2.7 %" "-"    
fmt_helper(ht, list(\(v) sprintf("<%s>", format(v))))    # custom function
#> [1] "x"       "<0.125>" "<2.675>" "-"      
fmt_helper(ht, NA)                                       # as.character() via NA
#> [1] "x"     "0.125" "2.675" "-"    


# Factors, times (UTC) and struck-through cells
df <- data.frame(
    group = factor(c("low", "high", NA)),
    time = as.POSIXct(c("2026-01-05 13:30:00", NA, NA), tz = "UTC"),
    x = c(2.71, 3.1, 4)
)
ht <- pub_table(df, digits = c(x = 2), na = "-")
pub_cell_text(pub_strikeout(ht, 2, "x"))
#>      [,1]    [,2]                      [,3]      
#> [1,] "group" "time"                    "x"       
#> [2,] "low"   "2026-01-05 13:30:00 UTC" "~~2.71~~"
#> [3,] "high"  "-"                       "3.10"    
#> [4,] "-"     "-"                       "4.00"    
```
