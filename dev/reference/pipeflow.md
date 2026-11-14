# pipeflow — facts relevant for pubflow

Checked 2026-11-12 against **pipeflow 0.5.0.9032** (GitHub
`rpahl/pipeflow`, commit 2ee2970; required since pubflow 0.0.0.9047 and
pinned in `Remotes`, D9) by reading the source and running examples;
first written for 0.5.0 (CRAN, commit aff664b), updated for 0.5.0.9012
(af3b0e5, pubflow 0.0.0.9021-9026), 0.5.0.9026 (bf6b314, pubflow
0.0.0.9027-9034) and 0.5.0.9028 (a3bbe82, pubflow 0.0.0.9035-9046); the
changes are in pipeflow's NEWS,
and its `dev/pipeflow.md` maps the run flow and invariants. Source: worktree `~/coding/rlang/pipeflow/main` (bare repo
`pipeflow.git` with worktrees; GitHub `rpahl/pipeflow`, which is public). pipeflow's maintainer is the pubflow maintainer: a problem
that is better solved in pipeflow may be solved there if the change is not
invasive (D9). Record new pipeflow bugs, quirks and feature requests
in §9.

## 1. Object model

- `pip_new(name = "pipe")` returns `structure(list(name, view, pipenv),
  class = "pipeflow")` — **not R6**. `pipenv` is an environment shared by
  the pipeline and all of its views; all functions mutate by reference and
  return `x` invisibly.
- `pipenv$data` is a data.table, one row per step, rows always in a valid
  topological order. Columns: `step` (chr), `fun` (list), `params` (list:
  named list per step), `out` (list), `state` (chr), `tags` (list of chr),
  `locked` (lgl), `exec` (chr), `time` (POSIXct: added/replaced or end of
  the last successful run), `time_start` (POSIXct: start of the last run,
  also of a failed one; since 0.5.0.9014), `duration` (difftime in
  seconds of the last run, also of a failed one; since 0.5.0.9023),
  `depends` (list: named chr param -> step), `unbound` (list of chr),
  `nodeId` (int). Pipelines saved before get `time_start`/`duration` (all
  `NA`) when read.
