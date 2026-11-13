# Rows of a table by role

Gives the rows of a table built by
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md):
header, spanner, body and footnote rows. Use them to style rows by role
with huxtable's functions, whose rows count from the first header row.

## Usage

``` r
pub_table_rows(ht)
```

## Arguments

- ht:

  A huxtable returned by
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md).

## Value

A list of integer row numbers: `header` (spanner and label rows),
`spanner`, `body` and `footnote`. The same list is passed to the `style`
function of a
[`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md).

## Details

[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
records the roles. huxtable's
[`rbind()`](https://rdrr.io/r/base/cbind.html),
[`cbind()`](https://rdrr.io/r/base/cbind.html), `[` and functions that
add rows make them unknown: finish the combined table with
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
again before asking for its rows. A table with footnotes that is
finished again keeps them as footnotes, unless it was bound or subset
since.

## See also

[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
df <- aggregate(Ozone ~ Month, data = airquality, FUN = mean)
ht <- pub_table(df, digits = c(Ozone = 1), footnotes = c(Ozone = "Mean in ppb."))
rows <- pub_table_rows(ht)
rows
#> $header
#> [1] 1
#> 
#> $spanner
#> integer(0)
#> 
#> $body
#> [1] 2 3 4 5 6
#> 
#> $footnote
#> [1] 7
#> 

# body row i is table row rows$body[i]
ht <- huxtable::set_bold(ht, rows$body[df$Ozone > 40], "Ozone")

# binding makes the roles unknown until the table is finished again
parts <- pub_table(df, digits = c(Ozone = 1))
both <- rbind(parts, parts[-1, ])
try(pub_table_rows(both))
#> Error in pub_table_rows(both) : The row roles of `ht` are unknown.
#> ℹ Build it with `pub_table()`, or finish it with `pub_table()` again after binding or subsetting it.
pub_table_rows(pub_table(both, footnotes = c(Ozone = "Mean in ppb.")))
#> $header
#> [1] 1
#> 
#> $spanner
#> integer(0)
#> 
#> $body
#>  [1]  2  3  4  5  6  7  8  9 10 11
#> 
#> $footnote
#> [1] 12
#> 
```
