# Print a param object

Prints the type and value of a param and its attributes, one per line.
The `description` is left out if it equals the `label`, and the validity
functions are only counted (`param_attr(x, "validity")` shows their
code). The children of a
[`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
are printed recursively.

## Usage

``` r
# S3 method for class 'param'
print(x, ...)
```

## Arguments

- x:

  A param object.

- ...:

  Not used.

## Value

`x`, invisibly.

## Examples

``` r
numeric_param(0.05, label = "Significance level", min = 0, max = 1)
#> param<numeric>: 0.05
#>   label: Significance level
#>   min: 0
#>   max: 1
#>   validity: <function>
param(FALSE, label = "Show points?")
#> param<logical>: FALSE
#>   label: Show points?
#>   validity: <function>
```
