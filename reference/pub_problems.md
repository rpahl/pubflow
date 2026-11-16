# Problems (error items and missing parts) of a document or of step outputs

Finds the failed steps and the missing parts
([`pub_missing()`](https://rpahl.github.io/pubflow/reference/pub_missing.md))
in a document or in the outputs placed into one, e.g. to check a report
before it is rendered
([`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
refuses both) or to list its problems in an app. With `type`, it finds
only one of the two kinds.

## Usage

``` r
pub_problems(x, type = c("error", "missing"))
```

## Arguments

- x:

  A document
  ([`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
  a section
  ([`pub_section()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
  or step outputs: failure objects of failed steps, error items of
  [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md),
  other outputs and lists of them (nested). Objects of other classes are
  converted with
  [`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md)
  first, as in a document.

- type:

  The items to find: `"error"` (error items), `"missing"` (missing
  parts) or both (default).

## Value

A list of the items found, in document order; empty if there are none.
Every item is a list with the element `message`; its class tells the
kinds apart:

- error items (class `pub_error`, as returned by
  [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md))
  have the elements:

  - `message`: the error message.

  - `step`: the step whose output the item replaces.

  - `failed_step`: the step that failed.

  - `pipeline`: the pipeline of the steps; only for an item of
    [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md).

- missing parts (class `pub_missing`) have the element:

  - `message`: what is missing and how to get it. No other elements.

## See also

[`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md),
[`pub_missing()`](https://rpahl.github.io/pubflow/reference/pub_missing.md)

## Examples

``` r
p <- pipeflow::pip_new("air") |>
    pipeflow::pip_add("data", \() airquality) |>
    pipeflow::pip_add("fit", \(data = ~data) stop("too few values")) |>
    pipeflow::pip_add("table", \(fit = ~fit) coef(fit))
suppressWarnings(pipeflow::pip_run(p, on_error = "continue"))
#> info [2026-11-16 07:59:27.554 UTC]: Starting run of pipeflow 'air'
#> info [2026-11-16 07:59:27.554 UTC]: Step 1/3 data
#> info [2026-11-16 07:59:27.555 UTC]: Step 2/3 fit
#> error [2026-11-16 07:59:27.555 UTC]: too few values
#> info [2026-11-16 07:59:27.556 UTC]: Step 3/3 table - skipping step, input 'fit' failed
#> info [2026-11-16 07:59:27.556 UTC]: Finished in 0.002 s (1 done, 1 skipped, 1 failed)
#> warn [2026-11-16 07:59:27.556 UTC]: Run of pipeline 'air' continued after 1 failed step:
#>   'fit': too few values
#> Steps not run because an input failed: 'table'

parts <- list(
    Data = head(airquality),
    Fit = pub_out(p, "table", on_error = "item"),
    Trend = pub_missing("Run the trend analysis first.")
)
# Both kinds, told apart by their class: the report can't be rendered yet
items <- pub_problems(parts)
vapply(items, \(x) class(x)[[1]], character(1))
#> [1] "pub_error"   "pub_missing"
vapply(items, \(x) x$message, character(1))
#> [1] "too few values"                "Run the trend analysis first."

# Only the failed steps
pub_problems(pub_doc(parts), type = "error")[[1]]$failed_step
#> [1] "fit"
```
