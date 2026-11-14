# pubflow (development version)

* `pub_doc()` has a new argument `front_matter` (e.g. a title page, a signature table
  and `pub_toc()`) that replaces the title block in the viewer, in `pub_html()` and in
  every format of `pub_render()`, with unnumbered sections (#18, D56). The
  `front_matter` function of `pub_report_spec()` replaces it and can build on it
  (`doc$front_matter`); so a spec of `\(doc, format) list()` is no longer needed to
  drop the title block when the document holds its own front matter.
* A `front_matter` function of `pub_report_spec()` that returns `NULL` now keeps the
  title block; return `list()` to drop it.
* `pub_html()` adds no table of contents if the document places one (`pub_toc()`).

# pubflow 0.0.0.9055

* New `pub_layout_sections()` makes the function of a layout step whose document has
  one section per view, e.g. `list(Data = pip_view(p, tags = "Data"), Model =
  pip_view(p, depends = "fit"))`, with the outputs of the view's steps in it (D55).

# pubflow 0.0.0.9054

* `pub_params_table()` shows a `param_group()` as `"<label>: <value>"` of its members
  that have a value (e.g. `"Lower: 1, Upper: 2"`) instead of only the values. Its new
  argument `na` sets the text of empty values (length 0, all `NA` or blank), which
  were shown as `"NA"` or as an empty cell.

# pubflow 0.0.0.9053

* In PDF via Typst, the text of Markdown table cells (e.g. from `pub_strikeout()`)
  is escaped: `$`, `#` and other characters with a meaning in Typst no longer break
  the document. As in Word, these cells may use strong, emphasis and strikethrough;
  other Markdown is an error naming the cell.

# pubflow 0.0.0.9052

* New `pub_md_escape()` escapes data (e.g. names from a data set) for `pub_text()`
  and Markdown table cells, so it shows as it is (D54).
* `pub_strikeout()` escapes the cell text for all of pubflow's Markdown (`$...$` in a
  struck-out cell no longer becomes math in `pub_markdown()`) and strikes each line of
  a cell through (a blank line in a cell no longer breaks the strikeout).
* A backslash-escaped backtick in a text no longer starts code: math and
  cross-references after it are shown.

# pubflow 0.0.0.9051

* New `pub_error_items()` finds the error items (failed steps) in a document or in
  step outputs, e.g. to list the problems of a report before rendering it (D53).

# pubflow 0.0.0.9050

* `pub_table(widths = )` means the same in HTML as in DOCX and PDF: numbers are
  shares of the table width (a width of 2 no longer gives 200 %), `"<n>cm"`
  columns keep their width, and a table with widths spans the page width unless
  all its columns are absolute.
* In PDF via Typst, columns without width in a table with `widths` get one
  share each, as in DOCX and HTML, instead of their content width.

# pubflow 0.0.0.9049

* New `pub_table_rows()` gives the header, spanner, body and footnote rows of a
  table built by `pub_table()`, e.g. to style body rows with huxtable. After
  binding or subsetting it fails until the table is finished with `pub_table()`
  again (D52).
* `pub_table()` keeps existing footnote rows as footnotes when it finishes a
  table again (unless the table was bound or subset since): borders, `digits`,
  `na`, `align` and the theme's `style` function treat them as footnotes, and new
  `labels` keep their footnote markers. Giving `footnotes` again for such a table
  is an error: give all footnotes in one call.

# pubflow 0.0.0.9048

* `pub_table_theme()` gains `border_color`, `border_width` and `style`, a
  function that styles each table by the role of its rows (header, spanner,
  body, footnote) after the rest of the theme, e.g. for a coloured header
  (D51).

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
