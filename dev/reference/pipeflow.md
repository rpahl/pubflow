# pipeflow — facts relevant for pubflow

Checked 2026-11-15 against **pipeflow 0.6.0** (tag `v0.6.0`, `d0ceae1`; GitHub
`rpahl/pipeflow`, public; source in `~/coding/rlang/pipeflow`, bare repo
`pipeflow.git` with worktrees). pubflow requires 0.6.0 from CRAN (D9). The API is in pipeflow's
help pages, its `NEWS.md` (with the changes of each version) and its vignettes; its
`dev/pipeflow.md` maps the code, the run flow and the invariants. This file keeps only
what shapes pubflow and is easy to get wrong. pipeflow's maintainer is the pubflow
maintainer: a problem that is better solved in pipeflow may be solved there if the
change is not invasive (D9). Record new pipeflow bugs, quirks and requests under "Open
issues".

## Object model

- A pipeline is `structure(list(name, view, pipenv), class = "pipeflow")`, **not R6**.
  `pipenv` is an environment shared by the pipeline and all of its views; functions
  mutate by reference and return `x` invisibly. S3 subclassing is fragile: `pip_view()`,
  `[`, `pip_clone()` and `rbind()` return plain `"pipeflow"` objects.
- `pipenv$data` is a data.table with one row per step in topological order. **No custom
  columns** (the next `pip_add()` fails) and no metadata column: param metadata lives
  inside the param *values* (pubflow's `param` objects).
- Pipelines survive `saveRDS()`/`readRDS()` and can be sent to other R processes.
- Writing a step property (`x[[step, j]] <- value`, `[<-`) outdates steps as listed in
  `?Extract.pipeflow` ("Which assignments outdate steps"); a bulk `[<-` changes all
  selected steps or none.
- `pip_clone(x, out = )` keeps only the outputs of the named steps (`character(0)`:
  none; done steps without output become "outdated"; failed and locked steps keep
  theirs). pubflow uses it to send results back from a worker (D60).

## Step functions

- **Every formal except `...` needs a default or a value in `params`**. Defaults are
  evaluated **once, when the step is added**, in `environment(fun)` (a `Sys.time()`
  default is frozen). `params` override the defaults; names that aren't formals are an
  error unless `fun` has `...`.
- Dependencies are one-sided formulas `~step` or `~-k` (relative) in defaults or
  `params`; the other params are the *unbound* ones. `~try(step)` is the same
  dependency and marks an argument that may receive a failure object. The mark lives in
  the step's params, so a new function's formals decide it on `pip_replace()`. Step
  names must not start with `-`.
- **`.self`** is provided only to a function whose body names it, and released when the
  step returns (also on error), so outputs that capture the step frame (ggplots,
  closures) don't keep the pipeline alive (D20); a returned closure that uses `.self`
  later fails. A `.self` formal or param is an error.
- A step function is called by the step name with its arguments as symbols (`fit(x =
  x)`), so errors and `match.call()` don't hold the step's inputs.
- A step that changes its own function, params or exec mode during its run (through
  `.self`), or that a later step changes, ends the run "outdated" and runs again in the
  next run; `pip_run()` warns (`pipeflow_outdated_before`).

## Parameters and hooks

- **`pip_param_value(x, ...)`** (S3 generic, default `x`) is applied to each **unbound**
  argument of a step call right before the call; not to `~step` inputs, partitions or
  failure objects. pubflow's `pip_param_value.param()` gives step functions plain
  values, also for steps added with `pipeflow::pip_add()`.
- **`` `pip_param_value<-`(x, ..., value) ``** is the write side. `pip_set_params()`
  calls it per row with the stored value as `x`, computes all rows first and, if any
  method fails, sets **nothing** and raises one `pipeflow_set_params_error` (fields
  `errors`: data.frame `step`, `name`, `message`; `parents`). pubflow merges the value
  and validates in its method (D36). A method should keep `pip_param_value(`
  `` `pip_param_value<-`(x, value = v)) == v `` and not modify `x` in place.
- `pip_set_params(x, params, unknown, force, scope, ...)`: every element named; skips
  values `identical()` to the stored one unless `force`; changed rows and the done rows
  downstream become "outdated". On a view, values go to every unlocked row of the
  **pipeline** that has the name unbound (`scope = "pipeline"`, default); `scope =
  "view"` restricts them to the view. `unknown = "warn"|"ignore"|"error"` for names that
  are unbound nowhere in the view.
- **A one-sided formula value binds the param** (all selected unlocked rows that have it
  unbound, to a step that comes before). Formula values are therefore passed as strings
  and turned into formulas in the step; two-sided formulas are values. See the first
  open issue below for pubflow's classed params.
