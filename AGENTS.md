# AGENTS.md

Guidance for coding agents working on **pubflow**, the companion package of pipeflow for
parameter UIs, result viewers and reports ("publishing workflow").

This is the single source of agent instructions. `CLAUDE.md` (for Claude Code) and
`.github/copilot-instructions.md` only point here, so add new instructions to this file.
Keep it to instructions agents can't get from the code or the docs: overviews, file maps
and module descriptions belong in `dev/ARCHITECTURE.md` and `dev/reference/README.md`.

## Start here

The development documents live in `dev/` (excluded from the build).

- `dev/ARCHITECTURE.md` — map of the code: parts, data flow and entry points with
  diagrams; start here if the code is new to you. Update it in the PR that changes the
  structure (new file, part or data flow).
- `dev/DESIGN.md` — the agreed design (source of truth): principles and the decision
  log (D1-D57) with the reasons. Add a decision there when a change settles a design
  question.
- `dev/PLAN.md` — the open work of v0.1 with acceptance criteria. Work on one PR per
  session/branch. Its last section lists open problems of building documents in layout
  steps (D19); check them before starting work. "Later" → "Parked" holds deferred
  ideas: mention the ones that touch the current work. Remove done items and settled
  problems (DESIGN keeps the decisions, NEWS the history).
- `dev/reference/` — research you should not need to redo; its `README.md` lists the
  files. Read `pipeflow.md` (pipeflow 0.5.0.9032 API facts and quirks) before any
  pipeline code; add new pipeflow findings to its §9, which also holds the IDs (B1, F7,
  Q15, ...) that DESIGN and PLAN cite.
- If DESIGN and reality disagree (pipeflow, huxtable, pandoc behave differently than
  described), stop and ask; then update DESIGN in the same branch.
- Before designing a new abstraction (a framework-like layer: tagging, dependency
  tracking, selective re-runs, split/map, ...), check `dev/reference/pipeflow.md` for an
  existing equivalent and prefer extending pipeflow's mechanism over reimplementing it.
  Propose the design (e.g. via plan mode) before writing the implementation, naming what
  pipeflow already provides vs. what is new, so complexity can be caught while it is
  still a paragraph in DESIGN, not hundreds of lines of code, tests and docs.

## Environment

- R: use **`/opt/R/4.5.3/bin/R`** for development. The `R` on PATH is 4.5.1; other
  versions live in `/opt/R/<version>/` (e.g. `/opt/R/4.3.2/bin/R` to reproduce problems
  on the oldest supported version, which CI also checks).
- Dependencies: renv-managed dev library; packages come from CRAN
  (`https://cloud.r-project.org`). Network access from the Bash sandbox may need
  `cloud.r-project.org` in the allowed domains. Don't install into global or system
  libraries.
  - For package projects renv keeps the library **outside the repo**, one per worktree
    path (`~/.cache/R/renv/library/<worktree>-<hash>/`). In a new worktree run
    `$R -q -e "renv::restore(prompt = FALSE)"` once (packages are linked from the renv
    cache).
  - Snapshot type is `"implicit"` with `snapshot.dev = TRUE`: the lockfile records the
    packages that DESCRIPTION (including Suggests) and the R files of the repo use. Dev
    tools that no R file uses (devtools, lintr, rcmdcheck, covr) are listed in
    `dev/dependencies.R`. Add a package with `renv::install("pkg")`, add it to
    DESCRIPTION if pubflow uses it (or to `dev/dependencies.R` if it is a dev tool) and
    record it with `renv::snapshot()`.
  - CI does not use renv (`RENV_CONFIG_AUTOLOADER_ENABLED=false`); it installs the
    dependencies from DESCRIPTION with pak.
  - DESCRIPTION lists the Imports of v0.1, and code in `R/` uses each of them
    (R CMD check notes unused Imports).
- Always start R from the pubflow repo root: starting R inside a client app directory
  activates that app's renv.
