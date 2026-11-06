# Parameter configs

A config is a named list of params that defines all parameters of a
pipeline.

## Usage

``` r
param_config(..., .duplicates = c("error", "first"))

# S3 method for class 'param_config'
c(..., .duplicates = c("error", "first"))

# S3 method for class 'param_config'
x[i]
```

## Arguments

- ...:

  Params (named arguments), lists of params or configs. `NULL` arguments
  are ignored. The names of list arguments are not used, only those of
  the params in them.

- .duplicates:

  `"error"` (default) or `"first"`: what to do with params of the same
  name.

- x:

  A param config.

- i:

  Index of the elements to keep.

## Value

A named list of params with class `c("param_config", "list")`.

## Details

### Functions

- `param_config()` collects params into a config. It checks that all
  elements are params with unique names and numbers them (attribute
  `order`), which sets their order in the parameter UI.

- [`c()`](https://rdrr.io/r/base/c.html) combines configs (and further
  params or lists of params) and numbers the params anew.

- `[` selects params and keeps the class. Unknown names and indices are
  an error.

Duplicate names are an error, unless you set `.duplicates = "first"`:
then the first definition wins. This is useful to merge the configs of
combined pipelines, where the more specific definition comes first (see
Examples).

## See also

[`param()`](https://rpahl.github.io/pubflow/reference/param.md),
[`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)

## Examples

``` r
prep <- param_config(
    yUnit = param("%", label = "Unit of y"),
    alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1)
)
stats <- param_config(
    alpha = numeric_param(0.01, label = "Alpha", min = 0, max = 1),
    list(showPoints = param(TRUE, label = "Show points?"))
)
names(prep)
#> [1] "yUnit" "alpha"
param_attr(stats$showPoints, "order")
#> [1] 2

# Merge configs: the first definition of 'alpha' wins
full <- c(prep, stats, .duplicates = "first")
param_value(full$alpha)
#> [1] 0.05
vapply(full, param_attr, numeric(1), which = "order")
#>      yUnit      alpha showPoints 
#>          1          2          3 

# By default, duplicate names are an error
try(c(prep, stats))
#> Error in c(prep, stats) : Duplicate param names: alpha.
#> ℹ Use `.duplicates = "first"` to keep the first definition.
```
