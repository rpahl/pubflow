# pubflow 0.0.0.9047

* Requires pipeflow 0.5.0.9032: failed steps called with symbols give light
  failures (pipeflow 0.5.0.9029).

# pubflow 0.0.0.9046

First public version, under development towards v0.1.
* R15 benchmarks recorded (`dev/reference/benchmarks.md`).

* Parameters: self-describing param objects with validity checks, collected into
  the config of a pipeline.
* Parameter UI: Shiny modules that build inputs from a pipeline's params, with
  per-field validation, locked params and a UI that screen readers and keyboard users
  can use.
* Outputs: `pub_table()` (huxtable), `pub_figure()` and `pub_text()` for step outputs,
  with metadata and a figure cache.
* Documents: layout steps (`pub_doc()`, `pub_section()`, ...) that arrange outputs
  into documents, also across pipelines.
* Viewer: a Shiny module that shows a document as one scrollable page.
* Reports: `pub_render()` writes HTML, Markdown, Word (DOCX) and PDF (LaTeX or Typst)
  via Pandoc, with a trace stamp, header and footer lines, native Word tables and
  optional locks in DOCX.
* Number formatting: `pub_round()` and `pub_format_num()` round half away from zero.
* Six vignettes and two example apps (`inst/examples`).
