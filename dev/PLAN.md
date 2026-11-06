# pubflow v0.1 — implementation plan

How to use this plan:
- One working session per PR. Start by reading `../AGENTS.md`, the
  decisions in `DESIGN.md` that touch the work, and the referenced `reference/` notes.
- Work on a branch from `main` (e.g. `m9c-release`) and open a PR to `main`
  when the acceptance criteria are met.
- Tick the checkboxes here as part of the PR's last commit; remove items
  and open problems once they are done or settled (DESIGN.md keeps the
  decisions, NEWS.md what each version added).
- If DESIGN.md is ambiguous or contradicts what pipeflow/huxtable/pandoc
  actually do, stop and ask; record the outcome in the decision log of
  `DESIGN.md` in the same PR.

Definition of done (every PR): new code fully tested; `devtools::test()`
green; `lintr::lint_package()` clean;
`rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")` with 0
errors / 0 warnings / 0 notes; NEWS.md entry; roxygen docs current;
development version bumped by one in `DESCRIPTION` (M9 releases 0.1.0)
with a matching NEWS heading `# pubflow <version>`. CI
(`.github/workflows/version-bump.yaml`) fails a PR whose version is not
higher than on `main`; label PRs that need no bump (documentation or CI
only) `no-version-bump`.

**Status:** M1-M8 are done (params, pipeline integration, param UI,
outputs, document tree and layout steps, HTML renderer, figure cache and
viewer, Pandoc path for DOCX, PDF and Markdown); M9 is in progress.

---

## M9 — Reports, traceability, post-processors, docs

Done: report specs, page setup, front matter, render-time metadata, trace
stamp and file names (D30-D32); DOCX post-processors for header/footer
lines and locks (D33); rounding half away from zero with `pub_round()` and
`pub_format_num()` (D16); pipeflow 0.5.0 from CRAN (D9); documents across
pipelines with `pub_out()` and a report pipeline (D34); pipeflow
0.5.0.9012 replaces pubflow's own machinery: params are set with its
setter hook (D36), nested pipelines are pipeline functions (D37), figures
are stamped by its output hook and steps are added with `pip_add()`
(D38); pipeflow 0.5.0.9025 fails mapped steps per key (D21); vignettes
v01-v06 (D2); accessible param UI (D50).

- [ ] Benchmarks recorded (R15 HTML/DOCX/PDF).

