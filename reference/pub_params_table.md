# Table of parameters

Makes a table (see
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md))
that lists params, e.g. for a parameter section in a report. By default
it shows their labels, values and descriptions. Values are shown as
`toString(param_value(p))` (date-times in UTC). A
[`param_group()`](https://rpahl.github.io/pubflow/reference/param.md) is
shown as `"<label>: <value>"` of its members that have a value, e.g.
`"Lower: 1, Upper: 2"`. An empty value (length 0, all `NA` or blank) is
shown as `na`.

## Usage

``` r
pub_params_table(
  params,
  caption = NULL,
  columns = c(label = "Parameter", value = "Value", description = "Description"),
  na = ""
)
```

## Arguments

- params:

  Named list of params, e.g. from
  [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md).
  Plain values are shown with their name as label.

- caption:

  `character(1)` table caption or `NULL`.

- columns:

  Named character vector: field -\> column header. The fields are
  `"name"` (the param name), `"value"` or any param attribute such as
  `"label"`, `"description"` or `"area"`.

- na:

  `character(1)` text shown for empty values.

## Value

A huxtable.

## See also

[`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)

## Examples

``` r
params <- param_config(
    alpha = numeric_param(0.05, label = "Alpha", description = "Level"),
    trans = choice_param("log", c("none", "log"), label = "Transformation"),
    limits = param_group(
        list(
            lower = numeric_param(1, label = "Lower"),
            upper = numeric_param(NA_real_, label = "Upper")
        ),
        label = "Limits"
    ),
    note = param("", label = "Note")
)
ht <- pub_params_table(params, caption = "Parameters", na = "-")
pub_cell_text(ht)
#>      [,1]             [,2]       [,3]            
#> [1,] "Parameter"      "Value"    "Description"   
#> [2,] "Alpha"          "0.05"     "Level"         
#> [3,] "Transformation" "log"      "Transformation"
#> [4,] "Limits"         "Lower: 1" "Limits"        
#> [5,] "Note"           "-"        "Note"          

pub_params_table(params, columns = c(name = "Name", value = "Value")) |>
    pub_cell_text()
#>      [,1]     [,2]      
#> [1,] "Name"   "Value"   
#> [2,] "alpha"  "0.05"    
#> [3,] "trans"  "log"     
#> [4,] "limits" "Lower: 1"
#> [5,] "note"   ""        
```
