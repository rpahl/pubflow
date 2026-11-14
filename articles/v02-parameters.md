# Parameters

[Get
started](https://rpahl.github.io/pubflow/articles/v01-get-started.md)
introduced params with three examples. This vignette goes deeper: what a
param holds, how its rules work, how params are grouped into configs and
set in a pipeline, and how they appear in a document. It builds on
pipeflow’s vignettes [Annotated parameter
values](https://cran.r-project.org/package=pipeflow/vignettes/v05d-param-value.html)
(the hook that pubflow’s params use) and [Pipeline
views](https://cran.r-project.org/package=pipeflow/vignettes/v03b-pipeline-views.html).

\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pipeflow`](https://rpahl.github.io/pipeflow/)`)`\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pubflow`](https://rpahl.github.io/pubflow/)`)`

### A param is a value with attributes

A param is a value together with attributes that describe it. The
functions of a pipeline never see the attributes, they get the plain
value.

\
`xVar`` ``<-`` `[`choice_param`](https://rpahl.github.io/pubflow/reference/param.md)`(`\
`    ``"Temp.Celsius"``,`\
`    choices ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``"Temp.Celsius"``, ``"Wind"``, ``"Solar.R"``)``,`\
`    label ``=`` ``"Predictor"``,`\
`    description ``=`` ``"Variable that explains the ozone concentration"``,`\
`    source ``=`` ``"user"`\
`)`\
`xVar`\
`# param<factor>: <factor[1]: Temp.Celsius>`\
`#   levels: Temp.Celsius, Wind, Solar.R`\
`#   label: Predictor`\
`#   description: Variable that explains the ozone concentration`\
`#   source: user`\
`#   validity: <function>`

The accessors read the value and the attributes:

\
[`param_value`](https://rpahl.github.io/pubflow/reference/param_value.md)`(``xVar``)`\
`# [1] Temp.Celsius`\
`# Levels: Temp.Celsius Wind Solar.R`\
[`param_type`](https://rpahl.github.io/pubflow/reference/is_param.md)`(``xVar``)`\
`# [1] "factor"`\
[`param_attr`](https://rpahl.github.io/pubflow/reference/param_attr.md)`(``xVar``, ``"label"``)`\
`# [1] "Predictor"`

Base functions work on a param as on its value, so `xVar == "Wind"` and
`levels(xVar)` work as expected. Note that
`identical(xVar, "Temp.Celsius")` is `FALSE`, because the attributes are
part of the object. Hand
[`param_value()`](https://rpahl.github.io/pubflow/reference/param_value.md)
to code that expects a plain value.

Besides `label` and `description`, pubflow knows the attributes `source`
(e.g. `"user"` for the params that the user sets), `area` (a group of
params), `advanced` (shown in a collapsed block), `locked` (shown as a
disabled input, see [Locked params](#locked-params)) and a few more for
the UI. Any other named argument is stored as well.
[`?param`](https://rpahl.github.io/pubflow/reference/param.md) lists all
of them.

### Constructors and validity

Each constructor comes with a rule that tells whether a value is valid.
[`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
applies it to the param’s own value or to any other value and returns
one message per rule, `""` meaning valid:

\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``xVar``)`\
`# [1] ""`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``xVar``, value ``=`` ``"Height"``)`\
`# [1] "value must be one of: Temp.Celsius, Wind, Solar.R"`\
\
`level`` ``<-`` `[`numeric_param`](https://rpahl.github.io/pubflow/reference/param.md)`(`\
`    ``0.95``,`\
`    label ``=`` ``"Confidence level"``,`\
`    min ``=`` ``0.5``,`\
`    max ``=`` ``0.999``,`\
`    source ``=`` ``"user"`\
`)`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``level``, value ``=`` ``1.5``)`\
`# [1] "value must be less than or equal to max (0.999)"`

[`numeral_param()`](https://rpahl.github.io/pubflow/reference/param.md)
is for numbers that must keep their decimal places. A number like `0.90`
is `0.9` as soon as it is a number; a numeral holds the text and checks
that it can be read as a number, in the given bounds:

\
`limit`` ``<-`` `[`numeral_param`](https://rpahl.github.io/pubflow/reference/param.md)`(``"80.0"``, label ``=`` ``"Ozone limit (ppb)"``, min ``=`` ``0``)`\
[`param_value`](https://rpahl.github.io/pubflow/reference/param_value.md)`(``limit``)`\
`# [1] "80.0"`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``limit``, value ``=`` ``"abc"``)`\
`# [1] "value was not coercible to numeric"`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``limit``, value ``=`` ``"-5"``)`\
`# [1] "value must be greater than or equal to min (0)"`

To add a rule of your own, use
[`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md).
A rule is a function that takes the plain value and returns `""` or a
message. It is used in addition to the default rule:

\
`level`` ``<-`` `[`add_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``level``, \``(``x``)`` ``{`\
`    ``if`` ``(``x`` ``!=`` ``0.5``)`` ``""`` ``else`` ``"a level of 0.5 is not allowed"`\
`}``)`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``level``, value ``=`` ``0.5``)`\
`# [1] ""                              "a level of 0.5 is not allowed"`

A rule that fails with an error counts as a message too, so a faulty
rule never breaks a parameter UI. Own constructors for recurring kinds
of params, which wrap one of the above, are shown in the examples of
[`?param`](https://rpahl.github.io/pubflow/reference/param.md).

### Groups

[`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
combines params that belong together, here the range of temperatures
that the analysis uses. The group is shown side by side in a UI and
checked as a whole: each child by its own rule and the group by rules
that see all children. Such a rule is added with
[`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
as well:

\
`window`` ``<-`` `[`param_group`](https://rpahl.github.io/pubflow/reference/param.md)`(`\
`    `[`list`](https://rdrr.io/r/base/list.html)`(`\
`        from ``=`` `[`numeric_param`](https://rpahl.github.io/pubflow/reference/param.md)`(``0``, label ``=`` ``"From"``, min ``=`` ``-``20``, max ``=`` ``60``)``,`\
`        to ``=`` `[`numeric_param`](https://rpahl.github.io/pubflow/reference/param.md)`(``30``, label ``=`` ``"To"``, min ``=`` ``-``20``, max ``=`` ``60``)`\
`    ``)``,`\
`    label ``=`` ``"Temperature range (°C)"``,`\
`    source ``=`` ``"user"``,`\
`    area ``=`` ``"data"`\
`)`` ``|>`\
`    `[`add_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``\``(``x``)`` ``if`` ``(``x``$``from`` ``<`` ``x``$``to``)`` ``""`` ``else`` ``"'From' must be below 'To'"``)`\
\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``window``)`\
`# group  from    to `\
`#    ""    ""    ""`\
[`param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md)`(``window``, value ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``from ``=`` ``30``, to ``=`` ``10``)``)`\
`#                       group                        from                          to `\
`# "'From' must be below 'To'"                          ""                          ""`

The result has one element for the group and one per child. A step gets
the value of a group as a plain named list, so `prep` below reads
`window$from` and `window$to`.

### Configs

A *config* collects the params of an analysis. It numbers the params in
the order given (the order of a parameter UI). Combining configs numbers
them anew.

\
`base`` ``<-`` `[`param_config`](https://rpahl.github.io/pubflow/reference/param_config.md)`(`\
`    xVar ``=`` ``xVar``,`\
`    level ``=`` ``level``,`\
`    window ``=`` ``window``,`\
`    title ``=`` `[`param`](https://rpahl.github.io/pubflow/reference/param.md)`(``"Ozone in New York"``, label ``=`` ``"Report title"``, source ``=`` ``"user"``)`\
`)`\
`base`\
`# <param_config: 4 params>`\
`#  name   type      value                     label                 `\
`#  xVar   factor    <factor[1]: Temp.Celsius> Predictor             `\
`#  level  numeric   0.95                      Confidence level      `\
`#  window list      <list[2]: from=0, to=30>  Temperature range (°C)`\
`#    from numeric   0                         From                  `\
`#    to   numeric   30                        To                    `\
`#  title  character Ozone in New York         Report title`

Configs are combined with [`c()`](https://rdrr.io/r/base/c.html). Names
must be unique, unless you say that the first definition wins. That is
useful for a stricter variant of a config, e.g. for a validated
analysis, that overrides single params of the base config:

\
`strict`` ``<-`` `[`param_config`](https://rpahl.github.io/pubflow/reference/param_config.md)`(`\
`    level ``=`` `[`numeric_param`](https://rpahl.github.io/pubflow/reference/param.md)`(`\
`        ``0.99``,`\
`        label ``=`` ``"Confidence level"``,`\
`        min ``=`` ``0.5``,`\
`        max ``=`` ``0.999``,`\
`        source ``=`` ``"user"``,`\
`        locked ``=`` ``TRUE`\
`    ``)`\
`)`\
`config`` ``<-`` `[`c`](https://rdrr.io/r/base/c.html)`(``strict``, ``base``, .duplicates ``=`` ``"first"``)`\
[`names`](https://rdrr.io/r/base/names.html)`(``config``)`\
`# [1] "level"  "xVar"   "window" "title"`\
[`param_value`](https://rpahl.github.io/pubflow/reference/param_value.md)`(``config``$``level``)`\
`# [1] 0.99`

### Params in a pipeline

The analysis is the pipeline of the Get started vignette with a filter
on the temperature and a table of the coefficients. The functions are
written with plain defaults that equal the values of the config.

The table is made by a function defined outside the pipeline, as in Get
started:

\
`coef_table`` ``<-`` ``function``(``model``, ``level``)`` ``{`\
`    ``ci`` ``<-`` `[`confint`](https://rdrr.io/r/stats/confint.html)`(``model``, level ``=`` ``level``)`\
`    ``coefs`` ``<-`` `[`data.frame`](https://rdrr.io/r/base/data.frame.html)`(`\
`        term ``=`` `[`rownames`](https://rdrr.io/r/base/colnames.html)`(``ci``)``,`\
`        estimate ``=`` `[`coef`](https://rdrr.io/r/stats/coef.html)`(``model``)``,`\
`        lower ``=`` ``ci``[``, ``1L``]``,`\
`        upper ``=`` ``ci``[``, ``2L``]`\
`    ``)`\
`    `[`pub_table`](https://rpahl.github.io/pubflow/reference/pub_table.md)`(`\
`        ``coefs``,`\
`        caption ``=`` `[`sprintf`](https://rdrr.io/r/base/sprintf.html)`(``"Coefficients with %g%% confidence limits"``, ``100`` ``*`` ``level``)``,`\
`        labels ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(`\
`            term ``=`` ``"Term"``,`\
`            estimate ``=`` ``"Estimate"``,`\
`            lower ``=`` ``"Lower"``,`\
`            upper ``=`` ``"Upper"`\
`        ``)``,`\
`        digits ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``estimate ``=`` ``3L``, lower ``=`` ``3L``, upper ``=`` ``3L``)`\
`    ``)`\
`}`

\
`pip`` ``<-`` `[`pip_new`](https://rpahl.github.io/pipeflow/reference/pip_new.html)`(``"ozone"``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"data"``, ``function``(``data`` ``=`` ``airquality``)`` ``data``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(`\
`        ``"prep"``,`\
`        ``function``(``df`` ``=`` ``~``data``, ``window`` ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``from ``=`` ``0``, to ``=`` ``30``)``)`` ``{`\
`            ``df``[``, ``"Temp.Celsius"``]`` ``<-`` ``(``df``[``, ``"Temp"``]`` ``-`` ``32``)`` ``*`` ``5`` ``/`` ``9`\
`            ``inRange`` ``<-`` ``df``$``Temp.Celsius`` ``>=`` ``window``$``from`` ``&`` ``df``$``Temp.Celsius`` ``<=`` ``window``$``to`\
`            ``df``[``inRange``, ``]`\
`        ``}`\
`    ``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"fit"``, ``function``(``data`` ``=`` ``~``prep``, ``xVar`` ``=`` ``"Temp.Celsius"``)`` ``{`\
`        `[`lm`](https://rdrr.io/r/stats/lm.html)`(`[`paste`](https://rdrr.io/r/base/paste.html)`(``"Ozone ~"``, ``xVar``)``, data ``=`` ``data``)`\
`    ``}``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"coef_table"``, ``function``(``model`` ``=`` ``~``fit``, ``level`` ``=`` ``0.99``)`` ``{`\
`        ``coef_table``(``model``, ``level``)`\
`    ``}``)`

The last steps add a summary text, a table of the params (explained in
[A table of parameters](#a-table-of-parameters)) and the layout step:

\
`pip`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"summary"``, ``function``(``model`` ``=`` ``~``fit``, ``xVar`` ``=`` ``"Temp.Celsius"``)`` ``{`\
`        `[`pub_text`](https://rpahl.github.io/pubflow/reference/pub_text.md)`(`[`sprintf`](https://rdrr.io/r/base/sprintf.html)`(`\
`            ``"**%s** explains %.0f%% of the variance of the ozone concentration."``,`\
`            ``xVar``,`\
`            ``100`` ``*`` `[`summary`](https://rdrr.io/r/base/summary.html)`(``model``)``$``r.squared`\
`        ``)``)`\
`    ``}``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(`\
`        ``"params_table"``,`\
`        ``function``(`\
`            ``xVar`` ``=`` ``"Temp.Celsius"``,`\
`            ``level`` ``=`` ``0.99``,`\
`            ``window`` ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``from ``=`` ``0``, to ``=`` ``30``)``,`\
`            ``title`` ``=`` ``"Ozone in New York"`\
`        ``)`` ``{`\
`            ``# the arguments are not used: they make the step run again when`\
`            ``# one of the reported params changes`\
`            `[`pub_params_table`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)`(`\
`                `[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``.self``, source ``=`` ``"user"``)``,`\
`                caption ``=`` ``"Parameters of the analysis"`\
`            ``)`\
`        ``}`\
`    ``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(`\
`        ``"report"``,`\
`        ``function``(`\
`            ``title`` ``=`` ``"Ozone in New York"``,`\
`            ``summary`` ``=`` ``~``summary``,`\
`            ``table`` ``=`` ``~``coef_table``,`\
`            ``params`` ``=`` ``~``params_table`\
`        ``)`` ``{`\
`            `[`pub_doc`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`\
`                `[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(``"Results"``, ``summary``, ``table``)``,`\
`                `[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(``"Parameters"``, ``params``)``,`\
`                title ``=`` ``title`\
`            ``)`\
`        ``}`\
`    ``)`

[`pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
sets the params of the config in every step that has an argument of the
same name. A step’s plain default has no rules, so this first
application stores the params of the config as they are, without a
check. Check a config before you apply it:
[`param_validity_assert()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
signals an error for an invalid entry. After that, every new value is
checked against the rules of its param (see below).

\
[`invisible`](https://rdrr.io/r/base/invisible.html)`(`[`lapply`](https://rdrr.io/r/base/lapply.html)`(``config``, ``param_validity_assert``)``)`

With `unknown = "error"`, a param that no step has is an error instead
of a warning:

\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``pip``, ``config``, unknown ``=`` ``"error"``)`\
`pip`\
`# <pipeflow> ozone (7 steps)`\
`# --------------------------`\
`#            step                     params                         depends state`\
`# 1:         data                       data                                   new`\
`# 2:         prep                  df,window                            data   new`\
`# 3:          fit                  data,xVar                            prep   new`\
`# 4:   coef_table                model,level                             fit   new`\
`# 5:      summary                 model,xVar                             fit   new`\
`# 6: params_table    xVar,level,window,title                                   new`\
`# 7:       report title,summary,table,params summary,coef_table,params_table   new`\
`# --------------------------`\
`# <ready> last run: never`\
`# steps: 7 new`

\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``pip``, `[`list`](https://rdrr.io/r/base/list.html)`(``alpha ``=`` ``0.05``)``, unknown ``=`` ``"error"``)`\
`# ``Error``:`\
`# ``!`` Trying to set parameters not defined in the target: alpha`

The steps still get plain values.
[`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)
reads the param objects back. It lists them in the order of the config
(`order = "config"`, the default) or in the order in which the pipeline
first uses the names (`order = "pipeline"`), and it can filter by
attributes:

\
[`names`](https://rdrr.io/r/base/names.html)`(`[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``)``)`\
`# [1] "level"  "xVar"   "window" "title"`\
[`names`](https://rdrr.io/r/base/names.html)`(`[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``, order ``=`` ``"pipeline"``)``)`\
`# [1] "window" "xVar"   "level"  "title"`\
[`names`](https://rdrr.io/r/base/names.html)`(`[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``, area ``=`` ``"data"``)``)`\
`# [1] "window"`

Setting a value that is not valid is an error, and nothing is set. All
failures are collected into one error that names step and param:

\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(`\
`    ``pip``,`\
`    `[`list`](https://rdrr.io/r/base/list.html)`(``xVar ``=`` ``"Height"``, window ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``from ``=`` ``30``, to ``=`` ``10``)``)`\
`)`\
`# ``Error``:`\
`# ``!`` Cannot set 5 parameters: nothing was set.`\
`#   step 'prep', parameter 'window': 'From' must be below 'To'`\
`#   step 'fit', parameter 'xVar': value must be one of: Temp.Celsius, Wind, Solar.R`\
`#   step 'summary', parameter 'xVar': value must be one of: Temp.Celsius, Wind, Solar.R`\
`#   step 'params_table', parameter 'xVar': value must be one of: Temp.Celsius, Wind, Solar.R`\
`#   step 'params_table', parameter 'window': 'From' must be below 'To'`

Run the pipeline once. A group is set as a list; this changes the data
that `prep` returns, so `prep` and all steps that depend on it are
outdated and run again:

\
[`pip_run`](https://rpahl.github.io/pipeflow/reference/pip_run.html)`(``pip``, lgr ``=`` ``NULL``)`\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``pip``, `[`list`](https://rdrr.io/r/base/list.html)`(``window ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``from ``=`` ``10``, to ``=`` ``25``)``)``)`\
`pip`\
`# <pipeflow> ozone (7 steps)`\
`# --------------------------`\
`#            step                     params                         depends    state`\
`# 1:         data                       data                                     done`\
`# 2:         prep                  df,window                            data outdated`\
`# 3:          fit                  data,xVar                            prep outdated`\
`# 4:   coef_table                model,level                             fit outdated`\
`# 5:      summary                 model,xVar                             fit outdated`\
`# 6: params_table    xVar,level,window,title                                 outdated`\
`# 7:       report title,summary,table,params summary,coef_table,params_table outdated`\
`#                                            out`\
`# 1:                         <data.frame[153x6]>`\
`# 2:                         <data.frame[126x7]>`\
`# 3:                                    <lm[13]>`\
`# 4:                             <huxtable[3x4]>`\
`# 5: **Temp.Celsius** explains 28% of the var...`\
`# 6:                             <huxtable[5x3]>`\
`# 7:                                <pub_doc[2]>`\
`# --------------------------`\
`# <ready> last run: 2026-11-14 10:39:29 (0.050 s)`\
`# steps: 1 done, 6 outdated`

### One value per name

A name has one value in the whole pipeline: `xVar` is the argument of
`fit`, `summary` and `params_table`, and setting it sets all of them.
This holds also if the params are set through a view (e.g. the steps
that a parameter UI shows). pipeflow’s [Pipeline
views](https://rpahl.github.io/pipeflow/articles/v03b-pipeline-views.html)
vignette describes this in detail (pipeflow 0.5.0.9027 or later). With
`scope = "view"` only the steps of the view are set:

\
`xVars`` ``<-`` ``function``(``p``)`` ``{`\
`    `[`sapply`](https://rdrr.io/r/base/lapply.html)`(`[`pip_get_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``p``, simplify ``=`` ``FALSE``)``$``xVar``, ``as.character``)`\
`}`\
\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(`[`pip_view`](https://rpahl.github.io/pipeflow/reference/pip_view.html)`(``pip``, step ``=`` ``"summary"``)``, `[`list`](https://rdrr.io/r/base/list.html)`(``xVar ``=`` ``"Wind"``)``)`\
`xVars``(``pip``)`\
`#          fit      summary params_table `\
`#       "Wind"       "Wind"       "Wind"`\
\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(`\
`    `[`pip_view`](https://rpahl.github.io/pipeflow/reference/pip_view.html)`(``pip``, step ``=`` ``"summary"``)``,`\
`    `[`list`](https://rdrr.io/r/base/list.html)`(``xVar ``=`` ``"Solar.R"``)``,`\
`    scope ``=`` ``"view"`\
`)`\
`xVars``(``pip``)`\
`#          fit      summary params_table `\
`#       "Wind"    "Solar.R"       "Wind"`

Now `summary` explains the ozone concentration with another variable
than `fit`, which is rarely intended. pipeflow warns when a step is
added or replaced with a param that differs from the same param in the
other steps:

\
`copy`` ``<-`` `[`pip_clone`](https://rpahl.github.io/pipeflow/reference/pip_clone.html)`(``pip``)`\
[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``copy``, ``"note"``, ``function``(``level`` ``=`` ``0.9``)`` ``level``)`\
`# Warning: Params with the same name have different values, but pip_set_params() sets one value in all steps that have the param:`\
`# - 'level' is 0.9 in step 'note', but 0.99 in step 'coef_table'`\
`# pip_get_params() with simplify = FALSE shows the values of all steps.`

Setting the config again puts the params back. (To change the function
of a step but keep the current values of its params, use the argument
`keep_params` of
[`pip_replace()`](https://rpahl.github.io/pipeflow/reference/pip_replace.html).)

\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``pip``, ``config``, unknown ``=`` ``"error"``)`\
`xVars``(``pip``)`\
`#            fit        summary   params_table `\
`# "Temp.Celsius" "Temp.Celsius" "Temp.Celsius"`

### A table of parameters

A report documents the params that an analysis used.
[`pub_params_table()`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)
makes a table from param objects, by default with their labels, values
and descriptions. Other columns are the name or any attribute:

\
`params`` ``<-`` `[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``, source ``=`` ``"user"``)`\
[`pub_params_table`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)`(``params``, columns ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``name ``=`` ``"Name"``, value ``=`` ``"Value"``, area ``=`` ``"Area"``)``)`` ``|>`\
`    `[`pub_cell_text`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md)`(``)`\
`#      [,1]     [,2]                [,3]  `\
`# [1,] "Name"   "Value"             "Area"`\
`# [2,] "level"  "0.99"              ""    `\
`# [3,] "xVar"   "Temp.Celsius"      ""    `\
`# [4,] "window" "0, 30"             "data"`\
`# [5,] "title"  "Ozone in New York" ""`

The step `params_table` above puts the table into the document. It reads
the param objects of the pipeline through `.self`, which a step function
can use without declaring it. The step lists the params it reports as
arguments, so that it runs again when one of them changes. `.self`
bypasses the pipeline’s dependency tracking, so list every param that
the table reports: one that is left out can change without the step
running again. The layout step takes the table as an input like any
other output:

\
[`pip_run`](https://rpahl.github.io/pipeflow/reference/pip_run.html)`(``pip``, lgr ``=`` ``NULL``)`

\
[`pub_html`](https://rpahl.github.io/pubflow/reference/pub_html.md)`(``pip``[[``"report"``, ``"out"``]``]``)`

## Ozone in New York

- [1 Results](#pubflow-sec-1)
- [2 Parameters](#pubflow-sec-2)

### 1 Results

**Temp.Celsius** explains 28% of the variance of the ozone
concentration.

| Term         | Estimate |   Lower |   Upper |
|--------------|---------:|--------:|--------:|
| (Intercept)  |  -46.540 | -82.019 | -11.061 |
| Temp.Celsius |    3.324 |   1.863 |   4.784 |

Table 1: Coefficients with 99% confidence limits {#tab:html-framed
.table .huxtable quarto-disable-processing="true"
style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

### 2 Parameters

| Parameter | Value | Description |
|----|----|----|
| Confidence level | 0.99 | Confidence level |
| Predictor | Temp.Celsius | Variable that explains the ozone concentration |
| Temperature range (°C) | 0, 30 | Temperature range (°C) |
| Report title | Ozone in New York | Report title |

Table 2: Parameters of the analysis {#tab:html-framed-2 .table .huxtable
quarto-disable-processing="true"
style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;"}

### Locked params

In a validated analysis, some params are fixed, here the confidence
level of `strict`. A param with `locked = TRUE` is shown in a parameter
UI as a disabled input: the user sees the value but can’t change it. The
steps run as usual.

\
[`param_attr`](https://rpahl.github.io/pubflow/reference/param_attr.md)`(`[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``)``$``level``, ``"locked"``)`\
`# [1] TRUE`

The lock binds the UI only. Code can still change a locked param,
subject to its validity rules:

\
[`pip_set_params`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)`(``pip``, `[`list`](https://rdrr.io/r/base/list.html)`(``level ``=`` ``0.9``)``)`\
[`param_value`](https://rpahl.github.io/pubflow/reference/param_value.md)`(`[`pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)`(``pip``)``$``level``)`\
`# [1] 0.9`

pipeflow’s step locks
([`pip_lock()`](https://rpahl.github.io/pipeflow/reference/pip_lock.html))
are different: a locked step no longer runs,
[`pip_set_params()`](https://rpahl.github.io/pipeflow/reference/pip_set_params.html)
skips it, and the UI shows its params as locked too. To fix params but
keep the steps running, use the attribute.

### Where next

- [Get
  started](https://rpahl.github.io/pubflow/articles/v01-get-started.md)
  shows the whole workflow in one example.
- The help pages of the functions describe the details:
  [`?param`](https://rpahl.github.io/pubflow/reference/param.md),
  [`?param_validity`](https://rpahl.github.io/pubflow/reference/param_validity.md),
  [`?param_config`](https://rpahl.github.io/pubflow/reference/param_config.md),
  [`?pub_get_params`](https://rpahl.github.io/pubflow/reference/pub_get_params.md),
  [`?pub_params_table`](https://rpahl.github.io/pubflow/reference/pub_params_table.md).