- **No custom columns** (the next `pip_add()` fails in `rbindlist()`), and
  no description/label/metadata column: param metadata lives inside the
  param *values* (pubflow's `param` objects).
- Pipelines survive `saveRDS()`/`readRDS()` and can be sent to other R
  processes (the DAG is rebuilt on demand).
- S3 subclassing is fragile: `pip_view()`, `[`, `pip_clone()` and `rbind()`
  return plain `"pipeflow"` objects.

## 2. Exported API (complete)

Construction/cloning: `pip_new(name = "pipe")`, `pip_clone(x, name = NULL)`
(deep copy, full pipeline only), `x[]` (copy).

Steps:
- `pip_add(x, step, fun, tags = character(0), params = list(),
  exec = "auto", after = length(x))` — full pipeline only. `after` = step
  name or integer 0..n (last argument since 0.5.0.9028). `params` names
  that aren't formals of `fun` are an error unless `fun` has `...`. Step
  names must not start with `-` (0.5.0.9030; `~-1` is a relative
  reference). **`step` may be a pipeline or view** (0.5.0.9030): its steps
  are copied with functions, params, tags and exec modes but without their
  upstream steps, and references are resolved by step name in `x`, e.g.
  `pip_add(p, q[c("fit", "plot")])` runs `q`'s analysis steps on `p`'s
  data steps; all or nothing.
- `pip_replace(x, step, fun, tags = NULL, params = list(), exec = NULL,
  keep_params = FALSE)`: `NULL` keeps the step's tags/exec; the params go
  back to the defaults of `fun` (plus `params`); `keep_params = TRUE`
  (0.5.0.9028) keeps the stored values (param objects included) of the
  old step's unbound params that are formals of `fun`, unless `params`
  give them or `fun` binds them; the output is cleared, the step is unlocked and
  "new"; done steps downstream become "outdated". `x[[s, "fun"]] <- f`
  also keeps tags/exec and resets the params.
- `pip_remove(x, step, force = FALSE)` (`force` also removes downstream),
  `pip_rename(x, from, to)` (updates depends and formulas).

Params: `pip_get_params(x)`, `pip_set_params(x, params = list(), unknown =
c("warn", "ignore", "error"), force = FALSE, ...)`, the generics
`pip_param_value(x, ...)` and `` `pip_param_value<-`(x, ..., value) `` (§4).
Outputs of steps: the generic `pip_output_value(x, ctx = list(), ...)` (§6).
Nesting: `as.function(x, out = NULL, cache = TRUE, on_error = c("stop",
"continue"), lgr = NULL, ...)` for a pipeline, `pip_inner(x, step)` (§7).
Run: `pip_run(x, lgr = pipeflow_lgr, force = FALSE, progress = NULL,
on_error = c("stop", "continue"), map = NULL)` (§6), `pip_run_state(x)`,
`pip_reset(x)`; default logger `pipeflow_lgr(level, msg)`; the option
`pipeflow.lgr` sets the default `lgr` of `pip_run()` (0.5.0.9029).
Outputs: `pip_collect(x, by = "step", as.table = FALSE, simplify = TRUE)`
(the alias `pip_collect_out()` was removed in 0.5.0.9019).
Tags: `pip_tag(x, tags)`, `pip_untag(x, tags)`.
Views: `pip_view(x, ..., join = c("intersect", "union"), fixed = TRUE)`,
`` `[.pipeflow`(x, i, j, view = TRUE) ``; data.table's `%like%`, `%chin%`,
`%between%`, ... work in `[` filters but are no longer re-exported (since
0.5.0.9019; elsewhere `library(data.table)`). `[` warns if the selector
is a column name that is also a variable of the caller (0.5.0.9029: with
`step <- "load"`, `p[step]` selects by the `step` column).
Locking: `pip_lock(x)`, `pip_unlock(x)` (no separate skip flag).
`pip_lock()` on a step that is not done outdates its downstream steps
(0.5.0.9032), as the locked step now passes its stored output.
Inspection: `pip_data(x)` (full step table, even for a view),
`pip_graph(x, include_upstream = FALSE, format = c("visNetwork",
"mermaid"))` (nodes with a hover `title`: state, exec, tags, lock, start
and duration of the last run, failed keys, params, inputs; `~try()` edges
dashed; `"mermaid"` returns flowchart text; the alias `pip_get_graph()`
was removed), `print` (footer with run state, last run and its duration,
and step counts by state, e.g. `steps: 3 done, 1 failed`; `duration` in
short form), `str`, `length`, `dim`.
Accessors: `` `[[.pipeflow`(x, i, j = NULL) ``, `[[<-`, `[<-`, `$`, `$<-`.
Writable step properties via `x[[step, j]] <- value`: `step` (NULL
removes), `fun`, `params`, `tags` (sets exactly), `locked`, `exec`,
`state`, `time`, `time_start` and `duration` (`NA` allowed), `out`.
Derived columns (`depends`, `unbound`, `nodeId`) are rejected.
**Assignments outdate steps** (since 0.5.0.9016, `?Extract.pipeflow`
"Which assignments outdate steps"): `fun` makes the step "new" and its
downstream steps "outdated"; `params` and `exec` outdate the step and its
downstream steps if a value changes; `out` outdates the downstream steps
(the step keeps its state); `step`, `state`, the times, `tags` and
`locked` outdate nothing. Also through `[<-` and views.
Combining: `rbind(..., deparse.level = 1)` (§7; `bind =` was removed in
0.5.0.9013); `p[i, ] <- q[i, ]` copies step properties (with the step's
`params`, and references by name). A bulk `[<-` changes all selected
steps or none (since 0.5.0.9017).
Method syntax: `p$add(...)`, `p$run()`, `p$set_params()`,
`p$get_params()`, `p$collect()`, ... (closed method table; `p$view` is the
meta field, not a method). Inside a step, `.self$restart(force = TRUE,
times = 1L)` and `.self$halt()` exist.

**Removed since 0.2.3** (relevant when porting code from pipeflow 0.2.3): `Pipeline` R6
class, all `pipe_*` functions, `keepOut`, `group`, `description`,
`$get_params_unique()`, `$set_params(warnUndefined=)`,
`$set_params_at_step()`, `$get_out()`, `$collect_out(groupBy=)`,
`$append(outAsIn=)`, `set_data_split`, `pop_steps_after`, hidden
(dot-prefixed) params, the internal S4 `Param` classes, automatic
unwrapping of `Param@value` (its successor is `pip_param_value()`, §4).

## 3. Step functions, defaults and `.self`

- **Every formal except `...` needs a default or a value in `params`**
  ("'x' has no default value - set one in fun or give a value in params"),
  so existing functions can be steps, e.g. `pip_add(p, "avg", mean,
  params = list(x = ~data, na.rm = TRUE))`. Each default is evaluated
  **once, when the step is added**, in `environment(fun)` (so defaults may
  call package functions; a `Sys.time()` default is frozen).
- **`params` override the defaults of `fun`** (since 0.5.0.9009; 0.5.0:
  the defaults won with a warning). A formula in `params` makes the
  argument a step reference even if its default is a value. `params` must
  be a list with unique names; further names are stored too and reach
  `fun` through `...` (so `fun` needs `...`). The step's params list the
  formals first (in their order), then the other params.
- Dependencies: one-sided formulas `~step` or `~-k` (relative) as defaults
  or in `params`; `unbound = setdiff(names(params), names(depends))`.
  `~try(step)` (also `~try(-k)`) is the same dependency and marks an
  argument that may receive a failure object (§6); only `try()` with one
  argument counts. The mark lives in the step's params (formals merged
  with `params`), so the formals of a new function decide on
  `pip_replace()` and `x[[step, "fun"]] <- f`; renames by `rbind()` keep
  it.
- Step functions are **stored as given** (attributes and class stay);
  `rbind()` changes the formals of appended steps (§7). Primitives are
  rejected ("fun must not be a primitive function; wrap it, ...").
