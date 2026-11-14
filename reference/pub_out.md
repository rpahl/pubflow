# Get up-to-date step outputs from outside pipelines

Returns the output of a step like `x[[step, "out"]]`, but only if the
step is "done", i.e. up to date in its own pipeline. Otherwise, it
signals an error or returns an error item (see `on_error`).

In a single pipeline, a *layout step* arranges the outputs of other
steps into a document with
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md), and
pipeflow handles inputs that failed or are outdated. When a document
combines the outputs of several pipelines that are run separately,
nothing does. `pub_out()` closes that gap, so that error objects, old
results or missing outputs never end up in a document.

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

### Steps that are not done

- A step that **failed** (state `"failed"`): its output is the error
  condition.

- A step **skipped** because a step it depends on failed (state
  `"outdated"` or `"new"`): it keeps its earlier output or has none.

- A step that **did not run yet** after a change, e.g. of its parameters
  or of a step it depends on (state `"outdated"`), or that was just
  added (state `"new"`): it keeps its earlier output or has none.

### What `pub_out()` does then

- `on_error = "stop"`: an error of class `pubflow_not_done` names the
  pipeline, the step, its state and the failed steps it depends on.

- `on_error = "item"`: for the first two cases, an *error item* is
  returned. A document shows it as an error box, like a failed input of
  a layout step (see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
  while
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  refuses it unless the report spec allows error items. The third case
  is always an error, as no failure is involved.

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
mean_pipeline <- function(name, values) {
    pipeflow::pip_new(name) |>
        pipeflow::pip_add("data", \(values = 1) values) |>
        pipeflow::pip_add("mean", \(x = ~data) {
            if (anyNA(x)) stop("missing values")
            mean(x)
        }) |>
        pipeflow::pip_add("content", \(m = ~mean) {
            pub_text(paste("Mean:", pub_format_num(m, 1)))
        }) |>
        pipeflow::pip_set_params(list(values = values))
}
# Ozone has missing values, so its mean fails
measures <- list(
    Temperature = mean_pipeline("Temperature", airquality$Temp),
    Ozone = mean_pipeline("Ozone", airquality$Ozone)
)
for (p in measures) {
    suppressWarnings(
        pipeflow::pip_run(p, lgr = NULL, on_error = "continue")
    )
}

pub_out(measures$Temperature, "content")
#> [1] "Mean: 77.9"
try(pub_out(measures$Ozone, "content"))
#> Error in pub_out(measures$Ozone, "content") : 
#>   The output of step 'content' of pipeline 'Ozone' is not up to date (state "new").
#> ✖ Step 'mean' failed: missing values

# One section per measure; the failed one shows an error box
parts <- lapply(measures, pub_out, step = "content", on_error = "item")
pub_doc(parts, title = "Means")
#> <pubflow document> "Means"
#> # Temperature
#>   text "Mean: 77.9"
#> # Ozone
#>   error "step 'mean' of pipeline 'Ozone' failed: missing values"
```
