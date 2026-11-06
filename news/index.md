# Changelog

## pubflow 0.0.0.9046

First public version, under development towards v0.1. \* R15 benchmarks
recorded (`dev/reference/benchmarks.md`).

- Parameters: self-describing param objects with validity checks,
  collected into the config of a pipeline.
- Parameter UI: Shiny modules that build inputs from a pipeline’s
  params, with per-field validation, locked params and a UI that screen
  readers and keyboard users can use.
- Outputs:
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
  (huxtable),
  [`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md)
  and
  [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)
  for step outputs, with metadata and a figure cache.
- Documents: layout steps
  ([`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md),
  [`pub_section()`](https://rpahl.github.io/pubflow/reference/pub_doc.md),
  …) that arrange outputs into documents, also across pipelines.
- Viewer: a Shiny module that shows a document as one scrollable page.
- Reports:
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  writes HTML, Markdown, Word (DOCX) and PDF (LaTeX or Typst) via
  Pandoc, with a trace stamp, header and footer lines, native Word
  tables and optional locks in DOCX.
- Number formatting:
  [`pub_round()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
  and
  [`pub_format_num()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
  round half away from zero.
- Six vignettes and two example apps (`inst/examples`).
