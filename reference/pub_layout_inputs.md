# Inputs of a layout step: the steps of a view

Helps to make a layout step (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
that shows all steps of a view, e.g. all steps tagged for one report, so
you don't have to list them by hand. The tags decide what a report shows
and the layout step arranges it.

## Usage

``` r
pub_layout_inputs(x)
```

## Arguments

- x:

  A pipeflow pipeline or view.

## Value

Named list (by step, in pipeline order) of one-sided formulas
`~try(<step>)`.

## Details

It returns `~try(step)` for every step of the view. Pass the result as
`params` of a layout step whose function takes `...` (see Examples). The
references work as usual:

- running the layout step runs only the steps it needs
  (`pipeflow::pip_run(pipeflow::pip_view(x, step = "doc"))`);

- an input that failed in a run with `on_error = "continue"` arrives as
  a failure object, which the document shows as an error box (see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)).

### Sections

- `pub_doc(list(...))` makes one section per step, titled by the step
  name;

- `pub_doc(unname(list(...)))` places the outputs one after the other.

### Add the layout step last

The steps are read when `pub_layout_inputs()` is called, so add the
layout step after the steps it should show. Steps added or tagged later
(also steps added during a run through `.self`) are not part of it.

### Split steps

If the view has steps downstream of a split step (partitioned outputs)
and other steps, add the layout step with `exec = "reduce"`. It then
runs once and places each partitioned output as one sub-section per key.
Otherwise pipeflow runs it once per partition.

## See also

[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)

## Examples

``` r
p <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("data", \(n = 4) {
        data.frame(x = seq_len(n), y = seq_len(n)^2)
    }) |>
    pipeflow::pip_add("table", \(data = ~data) {
        pub_table(data, caption = "Data")
    }, tags = "short") |>
    pipeflow::pip_add("mean", \(data = ~data) {
        pub_format_num(mean(data$y), "Mean: %.2f")
    }, tags = c("short", "long")) |>
    pipeflow::pip_add("max", \(data = ~data) {
        pub_format_num(max(data$y), "Maximum: %.2f")
    }, tags = "long")

pub_layout_inputs(pipeflow::pip_view(p, tags = "short"))
#> $table
#> ~try(table)
#> <environment: R_EmptyEnv>
#> 
#> $mean
#> ~try(mean)
#> <environment: R_EmptyEnv>
#> 

# One layout step per report
p |>
    pipeflow::pip_add("short", \(...) {
        pub_doc(list(...), title = "Short report")
    }, params = pub_layout_inputs(pipeflow::pip_view(p, tags = "short"))) |>
    pipeflow::pip_add("long", \(...) {
        pub_doc(unname(list(...)), title = "Long report")
    }, params = pub_layout_inputs(pipeflow::pip_view(p, tags = "long")))

# Runs only the steps the short report needs
pipeflow::pip_run(pipeflow::pip_view(p, step = "short"), lgr = NULL)
p[["short", "out"]]
#> <pubflow document> "Short report"
#> # table
#>   table "Data"
#> # mean
#>   text "Mean: 7.50"
```
