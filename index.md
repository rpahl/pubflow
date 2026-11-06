# pubflow

pubflow (“publishing workflow”) is the companion package of
[pipeflow](https://github.com/rpahl/pipeflow) (\>= 0.5.0.9028). pipeflow
computes; pubflow covers everything around a pipeline that is needed to
*publish* its results:

- **Parameters**: self-describing parameter objects with validity checks
  and configs;
- **Parameter UI**: a Shiny module that builds inputs from a pipeline’s
  parameters, with per-field validation;
- **Outputs and documents**: conventions for step outputs (tables,
  figures, Markdown text) and layout steps that arrange them into
  documents;
- **Viewer**: a Shiny module that shows a document as one scrollable
  page;
- **Reports**: HTML, Word (DOCX) and PDF via Pandoc, with traceability
  and DOCX post-processing.

## Status

Under development towards v0.1. The design is in
[dev/DESIGN.md](https://rpahl.github.io/pubflow/dev/DESIGN.md), the open
work in [dev/PLAN.md](https://rpahl.github.io/pubflow/dev/PLAN.md).

## Example

A step returns a table, a layout step arranges it into a document, and
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
writes the document to a Word file:

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
`        `[`pub_table`](https://rpahl.github.io/pubflow/reference/pub_table.md)`(``fit``, caption ``=`` ``"Linear model of the ozone concentration"``,`\
`                  digits ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``estimate ``=`` ``3L``)``)`\
`    ``}``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"report"``, ``function``(``table`` ``=`` ``~``table``)`` ``{`\
`        `[`pub_doc`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(``"Results"``, ``table``)``, title ``=`` ``"Ozone in New York"``)`\
`    ``}``)`\
[`pip_run`](https://rpahl.github.io/pipeflow/reference/pip_run.html)`(``pip``)`\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``pip``[[``"report"``, ``"out"``]``]``, ``"docx"``)`

The vignette
[`vignette("v01-get-started", package = "pubflow")`](https://rpahl.github.io/pubflow/articles/v01-get-started.md)
goes through the whole flow: params, outputs, documents, report files
and a Shiny app.

## Installation

\
`# install.packages("pak")`\
`pak``::`[`pak`](https://pak.r-lib.org/reference/pak.html)`(``"rpahl/pubflow"``)`

System requirements: pandoc \>= 3.6; for PDF output xelatex (default) or
typst. pubflow finds pandoc via the environment variable
`PUBFLOW_PANDOC`, then `RSTUDIO_PANDOC`, then the PATH; typst via
`PUBFLOW_TYPST`, then the PATH, then the typst bundled with Quarto. PDF
via xelatex needs the LaTeX packages of huxtable
([`huxtable::install_latex_dependencies()`](https://hughjonesd.github.io/huxtable/reference/report_latex_dependencies.html))
and pdflscape, fancyhdr, lastpage, float and newunicodechar (TinyTeX:
`tinytex::tlmgr_install(c("pdflscape", "fancyhdr", "lastpage", "float", "newunicodechar"))`);
pandoc finds xelatex on the PATH.

## Word reference documents

DOCX output uses pubflow’s reference document
(`inst/templates/reference.docx`, built by `data-raw/reference_docx.R`).
Its styles and the bookmarks of the header and footer lines that your
own reference document must provide are listed in
[`vignette("v06-reports", package = "pubflow")`](https://rpahl.github.io/pubflow/articles/v06-reports.md).

## Development

The development library is managed with
[renv](https://rstudio.github.io/renv/) for R 4.5.3; start R in the
repository root and run `renv::restore()` once. R \>= 4.3 is supported
and checked on CI.

``` bash
R -q -e "devtools::document()"
R -q -e "devtools::test()"
R -q -e "pkgload::load_all(quiet = TRUE); lintr::lint_package()"
R -q -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning', check_dir = 'check')"
```
