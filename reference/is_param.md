# Type and class of param objects

Test whether an object is a param and get the type of the value of a
param.

## Usage

``` r
is_param(x)

param_type(x)
```

## Arguments

- x:

  A param object (`param_type()` also accepts plain values).

## Value

- `is_param()`: `TRUE` or `FALSE`.

- `param_type()`: the type of the value, one of

  - `"character"`

  - `"factor"` (also ordered factors)

  - `"logical"`

  - `"numeric"` (double and integer)

  - `"list"` (also param groups)

  - `"data.frame"`

  - or else the first class of the value, e.g. `"Date"`.

## Details

### Functions

- `is_param()` tests whether `x` is a param.

- `param_type()` returns the type of the value of a param, e.g.
  `"numeric"` for a number. pubflow uses it to choose the input widget.
  ([`class()`](https://rdrr.io/r/base/class.html) of a param is no help
  here, as it starts with `"param"`.)

## Examples

``` r
is_param(param(1))
#> [1] TRUE
is_param(1)
#> [1] FALSE

param_type(param(1L))
#> [1] "numeric"
param_type(choice_param("b", c("a", "b")))
#> [1] "factor"
param_type(param(Sys.Date()))
#> [1] "Date"
param_type(param_group(list(a = param("x"))))
#> [1] "list"
```
