# Output of a step that is up to date

Returns the output of a step like `x[[step, "out"]]`, but only if the
step is "done". After a failed run, a step keeps its earlier output and
a step that never ran has none, so reading the output directly could put
old or missing results into a document.

## Usage

``` r
pub_out(x, step, on_error = c("stop", "item"))
```

## Arguments

- x:

  A pipeflow pipeline or view.

- step:

  `character(1)` name of the step.

- on_error:

  What to return if the step is not done because of a failure: `"stop"`
  signals an error, `"item"` returns an error item.

## Value

The output of `step`, or an error item (class `pub_error`). For a step
that failed for some partition keys and `on_error = "item"`, its
partitioned output with an error item for each failed key.

## Details

Use `pub_out()` to take parts of a document from other pipelines, e.g.
from one pipeline per test whose layout steps make the parts of one
report (see Examples).

### A step that is not done

- `on_error = "stop"`: an error of class `pubflow_not_done` names the
  pipeline, the step, its state and the failed steps it depends on.

- `on_error = "item"`: an *error item* is returned if the step or a step
  it depends on failed. A document shows it as an error box, like a
  failed input of a layout step (see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
  while
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  refuses it unless the report spec allows error items.

A step that is not done for another reason (e.g. its pipeline was not
run after a change) is always an error.

The message is the one of the failed step's last attempt. A step that
failed itself is named as the cause, otherwise the first failed step it
depends on (failures before a step that is done, e.g. one that recovered
with `~try()`, don't count).

### Split steps

A step downstream of a step with `exec = "split"` runs once per
partition key and can fail for some keys only. It then keeps the outputs
of the keys that succeeded.

- `on_error = "item"` returns the partitioned output with an error item
  for each failed key, so a document shows the results of the other keys
  and one error box per failed key.

- `on_error = "stop"` signals an error that names the failed keys.

## See also

[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)

## Examples

``` r
test_pipeline <- function(name, values) {
    pipeflow::pip_new(name) |>
        pipeflow::pip_add("data", \(values = 1) values) |>
        pipeflow::pip_add("mean", \(x = ~data) {
            if (anyNA(x)) stop("missing values")
            mean(x)
        }) |>
        pipeflow::pip_add("content", \(m = ~mean) {
            pub_text(paste("Mean:", pub_format_num(m, 2)))
        }) |>
        pipeflow::pip_set_params(list(values = values))
}
tests <- list(
    Assay = test_pipeline("Assay", c(99.1, 98.7)),
    Water = test_pipeline("Water", c(0.4, NA))
)
for (p in tests) {
    suppressWarnings(
        pipeflow::pip_run(p, lgr = NULL, on_error = "continue")
    )
}

pub_out(tests$Assay, "content")
#> [1] "Mean: 98.90"
try(pub_out(tests$Water, "content"))
#> Error in pub_out(tests$Water, "content") : 
#>   The output of step 'content' of pipeline 'Water' is not up to date (state "new").
#> ✖ Step 'mean' failed: missing values

# One section per test; the failed one shows an error box
parts <- lapply(tests, pub_out, step = "content", on_error = "item")
pub_doc(parts, title = "Tests")
#> <pubflow document> "Tests"
#> # Assay
#>   text "Mean: 98.90"
#> # Water
#>   error "step 'mean' of pipeline 'Water' failed: missing values"
```
