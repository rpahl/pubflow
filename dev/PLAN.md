# pubflow v0.1 — open work

One PR per session, from a branch off `main`. Read `../AGENTS.md` and the decisions in
`DESIGN.md` that touch the work first. Remove items here once they are done or settled
(DESIGN.md keeps the decisions, NEWS.md what each version added). If DESIGN.md
contradicts what pipeflow, huxtable or pandoc do, stop and ask, and record the outcome
in the decision log in the same PR.

**Definition of done** (every PR): the checks of "Before opening a PR" in `AGENTS.md`,
a NEWS entry and the development version bumped by one (M9 releases 0.1.0), see
`.github/workflows/version-bump.yaml`; label PRs that change only documentation or CI
`no-version-bump`.

**Status:** M1-M8 are done; M9 (reports, traceability, post-processors, docs) is in its
last step, the release.

## Release v0.1.0 (first CRAN version)

- [ ] pubflow validated in a real project; findings fixed.
- [ ] pipeflow 0.6.0 on CRAN; `Remotes` and the pin removed.
- [ ] R CMD check 0/0/0, version 0.1.0 with a NEWS heading, tag `v0.1.0`, GitHub
  release, CRAN submission.

---

## Later

- Later versions: see `DESIGN.md` §1.
- **Benchmark R15 body rows**: `inst/bench/r15.R` computes body rows as
  `sum(header_rows(ht)) + i`; switch to `pub_table_rows(ht)$body` when the benchmark is
  next recorded (it also runs against versions before 0.0.0.9049). Its texts and labels
  were reworded after the last recording, so expect small shifts.

### Parked (decide when convenient)

- **React param form via shinyreact**: assessed and not adopted; the modules already
  work in `page_react()` apps (`renderUI(pub_params_ui("pipeline"))` in `ShinyOutput`).
  Revisit if an app moves to React. A state-driven form needs a JSON description of
  params, a JS bundle and a second UI; validity functions are R code and the server
  validates anyway (also locks, D48), and custom widgets don't map to JSON.
- **Params that follow other params** (the example apps' range param follows the
  predictor): apps replace the param with `pip_set_params()` in an observer on
  `revision()`, keep the config `order` by hand and bump `refresh`. Options: keep the
  stored `order` when a param is replaced, or a module hook called after
  `pip_set_params()` and before `revision` goes up.
- **Atomic group sync on the server**: the module takes a mix of new and old child
  values as a user edit; the client sends the children in one message since 0.0.0.9044.
  A server-side guard or one Shiny input per group would make it independent of the
  client.
- **Locked params in `pub_params_table()`** (D48): mark the params that a workflow
  fixes (attribute `locked`, step locks), e.g. for a QC report.
- **Cross-references, more** (D44): per-section scoping of duplicate ids (a mapped step
  gives every partition a figure with the same id), references in captions and titles,
  section references (`@sec:`), widgets as targets.
- **Slow `huxtable::to_typst()`**: ~0.5 ms per cell, 10-15x `to_latex()`/`to_html()`;
  95% of `pub_markdown(target = "typst")` on R15 (5.3 s), so a Typst PDF takes 10.9 s
  cold / 6.5 s warm, although pandoc + typst need ~1.2 s. Cause: `typst_cell()` calls
  ~25 property getters per cell, each building the whole table's matrix. Options: (1)
  upstream PR to huxtable that fetches the property matrices once (preferred; no issue
  filed yet); (2) pubflow's own Typst table writer, like the WML writer; (3) keep the
  Typst code in the render cache (D25), which helps warm renders only. Other HTML -> PDF
  or DOCX tools (headless Chrome, WeasyPrint, Prince, LibreOffice) were rejected.
- **Cold figures**: ~115 ms per ggplot, rendered one by one, so R15's 45 figures cost
  ~5 s on a new cache, paid once per figure and re-run, not per format (D40). Option:
  render the missing figures in parallel before emitting the document (fork on Linux,
  needs a Windows fallback). Steps that render their figures (D43) already do so where
  they run.
- **Provenance of items in the viewer** (D41): if "made by step X" hints are needed,
  stamp tables with a `pip_output_value.huxtable()` method and texts as a pubflow class,
  and leave the stamp out of the table cache key (D25).
- **Diagnostic for outputs that reach their pipeline** (D20): an opt-in warning
  (`getOption("pubflow.check_output_environments", FALSE)`, class
  `pubflow_output_reaches_pipeline`) in the figure hook that follows the chains of
  `plot_env` and the mapping quosures (~0.1 ms per ggplot). A hint, not a validator.
  Revisit with parallel figure rendering, where documents cross processes.
- **Building tables in steps**: `pub_table()` of a 40x8 table takes ~15 ms (~50 ms with
  spanner, footnote and merged column), about half in huxtable's property setters. For
  R15's 75 tables that is 1-4 s per full run, repeated only for steps that rerun: low
  priority. Option: fewer, bulk huxtable calls.