- pandoc 3.13 (`~/.local/bin/pandoc`, a link to `~/.local/opt/pandoc-3.13`; the apt
  pandoc 3.8.3 in `/usr/bin` comes later on the PATH). The oldest supported pandoc,
  3.6, is in `~/.local/opt/pandoc-3.6`: run the tests with
  `PUBFLOW_PANDOC=~/.local/opt/pandoc-3.6/bin/pandoc` when a change depends on
  pandoc's output. xelatex from TeX Live 2026 (`~/.local/bin`); typst 0.15.1
  standalone binary (`~/.local/bin/typst`, runs inside the Claude Code Bash sandbox).
  The snap `/snap/bin/typst` is still installed but can't start inside the sandbox and
  has a private `/tmp`; make sure `typst` resolves to `~/.local/bin`.
- Git layout: bare repository `~/coding/rlang/pubflow/pubflow.git` with worktrees;
  `main` is checked out at `~/coding/rlang/pubflow/main`. Milestone worktree example:
  `git -C ~/coding/rlang/pubflow/pubflow.git worktree add ../m2-params -b m2-params main`.
  Remote `origin` = `rpahl/pubflow`. Commit when the user asks (or as agreed for the
  milestone); never push without asking.

## Commands (from the package root)

```bash
R=/opt/R/4.5.3/bin/R
$R -q -e "devtools::document()"
$R -q -e "devtools::test()"
$R -q -e "devtools::test_active_file('tests/testthat/test-param.R')"
air format .
air format --check .
$R -q -e "pkgload::load_all(quiet = TRUE); lintr::lint_package()"
$R -q -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning', check_dir = 'check')"
$R -q -e "devtools::test_coverage_active_file(normalizePath('tests/testthat/test-cache.R'))"
$R -q -e "covr::report(covr::package_coverage(), 'check/coverage.html', browse = FALSE)"
```

- Coverage: `test_coverage_active_file()` covers one source file with its test file
  (it needs an absolute path); `package_coverage()` covers the whole package (about
  1.5 min).

