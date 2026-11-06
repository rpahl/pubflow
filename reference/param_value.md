# Get or set the value of a param

Get the plain value of a param or replace it, keeping the rest of the
param.

## Usage

``` r
param_value(x)

param_value(x) <- value
```

## Arguments

- x:

  A param object.

- value:

  The new value.

## Value

`param_value()`: the plain value. `param_value<-`: the updated param
object.

## Details

### Functions

- `param_value()` returns the plain value: the value without label,
  validity and the other attributes of the param, but with its class
  (e.g. `factor`, `Date`) and structure (e.g. `names`, `dim`). For a
  [`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
  it returns a named list of the plain values of its children.

- `param_value<-` replaces the value and keeps everything else (label,
  validity, ...).

### Setting a value

The new value is converted to the type of the current one, e.g. a text
`"2"` becomes the number 2 for a numeric param. Also:

- The names or dimensions of the new value replace those of the current
  one.

- A factor param keeps its levels: values outside them become `NA`,
  which the validity check of
  [`choice_param()`](https://rpahl.github.io/pubflow/reference/param.md)
  reports. A new factor brings its own levels.

- A date-time param reads texts in its own time zone. ISO 8601 texts
  with `T` and a trailing `Z` (UTC) work too.

- A param as new value contributes its plain value.

- A param group takes a named list with (at least) the names of its
  children.

## Examples

``` r
p <- choice_param("yes", c("yes", "no"), label = "Question")
param_value(p)
#> [1] yes
#> Levels: yes no
param_value(p) <- "no"
p
#> param<factor>: <factor[1]: no>
#>   levels: yes, no
#>   label: Question
#>   validity: <function>

g <- param_group(list(a = param("x"), b = numeric_param(1)))
param_value(g)
#> $a
#> [1] "x"
#> 
#> $b
#> [1] 1
#> 
param_value(g) <- list(a = "y", b = 2)
param_value(g)
#> $a
#> [1] "y"
#> 
#> $b
#> [1] 2
#> 

# Date-times: texts are read in the time zone of the param
start <- param(
    as.POSIXct("2026-10-05 12:00:00", tz = "Europe/Berlin"),
    label = "Start"
)
param_value(start) <- "2026-10-06 08:30:00"
param_value(start)
#> [1] "2026-10-06 08:30:00 CEST"

# ISO 8601 texts with a trailing Z are UTC (08:30 UTC is 10:30 in Berlin)
param_value(start) <- "2026-10-06T08:30:00Z"
param_value(start)
#> [1] "2026-10-06 10:30:00 CEST"
```
