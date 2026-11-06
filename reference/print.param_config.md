# Print a param config

Prints an overview of a
[`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md)
as a table: one row per param with its name, type, value and label, in
the config order. The children of a
[`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
follow their group, indented. Print a single param (e.g.
`print(cfg$alpha)`) to see all its attributes.

## Usage

``` r
# S3 method for class 'param_config'
print(x, ...)
```

## Arguments

- x:

  A param config.

- ...:

  Not used.

## Value

`x`, invisibly.

## Examples

``` r
param_config(
    alpha = numeric_param(0.05, label = "Significance level", min = 0, max = 1),
    showPoints = param(FALSE, label = "Show points?")
)
#> <param_config: 2 params>
#>  name       type    value label             
#>  alpha      numeric 0.05  Significance level
#>  showPoints logical FALSE Show points?      
```