- **`.self`** is provided per step call, and only to a step function whose
  body names it (`".self" %in% all.names(body(fun))`, also in functions
  defined in the body; `get(".self")` is not detected): pipeflow calls a
  copy whose environment is a new child of `environment(fun)` holding
  `.self`, the full running pipeline (view = NULL). **Since 0.5.0.9002
  pipeflow removes `.self` from that environment when the step returns**
  (also on error), so outputs that capture the step frame (ggplots,
  closures) no longer keep the pipeline alive; a returned closure that
  uses `.self` later fails with "object '.self' not found". Clones have
  their own `.self`. A `.self` formal or param is an error ("reserved
  parameter name").
- **A step that changes its own function, params or exec mode during its
  run** (through `.self`), or that a later step changes, ends the run
  "outdated" (not "done"), and so do the steps that ran with its output
  (since 0.5.0.9016, breaking): its output comes from the old definition.
  A step that sets its own params to fixed values settles after one more
  run; one that sets new values in every run runs in every run. Since
  0.5.0.9031 `pip_run()` warns about it (class `pipeflow_outdated_before`)
  if a step changes itself or a done step before it (not if it halts or
  restarts the run); setting params of *later* steps stays silent.
- **The step call** (since 0.5.0.9029): a step function is called by the
  step name with its arguments as symbols, e.g. `fit(x = x)`, in an
  environment whose parent is pipeflow's namespace. So the call of an
  error raised in the step (and of a traceback) no longer holds the step's
  inputs, and `match.call()` in a step gives `fit(x = x)` (an `lm` step
  stores a call that `update()` can't evaluate later). Params that are
  symbols or calls go into the call as they are (`subset()` works). An
  output that keeps the step frame no longer keeps the pipeline through
  an argument the step didn't force; a step function defined inside a
  pipeline constructor still encloses that constructor (D20).

## 4. Parameters

- `pip_get_params(x)`: unbound params only, of the pipeline or view rows
  (locked rows included); duplicate names keep the **first occurrence** in
  pipeline order (a plain default of an earlier step hides a param object
  of a later one); values exactly as stored (attributes/class intact).
  `simplify = FALSE` (since 0.5.0.9027): all values, grouped by name (in
  the order of the first occurrence) and named by step. Per step:
  `x[["params"]]` (named by step, bound formulas included) or
  `x[["unbound"]]`.
- `pip_set_params(x, params, unknown, force, scope = c("pipeline",
  "view"), ...)`:
  - every element must be named;
  - on a view, the view's rows select the names (see unknown names
    below); **values go to every unlocked row of the pipeline that has the
    name unbound** (`scope = "pipeline"`, the default since 0.5.0.9027),
    or to the view's unlocked rows only (`scope = "view"`, the behaviour
    before). Bindings (formula values) ignore `scope`: they apply to the
    view's rows only. The `errors` of a failed call may name steps outside
    the view. An option named `scope` no longer reaches the setter
    methods through `...`;
  - no unlocked row to change: message "No steps to update: all selected
    steps are locked";
  - **per row**, the value to store is `` `pip_param_value<-`(<stored
    value>, ..., value = <new value>) `` (dispatch on the stored value of
    that row; default method: `value`, i.e. overwrite). `...` of
    `pip_set_params()` goes to the methods only. All rows are computed
    first; if any method fails, **nothing is set** and one error of class
    `pipeflow_set_params_error` is raised (fields `errors`: data.frame
    `step`, `name`, `message`; `parents`: list of the conditions; message
    "Cannot set N parameters: nothing was set." plus one line per
    failure);
  - skips (row, name) pairs whose merged value is `identical()` to the
    stored one, unless `force = TRUE`;
  - changed rows and the done rows downstream of them become "outdated";
    "new" rows stay "new";
  - **a one-sided formula value binds the param** (since 0.5.0.9010): in
    every selected unlocked row that has it unbound, which must come after
    the target step (else "cannot bind ... use a view"); relative
    references are an error, `~try(step)` works; setting the same binding
    again does nothing. Formula values are passed as strings and turned
    into formulas in the step. Two-sided formulas (`y ~ x`) are values;
  - unknown names (unbound in none of the view's rows, locked rows
    included): `unknown = "warn"` gives one warning "Trying to set
    parameters not defined in the target: a, b" (without the call),
    `"ignore"` nothing, `"error"` that message as an error before anything
    is set.
- **`pip_param_value(x, ...)`**: exported S3 generic (default method: `x`),
  applied to each **unbound** argument of a step call (from the formals or
  `params`, also names that go into `...`) right before the call; not to
  `~step` inputs, partitions or failure objects. An error in a method is a
  step error. Methods are meant for one's own classes (pubflow:
  `pip_param_value.param()`). Its write side `` `pip_param_value<-`() ``
  is used by `pip_set_params()` (above); a method should satisfy
  `pip_param_value(`pip_param_value<-`(x, value = v)) == v` and not modify
  `x` in place (vignette v05d: a plain value keeps the annotation).
- Setting one step: `pip_set_params(pip_view(x, step = s), ...,
  scope = "view")` or `x[[s, "params"]] <- list(...)`.
- **Param conflicts** (since 0.5.0.9027): `pip_add()`, `pip_replace()` and
  `rbind()` warn (class `pipeflow_param_conflict`, field `conflicts`, a
  data.frame `step`, `param`, `value`, `other`, `other_value`) if an
  unbound param of a new step has another value than the first other step
  that has it unbound; values are compared with `identical()` after
  `pip_param_value()`, so pubflow's labels and validity don't count. Off
  with `options(pipeflow.warn_param_conflicts = FALSE)`. A step replaced
  after the user changed a value warns unless `pip_replace(keep_params =
  TRUE)` keeps the stored values (D46).