- `pip_get_params(x)`: unbound params only, locked rows included; duplicate names keep
  the **first occurrence** (a plain default in an earlier step hides a param object of a
  later one). `simplify = FALSE` returns all values grouped by name and named by step.
- `pip_add()`, `pip_replace()` and `rbind()` warn (`pipeflow_param_conflict`) if an
  unbound param of a new step has another value than the same param elsewhere;
  `pip_replace(keep_params = TRUE)` keeps the stored values (D46).
- **`pip_output_value(x, ctx, ...)`** (S3 generic, default `x`) is applied once to the
  whole output of every step when the step returns (once per partition key for
  partitioned outputs); list leaves are not visited. `ctx = list(step, key, time)`. Not
  applied to failures or inputs. Inner steps of `as.function()` are annotated in the
  inner run and again in the outer one, so methods must be idempotent. pubflow stamps
  figures for the render cache here (D22).

## Tags and views

- Tags are flat strings. `pip_view(x, tags = )` matches steps with **any** of the tags;
  filters combine with AND or OR; **no negation** (use `[`).
- Pitfall: in `[` expressions `tags %like% "char"` matches the deparsed list column, so
  untagged steps match "char" and substrings match. `pip_view(tags = )` is not affected.
- A view is the same object whose `view` field holds the node ids of its steps; it stays
  valid when steps are added, removed or renamed, and its rows keep pipeline order.
  `view[["pipenv"]]` is shared with its pipeline. Running a view runs its steps plus
  their upstream steps. `pip_add()`, `pip_clone()` and `rbind()` don't work on views.
- `pip_collect(by = "tags")`: a step appears in every one of its tag groups, untagged
  steps are omitted; `simplify = TRUE` flattens only if all groups have one step.

## Running, outputs and errors

- Step states "new", "outdated", "done", "failed"; run states "ready", "running",
  "restart", "halted", "failed", "continued". `pip_run()` skips "done" steps (unless
  `force`) and locked steps, but re-runs a done step whose input ran in the same run.
- `progress(value, detail)` is called before every step; if it returns `FALSE`, the run
  is halted (a Shiny app can cancel between steps).
- `time_start` and `duration` are set for every run of a step, also a failed one; `time`
  is the end of the last successful run (it is `ctx$time` of the output hook).
- `map` (`pip_run(map = )`): a function like `lapply()` that runs the keys of mapped
  steps, e.g. in parallel. Steps that name `.self` and `as.function()` steps with
  `cache = TRUE` still run their keys one after another. The output hook runs in the
  main process on the returned outputs (figures crossed a process boundary, D43).
