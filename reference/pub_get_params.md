# Get the param objects of a pipeline

Returns the params stored in a pipeline or view as a named list, e.g. to
build a parameter UI. If a name occurs in several steps, the first
occurrence that is a param counts. So, unlike
[`pipeflow::pip_get_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html),
a plain default of an earlier step does not hide the param of a later
step (see Examples).

## Usage

``` r
pub_get_params(x, ..., order = c("config", "pipeline"))
```

## Arguments

- x:

  A pipeflow pipeline or view.

- ...:

  Optional named arguments that filter the params by their attributes,
  e.g. `source = "user"` keeps the params with exactly that source.
  Several filters are combined with "and", that is, a param is kept only
  if it matches all of them, e.g. `source = "user", area = "analysis"`
  keeps the *user* params of the *analysis* area. `NULL` keeps the
  params without the attribute (`source = NULL`: params with no
  `source`). No filter keeps all params. See also "Parameter filters" in
  the Examples.

- order:

  `"pipeline"`: order of first use in the pipeline. `"config"`: order of
  the config (attribute `order`); params without it follow in pipeline
  order.

## Value

Named list of param objects; names that the pipeline holds only as plain
values are left out.

## Details

### Order

The params are listed in the order in which the pipeline first uses
their names, also as plain defaults. With `order = "config"` they follow
the order of their config instead (see
[`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md)).

### Setting params