## 5. Tags and views

- Tags are free, flat character strings (no hierarchy). Set via
  `pip_add(tags=)`, `pip_replace(tags=)` (`NULL` keeps), `pip_tag()`/
  `pip_untag()` (add/remove on all rows of the pipeline/view, skip locked
  rows), `x[[s, "tags"]] <- chr`.
- `pip_view(x, tags = c("a", "b"))` matches steps with **any** of the tags.
  Several filters (`step=`, `params=`, `depends=`, `state=`, `tags=`,
  `exec=`) combine with AND (`join = "intersect"`) or OR (`"union"`);
  `fixed = FALSE` = regex. All tags required: chain views. **No negation**
  in `pip_view()`; use `[`, e.g. `p[vapply(tags, \(t) !"x" %in% t,
  logical(1))]`.
- Pitfall: in `[` expressions `tags %like% "char"` matches the deparsed
  list column, so untagged steps match "char" (from `character(0)`), and
  substrings match. `pip_view(tags = )` is not affected.
- A view is the same object whose `view` field holds the node ids of its
  steps: it stays valid when steps are added, removed, renamed or replaced
  through any handle. `v[["view"]]` returns the names of its steps, a view
  keeps its pipeline's name, and its rows are always in pipeline order (no
  custom order). `x[[j]]` on a view returns the column for its steps,
  named by step; `x[[step, j]]` reads that step's row.
- Works on views: `pip_run()` (view rows plus upstream),
  `pip_get_params()`, `pip_set_params()`, `pip_collect()`, tag/untag,
  lock/unlock, reset, remove/rename/replace (step in view), graph, print,
  `pip_run_state()`, `[`, `[[`. Not on views: `pip_add()`, `pip_clone()`,
  `rbind()`.
- `x[i, view = FALSE]` builds a new pipeline of the selected steps plus
  upstream.

## 6. Running, outputs and errors

- Step states: "new", "outdated", "done", "failed". Run state
  (`pip_run_state()`): "ready", "running", "restart", "halted" (a step
  called `.self$halt()`), "failed" (the last run stopped on an error),
  "continued" (the last run went on after failures); `pip_reset()` sets
  "ready".
- `pip_run()` walks the rows in order; skips "done" steps (unless `force`)
  and locked steps (always), but re-runs a "done" step if one of its inputs
  was executed in the same run. On a view it runs the view rows plus
  upstream. A run marks only steps downstream of *executed* steps
  "outdated" ("new" stays "new", locked steps keep their state). No "run a
  single step": use `pip_run(pip_view(p, step = s))`.
- `pip_run()` checks each step's state when it reaches the step, so a step
  that sets params of later steps (through `.self`) makes them run in the
  same run.
- `progress(value = i, detail = step)` is called before every step of the
  run list (also skipped ones) — fits `shiny::setProgress()`. **If it
  returns `FALSE`, the run is halted** before that step, as by
  `.self$halt()` (run state "halted"; since 0.5.0.9021): a Shiny app can
  cancel a run between steps.
- **Time stamps** (`?pip_run` "Time stamps"): `time_start` is set each
  time a step runs, also if it fails; `duration` likewise; both `NA` after
  `pip_add()`, `pip_replace()`, `pip_reset()`, and kept by skipped steps
  (done, locked, failed input). `time` = added/replaced or end of the last
  successful run (a failed run doesn't change it; it is `ctx$time` of the
  output hook). With `t0 <- Sys.time()` before `pip_run()`: the step ran
  in that run if `time_start >= t0`; its last run succeeded if it is "done"
  and `time >= time_start`. The last log line of a run gives the total
  time and counts, e.g. `Finished in 0.025 s (2 done, 1 skipped, 2
  failed)`.
- `pip_reset()` marks the downstream steps of the reset steps "outdated"
  (since 0.5.0.9020); on a view it keeps the pipeline's run state and last
  run time (0.5.0.9022).
