# Error items of a document or of step outputs

Finds the failed steps in a document or in the outputs placed into one,
e.g. to check a report before it is rendered
([`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
refuses error items) or to list its problems in an app.

## Usage

``` r
pub_error_items(x)
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

## Value

A list of error items (class `pub_error`, as returned by
[`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md)), in
document order; empty if there are none. An error item is a list with
the elements `step` (the step whose output it replaces), `failed_step`
(the step that failed), `message` (its error message) and, for an item
of [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md),
`pipeline` (the pipeline of the steps).

## See also

[`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md)

## Examples

``` r
p <- pipeflow::pip_new("air") |>
    pipeflow::pip_add("data", \() airquality) |>
    pipeflow::pip_add("fit", \(data = ~data) stop("too few values")) |>
    pipeflow::pip_add("table", \(fit = ~fit) coef(fit))
suppressWarnings(pipeflow::pip_run(p, on_error = "continue"))
#> info [2026-11-14 11:12:34.550 UTC]: Starting run of pipeflow 'air'
#> info [2026-11-14 11:12:34.550 UTC]: Step 1/3 data
#> info [2026-11-14 11:12:34.551 UTC]: Step 2/3 fit
#> error [2026-11-14 11:12:34.552 UTC]: too few values
#> info [2026-11-14 11:12:34.552 UTC]: Step 3/3 table - skipping step, input 'fit' failed
#> info [2026-11-14 11:12:34.552 UTC]: Finished in 0.003 s (1 done, 1 skipped, 1 failed)
#> warn [2026-11-14 11:12:34.553 UTC]: Run of pipeline 'air' continued after 1 failed step:
#>   'fit': too few values
#> Steps not run because an input failed: 'table'

parts <- list(
    Data = head(airquality),
    Fit = pub_out(p, "table", on_error = "item")
)
errors <- pub_error_items(parts)
length(errors)
#> [1] 1
errors[[1]]$message
#> [1] "too few values"

pub_error_items(pub_doc(parts))[[1]]$failed_step
#> [1] "fit"
```
