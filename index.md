# pubflow

{pubflow} (“publishing workflow”) is the companion package of
[pipeflow](https://github.com/rpahl/pipeflow) (\>= 0.5.0.9032): it takes
the results a pipeline computes and covers what is needed to *publish*
them.

## Why pubflow?

Unlike knitr, rmarkdown and Quarto, a pubflow document is not a source
file to knit: the pipeline builds it, so it can update in place and feed
a viewer or a report.

- **Parameter UI for free**: Shiny inputs and validation built from a
  pipeline’s params
- **Live preview**: see a change in the viewer without re-knitting the
  document
- **Only what changed**: documents are pipeline steps, so pipeflow
  re-runs just what a change affects
- **Same document, every format**: the same tables, figures and text in
  HTML, Word, PDF and Markdown
- **Traceable by design**: deterministic output with trace stamps and
  session info

## Status

Under development towards v0.1. The design is in
[dev/DESIGN.md](https://rpahl.github.io/pubflow/dev/DESIGN.md), the open
work in [dev/PLAN.md](https://rpahl.github.io/pubflow/dev/PLAN.md).

## Installation

\
`# Install development version from GitHub`\
`# install.packages("pak")`\
`pak``::`[`pak`](https://pak.r-lib.org/reference/pak.html)`(``"rpahl/pubflow"``)`

## Usage

A step returns a table, a layout step arranges it into a document, and
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
writes the document to a file:

\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pipeflow`](https://rpahl.github.io/pipeflow/)`)`\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pubflow`](https://rpahl.github.io/pubflow/)`)`\
\
`pip`` ``<-`` `[`pip_new`](https://rpahl.github.io/pipeflow/reference/pip_new.html)`(``"my-pip"``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"fit"``, ``function``(``data`` ``=`` ``airquality``, ``xVar`` ``=`` ``"Temp"``)`` ``{`\
`        ``coefs`` ``<-`` `[`coef`](https://rdrr.io/r/stats/coef.html)`(`[`lm`](https://rdrr.io/r/stats/lm.html)`(`[`paste`](https://rdrr.io/r/base/paste.html)`(``"Ozone ~"``, ``xVar``)``, data ``=`` ``data``)``)`\
`        `[`data.frame`](https://rdrr.io/r/base/data.frame.html)`(``term ``=`` `[`names`](https://rdrr.io/r/base/names.html)`(``coefs``)``, estimate ``=`` `[`unname`](https://rdrr.io/r/base/unname.html)`(``coefs``)``)`\
`    ``}``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"table"``, ``function``(``fit`` ``=`` ``~``fit``)`` ``{`\
`        `[`pub_table`](https://rpahl.github.io/pubflow/reference/pub_table.md)`(``fit``, caption ``=`` ``"Linear model of the ozone concentration"``)`\
`    ``}``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"report"``, ``function``(``table`` ``=`` ``~``table``)`` ``{`\
`        `[`pub_doc`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(``"Results"``, ``table``)``, title ``=`` ``"Ozone in New York"``)`\
`    ``}``)`\
[`pip_run`](https://rpahl.github.io/pipeflow/reference/pip_run.html)`(``pip``)`\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``pip``[[``"report"``, ``"out"``]``]``, ``"html"``)`\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``pip``[[``"report"``, ``"out"``]``]``, ``"md"``)`

## Learning pubflow

If you are new to pubflow, read the vignettes in the order they are
listed below. They build one example up from a pipeline with params to a
report file and a Shiny app.

### Getting started

- [Get started with
  pubflow](https://rpahl.github.io/pubflow/articles/v01-get-started.html):
  the whole flow, from params and outputs to a document, a report file
  and a Shiny app.

### Building documents

- [Parameters](https://rpahl.github.io/pubflow/articles/v02-parameters.html):
  self-describing params, validity rules, groups, configs and locked
  params.
- [Tables, figures and
  text](https://rpahl.github.io/pubflow/articles/v03-tables-figures-text.html):
  the outputs a document shows, their metadata and cross-references.
- [Documents and layout
  steps](https://rpahl.github.io/pubflow/articles/v04-documents.html):
  arrange outputs into documents, handle failed steps and test layout
  steps.

### Publishing

- [Parameter UI and viewer in
  Shiny](https://rpahl.github.io/pubflow/articles/v05-shiny.html):
  params and the document in an app, with validation and a live preview.
- [Reports](https://rpahl.github.io/pubflow/articles/v06-reports.html):
  Word, PDF, HTML and Markdown files, trace stamps, reference documents
  and the tools each format needs.