Set values with
[`pipeflow::pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html).
pubflow extends it as follows:

- A *plain value* is merged into the param stored in each step (label,
  choices and validity are kept) and checked.

- A *param object* replaces the stored one (and is checked too).

- Steps that store a plain value get the plain value.

- If any value is *invalid* or can't be merged (e.g. a group value
  without the names of the children), nothing is set and one error
  (`pipeflow_set_params_error`) lists all problems in its field
  `errors`, a data.frame with columns `step`, `name` and `message`.

- `validate = FALSE` skips the validity check.

Some hints:

- Apply a *config*, e.g. at the end of a pipeline constructor, with
  `pip_set_params(x, config, unknown = "error")`. The last argument
  catches names the pipeline does not know.

- *Inside a step*, `pip_set_params(.self, ...)` can be used to set
  derived params for later steps.

- *On a view*, you can set the params of the view's steps. The values
  still go to every step of the pipeline that has them, unless
  `scope = "view"` is used, which updates only the view's steps. Note
  that in the latter case, steps outside the view keep their old values,
  so the same param may hold different values in different steps.

- After *combining pipelines* with
  [`rbind()`](https://rdrr.io/r/base/cbind.html), steps also may hold
  different objects of the same name (pipeflow warns if their values
  differ). To end up with one definition per name, apply the merged
  configs, in which the first (more specific) definition wins:
  `param_config(..., .duplicates = "first")`.

### Defaults of step functions

Step functions (added with
[`pipeflow::pip_add()`](https://rpahl.github.io/pipeflow/reference/pip_add.html))
are always defined with plain defaults, e.g. `\(x = 1)` and not
`\(x = numeric_param(1))`. The param config is then applied on top, so
the steps hold the param objects. This means that for a choice, the
plain default is a factor that must carry the choice levels, e.g.
`factor("none", levels = c("none", "log"))`.

- pipeflow warns (`pipeflow_param_conflict`) if you add or replace a
  step with a default that clashes with the value in existing steps,
  e.g. `pip_add(p, "new_step", \(x = 2) ...)` while other steps have
  `x = 1`.

- [`pipeflow::pip_replace()`](https://rpahl.github.io/pipeflow/reference/pip_replace.html)
  takes the params from the new function's arguments. To keep the param
  objects and their current values, use `keep_params = TRUE`.

### Locked params

Param UIs show params with a `locked = TRUE` attribute (e.g. fixed by a
config) as disabled inputs.
[`pub_pipeline_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)
also disables the params that belong to locked steps (see
[`pipeflow::pip_lock()`](https://rpahl.github.io/pipeflow/reference/pip_lock.html)),
as a change could not reach them. See also "Locked params" in
[`pub_params_ui()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md).

## See also

[`pipeflow::pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html),
[`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md),
[`pub_params_table()`](https://rpahl.github.io/pubflow/reference/pub_params_table.md),
[`pub_pipeline_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)

## Examples

``` r
p <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("prep", \(yUnit = "") yUnit) |>
    pipeflow::pip_add("plot", \(ylab = "y", yUnit = "") paste(ylab, yUnit))
cfg <- param_config(
    ylab = param("Response", label = "y-axis label", source = "user"),
    yUnit = param("%", label = "Unit", source = "user")
)
# Set in step 'plot' only, so the plain default of step 'prep' comes first
pipeflow::pip_set_params(pipeflow::pip_view(p, step = "plot"), cfg, scope = "view")

pipeflow::pip_get_params(p)$yUnit  # plain default of step 'prep'
#> [1] ""
pub_get_params(p)$yUnit            # param object of step 'plot'
#> param<character>: %
#>   label: Unit
#>   source: user
#>   order: 2
#>   validity: <function>


# Parameter filters: keep the params whose attributes match
p <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("fit", \(level = 0.95, xVar = "x", nMin = 3) level)
pipeflow::pip_set_params(p, param_config(
    level = numeric_param(0.95, label = "Level", source = "user",
                          area = "analysis"),
    xVar = param("x", label = "Predictor", source = "data", area = "analysis"),
    nMin = numeric_param(3, label = "Minimum n", source = "internal")
))
names(pub_get_params(p, source = "user"))
#> [1] "level"
names(pub_get_params(p, area = "analysis"))
#> [1] "level" "xVar" 
names(pub_get_params(p, source = "data", area = "analysis"))  # all must match
#> [1] "xVar"
names(pub_get_params(p, area = NULL))  # params without an area
#> [1] "nMin"


# Setting merges plain values into the params and validates them
p <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("fit", \(alpha = 0.05,
                               method = factor("a", c("a", "b"))) {
        paste(alpha, method)
    })
pipeflow::pip_set_params(p, param_config(
    alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1),
    method = choice_param("a", choices = c("a", "b"), label = "Method")
), unknown = "error")
pipeflow::pip_set_params(p, list(alpha = 0.1, method = "b"))
pub_get_params(p)$method
#> param<factor>: <factor[1]: b>
#>   levels: a, b
#>   label: Method
#>   order: 2
#>   validity: <function>

err <- tryCatch(
    pipeflow::pip_set_params(p, list(alpha = 2, method = "c")),
    pipeflow_set_params_error = identity
)
err$errors
#>   step   name                                     message
#> 1  fit  alpha value must be less than or equal to max (1)
#> 2  fit method                  value must be one of: a, b


# A pipeline with the same param in two steps, used in the next examples
make_pipeline <- function() {
    pipeflow::pip_new("demo") |>
        pipeflow::pip_add("fit", \(alpha = 0.05, level = 0.95) alpha) |>
        pipeflow::pip_add("plot", \(alpha = 0.05) alpha) |>
        pipeflow::pip_set_params(
            param_config(
                alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 1),
                level = numeric_param(0.95, label = "Level", locked = TRUE)
            ),
            unknown = "error"
        )
}
alpha_values <- function(p) {
    vapply(pipeflow::pip_get_params(p, simplify = FALSE)$alpha, as.numeric, 1)
}


# A view: values go to every step that has the param, unless scope = "view"
p <- make_pipeline()
plot_view <- pipeflow::pip_view(p, step = "plot")
pipeflow::pip_set_params(plot_view, list(alpha = 0.1))
alpha_values(p)
#>  fit plot 
#>  0.1  0.1 
pipeflow::pip_set_params(plot_view, list(alpha = 0.2), scope = "view")
alpha_values(p)
#>  fit plot 
#>  0.1  0.2 


# Replacing a step: keep_params = TRUE keeps the param objects and their values
p <- make_pipeline()
pipeflow::pip_set_params(p, list(alpha = 0.2))
new_plot <- \(alpha = 0.05) alpha * 2
kept <- pipeflow::pip_replace(p, "plot", new_plot, keep_params = TRUE)
alpha_values(kept)
#>  fit plot 
#>  0.2  0.2 

p <- make_pipeline()
pipeflow::pip_set_params(p, list(alpha = 0.2))
replaced <- suppressWarnings(pipeflow::pip_replace(p, "plot", new_plot))
alpha_values(replaced)  # the plain default of the new function
#>  fit plot 
#> 0.20 0.05 


# Locked params and steps: the Shiny module shows both as disabled inputs
p <- make_pipeline()
names(pub_get_params(p, locked = TRUE))
#> [1] "level"

# pip_set_params() skips locked steps, so the values would drift apart
pipeflow::pip_lock(pipeflow::pip_view(p, step = "fit"))
pipeflow::pip_set_params(p, list(alpha = 0.3))
alpha_values(p)
#>  fit plot 
#> 0.05 0.30 
```