- **`on_error = "stop"`** (default): the failed step's condition is stored as its
  output; `pip_run()` signals a `pipeflow_step_error` (fields `step`, `parent` = the
  step's own condition, so a classed condition survives as `parent`). A failed
  partition's condition is a `pipeflow_key_error` (field `key`).
- **`on_error = "continue"`**: steps with a failed input that is not a `~try()`
  reference are skipped; a `~try()` argument gets a failure object of class
  `c("pipeflow_failure", "error", "condition")` (fields `message`, `step`,
  `failed_step`, `parent`). The run ends in run state "continued" with a
  `pipeflow_run_failed` warning (fields `failed`, `skipped`, `keys`). Failure objects are
  light (they don't carry the step's inputs). A mapped step fails **per key**: its
  output keeps the results of the keys that succeeded plus a `pipeflow_failure` (field
  `key`) per failed key. Downstream, a mapped step isn't called for failed keys unless
  the argument is `~try()`; a `reduce` or `split` step is skipped unless `~try()`.
- The next run calls a failed mapped step only for its failed keys (not for a copy made
  by `pip_clone()`, see "Open issues").
- Exec modes `"auto"|"split"|"reduce"|"plain"`; split outputs are lists of class
  `c("list", "pipeflow_partitioned")`.

## Nesting and combining

- **`as.function(inner, out, cache, on_error, lgr)`** turns a pipeline into a step
  function whose formals are `pip_get_params(inner)`, so the inner param objects become
  params of the outer step; setting one outdates the outer step. `cache = TRUE` keeps
  one run inner pipeline per outer step name and partition key (the cache lives in the
  function: clones share it; `pip_run(force = TRUE)` doesn't force inner runs).
  `pip_inner(x, step)` returns the kept pipelines. With `"stop"` the outer error nests
  the inner one; with `"continue"` the call fails only if a step named in `out` failed.
  Param names stay global (no namespacing).
- A step that returns a pipeline stores a `"pipeflow"` object in `out`; `pip_collect()`
  doesn't recurse into it.
- `rbind(a, b)`: clashing step names get numeric suffixes with rewired depends; the
  current param values of the steps of `b` are folded into the defaults of their
  functions' formals. **Param names stay shared** (`pip_get_params()` shows the first,
  `pip_set_params()` sets all). To feed steps of `b` with outputs of `a`, bind their
  params afterwards with a view of `b`'s steps.

## Consequences for pubflow

1. Param metadata travels inside param values. pubflow registers
   `pip_param_value.param()`; its output hook methods stamp figures (D22), and the
   `.self` release keeps outputs from reaching the pipeline (D20), so pubflow has no
   step wrapper (D38).
2. Merge-on-set and validation happen in pubflow's setter method (D36); collecting the
   errors, change detection and unknown names are pipeflow's.
3. Look up the first **param** occurrence across all rows, not `pip_get_params()`' first
   occurrence: pubflow picks it from `pip_get_params(simplify = FALSE)`.
4. After `rbind()`, apply the merged param config so all rows share the same param
   objects.
5. Document structure is explicit (layout steps, D19): tags are flat and views keep
   pipeline order. Layout steps write `~try(step)` per argument; a forgotten `~try()`
   skips the whole layout step instead of showing an error box.
6. Partitioned outputs are placed by pubflow (one section per key); a failed key arrives
   as a `pipeflow_failure` inside the partitioned output and becomes an error box (D21).
7. The step's own condition (e.g. a `pubflow_error`) is the `parent` of the
   `pipeflow_step_error`; errors of the setter (`pubflow_invalid_param`) are the
   `parents` of a `pipeflow_set_params_error`.

## Open issues

Add new findings here: bugs with a reproducible example and a suggested fix, quirks, and
feature requests with their value for pubflow and their cost (pipeflow stays lean: only
features that make pubflow a lot simpler or that many R users need). All are open in
0.6.0.

- **Clones forget the failed keys** (found 2026-11-15; pipeflow #172): `.pip_clone()`
  doesn't copy `.steps_with_current_out`, so a run of a clone (`pip_clone()`, `p[]`)
  calls a failed mapped step for all its keys again. Matters for apps that send a clone
  to a worker after a partly failed run. Fix: copy the environment. Low priority.
- **Annotated formula values bind** (found 2026-10-20): `pip_set_params()` treats any
  value with `inherits(x, "formula") && length(x) == 2` as a binding
  (`.is_one_sided_formula()`, `R/utils.R`), so a pubflow `param(~a)` binds to step `a`
  instead of being a value. Possible fix: bind only unclassed formulas, or test
  `pip_param_value(x)`. Low priority: the documented way is a string.
- **Print footer in local time** (found 2026-10-26): the footer of `print()` shows the
  last run in the session's time zone, `pipeflow_lgr()` logs in UTC. Cosmetic; pubflow
  doesn't print pipelines in documents.
- **Unnamed empty grouping** (found 2026-10-31): `pip_get_params(x, simplify = FALSE)`
  returns an unnamed `list()` if no row has unbound params. Fix:
  `setNames(list(), character(0))`. pubflow's `pub_get_params()` returns a named empty
  list itself. Low priority.
- **Step names that can't be arguments** (found 2026-11-14): `pip_add()` accepts steps
  named `.self` and `...`, but no step can take them as an argument of the same name (a
  `...` argument with a `~step` default is dropped, so the dependency is silently
  missing). pubflow's `.try_inputs()` rejects such steps. Fix: reject the names in
  `pip_add()`. Low priority.

**Quirks by design** (no change planned):
- `pip_get_params()` includes locked rows, `pip_set_params()` skips them; to read the
  params of unlocked steps only, use `pip_get_params(p[!locked])`.
- `pip_get_params()` returns the first occurrence of a name; a plain default in an
  earlier step hides a param object of a later one only if the config did not reach that
  step (locked steps, names outside the config): apply the config to the whole pipeline
  at the end.
- `rbind()` folds param values into the formals of appended steps; harmless, since
  pipeflow supplies all arguments of a step.

**Not wanted in pipeflow** (considered 2026-10-04, revised 2026-10-16):
- custom or metadata columns in the step table (metadata lives in the param values);
- a param *validation* protocol of its own: validity is part of the
  `` `pip_param_value<-` `` method of the param class;
- hierarchical tags, negation in `pip_view()`, a custom view order (layout steps own the
  document structure, D19);
- namespaced params for inner pipelines;
- `pip_add(..., try = TRUE)` (every `~step` becomes `~try(step)`): layout steps write
  `~try(step)` per argument.
