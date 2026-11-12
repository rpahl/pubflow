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
  border_color = NULL,
  border_width = NULL,
  style = NULL,
  number_format = 4L
)
```

## Arguments

- ...:

  Further huxtable cell properties applied to every cell, e.g.
  `font = "Arial"`, `top_padding = 2` or `valign = "middle"` (see
  [`huxtable::style_cells()`](https://hughjonesd.github.io/huxtable/reference/style-functions.html)).

- font_size:

  Font size in points.

- borders:

  `"booktabs"`: horizontal rules above and below the header (and below
  spanners) and below the body; `"grid"`: borders around all header and
  body cells.

- border_color:

  Colour of the borders, e.g. `"#D9E2F3"`, or `NULL`: the cells keep
  their colour (black in a new table).

- border_width:

  Width of all borders in points, or `NULL`: 0.4 pt, with booktabs 0.8
  pt above and below the table.

- style:

  `NULL` or a function `function(ht, rows)` that styles the table after
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
  has applied the rest of the theme. `rows` is a list of row numbers by
  role: `header` (spanner and label rows), `spanner`, `body` and
  `footnote`. The function returns the styled huxtable, with the same
  rows and columns; its metadata
  ([`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md),
  with the caption) stays as before. Use it for a look that depends on
  the role of a row, e.g. a coloured header. It runs on every call of
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md),
  also when a table is finished again, so set properties
  (`bold(ht)[rows$header, ] <- TRUE`) rather than change them relative
  to their value.

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

# A house style: light blue grid, bold centred header on a grey background
house <- pub_table_theme(
    borders = "grid",
    border_color = "#D9E2F3",
    border_width = 0.5,
    valign = "middle",
    style = function(ht, rows) {
        huxtable::align(ht)[rows$header, ] <- "center"
        huxtable::background_color(ht)[rows$header, ] <- "grey90"
        ht
    }
)
ht <- pub_table(data.frame(x = 1:2, y = c("a", "b")), theme = house)
huxtable::background_color(ht)[, 1]
#>                 1        2 
#> "grey90"       NA       NA 
```
