# Layout step with one section per view

Makes the function of a layout step (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
whose document has one section per view: the section is titled by the
name of the view and shows the outputs of the steps of the view, in
pipeline order. Select the steps of each section with
[`pipeflow::pip_view()`](https://rpahl.github.io/pipeflow/reference/pip_view.html),
e.g. by a tag naming the section or by the steps that depend on a model
fit. Add the layout step with
[`pipeflow::pip_add()`](https://rpahl.github.io/pipeflow/reference/pip_add.html)
(see Examples).

## Usage

``` r
pub_layout_sections(sections)
```

## Arguments

- sections:

  Named list of pipeflow views of one pipeline, one per section, named
  by the section titles. The views must not contain other layout steps
  (a document can't be part of a document).

## Value

A function for
[`pipeflow::pip_add()`](https://rpahl.github.io/pipeflow/reference/pip_add.html).
It takes the outputs of the steps of the views (`~try(step)`) and
returns a
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md).

## Details

This is a ready-made layout on top of
[`pub_layout_inputs()`](https://rpahl.github.io/pubflow/reference/pub_layout_inputs.md),
which gives the inputs for a layout function you write yourself (e.g.
one section per step). The inputs behave as there: running the layout
step runs only the steps it needs, a failed input is shown as an error
box in its section, the steps are read when `pub_layout_sections()` is
called (so add the layout step last), and partitioned outputs together
with other outputs need `exec = "reduce"`.

A step in several views appears in each of their sections (not a table
or figure with an `id`, which must be unique in a document). A section
whose outputs are all `NULL` is left out (see `on_empty` of
[`pub_section()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)),
so a step can leave its section out by returning `NULL`, e.g. if a param
switches it off.

## See also

[`pub_layout_inputs()`](https://rpahl.github.io/pubflow/reference/pub_layout_inputs.md)
for other layouts.

## Examples

``` r
p <- pipeflow::pip_new("ozone") |>
    pipeflow::pip_add("data", \(month = 5) {
        subset(airquality, Month == month, select = c(Day, Ozone, Temp))
    }) |>
    pipeflow::pip_add("table", \(data = ~data) {
        pub_table(head(data), caption = "First days")
    }, tags = "Data") |>
    pipeflow::pip_add("fit", \(data = ~data) {
        stats::lm(Ozone ~ Temp, data = data)
    }) |>
    pipeflow::pip_add("slope", \(fit = ~fit, show_model = param(TRUE)) {
        if (!show_model) {
            return(NULL)
        }
        pub_format_num(stats::coef(fit)[["Temp"]], "Slope: %.2f ppb per degree F")
    })

layout <- pub_layout_sections(list(
    Data = pipeflow::pip_view(p, tags = "Data"),
    Model = pipeflow::pip_view(p, depends = "fit")
))
pipeflow::pip_add(p, "doc", layout)
pipeflow::pip_run(p, lgr = NULL)
p[["doc", "out"]]
#> <pubflow document>
#> # Data
#>   table "First days"
#> # Model
#>   text "Slope: 1.88 ppb per degree F"

# The model section is left out if its only step returns NULL
pipeflow::pip_set_params(p, list(show_model = FALSE))
pipeflow::pip_run(p, lgr = NULL)
p[["doc", "out"]]
#> <pubflow document>
#> # Data
#>   table "First days"
```
