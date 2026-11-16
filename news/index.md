# Changelog

## pubflow 0.0.0.9063

- pubflow requires pipeflow 0.6.0 from CRAN; the `Remotes` pin on a
  pipeflow commit is gone.

## pubflow 0.0.0.9062

- New test helpers for apps: `inst/testhelpers/helper-pubflow.R` (find
  it with
  `system.file("testhelpers", "helper-pubflow.R", package = "pubflow")`)
  reads table cells, labels, spanners, footnotes, styles and decimals,
  document sections, child types and items, checks that items are locked
  and reads Word files. Copy it into `tests/testthat/`
  ([\#27](https://github.com/rpahl/pubflow/issues/27)).

## pubflow 0.0.0.9061

- Internal: the roxygen headers of internal helpers are kept only where
  they explain more than the name, the signature and the body do.
- Internal: the open work moved from `dev/PLAN.md` into GitHub issues,
  and `dev/reference/pipeflow.md` now covers pipeflow 0.6.0 and only
  what shapes pubflow.

## pubflow 0.0.0.9060

- pubflow requires pipeflow 0.5.0.9040, whose `pip_clone(out = )` copies
  a pipeline with the outputs of the named steps only
  ([\#20](https://github.com/rpahl/pubflow/issues/20)).
- New section “Long runs in a worker” in
  [`vignette("v05-shiny")`](https://rpahl.github.io/pubflow/articles/v05-shiny.md):
  a Shiny app runs the pipeline in a
  [`shiny::ExtendedTask`](https://rdrr.io/pkg/shiny/man/ExtendedTask.html)
  and the worker sends back only the document (`pip_clone(out = )`),
  which
  [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md)
  reads; with the params of the run, so the viewer can mark results that
  don’t match the current params.

## pubflow 0.0.0.9059

- `pub_table(footnotes = )` also takes footnotes on body cells: a
  data.frame with the columns `row` (body row, `NA` for the label),
  `col` and `text`. pubflow numbers the markers in reading order, lists
  equal texts once and keeps the borders and the number format of the
  marked cells ([\#16](https://github.com/rpahl/pubflow/issues/16),
  D59).
- Footnote markers are superscript numbers in parentheses,
  e.g. `Ozone⁽¹⁾`, also on labels (was `Ozone¹`), so that several
  markers in one cell stay apart.

## pubflow 0.0.0.9058

- New
  [`pub_missing()`](https://rpahl.github.io/pubflow/reference/pub_missing.md)
  stands in for a part of a document that doesn’t exist yet, e.g. the
  results of an analysis not run: the viewer shows its message as a
  neutral placeholder, and
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  refuses it like an error item (or, with
  `pub_report_spec(problems = "show")`, shows it as an italic
  paragraph).
  [`pub_problems()`](https://rpahl.github.io/pubflow/reference/pub_problems.md)
  finds these parts too, so it lists everything
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  refuses; its new argument `type` picks one kind (`"error"` or
  `"missing"`) ([\#17](https://github.com/rpahl/pubflow/issues/17),
  D58).

- Renamed `pub_error_items()` to
  [`pub_problems()`](https://rpahl.github.io/pubflow/reference/pub_problems.md)
  and the report spec field `error_items` to `problems`, as they cover
  missing parts as well as error items (D58).

## pubflow 0.0.0.9057

- While the document is made again (e.g. while `doc()` runs the
  pipeline), the viewer shows the previous document in grey and puts
  “Updating …” in a bar at its top, so users don’t mistake the results
  of the previous run for the new ones. For runs outside of `doc()`
  (e.g. in an `ExtendedTask`) or params not applied yet, the new
  argument `pending` of
  [`pub_viewer_server()`](https://rpahl.github.io/pubflow/reference/pub_viewer_ui.md)
  takes a reactive returning the label to show
  (e.g. `"Parameters changed"`) or `NULL`
  ([\#19](https://github.com/rpahl/pubflow/issues/19), D57).

## pubflow 0.0.0.9056

- [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)
  has a new argument `front_matter` (e.g. a title page, a signature
  table and
  [`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md))
  that replaces the title block in the viewer, in
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md)
  and in every format of
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
  with unnumbered sections
  ([\#18](https://github.com/rpahl/pubflow/issues/18), D56). The
  `front_matter` function of
  [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  replaces it and can build on it (`doc$front_matter`); so a spec of
  `\(doc, format) list()` is no longer needed to drop the title block
  when the document holds its own front matter.
- A `front_matter` function of
  [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  that returns `NULL` now keeps the title block; return
  [`list()`](https://rdrr.io/r/base/list.html) to drop it.
- [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md)
  adds no table of contents if the document places one
  ([`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)).

## pubflow 0.0.0.9055

- New
  [`pub_layout_sections()`](https://rpahl.github.io/pubflow/reference/pub_layout_sections.md)
  makes the function of a layout step whose document has one section per
  view,
  e.g. `list(Data = pip_view(p, tags = "Data"), Model = pip_view(p, depends = "fit"))`,
  with the outputs of the view’s steps in it (D55).

## pubflow 0.0.0.9054

- [`pub_params_table()`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)
  shows a
  [`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
  as `"<label>: <value>"` of its members that have a value
  (e.g. `"Lower: 1, Upper: 2"`) instead of only the values. Its new
  argument `na` sets the text of empty values (length 0, all `NA` or
  blank), which were shown as `"NA"` or as an empty cell.

## pubflow 0.0.0.9053

- In PDF via Typst, the text of Markdown table cells (e.g. from
  [`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md))
  is escaped: `$`, `#` and other characters with a meaning in Typst no
  longer break the document. As in Word, these cells may use strong,
  emphasis and strikethrough; other Markdown is an error naming the
  cell.

## pubflow 0.0.0.9052

- New
  [`pub_md_escape()`](https://rpahl.github.io/pubflow/reference/pub_md_escape.md)
  escapes data (e.g. names from a data set) for
  [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)
  and Markdown table cells, so it shows as it is (D54).
- [`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md)
  escapes the cell text for all of pubflow’s Markdown (`$...$` in a
  struck-out cell no longer becomes math in
  [`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md))
  and strikes each line of a cell through (a blank line in a cell no
  longer breaks the strikeout).
- A backslash-escaped backtick in a text no longer starts code: math and
  cross-references after it are shown.

## pubflow 0.0.0.9051

- New `pub_error_items()` finds the error items (failed steps) in a
  document or in step outputs, e.g. to list the problems of a report
  before rendering it (D53).

## pubflow 0.0.0.9050

- `pub_table(widths = )` means the same in HTML as in DOCX and PDF:
  numbers are shares of the table width (a width of 2 no longer gives
  200 %), `"<n>cm"` columns keep their width, and a table with widths
  spans the page width unless all its columns are absolute.
- In PDF via Typst, columns without width in a table with `widths` get
  one share each, as in DOCX and HTML, instead of their content width.

## pubflow 0.0.0.9049

- New
  [`pub_table_rows()`](https://rpahl.github.io/pubflow/reference/pub_table_rows.md)
  gives the header, spanner, body and footnote rows of a table built by
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md),
  e.g. to style body rows with huxtable. After binding or subsetting it
  fails until the table is finished with
  [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
  again (D52).
- [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
  keeps existing footnote rows as footnotes when it finishes a table
  again (unless the table was bound or subset since): borders, `digits`,
  `na`, `align` and the theme’s `style` function treat them as
  footnotes, and new `labels` keep their footnote markers. Giving
  `footnotes` again for such a table is an error: give all footnotes in
  one call.

## pubflow 0.0.0.9048

- [`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md)
  gains `border_color`, `border_width` and `style`, a function that
  styles each table by the role of its rows (header, spanner, body,
  footnote) after the rest of the theme, e.g. for a coloured header
  (D51).

## pubflow 0.0.0.9047

- Requires pipeflow 0.5.0.9032: failed steps called with symbols give
  light failures (pipeflow 0.5.0.9029).

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
