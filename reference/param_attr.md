# Retrieve an attribute of a param

Unlike [`attr()`](https://rdrr.io/r/base/attr.html), `param_attr()` does
no partial matching of the attribute name and returns a default if the
attribute is not set.

## Usage

``` r
param_attr(x, which, default = NULL)
```

## Arguments

- x:

  A param object.

- which:

  `character(1)` name of the attribute.

- default:

  Value returned if the attribute is not set.

## Value

The attribute's value, or `default` if it is not set.

## Examples

``` r
p <- param(1, label = "my label", source = "user")
param_attr(p, "label")
#> [1] "my label"
param_attr(p, "source")
#> [1] "user"
param_attr(p, "lab")
#> NULL
param_attr(p, "area", default = NA_character_)
#> [1] NA
```