Acceptance:
- end-to-end test: demo pipeline -> layout step -> `pub_render()` for html,
  docx, pdf (engines permitting), md (done: `test-report-app.R`, with the
  report app's downloads and the serialized size of its documents, D20);
- R CMD check 0/0/0; tag `v0.1.0` after review.

---

## Later

- Later versions: see `DESIGN.md` §1.

### Parked (decide when convenient)

- **React param form via shinyreact** 
  shinyreact 0.1.0 was assessed and not adopted; the current modules
  already work in `page_react()` apps
  (`renderUI(pub_params_ui("pipeline"))` hosted by `ShinyOutput`, plus a
  Bootstrap theme). Revisit if an app moves to React: a state-driven
  form would replace render-once/update-in-place and `syncInputValue`, but
  needs a JSON description of params, a JS bundle with a build chain, and
  a second UI next to the Shiny one. For it: the input state lives in two
  places (widgets and the module's `validValues`/`seen`), which made the
  group sync bug possible (fixed in 0.0.0.9044: the children of a group
  were synced one by one, and the server set the mix of new and old
  values).
  Against: validity functions are R code (they would be duplicated in JS or
  checked by round trips, and the server validates anyway, also locks,
  D48), server-side updates stay (refresh, step locks, rejected values),
  and custom widgets (`ui_widget = <function>`) don't map to JSON. "Set
  only when the pipeline runs" needs no client-side form: apps already
  decide when to run, and an "Apply" option of the module would be small.
- **Params that follow other params** (seen in the example apps' range
  param, which follows the predictor): apps replace the param with
  `pip_set_params()` in an observer on `revision()` with a higher priority
  than the outputs, keep the config `order` by hand
  (`attr(new, "order") <- param_attr(old, "order")`) and bump `refresh`.
  Options: keep the stored `order` when a param is replaced (pipeflow or a
  pubflow setter), a module hook called after `pip_set_params()` and
  before `revision` goes up.
- **Atomic group sync on the server**: the module takes a mix of new and
  old child values as a user edit; since 0.0.0.9044 the client sends the
  children in one message (Shiny batches default-priority values). A
  server-side guard (ignore group states that mix expected and old values)
  or one Shiny input per group would make it independent of the client.
- **Locked params in `pub_params_table()`** (D48): mark the params that a
  workflow fixes (attribute `locked`, step locks), e.g. for a QC report.
- **Cross-references, more** (D44): per-section scoping of duplicate ids
  (a mapped step gives every partition a figure with the same id; a
  reference would resolve to the one in the innermost section around the
  text), references in captions and titles, section references
  (`@sec:`), widgets as targets.
- **Slow `huxtable::to_typst()`**: ~0.5 ms per cell, 10-15x
  `to_latex()`/`to_html()` (6 columns: 40 rows 110 vs 13 ms, 160 rows 523
  vs 39 ms); 95% of `pub_markdown(target = "typst")` on R15 (5.3 s), so
  a Typst PDF takes 10.9 s cold / 6.5 s warm, although pandoc + typst need
  only ~1.2 s. Cause: `typst_cell()` calls ~25 property getters per cell,
  each building the whole table's matrix to read one element (86% in
  `typst_stroke()`: 12 border getters plus `format_color()`). Options: (1)
  upstream PR to huxtable that fetches the property matrices once before
  the cell loop (preferred; no issue filed yet); (2) pubflow's own Typst
  table writer, like the WML writer (duplicates huxtable); (3) keep the
  Typst code in the render cache like table HTML (D25), helps warm renders
  only. Estimate with fast tables: ~6 s cold (mostly figures), ~1.5 s
  warm. Faster HTML -> PDF/DOCX tools were considered and rejected:
  headless Chrome needs Chrome on Connect and paged.js for TOC page
  numbers, WeasyPrint is slower, Prince is commercial; HTML -> DOCX
  converters (LibreOffice, altChunk) lose fidelity and are not faster.
- **Cold figures**: ~115 ms per ggplot (png 200 dpi), rendered one by one
  (`.render_figure()` via `R/render_html.R`), so R15's 45 figures cost
  ~5 s on a new cache. Since D40 the viewer and every format share them,
  so this is paid once per figure and re-run, not per format. Option:
  render the missing figures of a document in parallel before emitting it
  (fork on Linux, e.g. `parallel::mclapply()`; needs a Windows fallback).
  Steps that render their figures (D43) render them where they run, so
  apps with workers render in parallel already.
- **Provenance of items in the viewer** (D41): if a need comes up (e.g.
  "made by step X" hints for debugging), stamp tables with a
  `pip_output_value.huxtable()` method and texts as a pubflow class (not
  plain character), and leave the stamp out of the table cache key (D25).
- **Diagnostic for outputs that reach their pipeline** (D20): an opt-in
  warning (`getOption("pubflow.check_output_environments", FALSE)`, class
  `pubflow_output_reaches_pipeline`, naming step and binding) in the
  figure hook, also for figures in lists, following only the chains of
  `plot_env` and the mapping quosures and skipping unforced promises and
  active bindings (~0.1 ms per ggplot). A hint, not a validator (a miss
  proves nothing). Revisit with the parallel figure rendering above,
  where documents cross processes.
- **Building tables in steps**: `pub_table()` of a 40x8 table takes ~15
  ms, ~50 ms with spanner, footnote and merged column; `pub_strikeout()` of
  20 rows ~22 ms. About half is huxtable's property setters (`prop_set()`
  validation), the rest `merge_cells()`, `rbind()`/`as_hux()` and
  footnotes. For R15's 75 tables that is 1-4 s per full pipeline run,
  spread over steps and repeated only for steps that rerun, hence low
  priority. Option: fewer, bulk huxtable calls (set properties as matrices
  once, build the spanner row without `rbind()`).

---

## Open problems

Documents are built in pipeline steps (D19); these problems come with
that decision. Tackle them one at a time; pipeflow may be changed where
that is not invasive (D9). The numbers are IDs (DESIGN.md and notes cite
them), so settled problems leave gaps.

None open: problems 2, 5, 8, 10 and the roundtrip of outputs across
processes are settled (D41, D42, D20, D21, D43).
