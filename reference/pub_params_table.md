# Table of parameters

Makes a table (see
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md))
that lists params, e.g. for a parameter section in a report. By default
it shows their labels, values and descriptions. Values are shown as
`toString(param_value(p))` (date-times in UTC).

## Usage

``` r
pub_params_table(
  params,
  caption = NULL,
  columns = c(label = "Parameter", value = "Value", description = "Description")
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

## Value

A huxtable.

## See also

[`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)

## Examples

``` r
params <- param_config(
    alpha = numeric_param(0.05, label = "Alpha", description = "Level"),
    trans = choice_param("log", c("none", "log"), label = "Transformation")
)
ht <- pub_params_table(params, caption = "Parameters")
pub_cell_text(ht)
#>      [,1]             [,2]    [,3]            
#> [1,] "Parameter"      "Value" "Description"   
#> [2,] "Alpha"          "0.05"  "Level"         
#> [3,] "Transformation" "log"   "Transformation"

pub_params_table(params, columns = c(name = "Name", value = "Value")) |>
    pub_cell_text()
#>      [,1]    [,2]   
#> [1,] "Name"  "Value"
#> [2,] "alpha" "0.05" 
#> [3,] "trans" "log"  
```
