# Validity checks of params

Each param carries rules that tell whether its value is valid. A rule is
a *validity function*: it takes the plain value and returns `""` if the
value is valid, otherwise a message that says what is wrong.

## Usage

``` r
param_validity(x, value = x)

param_validity_assert(x, value = x)

add_validity(x, f)

default_param_validity(x)
```

## Arguments

- x:

  A param (`default_param_validity()`: a plain value).

- value:

  The value to check; defaults to the param's own value. Params are
  treated as their plain values.

- f:

  A validity function or a list of them.

## Value

- `param_validity()`: a character vector with one message per validity
  function (`""`: valid). For groups, a named vector (see Details).

- `param_validity_assert()`: `value`, invisibly, if it is valid.

- `add_validity()`: the updated param.

- `default_param_validity()`: `character(1)`, `""` if valid.

## Details

### Functions

- `param_validity()` checks a value against all rules of a param and
  returns their messages. By default it checks the param's current
  value; pass `value` to check another one.

- `param_validity_assert()` does the same but signals an error if any
  rule reports a problem.

- `add_validity()` adds rules to a param.

- `default_param_validity()` is the default rule of
  [`param()`](https://rpahl.github.io/pubflow/reference/param.md): the
  value must be neither empty nor `NA`.

A message can be any text (other results are converted with
[`toString()`](https://rdrr.io/r/base/toString.html)).

If a rule itself fails with an error (e.g. because of unexpected input),
the error is caught and reported as the message
`"validity check failed: <error message>"`. The value then counts as
invalid. So `param_validity()` itself never fails because of a rule,
which keeps a parameter UI from crashing on a faulty rule (see
Examples).

For a
[`param_group()`](https://rpahl.github.io/pubflow/reference/param.md),
the rules of the group get the named list of the child values and each
child is checked with its own rules. The result has one element for the
group (named `group`) and one per child. Each element holds the messages
of that part, joined by `", "`:

    c(group = "lower must be below upper", lower = "", upper = "")

## Examples

``` r
# Numeric params check their bounds; "" means valid
p <- numeric_param(0.5, min = 0, max = 1)
param_validity(p)
#> [1] ""
param_validity(p, value = 2)
#> [1] "value must be less than or equal to max (1)"
param_validity_assert(p, value = 0.7)
try(param_validity_assert(p, value = 2))
#> Error in param_validity_assert(p, value = 2) : 
#>   value must be less than or equal to max (1)

# A rule that fails with an error is reported as a message
bad <- add_validity(p, \(x) if (log(x) > -5) "" else "too small")
param_validity(bad, value = "a")
#> [1] "value must be less than or equal to max (1)"                         
#> [2] "validity check failed: non-numeric argument to mathematical function"

# Add a rule of your own
p <- add_validity(p, \(x) if (x != 0.25) "" else "must not be 0.25")
param_validity(p, value = 0.25)
#> [1] ""                 "must not be 0.25"

default_param_validity(NA)
#> [1] "value cannot be NA"
```