- **`map`** (since 0.5.0.9025): a function like `lapply()`, called as
  `map(X, FUN)`, runs the keys of every mapped step of the run, e.g.
  `\(X, FUN) parallel::mclapply(X, FUN, mc.cores = 4)` or
  `future.apply::future_lapply`. Not used for inner runs of
  `as.function()`; steps that name `.self`, and pipeline functions made
  with `cache = TRUE` (the default), still run their keys one after
  another (the kept inner pipelines would be lost in another process). A
  single key runs with `lapply()`. All keys run before the first key error
  is raised; warnings/messages reach `lgr` only if the backend relays them
  (`future_lapply` does, `mclapply` doesn't); random numbers are the
  backend's business (`future.seed = TRUE`). The output hook runs in the
  main process on the returned outputs (so pubflow stamps figures there;
  the figures themselves crossed a process boundary, see D43).
- **Errors** (`on_error = "stop"`, the default): the step becomes
  "failed", its condition is stored as its output (since 0.5.0.9026;
  before it kept the output of an earlier attempt), and `pip_run()`
  signals a `pipeflow_step_error` (message "step
  '<step>': <message>", fields `step` and `parent` = the step's own
  condition, so a classed condition survives as `parent`). The error of a
  nested run becomes the `parent` of the outer step's error ("step 'run':
  step 'fit': boom"). A failed partition's
  condition is a `pipeflow_key_error` ("key '<key>': <message>", fields
  `key`, `parent`). Messages use `conditionMessage()` of the step's
  condition.
- **`on_error = "continue"`**: a failed step's output is its condition;
  steps with a failed input that is not a `~try()` reference are skipped
  (they keep their output; "done" -> "outdated", "new" stays "new"); a
  `~try()` argument gets a failure object of class `c("pipeflow_failure",
  "error", "condition")` with `message` ("step 'oot' failed: <message>",
  or "step 'x' was not run: step 'oot' failed: <message>"), `step`,
  `failed_step` and `parent` (the failed step's condition; for partitions
  the key error). Failures are light since 0.5.0.9029 (step call with
  symbols, §3): measured 2026-11-12 with an 8 MB input, a failure from
  `stop()` or `rlang::abort()` in the step serialises to 0.5 KB / 59 KB
  (the rlang backtrace), with 0.5.0.9028 to 8 MB each, and the
  `pipeflow_run_failed` warning to 60 KB instead of 16 MB. Data can still
  get into a condition's call if the step passes it inlined, e.g.
  `do.call(f, list(data))` where `f` itself raises the error.
  Once all states and outputs are stored, the run ends in
  run state "continued" and warns with class `pipeflow_run_failed` (fields
  `failed`: named list of the conditions, `skipped`: step names, `keys`:
  named list step -> failed keys of mapped steps; message e.g.
  `'fit': key 'b': negative (1 of 3 keys)`). Mapped steps fail per key,
  see "Failures and partitions" below.
- Warnings and messages of steps go to the logger and still propagate. A
  logger is `function(level, msg)` with levels "info", "warn" and "error";
  `NULL` silences; `pipeflow_lgr()` (the default) prints with `cat()`.
- **`pip_output_value(x, ctx, ...)`** (since 0.5.0.9003): exported S3
  generic (default: `x`) applied to the output of every step when the step
  returns; its result is stored. `ctx = list(step, key, time)`: `step` as
  named when it ran, `key` `NULL` unless the output is partitioned (applied
  once per partition for split and mapped outputs; `reduce` outputs as a
  whole), `time` one `Sys.time()` per step (equal to the `time` column).
  Applied **once to the whole output**: list leaves are not visited (a
  method for a list class has to walk it). Not applied to failures (the
  stored condition, the failed keys of a mapped step) or inputs; a step
  that gets a failure through
  `~try()` and returns is annotated as usual. An error in a method is a
  step error (`on_error` applies). Inner steps of `as.function()` are
  annotated in the inner run and the function's result again in the outer
  one, so methods must be idempotent (vignette v05e: `stamped` class).
- Outputs: `out` column, NULL until run. `x[[s, "out"]]`, `x[["out"]]`
  (named list), `pip_collect()`; `pip_reset()` clears them. `print()`
  shows conditions, functions, matrices, ... in `out` in short form, e.g.
  `<error/simpleError>`, `<partitioned: 1/3 failed>`.
- `pip_collect(x, by = "step"|"tags"|..., as.table, simplify)`: with
  `by = "tags"` a step appears in **every** one of its tag groups; untagged
  steps are omitted; groups come in first-appearance order; steps keep
  pipeline order inside a group. `simplify = TRUE` flattens only if
  **all** groups have one step (then the step names are lost) — use
  `simplify = FALSE` for a stable shape.
- Exec modes: `exec = "auto" | "split" | "reduce" | "plain"` (split/map/
  reduce over data partitions).
  Split outputs are named lists of class `c("list",
  "pipeflow_partitioned")`.
- **Failures and partitions** (since 0.5.0.9015, breaking; F7): with
  `on_error = "continue"` a mapped step fails **per key**. Its output is
  the partitioned list with the results of the keys that succeeded and,
  for each failed key, a `pipeflow_failure` with a field `key` (`parent` =
  the `pipeflow_key_error`, message "step 'fit' failed: key 'b':
  negative"); the step is "failed". Downstream:
  - a mapped step is not called for the failed keys unless the argument
    is `~try()`; such a key's output is a failure too ("step 'show' was not
    run: step 'fit' failed: key 'b': negative", with `key`), and the step
    is "failed" (listed in `failed` with "input step 'fit' failed");
  - a step that is not mapped (`reduce`, `split`) is skipped unless the
    argument is `~try()`; then it gets the whole partitioned list with the
    failures inside.
  Whole-step failures stay for a failing split step and steps without
  partitioned inputs; a `reduce` step whose input is such a failure
  object counts it as partitioned and runs once. With `"stop"` the first
  key error stops the run (`pipeflow_step_error` with a
  `pipeflow_key_error` parent).
- **Retry per key:** the next run calls a failed mapped step only for its
  failed keys and keeps the results (and the output hook's annotations) of
  the others, unless its params, exec mode or an input step changed (it is
  then "outdated"), an input ran again in the same run, or `force = TRUE`.

## 7. Nesting and combining

- **`as.function(inner, out, cache, on_error, lgr)`** (since 0.5.0.9006)
  turns a pipeline into a step function (vignette v05b):
  ```r
  pip_add(outer, "inner_run", as.function(inner, out = "coefs"),
      params = list(input_df = ~split_df))  # bind inputs like any step
  ```
  - Snapshot: a reset clone of `inner` (full pipeline only; locked steps
    keep their outputs). Formals = `pip_get_params(inner)` (unbound params,
    first default wins), so the **inner param objects become params of the
    outer step** (`pip_get_params(outer)` shows them with their
    attributes); setting one outdates the outer step. The function gets
    plain values (`pip_param_value()`) and sets them in the inner pipeline
    with `pip_set_params()` semantics (setter method dispatches on the
    inner stored value; formulas are values here, not bindings).
  - `out`: `NULL` = `pip_collect()`, step name(s), or a function called
    with a light snapshot of the run inner pipeline (shares values).
  - `cache = TRUE` keeps one run inner pipeline per outer step **name** and
    partition key, so a later call reruns only inner steps whose params or
    inputs changed (bound inputs compared with `identical()`). The cache
    lives in the function: `saveRDS()` copies it; `pip_clone()`, `p[i] <-
    q[j]` and using one function in two pipelines share it (results stay
    correct, reuse gets worse: make one function per pipeline).
    `pip_run(outer, force = TRUE)` does not force the inner runs.
  - Failures: with `on_error = "stop"` the outer error nests the inner one
    ("step 'by_batch': key 'D': step 'fit': ..."; `?as.function.pipeflow`
    "Errors of inner steps", vignette v05c shows how to get the outer
    step, key and inner step); with `"continue"` the inner run continues,
    and the call fails only if a step named in `out` failed or was not
    run. Mapped, a failing call fails only its key (§6).
  - `pip_run(map = )` runs the keys of a mapped pipeline function in
    parallel only if it was made with `cache = FALSE` (§6).
  - `lgr = NULL`: inner run silent (warnings/messages still propagate).
  - `pip_inner(x, step)`: the kept inner pipelines (one; or a list by key
    for a mapped step; `list()` before the first run), for debugging.
  The older pattern (a step clones the inner pipeline, sets
  `pip_set_params(p, list(...))` and runs it, with `params =
  pip_get_params(inner)`) still works ("Full control" in v05b). Param
  names stay global (no namespacing). A step returning a pipeline stores
  an object of class "pipeflow" in `out`; `pip_collect()` does **not**
  recurse into it.
- `rbind(a, b, ...)`: name "a-b"; clashing step names get numeric suffixes
  (`data` -> `data2`) with rewired depends (`~try()` marks stay);
  tags/exec/out/state/time/locked are kept. The current param values of
  the steps of `b` (and later pipelines) are folded into the defaults of
  their functions' formals, so param objects become formal defaults.
  **Param names stay unchanged and shared** (`pip_get_params()` shows the
  first, `pip_set_params()` sets all). To feed steps of `b` with outputs
  of `a`, bind their params afterwards with a view of `b`'s steps:
  `pip_set_params(ab[-seq_along(a)], list(data = ~prep))` (the
  `bind =` argument of 0.5.0.9008 was removed in 0.5.0.9013); or rewire,
  e.g. `pip_replace("data2", \(x = ~-1) x)`.

## 8. Consequences for pubflow

1. Param metadata travels inside param values (classed objects). pubflow
   registers `pip_param_value.param()`, so step functions get plain values
   (also steps added with `pipeflow::pip_add()`). pubflow's methods for
   the output hook (§6) stamp figures for the render cache (D22), and the
   `.self` release (§3) keeps outputs from reaching the pipeline (D20), so
   pubflow has no step wrapper (D38).
2. Merge-on-set (`param_value<-`) and validation happen in pubflow's
   method for the setter hook (§4, D36); collecting the errors,
   change detection and unknown names are pipeflow's (`force`,
   `unknown`). A param whose value is a one-sided formula is
   bound like a plain formula (§4; pinned in `test-pipeline.R`).
3. Look up the first **param** occurrence across all rows (not
   `pip_get_params()`' first occurrence) — a plain default in an earlier
   step otherwise hides the param object. pubflow picks it from
   `pip_get_params(simplify = FALSE)`'s grouping by name.
4. After combining pipelines (`rbind()`), apply the merged param config so
   all rows share the same param objects.
5. Document structure must be explicit (layout steps, D19): tags are
   flat and views keep pipeline order.
6. Partitioned outputs are placed by pubflow (one section per key); inner
   pipelines contribute through their own layout steps. A failed key
   arrives as a `pipeflow_failure` inside the partitioned output and is
   placed as an error box in its section (§6; D21).
7. Step errors are `pipeflow_step_error`s; the step's own condition (e.g.
   a `pubflow_error` raised by a step) is their `parent`; errors of the
   setter (`pubflow_invalid_param`) are the `parents` of a
   `pipeflow_set_params_error`.

## 9. Open issues, quirks and requests

Add new findings here: bugs with a reproducible example and a suggested
fix, quirks, and feature requests with their value for pubflow and their
cost (pipeflow stays lean: only features that make pubflow a lot simpler
or that many R users need).

**Open:**
- **Annotated formula values bind** (found 2026-10-20): `pip_set_params()`
  treats any value with `inherits(x, "formula") && length(x) == 2` as a
  binding (`is_one_sided_formula()`, `R/utils.R`), so a pubflow param
  `param(~a)` binds the param to step `a` instead of being a value.
  Possible fix: bind only unclassed formulas (`class(x) == "formula"`), or
  test `pip_param_value(x)`. Low priority: one-sided formula values are
  rare and the documented way is a string.
- **Print footer in local time** (found 2026-10-26): the footer of
  `print()` shows the last run in the session's time zone
  (`last run: 2026-10-26 11:13:15`), while `pipeflow_lgr()` logs in UTC
  (`10:13:15 UTC`). Cosmetic; pubflow formats its own times with
  `tz = "UTC"` and doesn't print pipelines in documents.
- **Unnamed empty grouping** (found 2026-10-31): `pip_get_params(x,
  simplify = FALSE)` returns an unnamed `list()` if no row has unbound
  params (empty pipeline, steps without arguments), a named list
  otherwise. Suggested fix: return `setNames(list(), character(0))`.
  pubflow's `pub_get_params()` returns a named empty list itself until
  then. Low priority.
- **Step names that can't be arguments** (found 2026-11-14): `pip_add()`
  accepts steps named `.self` and `...`, but no step can take them as an
  argument of the same name: `pip_add()` rejects a `.self` argument
  (reserved), and a `...` argument with a `~step` default is dropped from
  the inputs, so the dependency is silently missing. `.try_inputs()`
  (`pub_layout_inputs()`, `pub_layout_sections()`) rejects such steps.
  Possible fix: reject the two step names in `pip_add()`. Low priority.
  The views of a pipeline share its environment (`view[["pipenv"]]`),
  which `pub_layout_sections()` compares to reject views of different
  pipelines.

**Landed in pipeflow 0.5.0.9029-0.5.0.9032** (pubflow requires it from
0.0.0.9047; no pubflow code change needed, the tests pass unchanged):
step calls with symbols, so failures no longer carry the step's inputs
(§3, §6; this settles "light failures" of the SM lessons,
`dev/PUBFLOW_LESSONS_LEARNED.md` item 7), the option `pipeflow.lgr`, the
`[` warning for column-named selectors (§2), `pip_add()` of a pipeline or
view (§2), the `pipeflow_outdated_before` warning (§3) and `pip_lock()`
outdating the dependents of a step that is not done (§2). Docs:
`?pip_add` "Outputs that keep an environment" (same advice as D20) and
`?pip_view` (a view covers only its steps, running it runs their upstream
steps too).

**Landed in pipeflow 0.5.0.9028** (pubflow adopts it in 0.0.0.9035):
`pip_replace(keep_params = )` (requested here 2026-10-31 for replaced
steps keeping their param objects, D46), an error for `params` that
aren't formals of `fun` (unless it has `...`), and `after` as the last
argument of `pip_add()`.

**Landed in pipeflow 0.5.0.9027** (pubflow adopts it in 0.0.0.9035):
`pip_set_params(scope = )` with values of a view set in the whole pipeline
by default, the `pipeflow_param_conflict` warning and
`pip_get_params(simplify = FALSE)` (§4; requested here 2026-10-30 for
param UIs on views, D46).

**Landed in pipeflow 0.5.0.9013-0.5.0.9026** (pubflow adopts them in
0.0.0.9027): a step failing in a stop run stores its condition as its
output (0.5.0.9026; found in the Copilot review of PR #28: before, a
continued run after it made `pub_out()` return the step's output of an
earlier attempt), per-key failures of mapped steps and retries of the failed
keys only (F7, §6; requested here as "per-key failures", PLAN.md open
problem 10), `time_start` (requested 2026-10-23) and `duration` (§1, §6),
cancelling a run from `progress`, `pip_run(map = )` (§6), assignments that
outdate steps, atomic bulk `[<-` (§2), steps changing themselves during a
run end "outdated" (§3), `pip_graph()` hover info and mermaid (§2); removed:
`rbind(bind =)`, `pip_collect_out()`, `pip_get_graph()` and the re-exported
data.table operators (pubflow used none of them).

**Landed in pipeflow 0.5.0.9002-0.5.0.9012** (planned 2026-10-16 as WP1-3
and `as.function()`; pubflow adopts them as listed in PLAN.md "pipeflow
0.5.0.9012"): `.self` released when a step returns (§3), output hook
`pip_output_value()` (§6), setter hook `` `pip_param_value<-` `` with
collected errors (§4), `as.function()` and `pip_inner()` (§7), plus
`params` overriding defaults (§3), formula values binding in
`pip_set_params()` (§4) and `rbind(bind =)` (§7). The output hook visits
the whole output, not the leaves of plain lists as first planned: pubflow
walks lists in its own method.

**Quirks by design** (no change planned):
- `rbind()` folds param values into the formals of appended steps (§7);
  harmless for pubflow, since pipeflow supplies all arguments of a step.
- The cache of an `as.function()` step function is keyed by the outer
  step name and shared by clones (§7).
- `pip_get_params()` returns the first occurrence of a name (§4); pubflow's
  `pub_get_params()` returns the first *param* occurrence (an internal
  helper after the planned changes). A plain default in an earlier step
  hides a param object of a later one only if the config did not reach
  that step (locked steps; names outside the config): applying the config
  to the whole pipeline at the end avoids it.
- `pip_get_params()` includes locked rows, `pip_set_params()` skips them.
  To read the params of unlocked steps only, use a view:
  `pip_get_params(p[!locked])`.
- Formal defaults are evaluated once, when the step is added (§3).
- `tags %like%` in `[` matches untagged steps (§5).

**Not wanted in pipeflow** (considered 2026-10-04, revised 2026-10-16):
- custom or metadata columns in the step table (metadata lives in the
  param values);
- a param *validation* protocol of its own: validity is part of the
  `` `pip_param_value<-` `` method of the param class (WP3); pipeflow only
  collects the errors and aborts before anything is set;
- hierarchical tags, negation in `pip_view()`, a custom view order (layout
  steps own the document structure, D19);
- namespaced params for inner pipelines (names stay global; nesting itself
  is `as.function()` of a pipeline, §7);
- `pip_add(..., try = TRUE)` (every `~step` becomes `~try(step)`): layout
  steps write `~try(step)` per argument (pubflow's `layout = TRUE` is
  gone, D38). Watch for forgotten `~try()`: a failed input skips the
  whole layout step instead of showing an error box.

**Issue IDs.** DESIGN, PLAN, NEWS and tests refer to the items of the
pipeflow 0.4.0 review (2026-10-04 to 2026-10-13; details, repros and
pubflow's follow-ups in `reference/pipeflow-0.4.0-bugs.md` in git history
up to pubflow 0.0.0.9018). pipeflow grouped them into work packages
WP1-WP8 (`dev/PLAN-0.5.0.md` in the pipeflow repository); pubflow adopted
WP0 (`~try()`) in 0.0.0.9015 and the rest in 0.0.0.9018.

| ID | Issue | Resolved in |
|---|---|---|
| B1 | `x[[step, j]]` on a view read the wrong row | 0.5.0 |
| B2 | clones shared `.self` with the original | 0.5.0 |
| B3 | names held only by locked steps counted as unknown | 0.5.0 |
| B4 | setting params turned "new" steps "outdated" | 0.4.0.9002 |
| B5 | wrong messages (`.self` formal, primitives), dead code, docs | 0.5.0 |
| B6 | running a view outdated steps whose inputs did not change | 0.4.0.9002 |
| B7 | a manual halt was overwritten | 0.5.0 |
| F1 | skip identical values in `pip_set_params()` (`force`) | 0.5.0 |
| F2 | step names in errors, original condition kept | 0.5.0 |
| F3 | `unknown =` in `pip_set_params()` | 0.5.0 |
| F4 | pipelines survive serialisation | 0.5.0 |
| F5 | hook for argument values (`pip_param_value()`) | 0.5.0 |
| F6 | `on_error = "continue"`, failure objects, `~try(step)` | 0.4.0.9002, 0.4.0.9003 |
| F7 | failures in split/reduce chains | (a) 0.5.0; per-key failures 0.5.0.9015 |
| Q1 | formal defaults silently won over `params` (now a warning) | 0.5.0 |
| Q2, Q3 | = F1, F3 | 0.5.0 |
| Q4 | step errors re-raised as plain `simpleError` (= F2) | 0.5.0 |
| Q5 | `pip_replace()` cleared tags and reset exec | 0.5.0 |
| Q6 | step functions rebuilt (attributes dropped, `.self` levels) | 0.5.0 |
| Q7, Q8, Q9, Q11, Q13 | quirks by design (above) | — |
| Q10 | views stored row numbers and went stale | 0.5.0 |
| Q12 | = F4 | 0.5.0 |
| Q14 | default logger not exported | 0.5.0 |
| Q15 | `.self` injected into every step function (D20) | 0.5.0 (only if named) |
| Q16 | views were named "<name> view" | 0.5.0 |
| Q17 | messages via `conditionMessage()` repeated rlang's parent lines | moot since 0.0.0.9018 |
| Q18 | conditions printed in full in the `out` column | 0.5.0 |
| Q19 | warning about an existing edge for repeated references | 0.5.0 |

## 10. Vignettes

`v01-get-started`, `v02-modify-pipeline`, `v03a-combine-pipelines`,
`v03b-pipeline-views`, `v04-collect-output`, `v05a-split-map-reduce`,
`v05b-nested-pipeline` (`as.function()`, `pip_inner()`),
`v05c-error-handling` (failures, `~try()`), `v05d-param-value`
(`pip_param_value()` and its setter), `v05e-output-value`
(`pip_output_value()`), `v06-self-modify-pipeline`;
`articles/v07-vs-targets` ("Comparison and benchmarks") and
`articles/v07b-emulate-targets` (recipes: file tracking, a `tar_meta()`-like
table, saved results, runs in a fresh R process; pkgdown only). Read them in
`~/coding/rlang/pipeflow/main/vignettes/`.
