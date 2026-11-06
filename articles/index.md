# Articles

### Get started

- [Get started with
  pubflow](https://rpahl.github.io/pubflow/articles/v01-get-started.md):

  Start here: from a pipeline with parameters to a document, a report
  file and a Shiny app.

### Building documents

Params, outputs and layout steps that build a document.

- [Parameters](https://rpahl.github.io/pubflow/articles/v02-parameters.md):

  Params in depth: constructors and validity rules, groups, configs,
  params in a pipeline, one value per name, a parameter table for
  documents and locked params.

- [Tables, figures and
  text](https://rpahl.github.io/pubflow/articles/v03-tables-figures-text.md):

  The outputs of a document: tables with pub_table() and huxtable,
  struck-through cells, rounding half away from zero, figures, Markdown
  texts, metadata and cross-references.

- [Documents and layout
  steps](https://rpahl.github.io/pubflow/articles/v04-documents.md):

  Build documents in pipeline steps: failed inputs, selecting the steps
  of a report by tags, layouts that change with the data, documents
  across pipelines and how to test layout steps.

### Shiny

Parameter UI and document viewer in an app.

- [Parameter UI and viewer in
  Shiny](https://rpahl.github.io/pubflow/articles/v05-shiny.md):

  Two Shiny modules turn a pipeline into an app: a parameter UI that
  checks every input and a viewer that shows the document. Invalid
  input, locked inputs, failed steps, running only the steps of the
  report shown, the render cache and Bootstrap 3 and 5.

### Reports

Report files in Word, PDF, HTML and Markdown.

- [Reports](https://rpahl.github.io/pubflow/articles/v06-reports.md):

  A report is a document written to a Word, PDF, HTML or Markdown file.
  Render-time metadata, the trace stamp and file names, report specs for
  each format, error items, the Word header, footer and locks, Word
  reference documents, and the setup of LaTeX and Typst.