- Format with [air](https://posit-dev.github.io/air/) (`air.toml`) before committing;
  the binary ships with the Air VS Code extension
  (`~/.vscode-server/extensions/posit.air-vscode-*/bundled/bin/air`). air keeps existing
  line breaks inside calls, so it may not undo a manual wrap; join such lines yourself.
  Mark hand-aligned code (e.g. tables of values) with `# fmt: skip`. CI
  (`.github/workflows/lint.yaml`) runs `air format --check .` before lintr and fails on
  unformatted files; it checks the indentation instead of lintr's slow
  `indentation_linter` (off in `.lintr`). Keep formatting-only commits separate and list
  them in `.git-blame-ignore-revs`.
- Lint with the package loaded: lintr's `object_usage_linter` resolves functions defined
  in other files via the package namespace, otherwise it reports them as "no visible
  global function definition".
- CI (`.github/workflows/lint.yaml`) lints with
  `pkgload::load_all(quiet = TRUE, helpers = FALSE, attach_testthat = FALSE); lintr::lint_package()`:
  without the test helpers and without testthat attached, so top-level functions in
  test files must not call `expect_*()` or helpers of other files (define such functions
  inside `describe()`). Run the same command locally before pushing.
- R CMD check skips snapshot tests (testthat skips them unless `NOT_CRAN=true`);
  `devtools::test()` and CI run them.
- `NAMESPACE` and `man/` are generated by roxygen (`devtools::document()`); don't edit
  them by hand.

## Before opening a PR

- Clean up and review the branch's changes against `main`. First simplify
  them (Claude Code: `/simplify`), then review them for bugs (Claude Code:
  `/code-review high`), and fix or explicitly dismiss each finding.
- Run the full check in this order: format (`air format --check .`), lint, tests,
  R CMD check. Target for every PR: tests green, lint clean, R CMD check 0 errors /
  0 warnings / 0 notes.
- If the same failure is still there after 3 fix attempts, stop and summarize the
  attempts instead of weakening tests or masking errors.
- Note user-facing changes in `NEWS.md`.
- Bump the version as the last commit of a PR (no CI job does it;
  `.github/workflows/version-bump.yaml` only checks it): rebase on `main` first (so the
  version doesn't clash with other PRs), increment the development version in
  `DESCRIPTION` (`0.0.0.9027` → `0.0.0.9028`), make sure the top heading of `NEWS.md` is
  `# pubflow <new version>` with the PR's bullets under it, and commit as
  `chore: bump version to <version>`. PRs that change only documentation or CI need no
  bump: label them `no-version-bump`.

## Code style

- Keep the exported API lean: export a function only for a clear user use case that
  existing exports don't cover; otherwise keep it internal (`.name`, `@noRd`) or extend
  an existing function. Don't add convenience wrappers that only save a line.
- List every new exported help topic in the `reference:` index of `_pkgdown.yml`
  (`pkgdown::build_reference_index()` fails on a missing topic).
- Native pipe `|>`; 4-space indentation; lines <= 88 characters (`.lintr`, `air.toml`).
- Functions snake_case; local variables camelCase; internal helpers start with `.`;
  exported non-param functions start with `pub_`; param functions are named after the
  param concepts (`param()`, `param_value()`, ...); S3 classes `pub_*`; error classes
  `pubflow_*`; CSS/JS prefix `pubflow`.
- roxygen2 for every function: exported ones with full docs and runnable examples,
  internal ones with `@noRd`.
- Keep functions short (ideally <= 50 lines).
- Source files are split into sections: a full-width `# ====` banner opens a block, a
  short `# ---` rule as long as its title a section within it (small files have
  sections only). In a section the exported function comes first, then its helpers in
  the order they are called; helpers used by several blocks go into a last "Helpers"
  block, helpers used by several files into `R/utils.R`. Put a new function into the
  section it belongs to (see "Sections" in `dev/ARCHITECTURE.md` §2).
- Conventional commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`,
  `style:`).

## Hard rules (see DESIGN §3)

- No knitr/rmarkdown dependency; pandoc is called directly.
- No S3 methods for base classes (e.g. no `print.factor`; the exception is
  `pip_output_value.list()` on pipeflow's output hook, D38), no global options
  changed on load, no Shiny private internals (`session$.__enclos_env__`), no
  per-session state in package globals.
- Step functions never see param objects (pubflow's `pip_param_value.param()` method).
  Steps are added with `pipeflow::pip_add()`; layout steps write `~try(step)` for inputs
  that may arrive failed.
- Never embed errors silently in rendered documents.
- Format all times with an explicit `tz = "UTC"`.
- Call huxtable functions with `huxtable::` (flextable masks `to_html`,
  `set_caption`); never subclass huxtables.

## Tests

- testthat 3rd edition, `tests/testthat/test-<source-file>.R`, `describe()`/`it()`
  style; add tests together with the code. A test file follows the sections of its
  source file in the same order; tests that span the file go last under "Scenarios".
- Mock external tools (pandoc/typst discovery) and Shiny messages
  (`session$sendCustomMessage`) with mockery or local bindings.
- In `shiny::testServer()` the module namespace is `proxy1`: build expected ids with
  `session$ns()`. The module's session proxy is locked: record
  `sendCustomMessage`/`sendInputMessage` by assigning mocks to `session$rootScope()`
  (see `capture_messages()` in `tests/testthat/helper-shiny.R`). `testServer()` renders
  outputs during `session$flushReact()`.
- After test runs, check `git status` for unexpected snapshot changes or deletions.

## Related repositories (read-only)

- pipeflow 0.5.0.9032 (GitHub commit 2ee2970, pinned in `Remotes` and `renv.lock`;
  required since pubflow 0.0.0.9047). pipeflow development source:
  `~/coding/rlang/pipeflow` (bare repo `pipeflow.git` with worktrees; GitHub
  `rpahl/pipeflow`; the local `main` worktree may lag behind GitHub, so check
  `gh api repos/rpahl/pipeflow/commits` or ask)
