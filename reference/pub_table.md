# Create a pubflow table

Builds a styled
[huxtable](https://hughjonesd.github.io/huxtable/reference/huxtable.html)
from a data.frame or matrix, or finishes an existing huxtable.

## Usage

``` r
pub_table(
  x,
  caption = NULL,
  labels = NULL,
  digits = NULL,
  align = NULL,
  widths = NULL,
  header = NULL,
  footnotes = NULL,
  merge = NULL,
  na = "",
  font_size = NULL,
  theme = getOption("pubflow.table_theme", pub_table_theme())
)
```

## Arguments

- x:

  A data.frame or matrix, or a huxtable to finish.

- caption:

  `character(1)` table caption or `NULL` (as is a blank string).

- labels:

  Named character vector: column name -\> header label. Columns not
  named keep their name (or label) as label.

- digits:

  Named vector: column name -\> number of decimal places (0 to 324) of a
  numeric column (rounded half away from zero, see
  [`pub_round()`](https://rpahl.github.io/pubflow/reference/pub_round.md)).

- align:

  Named character vector: column name -\> `"left"`, `"right"` or
  `"center"`. Default: numeric columns right, others left.

- widths:

  Named vector: column name -\> relative width (a positive number),
  absolute width (`"<n>cm"`) or `"auto"` (as if not given). Absolute
  columns keep their width, relative widths share the rest of the table
  width. Usually not needed: without widths, columns are sized by their
  content and text wraps to fit the page. (In PDF via LaTeX pubflow
  computes the widths from the cell texts, and a table whose longest
  words don't fit gets a smaller font.)

- header:

  Named character vector: column name -\> spanner label shown above the
  labels. Consecutive equal labels are merged; columns without a spanner
  get an empty cell. Data.frames and matrices only.

- footnotes:

  Named character vector: column name -\> footnote. The label gets a
  numbered marker (superscript digit), the footnotes are listed below
  the body (equal texts share one number). Give all footnotes in one
  call, for the final table: a table that has footnotes keeps them when
  it is finished again, but after binding or subsetting they become body
  rows.

- merge:

  Character vector of column names whose consecutive equal body cells
  are merged vertically.

- na:

  `character(1)` text shown for missing values.

- font_size:

  Font size in points (default: the theme's).

- theme:

  A
  [`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md).
  Default: option `pubflow.table_theme`, otherwise
  [`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md).

## Value

A huxtable.

## Details

Compared with
[`huxtable::huxtable()`](https://hughjonesd.github.io/huxtable/reference/huxtable.html),
`pub_table()` sets up labels, spanner headers, footnotes, merged cells
and a theme in one call, and its number formatting (rounded half away
from zero, see
[`pub_round()`](https://rpahl.github.io/pubflow/reference/pub_round.md))
gives the same text in every output format.

### Structure

A table built from a data.frame or matrix has

- header rows: an optional spanner row above the label row;

- the body;

- optional footnote rows,

and is styled by a table theme (see
[`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md)).

Given a huxtable, `pub_table()` finishes it instead: it applies theme,
borders, labels, digits, footnotes etc. to its header and body rows,
e.g. after you combined tables with huxtable's
[`rbind()`](https://rdrr.io/r/base/cbind.html).

### Number formats

Rounding and formatting happen only when the table is rendered, by one
formatter that is used for all output formats, so the cells show the
same text everywhere (see
[`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md)).
Until then the cells hold the unrounded values as text, and the format
of numbers is stored in huxtable's `number_format` (from `digits`,
otherwise the theme's default for numeric columns) and `na_string` (from
`na`).

### Styling

Style tables with huxtable's functions, e.g.
[`huxtable::set_text_color()`](https://hughjonesd.github.io/huxtable/reference/text_color.html)
or
[`huxtable::map_text_color()`](https://hughjonesd.github.io/huxtable/reference/text_color.html).
Keep in mind:

- Their rows include the header rows:
  [`pub_table_rows()`](https://rpahl.github.io/pubflow/reference/pub_table_rows.md)
  gives the table rows of the header, body and footnotes (see Examples).

- Use integer rows: huxtable recycles short logical vectors, also into
  the footnote rows.

- Strike cells through with
  [`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md).

### Combining tables

The simplest way is to combine the data and build one table (see
Examples). You can also combine finished tables with huxtable's
[`rbind()`](https://rdrr.io/r/base/cbind.html),
[`cbind()`](https://rdrr.io/r/base/cbind.html) and `[`. They preserve
cell properties (styles, number formats, merges, struck-through cells),
but

- bind by position;

- keep the borders of each part;

- drop pubflow's metadata
  ([`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)),
  except [`rbind()`](https://rdrr.io/r/base/cbind.html), which keeps
  that of the first table.

So finish the combined table with `pub_table()` and set footnotes,
widths, metadata and strikeout on the final table.

## See also

[`pub_table_rows()`](https://rpahl.github.io/pubflow/reference/pub_table_rows.md),
[`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md),
[`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md),
[`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md),
[`pub_params_table()`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)

## Examples

``` r
df <- airquality[c(1, 2, 32, 33), c("Month", "Day", "Ozone", "Wind")]
df$Month <- month.name[df$Month]
ht <- pub_table(
    df,
    caption = "First days of May and June",
    labels = c(Ozone = "Ozone (ppb)", Wind = "Wind (mph)"),
    digits = c(Wind = 0),
    header = c(Ozone = "Measured", Wind = "Measured"),
    footnotes = c(Ozone = "Mean from 1 to 3 pm."),
    merge = "Month",
    na = "-"
)
pub_cell_text(ht)
#>      [,1]                     [,2]                     [,3]                    
#> [1,] ""                       ""                       "Measured"              
#> [2,] "Month"                  "Day"                    "Ozone (ppb)¹"          
#> [3,] "May"                    "1"                      "41"                    
#> [4,] "May"                    "2"                      "36"                    
#> [5,] "June"                   "1"                      "-"                     
#> [6,] "June"                   "2"                      "-"                     
#> [7,] "¹ Mean from 1 to 3 pm." "¹ Mean from 1 to 3 pm." "¹ Mean from 1 to 3 pm."
#>      [,4]                    
#> [1,] "Measured"              
#> [2,] "Wind (mph)"            
#> [3,] "7"                     
#> [4,] "8"                     
#> [5,] "9"                     
#> [6,] "10"                    
#> [7,] "¹ Mean from 1 to 3 pm."

# Style with huxtable: body row i is table row pub_table_rows(ht)$body[i]
body <- pub_table_rows(ht)$body
ht <- huxtable::set_text_color(ht, body[df$Wind > 9], "Wind", "red")

# Combine the data, then build one table
more <- rbind(df, data.frame(Month = "July", Day = 1L, Ozone = 135L, Wind = 4.1))
pub_cell_text(pub_table(more, digits = c(Wind = 0), merge = "Month"))
#>      [,1]    [,2]  [,3]    [,4]  
#> [1,] "Month" "Day" "Ozone" "Wind"
#> [2,] "May"   "1"   "41"    "7"   
#> [3,] "May"   "2"   "36"    "8"   
#> [4,] "June"  "1"   ""      "9"   
#> [5,] "June"  "2"   ""      "10"  
#> [6,] "July"  "1"   "135"   "4"   

# A matrix works like a data.frame
m <- as.matrix(airquality[1:2, c("Wind", "Temp")])
pub_cell_text(pub_table(m, digits = c(Wind = 1, Temp = 0)))
#>      [,1]   [,2]  
#> [1,] "Wind" "Temp"
#> [2,] "7.4"  "67"  
#> [3,] "8.0"  "72"  

# Layout: alignment, column widths and font size
pub_table(
    df,
    align = c(Month = "center"),
    widths = c(Month = "2cm", Ozone = 1),
    font_size = 9
)
#>                        ─────────────────────────────────
#>                          Month    Day   Ozone     Wind  
#>                        ─────────────────────────────────
#>                           May       1      41   7.4000  
#>                           May       2      36   8.0000  
#>                          June       1           8.6000  
#>                          June       2           9.7000  
#>                        ─────────────────────────────────
#> 
#> Column names: Month, Day, Ozone, Wind

# Combined tables: `[` and `cbind()` drop the metadata, `rbind()` keeps the first
ht <- pub_set_meta(pub_table(df), id = "first-days")
pub_meta(ht[1:2, ], "id")
#> NULL
pub_meta(rbind(ht, ht), "id")
#> [1] "first-days"
```
