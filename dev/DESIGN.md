# pubflow — design

The agreed design of pubflow and the reasons behind it. `ARCHITECTURE.md` maps the
code; `PLAN.md` lists the open work; the help pages and vignettes document the API.
This file keeps what none of them show: **why** things are the way they are. Cite a
decision by its number (D1-D53) in code comments, commits and PRs, and add a new one
here (not a renumbering) when a change settles a design question.

## 1. Purpose and scope

pubflow is the companion of [pipeflow](https://github.com/rpahl/pipeflow). pipeflow
computes; pubflow covers everything around a pipeline that is needed to *publish* its
results:

1. **Parameters**: self-describing param objects, configs, validity checks.
2. **Parameter UI**: Shiny modules that build inputs from a pipeline's params.
3. **Outputs and documents**: conventions for step outputs (tables, figures, text) and
   a document tree that layout steps build from them.
4. **Viewer and rendering**: HTML for the in-app viewer; HTML, DOCX, PDF and Markdown
   files.
5. **Reports**: report specs, traceability (trace stamp, file names, session info) and
   DOCX post-processors (header and footer lines, locks).

Non-goals: app-specific content, data access, statistics, async orchestration (apps do
it; pubflow offers pure functions that run in any worker), Excel/PowerPoint export,
conditional params, interactive widgets in DOCX/PDF.

Later versions: incremental per-section viewer updates and lazy image loading;
conditional params (`visible_if`); interactive widgets with static fallbacks; Excel
export of tables; offline math for HTML files (bundled KaTeX/MathJax).

## 2. Constraints

- Develop with R 4.5.3; support R >= 4.3 (CI checks the oldest).
- pipeflow >= 0.5.0.9032, pinned by commit in `Remotes` until it is on CRAN (D9).
- pandoc >= 3.6; optional xelatex and typst for PDF.
- Regulated (GxP-style) use: traceable, deterministic output; errors never silently
  in a deliverable; all times in UTC.
- Performance matters (see §4).

## 3. Principles

- **pubflow never runs a pipeline** (D19): apps and tests call `pip_run()`.
- **Same document and spec give identical Markdown/HTML**: stable ids and numbering, no
  randomness, time only from metadata.
- **A table shows identical cell text in every output format** (D15, D16).
- **Errors are never embedded silently**: an error in a document is an explicit error
  item (a marked box) that reports refuse unless asked otherwise (D21, D32).
- No global options changed on load; no S3 methods for base generics (the one exception
  is a method on pipeflow's own output hook, D38); no Shiny private internals; no
  per-session state in package globals.
- Prefer extending pipeflow's mechanisms to reimplementing them (D9, D19, D36-D38).

Error classes all inherit `pubflow_error` (`pubflow_invalid_param`,
`pubflow_render_error`, `pubflow_tool_missing`, `pubflow_unsupported_output`,
`pubflow_pipeline_output`, `pubflow_not_done`); they are rlang errors built in
`R/errors.R`. Step errors are pipeflow's (`pipeflow_step_error`, `pipeflow_key_error`).

## 4. Performance targets

Workload "R15" (`inst/bench/r15.R`): 15 sections, one pipeline per test, each with 4
texts, 3 tables and 3 figures, plus 30 extra tables. Targets: making the document from
computed outputs < 200 ms; `pub_html()` with a warm cache < 500 ms (measured 99 ms);
`pub_render(format = "docx")` with a warm cache < 5 s; native Word table 40x8 < 10 ms;
param UI initial render (20 params) < 100 ms. Benchmarks do not run on CI; record
results in the PR (`reference/benchmarks.md` has the measurements behind the decisions).

## 5. Decision log

### Scope and dependencies

| # | Decision |
|---|---|
| D1 | The package is called **pubflow** ("publishing workflow"). |
| D2 | No knitr/rmarkdown in the rendering. Outputs go into an in-memory **document tree**, rendered to HTML with htmltools (UI, HTML files) or to **Pandoc Markdown with raw format-specific blocks and one pandoc call** (DOCX, PDF, Markdown). The vignettes use knitr and rmarkdown (Suggests only). |
| D3 | PDF via LaTeX (xelatex, default) and Typst (optional). |
| D7 | Scope of v0.1: params, param UI, outputs and tables, document tree, HTML renderer and viewer, DOCX/PDF/Markdown rendering, report specs and post-processors. |
| D9 | Requires pipeflow >= 0.5.0.9032. A problem better solved in pipeflow is solved there (the maintainer is the same) if the change is not invasive; pubflow then pins the pipeflow commit until it is on CRAN. pipeflow hands plain values to step functions through pubflow's `pip_param_value()` method. |
| D12 | The Shiny UI works with Bootstrap 3 and 5. |
| D13 | Develop with R 4.5.3, support R >= 4.3, verified on CI. |

### Parameters

| # | Decision |
|---|---|
| D8 | Params are self-describing objects (`param()`) with validity rules; cross-field rules use `param_group()` plus `add_validity()`. |
| D10 | Categorical params are **factors** (levels = choices); yes/no choices are lowercase. |
| D11 | Invalid input: inline message, highlight and **restore the last valid value** (default); "keep and mark invalid" is optional. |
| D35 | No exported attribute filter for configs: filtering the params of a pipeline is `pub_get_params(x, ...)`, filtering a config is `Filter()`. |
| D36 | Params are set with **pipeflow's setter hook**: pubflow's method for `` `pip_param_value<-` `` merges a plain value into the stored param and validates it; `pipeflow::pip_set_params()` collects all failures and sets nothing. Configs are applied with `pip_set_params(x, config, unknown = "error")`. pubflow keeps only `pub_get_params()`. |
| D46 | Params have **one value per name**: pipeflow sets the params of a view in every step of the pipeline that has them, and warns (`pipeflow_param_conflict`) when a new step's param differs from the same param elsewhere. So a param UI on a view (`pub_pipeline_params_server(pip = pip_view(...))`) needs no step-selection argument. `pip_replace(keep_params = TRUE)` keeps a step's param objects. |
| D47 | Param constructors only for distinct value types: `param()`, `numeric_param()`, `numeral_param()`, `choice_param()`, `param_group()`. Specialisations (yes/no, on/off) are examples in `?param`; an app keeps its own. |
| D48 | **Locked params are shown as disabled inputs**: a param attribute `locked = TRUE` (set in a config) or a locked pipeflow step that holds the name. The UI marks a param locked if *any* step holding the name is locked (pipeflow skips locked steps, so a change would otherwise leave steps with different values). The server ignores changes of locked inputs; the attribute binds the UI only, code can still set the value. Step locks alone can't fix params, since a locked step also freezes its output. |
| D49 | The param UI shows **all params by default** (`filter = list()`): an extra input is visible and fixed with one argument, a missing one is not. |
| D50 | **Accessible param UI**, checked with axe-core on Bootstrap 3 and 5: every input has an accessible name (`<label for>` or a named `role="group"`), group headings are fieldset legends, description tooltips also show on keyboard focus and hide on Escape, a viewer with fixed height is a focusable region. Not pubflow's to fix: shinyWidgets radio buttons on Bootstrap 3, ion.rangeSlider handles, page landmarks. |

### Steps, pipelines and documents

| # | Decision |
|---|---|
| D5 | Document structure is explicit, built by layout steps, not derived from pipeline groups or tags. |
| D6 | Output metadata lives in **one attribute**, `attr(x, "pubflow")` (a named list). |
| D14 | Split/apply/combine uses pipeflow's exec modes (`split`/`reduce`); nested pipelines are the general tool. |
| D19 | **Documents are built in pipeline steps.** A *layout step* takes other steps' outputs (`~step`) and returns a `pub_doc()`, `pub_section()` or a list of outputs; pipeflow resolves dependencies, runs only what the document needs and maps over partitions. Declarative outlines (selectors, per-group repetition) were rejected: they duplicated pipeflow. |
| D20 | **Outputs must not keep the pipeline alive.** A ggplot keeps the frame of its step; if that frame reaches the pipeline, an output that travels (to a worker, to disk, into a long-lived viewer) drags the pipeline and its data along (40.8 MB against 0.77 MB in the measurement). Documented, not checked at run time (a check costs ~65 ms per ggplot and is unreliable): write steps that make figures, fits or closures as top-level functions and give them to `pip_add()`; apps test the serialized size of real documents. |
| D21 | **Failures in documents.** The viewer runs with `pip_run(on_error = "continue")`; layout steps write `~try(step)` for inputs that may arrive failed and place the failure object as an error item. Computation steps never see failure objects. Reports run with `on_error = "stop"`; `pub_render()` refuses error items unless the spec allows them. A mapped step fails per partition key, so only the sections of failed keys show an error box. |
| D34 | **Documents across pipelines.** Groups with their own params, UI or runs are independent pipelines from one constructor; each has a layout step for its part and a **report pipeline** assembles the report. Parts are read with `pub_out()`, which returns a step's output only if the step is "done" (a failed step keeps its old output otherwise); a part that isn't done is a `pubflow_not_done` error or, with `on_error = "item"`, an error item. Groups that share one param set and are computed together stay **nested pipelines** (D37). |
| D37 | **Nested pipelines are pipeline functions**: `as.function(inner, out = <steps>)` is the function of an outer step, with one kept inner pipeline per partition key, so a change re-runs only the inner steps it outdates. Added with `pipeflow::pip_add()`. |
| D38 | **No step wrapper**: steps are added with `pip_add()` and replaced with `pip_replace()`. pubflow's methods on pipeflow's `pip_output_value()` stamp ggplots and recorded plots for the figure cache. Layout steps need `~try()` per fallible input (a forgotten one skips the step, so the viewer shows no document). |
| D39 | **Tags select the steps of a layout step**: `pub_layout_inputs(x)` returns `~try(step)` for every step of a pipeline or view, to be given as `params` of a layout step whose function takes `...`. pipeflow's tags and views decide what a report shows; pubflow adds no selection or run logic. |
| D41 | Items carry **no provenance** besides the figure stamp: traceability is per document (trace stamp, file names, `pub_session_info()`), and a stamp on texts and tables would change cache keys on every re-run. |
| D42 | **Steps are not added during a run**: such a step can't be named as `~step`, and reading its output through `.self` bypasses dependency tracking. Variable numbers of outputs are covered by named lists, split steps and pipeline functions. |

### Tables and numbers

| # | Decision |
|---|---|
| D4 | Tables are **huxtable** objects (per-cell formatting survives `rbind`/`cbind`/subsetting). pubflow builds and finishes them and adds a **native Word table writer** (no flextable). |
| D15 | Below the label row huxtable stores every value as text, so pubflow turns cells into display strings at **render time with one common formatter** used by every writer; huxtable's own number formatting never reaches an output. A table shows identical cell text in every format. Values within ~1e-15 of a decimal tie round as their 15-digit text. |
| D16 | Table numbers are rounded **half away from zero on the decimal value** (0.125 -> 0.13, 2.675 -> 2.68, -0.5 -> -1, a result of zero has no sign), as reports under USP rounding rules require. pubflow rounds the cell's text digit by digit (no fuzz factor); `round()`, `sprintf()` and `formatC()` round the binary value and differ. Step code gets the same rule from `pub_round()` and `pub_format_num()`. Number formats are digits or a `sprintf()` format with exactly one `%.nf`, `%.ne` or `%.ng` conversion. |
| D17 | Numeric columns without `digits` show 4 decimal places, integer columns 0; steps should set `digits` deliberately. |
| D18 | **huxtable's API for styling and combining**: pubflow builds and finishes tables (`pub_table()`) and adds only `pub_strikeout()`. Pattern: combine the data, build the table once; footnotes, widths, metadata and strikeout belong to the final table (huxtable's `[` and `cbind()` drop the pubflow attribute). No underline. |
| D51 | **Table themes carry a house style as data plus one hook**: `pub_table_theme()` has `border_color` and `border_width` (the borders are pubflow's own logic, booktabs or grid) and `style = function(ht, rows)`, called last in every `pub_table()` with the row roles (`header`, `spanner`, `body`, `footnote`); `...` takes any other huxtable property (e.g. `valign`). Header bold/alignment and other role-dependent looks go into `style`, not into more arguments. The hook runs again when a combined table is finished, so it sets properties instead of changing them relative to their value. No S3 generic: a theme is a value (set as the default with an option), and an app wraps `pub_table_theme()` to extend it. |
| D52 | **Row roles of a table are recorded by `pub_table()`** and exported as `pub_table_rows(ht)` (same list as the `style` hook gets): the footnote rows can't be told apart from body rows afterwards. A plain function, not a generic, as pubflow's tables are huxtables (D4); it can become a generic later without breaking calls. `pub_table()` stores the number of footnote rows, of all rows, the header rows and the footnote marker of each column in the attribute `pub_table_rows` (not in `pub_meta()`); the other roles follow from them. `[` and `cbind()` drop the attribute, `rbind()` and added rows change the number of rows (best effort: cells changed in place go unnoticed), so binding after the last `pub_table()` makes the roles unknown: `pub_table_rows()` fails and asks to finish the table with `pub_table()` again (D18) instead of returning wrong rows. A table finished again keeps its recorded footnote rows (and label markers); footnotes are given in one call, a second `footnotes` is an error. |
| D53 | **Error items are found with `pub_error_items(x)`**, for documents, sections and (nested) step outputs, so an app can check a report before rendering it. It returns the `pub_error` objects of `pub_out()` (failure objects converted), walks the structure by the types of `pub_type()` without building tables (other classes go through `as_pub_output()`, as in a document), and is what `pub_render()` uses to refuse error items. No `types` filter for other items: no use yet. |
| D27 | **Column widths are automatic**: columns are sized by content and wrap to the page, using each engine's own layout (Word autofit, Typst `auto`, browsers). LaTeX has none, so pubflow computes widths from the cell texts like a browser and passes them to huxtable. `pub_table(widths = )` overrides, with the same meaning in every format: `"<n>cm"` is fixed, numbers are shares of the rest of the table width (columns without width count as one share), and the table spans the page width unless all columns are absolute. |
| D28 | **Tables break across pages in PDF**: every LaTeX/Typst table is a `breakable()` table (longtable) with repeated header rows. huxtable's default float doesn't break and silently lost rows. |
| D29 | **PDF typography**: table cells, captions and header/footer lines are written literally (pubflow escapes ligatures and shorthands itself); other text is written by pandoc and keeps the engines' typography. |

### Text and escaping

| # | Decision |
|---|---|
| D23 | **Raw HTML in Markdown text is escaped** in HTML output: texts carry user input (param values) into the viewer, and commonmark has no safe mode. Raw HTML nodes are found by commonmark's own parser. On purpose: `pub_raw(html = )`. |
| D26 | **Texts on the Pandoc path are CommonMark, escaped like the HTML**: read with pandoc's `commonmark` reader plus the extensions pubflow's own markup needs, not Pandoc Markdown (raw TeX would pass into LaTeX). Raw attributes, spans and divs are neutralised in text nodes; strings pubflow writes itself are escaped as literal text. Math in LaTeX output is checked first by pandoc's math parser (texmath): a formula it can't parse or one that defines macros is a `pubflow_render_error`, so only math commands reach TeX. |
| D44 | **Cross-references** `@fig:<id>` and `@tab:<id>` in texts refer to the figure or table with that metadata `id` (unique per document). They are **engine-native where the engine numbers captions**: a `REF` field in DOCX, `\hyperref` in LaTeX, `#ref` in Typst, a link in HTML, the number as text in Markdown. Problems (unknown id, wrong prefix, no caption, duplicates) are a `pubflow_render_error` in reports and a warning in the viewer. |
| D45 | **Lists of figures and tables** are `pub_toc(what = "figures")` and `"tables"`, placed like a table of contents; the engines list their captions themselves (Word TOC field, `\listoffigures`, Typst `#outline`). HTML and Markdown leave them out. |

### Figures and caching

| # | Decision |
|---|---|
| D22 | **Figure cache key** = hash of (stamp, `rlang::hash(<figure>)`, metadata, device settings). pubflow stamps a figure (step, partition key, run time) through pipeflow's output hook; a re-run of the creating step changes the key. `rlang::hash()` alone isn't safe (environments are hashed by address, and freed addresses are reused). |
| D24 | **The figure cache is capped** (`pub_cache(max_entries = 500)`, least recently used removed): a long Shiny session would otherwise keep adding files to the temp dir. |
| D25 | **The render cache also keeps the HTML of tables**, keyed by the hash of the stored huxtable and its font size: `huxtable::to_html()` took 6-9 ms per table, 811 of the 867 ms of a warm `pub_html()`. |
| D40 | **One figure default for all formats: PNG at 200 dpi**, so the viewer and every format share the cached figures. 200 dpi is sharp on 2x screens and in zoomed PDFs at ~20% more time and ~30% more size than 150 dpi. `figure = list(device = "pdf")` or `"svg"` still gives vector figures. |
| D43 | **Figures rendered in the step**: `pub_figure(x, render = TRUE)` renders to PNG bytes in the step that returns it. A ggplot holds environments, so a pipeline returned by a worker holds copies whose hash differs while the stamp stays; PNG bytes survive round trips, need no cache or stamp, hold nothing of a constructor's frame (D20) and are rendered where the step runs. Costs: size and device are fixed in the step and later steps can't modify the figure. |

### Reports

| # | Decision |
|---|---|
| D30 | **Render-time metadata**: `pub_render(meta = )` merges over `doc$meta` (its entries win), and `time` is the render time unless given. Author, render time and application version describe the act of rendering, so they stay outside the pipeline. `pub_markdown()` and `pub_html()` use `doc$meta` only and stay deterministic. |
| D31 | **Trace stamp**: `pub_trace_stamp(meta)` = `"<author> at <dd-Mon-YYYY HH:MM:SS UTC> (<app> v<version>)"`. An error without `author` (no guessing from `Sys.info()`); English month names whatever the locale. `{trace}` in header/footer lines expands to it. |
| D32 | **Report spec** (`pub_report_spec()`): `NULL` means the format default; a field set for a format that can't use it is an error. `error_items = c("refuse", "show")` ("show" writes error boxes and warns). There is no `table_theme`: documents hold finished huxtables, so the theme is chosen where tables are made. Front matter and table of contents are optional; an explicit `pub_page()` overrides a reference document's page. |
| D33 | **DOCX post-processors** edit the parts with **xml2, not officer** (officer took 10 s per report, put header text outside `w:t`, rewrote most parts and wrote local time with "Z"). Header and footer lines go to six bookmarks of the reference docx (`header_left` ... `footer_right`); a non-empty line without its bookmark is an error. **Tables and figures are locked natively by `pub_markdown()`** (content controls `w:sdt` with `sdtContentLocked`, no marker paragraphs); `lock = TRUE` locks every table and figure plus header and footer, otherwise only items with `pub_set_meta(locked = TRUE)`; nothing is locked by default. The locks guard against accidental edits only (Word lets users remove them), which suffices when the PDF is the deliverable; Word's document protection is not used. |

## 6. Glossary

- **Param**: value plus attributes. **Config**: ordered named list of params.
- **Output**: whatever a step returns. **Item**: an output placed in a document.
- **Document**: a `pub_doc` (sections and items; plain data). **Layout step**: a
  pipeline step returning a document, a section or a list of outputs.
- **Target**: pandoc output family (docx, latex, typst, md).
