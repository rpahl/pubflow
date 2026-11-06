# Parameter UI module

A Shiny module that shows a compact table with one input per param
([`pub_param_input()`](https://rpahl.github.io/pubflow/reference/pub_param_input.md))
and checks every change with the validity functions of the params
([`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)).

## Usage

``` r
pub_params_ui(id)

pub_params_server(
  id,
  params,
  on_invalid = c("restore", "keep"),
  update_on = c("blur", "change"),
  group_by = "area",
  group_labels = NULL,
  width = "15ch",
  tooltips = TRUE,
  reset = FALSE
)

pub_pipeline_params_server(
  id,
  pip,
  on_invalid = c("restore", "keep"),
  update_on = c("blur", "change"),
  group_by = "area",
  group_labels = NULL,
  width = "15ch",
  tooltips = TRUE,
  reset = FALSE,
  filter = list(),
  refresh = NULL
)
```

## Arguments

- id:

  `character(1)` module id, the same as in `pub_params_ui()`.

- params:

  A reactive returning a named list (or
  [`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md))
  of param objects.

- on_invalid:

  `"restore"`: an invalid input gets back the last valid value;
  `"keep"`: it keeps the invalid value and `valid()` is `FALSE`.

- update_on:

  `"blur"`: text and numeric inputs report a change on blur or Enter;
  `"change"`: on every keystroke (after a short delay).

- group_by:

  `character(1)` name of the attribute that groups the params, or
  `NULL`.

- group_labels:

  Named character vector or list of group headings, e.g.
  `c(analysis = "Analysis parameters", report = "Report parameters")`.

- width:

  Width of the inputs (CSS), e.g. `"15ch"`, or `NULL`. The inputs of a
  [`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
  share it.

- tooltips:

  `TRUE`: show the description of a param as tooltip of its input.

- reset:

  `TRUE`: add a button that sets all inputs back to their initial values
  (see "Resetting values").

- pip:

  A pipeflow pipeline or view, or a reactive returning one.

- filter:

  Optional named list of attribute filters that is passed to
  [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md),
  e.g., `list(source = "user")` is called with
  `pub_get_params(pip, source = "user")`. The default
  [`list()`](https://rdrr.io/r/base/list.html) shows all params of the
  pipeline. See "Parameter filters" in the examples of
  [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md).

- refresh:

  `NULL` or a reactive: whenever it fires, the params are read again
  from the pipeline. Use it after code outside the module changed the
  pipeline.

## Value

- `pub_params_ui()`: a tag list with the container of the table and
  pubflow's HTML dependency (JavaScript and CSS).

- `pub_params_server()`: a list of reactives:

  - `values`: named list of the current valid plain values (`NULL`
    before the params are available);

  - `changed`: named list of the values that changed (and are valid)
    with the latest change; `NULL` before the first change;

  - `valid`: `TRUE` if no input holds an invalid value (only `FALSE`
    with `on_invalid = "keep"`).

- `pub_pipeline_params_server()`: the same as `pub_params_server()`
  plus:

  - `revision`: an integer that goes up by one whenever the module has
    updated the params in the pipeline (that is,
    [`pipeflow::pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
    succeeded). Usually, it is used to trigger a pipeline run that
    updates the results.

## Details

### Functions

- `pub_params_ui()` is the UI part: place it where the table should
  appear.

- `pub_params_server()` takes a reactive that returns the params, e.g. a
  [`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md).

- `pub_pipeline_params_server()` reads the params from a pipeline with
  [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)
  and sets every valid change in the pipeline with
  [`pipeflow::pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
  (see "Setting params" in
  [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)).

Given a view, e.g. `pipeflow::pip_view(p, tags = "analysis")`,
`pub_pipeline_params_server()` shows the params of the view's steps
only. It sets their values in every step of the pipeline that has them,
also outside the view, so that a param keeps one value.

### Layout

- The rows follow the order of the config (attribute `order`, see
  [`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md)),
  then the given order.

- If more than one value of the attribute `group_by` occurs, each group
  gets a heading (from `group_labels`, else the value). Params without
  the attribute come under "Other".

- Params with `advanced = TRUE` go into a collapsed "Advanced" block of
  their group.

- Input ids are `ns(<name>)`, for param groups `ns(<name>_<child>)`.

### Updates

The table is only rendered again if the structure of the params changes
(names, types, choices or attributes other than the validity functions,
also `locked`). If only values change, e.g. after a data-derived value
was set in the pipeline, the inputs are updated in place.

### Validation

Text and numeric inputs report their value on blur or Enter
(`update_on = "blur"`), other inputs immediately. The value is converted
to the type of the param (an empty numeric input becomes `NA`) and
validated:

- A valid value is emitted in `changed` and `values`.

- An invalid value is shown next to the input (the first message, for
  about 3 s) and the input glows. The message
  `"'<label>' input: <message>"` is also logged with
  [`message()`](https://rdrr.io/r/base/message.html) as an audit trail.
  What happens to the input depends on `on_invalid`:

  - `"restore"`: it gets back its last valid value;

  - `"keep"`: it keeps the invalid value, which does not reach `values`,
    and `valid()` is `FALSE` until the input is valid again.

- If a param group fails its own rule (e.g. lower limit below upper
  limit, see
  [`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)),
  the child input that was changed is marked.

### Locked params

Params with `locked = TRUE` are shown as disabled inputs (see
[`pub_param_input()`](https://rpahl.github.io/pubflow/reference/pub_param_input.md)),
so their values only come from `params()`.

- The server ignores changes of their inputs (logged as
  `"'<label>' input: locked, change ignored"`) and the input gets back
  its value.

- The reset button leaves them alone.

- `pub_pipeline_params_server()` also locks the params of a locked step
  ([`pipeflow::pip_lock()`](https://rpahl.github.io/pipeflow/reference/pip_lock.html)),
  also a step outside the view:
  [`pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
  skips locked steps, so a change would leave the steps of the same name
  with different values. New step locks are noticed when the params are
  read again (`refresh`).

### Resetting values

With `reset = TRUE` a button sets all inputs back to their initial
values: the values in `params()`. Locked params are left alone.

- If `params()` returns new values (e.g. data-derived defaults after a
  run), these are the new initial values.

- Values that only come back from the pipeline after a change by the
  user (with `refresh`, or after it rejected a value) are not new
  initial values, so the button still restores the values from before
  the user's changes.

- If the validity rules of a param changed in the meantime and its
  initial value no longer passes them, that input is not reset. The user
  sees the validity message, as for a rejected input, and the input
  keeps its value. E.g. the user set `n` from 1 to 2, then `params()`
  gave `n` a new rule "at least 2" with the same value 2: the reset to 1
  would break it.

### Rejected values

If
[`pipeflow::pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
fails (`pipeflow_set_params_error`, e.g. because the pipeline holds
stricter params than the ones read before), the input is treated like an
invalid one and shows the pipeline's value again.

## See also

[`pub_param_input()`](https://rpahl.github.io/pubflow/reference/pub_param_input.md),
[`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)

## Examples

``` r
cfg <- param_config(
    alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 0.5,
                          area = "analysis"),
    trans = choice_param("none", choices = c("none", "log"),
                         label = "Transformation", area = "analysis"),
    title = param("Report", label = "Title", area = "report")
)

ui <- shiny::fluidPage(
    shiny::sidebarLayout(
        shiny::sidebarPanel(pub_params_ui("params")),
        shiny::mainPanel(shiny::verbatimTextOutput("values"))
    )
)
server <- function(input, output, session) {
    params <- pub_params_server("params", shiny::reactive(cfg),
                                reset = TRUE)
    output$values <- shiny::renderPrint(str(params$values()))
}
if (interactive()) shiny::shinyApp(ui, server)

# Parameters of a pipeline
pip <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("fit", \(alpha = 0.05) alpha)
pipeflow::pip_set_params(pip, param_config(
    alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 0.5,
                          source = "user")
), unknown = "error")
server <- function(input, output, session) {
    params <- pub_pipeline_params_server("params", pip)
    output$values <- shiny::renderPrint({
        params$revision()
        pipeflow::pip_run(pip, lgr = NULL)
        pip[["fit", "out"]]
    })
}
if (interactive()) shiny::shinyApp(ui, server)
```
