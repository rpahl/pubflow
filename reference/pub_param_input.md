# Input widget for a param

Builds the Shiny input widget of a param, e.g. for your own layouts. The
parameter module
([`pub_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md))
uses it for every row of its parameter table.

## Usage

``` r
pub_param_input(
  x,
  inputId,
  label = param_attr(x, "label"),
  tooltip = FALSE,
  ...
)
```

## Arguments

- x:

  A param object.

- inputId:

  `character(1)` input id (namespaced by the caller, e.g. with `ns()` in
  a Shiny module).

- label:

  Label of the input; `NULL` for none.

- tooltip:

  `TRUE`: show the param's description as tooltip.

- ...:

  Further arguments for the widget function; those it does not accept
  are dropped automatically.

## Value

A Shiny tag (with pubflow's HTML dependency attached).

## Details

### Choosing the widget

The widget depends on the type of the value
([`param_type()`](https://rpahl.github.io/pubflow/reference/is_param.md)).
Choose another one with the param attribute `ui_widget`, either a widget
name or a function:

|           |                |               |
|-----------|----------------|---------------|
| Type      | Default widget | Other widgets |
| character | `"text"`       |               |
| factor    | `"select"`     | `"radio"`     |
| logical   | `"switch"`     |               |
| numeric   | `"numeric"`    | `"slider"`    |

The widgets are
[`shiny::textInput()`](https://rdrr.io/pkg/shiny/man/textInput.html),
[`shiny::selectInput()`](https://rdrr.io/pkg/shiny/man/selectInput.html),
[`shinyWidgets::radioGroupButtons()`](https://rdrr.io/pkg/shinyWidgets/man/radioGroupButtons.html),
[`shinyWidgets::prettySwitch()`](https://rdrr.io/pkg/shinyWidgets/man/prettySwitch.html),
[`shiny::numericInput()`](https://rdrr.io/pkg/shiny/man/numericInput.html)
and
[`shiny::sliderInput()`](https://rdrr.io/pkg/shiny/man/sliderInput.html).
Other types need `ui_widget`.

A [`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
gives the inputs of its children side by side, with the input ids
`<inputId>_<child>`. Their labels (else their names) are for screen
readers only; the group's label names the group as a whole. Its children
can't be groups. A `width` in `...` is the width of the whole group: the
children share it equally.

### Widget arguments

The param's value and attributes are passed to the widget function as
follows:

|             |                                                             |
|-------------|-------------------------------------------------------------|
| Widget      | Arguments from the param                                    |
| `"text"`    | `value`                                                     |
| `"switch"`  | `value`                                                     |
| `"select"`  | `choices` (the levels), `selected` (the current level)      |
| `"radio"`   | `choices` (the levels), `selected` (the current level)      |
| `"numeric"` | `value`, `min`, `max`, `step`                               |
| `"slider"`  | `value` (one value or a range of two), `min`, `max`, `step` |

`min` and `max` are the param's attributes of that name (unset: no
bound). Without a `step` attribute, `step` is a tenth of the range if
both bounds are finite. A slider needs finite `min` and `max`.

You can change these arguments:

- Arguments in `...` override those derived from the param.

- Only arguments that the widget function accepts are passed, so `...`
  can hold arguments for some widgets only (e.g. `updateOn` or `width`).

- The param attribute `ui_args` (a named list) overrides all of them,
  e.g. `ui_args = list(multiple = TRUE)` for a select input with
  multiple choices.

- The CSS in the param attribute `ui_style` applies to the input.

### Locked params

A param with `locked = TRUE` (for a group: the group's attribute) gives
a disabled input. It shows the value, but can't be changed, e.g. for a
param that a workflow fixes. The tooltip adds "(locked)". This also
works for widgets given as `ui_widget`.

### Tooltip

With `tooltip = TRUE` the input shows the param's `description` on hover
(after 1.5 s, hidden after 7 s) and when it gets the keyboard focus
(hidden on Escape). Without a description it shows the `label`;
`description = ""` turns the tooltip off. This works with Bootstrap 3
and 5 and needs pubflow's JavaScript, which `pub_param_input()` attaches
as an HTML dependency.

## See also

[`pub_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)

## Examples

``` r
alpha <- numeric_param(0.05, label = "Alpha", min = 0, max = 1)
pub_param_input(alpha, "alpha", updateOn = "blur")
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="alpha-label" for="alpha">Alpha</label>
#>   <input id="alpha" type="number" class="shiny-input-number form-control" value="0.05" data-update-on="blur" min="0" max="1" step="0.1"/>
#> </div>

trans <- choice_param("log", choices = c("none", "log"), label = "Scale")
pub_param_input(trans, "trans")
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="trans-label" for="trans">Scale</label>
#>   <div>
#>     <select id="trans" class="shiny-input-select"><option value="none">none</option>
#> <option value="log" selected>log</option></select>
#>     <script type="application/json" data-for="trans" data-nonempty="">{"plugins":["selectize-plugin-a11y"]}</script>
#>   </div>
#> </div>

# Another widget by name: the attribute `ui_widget` belongs to the param
trans <- choice_param(
    "log",
    choices = c("none", "log"),
    label = "Scale",
    ui_widget = "radio"
)
pub_param_input(trans, "trans")
#> <div class="form-group shiny-input-container shiny-input-radiogroup shiny-input-container-inline">
#>   <label class="control-label" id="trans-label" for="trans">Scale</label>
#>   <br/>
#>   <div id="trans" class="radio-group-buttons">
#>     <div aria-labelledby="trans-label" class="btn-group btn-group-container-sw" data-toggle="buttons" role="group">
#>       <div class="btn-group btn-group-toggle" role="group">
#>         <button class="btn radiobtn btn-default">
#>           <input type="radio" autocomplete="off" name="trans" value="none"/>
#>           none
#>         </button>
#>       </div>
#>       <div class="btn-group btn-group-toggle" role="group">
#>         <button class="btn radiobtn btn-default active">
#>           <input type="radio" autocomplete="off" name="trans" value="log" checked="checked"/>
#>           log
#>         </button>
#>       </div>
#>     </div>
#>   </div>
#> </div>

# A slider for a single value or, with two values, for a range
level <- numeric_param(0.5, label = "Level", min = 0, max = 1, ui_widget = "slider")
pub_param_input(level, "level")
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="level-label" for="level">Level</label>
#>   <input class="js-range-slider" id="level" data-skin="shiny" data-min="0" data-max="1" data-from="0.5" data-step="0.1" data-grid="true" data-grid-num="10" data-grid-snap="false" data-prettify-separator="," data-prettify-enabled="true" data-keyboard="true" data-data-type="number"/>
#> </div>
range <- numeric_param(
    c(0.2, 0.8),
    label = "Range",
    min = 0,
    max = 1,
    ui_widget = "slider"
)
pub_param_input(range, "range")
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="range-label" for="range">Range</label>
#>   <input class="js-range-slider" id="range" data-skin="shiny" data-type="double" data-min="0" data-max="1" data-from="0.2" data-to="0.8" data-step="0.1" data-grid="true" data-grid-num="10" data-grid-snap="false" data-prettify-separator="," data-prettify-enabled="true" data-keyboard="true" data-drag-interval="true" data-data-type="number"/>
#> </div>

# Your own widget function: it gets the arguments from the table above that it
# accepts, here `inputId`, `label` and `value`
notes <- param(
    "Some notes",
    label = "Notes",
    ui_widget = function(inputId, label, value) {
        shiny::textAreaInput(inputId, label, value, rows = 3)
    }
)
pub_param_input(notes, "notes")
#> <div class="shiny-input-textarea form-group shiny-input-container">
#>   <label class="control-label" id="notes-label" for="notes">Notes</label>
#>   <textarea id="notes" class="form-control" rows="3" data-update-on="change">Some notes</textarea>
#> </div>

# `ui_args` adds or overrides widget arguments, `ui_style` adds CSS
picks <- choice_param(
    "a",
    choices = c("a", "b", "c"),
    label = "Pick",
    ui_args = list(multiple = TRUE),
    ui_style = "width: 12em;"
)
pub_param_input(picks, "picks")
#> <style>#picks {width: 12em;}</style>
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="picks-label" for="picks">Pick</label>
#>   <div>
#>     <select id="picks" class="shiny-input-select" multiple="multiple"><option value="a" selected>a</option>
#> <option value="b">b</option>
#> <option value="c">c</option></select>
#>     <script type="application/json" data-for="picks">{"plugins":["selectize-plugin-a11y"]}</script>
#>   </div>
#> </div>

points <- param(TRUE, label = "Show points", description = "Plot the data")
pub_param_input(points, "points", tooltip = TRUE)
#> <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" title="Plot the data">
#>   <div class="pretty p-default p-switch">
#>     <input id="points" type="checkbox" checked="checked"/>
#>     <div class="state">
#>       <label>
#>         <span>Show points</span>
#>       </label>
#>     </div>
#>   </div>
#> </div>

limits <- param_group(
    list(
        lower = numeral_param("95", label = "Lower CI"),
        upper = numeral_param("105", label = "Upper CI")
    ),
    label = "Confidence limits"
)
pub_param_input(limits, inputId = "ci_limits", width = "10ch")
#> <div class="form-group shiny-input-container">
#>   <label class="control-label" id="ci_limits-param-label">Confidence limits</label>
#>   <div class="pubflow-param-group" role="group" aria-labelledby="ci_limits-param-label" style="width:10ch;">
#>     <div class="pubflow-param-item">
#>       <label class="pubflow-visually-hidden" for="ci_limits_lower">Lower CI</label>
#>       <div class="form-group shiny-input-container" style="width:100%;">
#>         <label class="control-label shiny-label-null" for="ci_limits_lower" id="ci_limits_lower-label"></label>
#>         <input id="ci_limits_lower" type="text" class="shiny-input-text form-control" value="95" data-update-on="change"/>
#>       </div>
#>     </div>
#>     <div class="pubflow-param-item">
#>       <label class="pubflow-visually-hidden" for="ci_limits_upper">Upper CI</label>
#>       <div class="form-group shiny-input-container" style="width:100%;">
#>         <label class="control-label shiny-label-null" for="ci_limits_upper" id="ci_limits_upper-label"></label>
#>         <input id="ci_limits_upper" type="text" class="shiny-input-text form-control" value="105" data-update-on="change"/>
#>       </div>
#>     </div>
#>   </div>
#> </div>

# A locked param is shown, but can't be changed
level <- numeric_param(0.95, label = "Level", min = 0, max = 1, locked = TRUE)
pub_param_input(level, "level")
#> <div class="pubflow-param-locked">
#>   <fieldset class="pubflow-param-fieldset" disabled>
#>     <div class="form-group shiny-input-container">
#>       <label class="control-label" id="level-label" for="level">Level</label>
#>       <input id="level" type="number" class="shiny-input-number form-control" value="0.95" data-update-on="change" min="0" max="1" step="0.1" disabled/>
#>     </div>
#>   </fieldset>
#> </div>
```
