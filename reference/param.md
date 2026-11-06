# Parameter objects

A param is a value (a number, a text, a choice, ...) together with
information that describes it: a label, a help text and rules that tell
whether the value is valid. Parameter UIs and reports read this
information, while the functions of a pipeline always get the plain
value (see
[`param_value()`](https://rpahl.github.io/pubflow/reference/param_value.md)).

## Usage

``` r
param(
  x,
  label = "parameter",
  description = label,
  validity = default_param_validity,
  ...
)

numeric_param(
  x,
  label = "numeric parameter",
  description = label,
  min = -Inf,
  max = Inf,
  validity = .numeric_validity(min, max),
  ...
)

numeral_param(
  x,
  label = "numeral parameter",
  description = label,
  min = -Inf,
  max = Inf,
  validity = .numeral_validity(min, max),
  ...
)

choice_param(
  x,
  choices,
  label = "choice parameter",
  description = label,
  validity = .choice_validity(choices),
  ...
)

param_group(x, label = "Parameter group", description = label, ...)
```

## Arguments

- x:

  The value (not `NULL`). For `choice_param()` the selected choice; for
  `param_group()` a named list of params.

- label:

  `character(1)` display name.

- description:

  `character(1)` help text; defaults to `label`.

- validity:

  A validity function or a list of them. Each function takes the plain
  value and returns `""` if it is valid, otherwise a message (see
  [`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)).
  See Validity for the default rules.

- ...:

  Further optional attributes as named arguments, e.g. `source = "user"`
  or `advanced = TRUE` (see Attributes below). Passed on to `param()` by
  the other constructors.

- min, max:

  Inclusive bounds of the (numeric) value.

- choices:

  The allowed values (no duplicates or `NA`), in the order they are
  shown.

## Value

A param object: `x` with class `c("param", class(x))` and the
attributes. `param_group()` returns an object of class
`c("param_group", "param", "list")`.

## Details

### Constructors

- `param()` creates a param of any type. The type is that of `x` (see
  [`param_type()`](https://rpahl.github.io/pubflow/reference/is_param.md)),
  e.g. a logical becomes a switch in the UI.

The other constructors are shortcuts for common cases:

- `numeric_param()`: a number (or numbers) between `min` and `max`;

- `numeral_param()`: a number entered as text that keeps its decimal
  places, e.g. `"1.50"`;

- `choice_param()`: one of a fixed set of choices;

- `param_group()`: several params shown side by side and checked
  together, e.g. a lower and an upper limit.

### Numerals

A number like `1.50` loses its trailing zero as soon as it is a number.
A `numeral_param()` therefore holds the text and checks it as a number
([`as.numeric()`](https://rdrr.io/r/base/numeric.html), without
rounding).

### Choices

The initial value of a `choice_param()` must be one of the `choices` (or
`NA`). Setting a value outside the choices with `param_value<-` gives
`NA`, which the validity check reports. For a simple yes/no question, a
logical param (`param(TRUE)`, shown as a switch) is often easier.

### Groups

The children of a `param_group()` are checked on their own and the group
as a whole. Add rules for the whole group with
[`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md),
e.g. that a lower limit is below an upper limit (see Examples). The name
`"group"` can't be used for a child, as it is reserved.

### Validity

Each constructor comes with a default rule (see
[`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
to apply it):

|                   |                                         |
|-------------------|-----------------------------------------|
| Constructor       | The value is invalid if it is ...       |
| `param()`         | empty or `NA`                           |
| `numeric_param()` | empty, `NA`, below `min` or above `max` |
| `numeral_param()` | as above, or not readable as a number   |
| `choice_param()`  | empty or not one of the `choices`       |

Pass `validity` to replace the default rule (see Examples), or add
further rules to an existing param with
[`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md).

### Working with params

Base functions such as arithmetic, comparisons,
[`as.character()`](https://rdrr.io/r/base/character.html),
[`levels()`](https://rdrr.io/r/base/levels.html) or
[`format()`](https://rdrr.io/r/base/format.html) work on a param as on
its value. Keep in mind that arithmetic keeps the attributes and that
`identical(param("a"), "a")` is `FALSE`. Pass
[`param_value()`](https://rpahl.github.io/pubflow/reference/param_value.md)
to code that expects plain values.

### Attributes

pubflow knows the following attributes. Any other named argument in
`...` is stored as well.

|  |  |
|----|----|
| Attribute | Meaning |
| `label`, `description` | display name; help text (tooltip) |
| `validity` | list of validity functions |
| `source` | origin, e.g. `"user"` (set in the UI), `"data"` (derived from data) |
| `area` | grouping, e.g. `"analysis"`, `"criteria"` |
| `order` | position in the UI, set by [`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md) |
| `min`, `max`, `step` | bounds and step of numeric inputs |
| `advanced` | `TRUE`: shown in a collapsed "Advanced" block of the UI |
| `locked` | `TRUE`: shown as a disabled input, can't be changed in the UI |
| `ui_widget`, `ui_args`, `ui_style` | input widget, its arguments and CSS |

## See also

[`param_value()`](https://rpahl.github.io/pubflow/reference/param_value.md),
[`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md),
[`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md)

## Examples

``` r
# A param is its value plus information about it
p <- param("abc", label = "Name", source = "user")
p
#> param<character>: abc
#>   label: Name
#>   source: user
#>   validity: <function>
param_value(p)
#> [1] "abc"

# Numbers within bounds; params can be used like their values
alpha <- numeric_param(0.05, label = "Significance level", min = 0, max = 1)
alpha < 0.1
#> [1] TRUE
param_validity(alpha, value = 1.5)
#> [1] "value must be less than or equal to max (1)"

# A number as text keeps its trailing zero
lsl <- numeral_param("0.90", label = "LSL")
param_value(lsl)
#> [1] "0.90"

# One of several choices
trans <- choice_param("log", choices = c("none", "log", "sqrt"),
                      label = "Transformation")
levels(trans)
#> [1] "none" "log"  "sqrt"
trans == "log"
#> [1] TRUE
param_validity(trans, value = "exp")
#> [1] "value must be one of: none, log, sqrt"

# Own constructors: wrap one of the above and fix some of its arguments
yes_no_param <- function(x = c("yes", "no"), label = "Yes/No", ...) {
    choice_param(match.arg(x), choices = c("yes", "no"), label = label, ...)
}
show <- yes_no_param("no", label = "Show points?")
as.character(show)
#> [1] "no"

spec_param <- function(..., side = c("lower", "upper")) {
    numeral_param(..., side = match.arg(side))
}

# Own validity: a positive whole number. Wrap numeric_param() and pass your own
# rule; it replaces the default one, so it has to check everything it needs.
pos_integer_param <- function(
    x,
    label = "positive integer",
    description = label,
    max = .Machine$integer.max,
    validity = \(x) {
        if (length(x) == 0) return("value cannot be empty")
        if (anyNA(x)) return("value cannot be NA")
        if (any(x != round(x))) return("value must be a whole number")
        if (any(x < 1)) return("value must be positive")
        if (any(x > max)) return(paste("value must not exceed", max))
        ""
    },
    ...
) {
    numeric_param(
        x, label = label, description = description, min = 1, max = max,
        validity = validity, ...
    )
}
n <- pos_integer_param(3L, label = "Sample size")
param_validity(n, value = 2.5)
#> [1] "value must be a whole number"
param_validity(n, value = 0)
#> [1] "value must be positive"
param_validity(n)
#> [1] ""

# Params shown and checked together
limits <- param_group(
    list(
        lower = spec_param("1.0", label = "Lower", side = "lower"),
        upper = spec_param("2.0", label = "Upper", side = "upper")
    ),
    label = "Limits"
) |>
    add_validity(\(x) {
        if (as.numeric(x$lower) < as.numeric(x$upper)) "" else
            "lower must be below upper"
    })
param_validity(limits, value = list(lower = "3", upper = "2"))
#>                       group                       lower 
#> "lower must be below upper"                          "" 
#>                       upper 
#>                          "" 
```
