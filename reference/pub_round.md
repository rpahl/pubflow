# Round numbers half away from zero

Rounds as pubflow's tables do, and as SAS's `ROUND()` does: if the first
digit after the last one kept is 5 or more, the number is rounded up in
magnitude.

## Usage

``` r
pub_round(x, digits = 0)

pub_format_num(x, format)
```

## Arguments

- x:

  A numeric vector.

- digits:

  A whole number \>= 0: the number of decimal places.

- format:

  A number format as in tables: either a whole number of decimal places
  (at most 324) or a [`sprintf()`](https://rdrr.io/r/base/sprintf.html)
  format with exactly one `%.nf`, `%.ne` or `%.ng` conversion and any
  other text, e.g. `"%.1f %%"` or `"Mean: %.2f"`. The number is rounded
  to `n` decimal places (`f`), `n + 1` significant digits (`e`) or `n`
  significant digits, at least 1 (`g`). Flags and widths as in `"%+.2f"`
  or `"%5.2f"` are not supported.

## Value

`pub_round()`: a double vector with the attributes of `x` (`NA`, `NaN`
and infinite values stay as they are).

`pub_format_num()`: a character vector with the names and dimensions of
`x`; `NA` and `NaN` give `NA`, infinite values `"Inf"` or `"-Inf"`.

## Details

### Functions

- `pub_round()` returns the rounded numbers, e.g. to compare a result
  with a threshold.

- `pub_format_num()` returns the text that a table cell with this number
  format shows (see
  [`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md)),
  e.g. for numbers in a text.

### Why not [`round()`](https://rdrr.io/r/base/Round.html)?

[`round()`](https://rdrr.io/r/base/Round.html),
[`formatC()`](https://rdrr.io/r/base/formatc.html) and
[`sprintf()`](https://rdrr.io/r/base/sprintf.html) round the number as
the computer stores it (in binary), and exact ties go to the even digit.
As most decimals can't be stored exactly, this often looks wrong: 2.675
is stored as 2.67499999999999982, so they give 2.67.

pub_round() and pub_format_num() use the digits of the number's decimal
text instead (the 15 significant digits that
[`as.character()`](https://rdrr.io/r/base/character.html) shows and a
table cell stores), so ties round as expected. A result of zero has no
sign.

|        |                   |               |
|--------|-------------------|---------------|
| `x`    | `pub_round(x, 2)` | `round(x, 2)` |
| 0.125  | 0.13              | 0.12          |
| 2.675  | 2.68              | 2.67          |
| -2.675 | -2.68             | -2.67         |
| 9.995  | 10                | 9.99          |
| -0.001 | 0                 | 0             |

## See also

[`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md),
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
x <- c(0.125, 2.675, 1.005, 0.285, -2.675, -0.001, 9.995)
round(x, 2)
#> [1]  0.12  2.67  1.00  0.28 -2.67  0.00  9.99
pub_round(x, 2)
#> [1]  0.13  2.68  1.01  0.29 -2.68  0.00 10.00
pub_format_num(x, 2)
#> [1] "0.13"  "2.68"  "1.01"  "0.29"  "-2.68" "0.00"  "10.00"
formatC(x, format = "f", digits = 2)  # the binary value, ties to even
#> [1] "0.12"  "2.67"  "1.00"  "0.28"  "-2.67" "-0.00" "9.99" 

pub_format_num(c(0.5, 2.5, -0.5), 0)
#> [1] "1"  "3"  "-1"
pub_format_num(c(0.125, 999.5), "%.2g")
#> [1] "0.13"  "1e+03"
pub_format_num(12.25, "%.1f %%")
#> [1] "12.3 %"

# Numbers in text
high <- mean(airquality$Ozone > 60, na.rm = TRUE)
pub_format_num(100 * high, "Days above 60 ppb: %.1f %%")
#> [1] "Days above 60 ppb: 26.7 %"
```
