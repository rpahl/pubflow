# Table theme

The styling that
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
applies when it builds or finishes a table: font size, borders, number
format and other cell properties. To use a theme for all tables, set it
as default with `options(pubflow.table_theme = pub_table_theme(...))`.

## Usage

``` r
pub_table_theme(
  ...,
  font_size = 9,
  borders = c("booktabs", "grid"),
  number_format = 4L
)
```

## Arguments

- ...:

  Further huxtable cell properties applied to every cell, e.g.
  `font = "Arial"` or `top_padding = 2` (see
  [`huxtable::style_cells()`](https://hughjonesd.github.io/huxtable/reference/style-functions.html)).

- font_size:

  Font size in points.

- borders:

  `"booktabs"`: horizontal rules above and below the header (and below
  spanners) and below the body; `"grid"`: borders around all header and
  body cells.

- number_format:

  Format of numeric (non-integer) columns without `digits` (integer
  columns get 0 decimal places), one of

  - a whole number of decimal places;

  - a [`sprintf()`](https://rdrr.io/r/base/sprintf.html) format with one
    `%.nf`, `%.ne` or `%.ng` conversion;

  - a function returning one string per value;

  - `NA`: [`as.character()`](https://rdrr.io/r/base/character.html).

  See
  [`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md).

## Value

An object of class `pub_table_theme`.

## Details

The arguments after `...` must be named in full, so that
`font = "Arial"` reaches huxtable instead of being taken for
`font_size`.

## See also

[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
theme <- pub_table_theme(font_size = 8, borders = "grid", font = "Arial")
ht <- pub_table(data.frame(x = c(1.5, 2)), theme = theme)
pub_cell_text(ht)
#>      [,1]    
#> [1,] "x"     
#> [2,] "1.5000"
#> [3,] "2.0000"
huxtable::font(ht)[1, 1]
#> [1] "Arial"

pub_table(data.frame(x = 1 / 3), theme = pub_table_theme(
    number_format = "%.2e"
)) |>
    pub_cell_text()
#>      [,1]      
#> [1,] "x"       
#> [2,] "3.33e-01"
```
