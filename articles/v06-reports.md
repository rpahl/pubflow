# Reports

[Documents and layout
steps](https://rpahl.github.io/pubflow/articles/v04-documents.md) built
documents; this vignette turns them into report files. A report is a
document that is written to a file: Word (DOCX), PDF, HTML or Markdown.
The file says who made it and when, it looks the same whoever opens it,
and pubflow refuses to write it if it has a hole in it. This vignette
goes through

- what is added at render time and what is not part of the pipeline;
- the report spec, which sets up a format;
- failed steps in a report;
- the extras of Word files: header, footer, locks and the reference
  document;
- what each format needs, and the setup of PDF output.

It builds on pipeflow’s vignette [Error
handling](https://rpahl.github.io/pipeflow/articles/v05c-error-handling.html)
for failed steps.

## Requirements

pubflow calls pandoc directly, so Word and PDF need the tools that
pandoc and its writers use. Which tools
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
needs depends on the format:

| Format         | Needs                                     |
|----------------|-------------------------------------------|
| HTML, Markdown | nothing                                   |
| Word (DOCX)    | pandoc (\>= 3.6)                          |
| PDF            | pandoc and xelatex (the default) or Typst |

**pandoc** is found via the environment variable `PUBFLOW_PANDOC`, then
`RSTUDIO_PANDOC`, then the `PATH`.

**xelatex** is found on the `PATH` by pandoc. Tables need the LaTeX
packages of huxtable
([`huxtable::install_latex_dependencies()`](https://hughjonesd.github.io/huxtable/reference/report_latex_dependencies.html)),
and pubflow itself needs pdflscape, fancyhdr, lastpage, float and
newunicodechar. With TinyTeX:

\
`tinytex``::`[`tlmgr_install`](https://rdrr.io/pkg/tinytex/man/tlmgr.html)`(`[`c`](https://rdrr.io/r/base/c.html)`(``"pdflscape"``, ``"fancyhdr"``, ``"lastpage"``, ``"float"``,`\
`                         ``"newunicodechar"``)``)`

**Typst** is found via the environment variable `PUBFLOW_TYPST` (the
executable or its directory), then the `PATH`, then the typst that comes
with Quarto.

## The example

The document of the previous vignettes: a table and a figure of a linear
model of the ozone concentration. Its header and footer lines have the
token [trace](https://zachariahmclean.github.io/trace/), which becomes
the trace stamp of the report.

\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pipeflow`](https://rpahl.github.io/pipeflow/)`)`\
[`library`](https://rdrr.io/r/base/library.html)`(`[`pubflow`](https://rpahl.github.io/pubflow/)`)`\
[`library`](https://rdrr.io/r/base/library.html)`(`[`ggplot2`](https://ggplot2.tidyverse.org)`)`\
\
`fit`` ``<-`` `[`lm`](https://rdrr.io/r/stats/lm.html)`(``Ozone`` ``~`` ``Temp``, data ``=`` ``airquality``)`\
`coefs`` ``<-`` `[`data.frame`](https://rdrr.io/r/base/data.frame.html)`(``term ``=`` `[`names`](https://rdrr.io/r/base/names.html)`(`[`coef`](https://rdrr.io/r/stats/coef.html)`(``fit``)``)``, estimate ``=`` `[`unname`](https://rdrr.io/r/base/unname.html)`(`[`coef`](https://rdrr.io/r/stats/coef.html)`(``fit``)``)``)`\
\
`doc`` ``<-`` `[`pub_doc`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`\
`    `[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`\
`        ``"Results"``,`\
`        `[`pub_text`](https://rpahl.github.io/pubflow/reference/pub_text.md)`(`[`sprintf`](https://rdrr.io/r/base/sprintf.html)`(`\
`            ``"The model explains **%.0f%%** of the variance."``,`\
`            ``100`` ``*`` `[`summary`](https://rdrr.io/r/base/summary.html)`(``fit``)``$``r.squared`\
`        ``)``)``,`\
`        `[`pub_table`](https://rpahl.github.io/pubflow/reference/pub_table.md)`(`\
`            ``coefs``,`\
`            caption ``=`` ``"Coefficients of the linear model"``,`\
`            digits ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``estimate ``=`` ``3L``)`\
`        ``)``,`\
`        `[`pub_figure`](https://rpahl.github.io/pubflow/reference/pub_figure.md)`(`\
`            `[`ggplot`](https://ggplot2.tidyverse.org/reference/ggplot.html)`(``airquality``, `[`aes`](https://ggplot2.tidyverse.org/reference/aes.html)`(``Temp``, ``Ozone``)``)`` ``+`` `[`geom_point`](https://ggplot2.tidyverse.org/reference/geom_point.html)`(``na.rm ``=`` ``TRUE``)``,`\
`            caption ``=`` ``"Ozone by temperature"``,`\
`            width ``=`` ``6``,`\
`            height ``=`` ``3.5`\
`        ``)`\
`    ``)``,`\
`    title ``=`` ``"Ozone in New York"``,`\
`    meta ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(`\
`        header ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``left ``=`` ``"Ozone study"``, right ``=`` ``"Draft"``)``,`\
`        footer ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``left ``=`` ``"{trace}"``)`\
`    ``)`\
`)`

## Render-time metadata

Who rendered a report, when and with which application are facts about
the act of rendering. They are not part of the pipeline: if they were
params of the layout step, every render would outdate it. They are
passed to
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
instead, where they are merged over the metadata of the document:

\
`file`` ``<-`` `[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(`\
`    ``doc``,`\
`    ``"docx"``,`\
`    meta ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``author ``=`` ``"Jane Doe"``, app ``=`` ``"ozone-app"``, version ``=`` ``"1.2.0"``)`\
`)`\
[`basename`](https://rdrr.io/r/base/basename.html)`(``file``)`\
`# [1] "20261114T082120Z_ozone_in_new_york.docx"`

- The entries of `meta` win over those of the document, and `NULL`
  removes one.
- `time` is the render time, unless the document or `meta` sets one.
- The file name, the title block, the trace stamp, the front matter and
  the post-processors (below) all see the merged result.
- [`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
  and
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
  which the viewer uses, only see the metadata of the document, so what
  you see in the viewer doesn’t change from one second to the next.

In an app, `meta` is where the user and the version go, e.g.
`list(author = session$user, app = "ozone-app", version = "1.2.0")`.

### Trace stamp

[`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)
makes the line that [trace](https://zachariahmclean.github.io/trace/)
stands for. It is an error without an author, since pubflow doesn’t
guess it: on a server, the system user is only the service account.
Times are always UTC, with English month names:

\
`meta`` ``<-`` `[`list`](https://rdrr.io/r/base/list.html)`(`\
`    author ``=`` ``"Jane Doe"``,`\
`    app ``=`` ``"ozone-app"``,`\
`    version ``=`` ``"1.2.0"``,`\
`    time ``=`` `[`as.POSIXct`](https://rdrr.io/r/base/as.POSIXlt.html)`(``"2026-11-02 09:30:00"``, tz ``=`` ``"UTC"``)`\
`)`\
[`pub_trace_stamp`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)`(``meta``)`\
`# [1] "Jane Doe at 02-Nov-2026 09:30:00 UTC (ozone-app v1.2.0)"`\
[`pub_trace_stamp`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)`(``meta``[`[`c`](https://rdrr.io/r/base/c.html)`(``"author"``, ``"time"``)``]``)`\
`# [1] "Jane Doe at 02-Nov-2026 09:30:00 UTC"`

\
[`pub_trace_stamp`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)`(`[`list`](https://rdrr.io/r/base/list.html)`(``app ``=`` ``"ozone-app"``)``)`\
`# ``Error```  in `pub_trace_stamp()`: ``\
`# ``!```  A trace stamp needs the metadata `author`. ``\
`# ``ℹ```  Pass it to `pub_render(meta = list(author = ...))`. ``

### File names

Without `file`, the report goes to R’s temporary directory under the
name that
[`pub_output_filename()`](https://rpahl.github.io/pubflow/reference/pub_output_filename.md)
makes, the render time (UTC) and the title:

\
[`pub_output_filename`](https://rpahl.github.io/pubflow/reference/pub_output_filename.md)`(`[`list`](https://rdrr.io/r/base/list.html)`(``title ``=`` ``"Ozone in New York"``, time ``=`` ``meta``$``time``)``, ``"docx"``)`\
`# [1] "20261102T093000Z_ozone_in_new_york.docx"`

Call it yourself for a download name, e.g. in the `filename` of a Shiny
[`downloadHandler()`](https://rdrr.io/pkg/shiny/man/downloadHandler.html).

## Report specs

A report spec sets up the report of one format, and
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
takes it as `spec`. Without it, `pub_report_spec(format)` is used: all
defaults. Printing a spec shows what it uses:

\
[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(``"docx"``)`\
`# <pubflow report spec: docx>`\
`#   reference_docx    default`\
`#   front_matter      title block`\
`#   toc               depth 3`\
`#   number_sections   yes`\
`#   page              reference document`\
`#   figure            default`\
`#   labels            Table, Figure`\
`#   lock              marked items`\
`#   error_items       refuse`\
`#   post_process      none`\
`#   pandoc_args       none`

Every field acts in every format that can show it. A field that the
format can’t use is an error, so a setting is never silently ignored:

\
[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(``"docx"``, placeholder_color ``=`` ``"#0083c0"``)`\
`# ``Error```  in `pub_report_spec()`: ``\
`# ``!```  `placeholder_color` can't be used for docx reports, only for html and pdf. ``

The fields in short
([`?pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
has the details):

| Field | What it sets |
|----|----|
| `reference_docx`, `latex_preamble`, `typst_template` | The template of DOCX, of PDF via LaTeX, of PDF via Typst |
| `front_matter` | A function that returns what replaces the title block, e.g. a title page |
| `toc`, `toc_depth` | A table of contents after the front matter, and its depth |
| `number_sections` | Number the headings or not |
| `labels` | The words before the caption numbers |
| `page` | Paper size, orientation and margins ([`pub_page()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)) of DOCX and PDF |
| `figure` | Image format and resolution of figures |
| `placeholder_color` | Colour of placeholders in HTML and PDF |
| `lock` | Lock tables, figures, header and footer of DOCX files |
| `error_items` | Refuse or show failed steps |
| `post_process` | Functions that change the finished file |
| `pandoc_args` | Extra pandoc arguments |

### Title page, contents and page

The front matter replaces the title block. It is a function of the
document (with the render-time metadata) and the format that returns
what a document can hold: sections, outputs and lists of them. Its
sections are not numbered, so the numbers of the body start at 1. End it
with a page break to start the contents on a new page:

\
`title_page`` ``<-`` ``function``(``doc``, ``format``)`` ``{`\
`    `[`list`](https://rdrr.io/r/base/list.html)`(`\
`        `[`pub_text`](https://rpahl.github.io/pubflow/reference/pub_text.md)`(`[`paste`](https://rdrr.io/r/base/paste.html)`(``"Prepared by"``, ``doc``$``meta``$``author``)``)``,`\
`        `[`pub_pagebreak`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)`(``)`\
`    ``)`\
`}`\
\
`spec`` ``<-`` `[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(`\
`    ``"pdf"``,`\
`    front_matter ``=`` ``title_page``,`\
`    toc_depth ``=`` ``2L``,`\
`    page ``=`` `[`pub_page`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(``"letter"``, margins ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``left ``=`` ``3``)``)``,`\
`    labels ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``table ``=`` ``"Tab."``, figure ``=`` ``"Fig."``)`\
`)`\
`spec`\
`# <pubflow report spec: pdf>`\
`#   latex_preamble    none`\
`#   typst_template    default`\
`#   front_matter      function`\
`#   toc               depth 2`\
`#   number_sections   yes`\
`#   page              Letter portrait, margins top 2.5, bottom 2, left 3, right 2.5 cm`\
`#   figure            default`\
`#   labels            Tab., Fig.`\
`#   placeholder_color default`\
`#   error_items       refuse`\
`#   post_process      none`\
`#   pandoc_args       none`

A document that places
[`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
itself (`what = "sections"`) gets no second table of contents. Lists of
figures and tables (`pub_toc(what = "figures")`) don’t count: to have
only those, set `toc = FALSE` in the spec.

A spec is a plain list that is checked when it is used. To have one spec
for every format, write a function that builds them, so the front matter
and the labels are in one place:

\
`my_spec`` ``<-`` ``function``(``format``)`` ``{`\
`    `[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(`\
`        ``format``,`\
`        front_matter ``=`` ``title_page``,`\
`        labels ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``table ``=`` ``"Tab."``, figure ``=`` ``"Fig."``)`\
`    ``)`\
`}`\
`spec_docx`` ``<-`` ``my_spec``(``"docx"``)`

Markdown shows the effect of a spec without any tool; the table caption
now starts with “Tab.”:

\
`path`` ``<-`` `[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(`\
`    ``doc``,`\
`    ``"md"``,`\
`    file ``=`` `[`tempfile`](https://rdrr.io/r/base/tempfile.html)`(``fileext ``=`` ``".md"``)``,`\
`    spec ``=`` ``my_spec``(``"md"``)``,`\
`    meta ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``author ``=`` ``"Jane Doe"``)`\
`)`\
[`grep`](https://rdrr.io/r/base/grep.html)`(``"Tab\\."``, `[`readLines`](https://rdrr.io/r/base/readLines.html)`(``path``)``, value ``=`` ``TRUE``)`\
`# [1] "Tab. 1: Coefficients of the linear model"`

## Failed steps in a report

A report has no holes:
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
refuses a document with error items and lists the failed steps (see
[Documents and layout
steps](https://rpahl.github.io/pubflow/articles/v04-documents.md)). Run
the pipeline of a report with the default `on_error = "stop"`, and a
failed step stops it before any document exists.

For a draft, run with `on_error = "continue"` and let the spec show the
error items instead:

\
`pip`` ``<-`` `[`pip_new`](https://rpahl.github.io/pipeflow/reference/pip_new.html)`(``"draft"``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"table"``, ``function``(``)`` `[`pub_table`](https://rpahl.github.io/pubflow/reference/pub_table.md)`(`[`head`](https://rdrr.io/r/utils/head.html)`(``airquality``)``, caption ``=`` ``"Data"``)``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(``"fit"``, ``function``(``data`` ``=`` ``airquality``)`` `[`lm`](https://rdrr.io/r/stats/lm.html)`(``Ozone`` ``~`` ``Height``, data ``=`` ``data``)``)`` ``|>`\
`    `[`pip_add`](https://rpahl.github.io/pipeflow/reference/pip_add.html)`(`\
`        ``"report"``,`\
`        ``function``(``table`` ``=`` ``~`` `[`try`](https://rdrr.io/r/base/try.html)`(``table``)``, ``fit`` ``=`` ``~`` `[`try`](https://rdrr.io/r/base/try.html)`(``fit``)``)`` ``{`\
`            `[`pub_doc`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(`[`pub_section`](https://rpahl.github.io/pubflow/reference/pub_doc.md)`(``"Results"``, ``table``, ``fit``)``, title ``=`` ``"Draft"``)`\
`        ``}`\
`    ``)`\
[`suppressWarnings`](https://rdrr.io/r/base/warning.html)`(`[`pip_run`](https://rpahl.github.io/pipeflow/reference/pip_run.html)`(``pip``, on_error ``=`` ``"continue"``, lgr ``=`` ``NULL``)``)`\
`draft`` ``<-`` ``pip``[[``"report"``, ``"out"``]``]`

\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``draft``, ``"md"``, file ``=`` `[`tempfile`](https://rdrr.io/r/base/tempfile.html)`(``fileext ``=`` ``".md"``)``)`\
`# ``Error```  in `pub_render()`: ``\
`# ``!`` Can't render a document with error items (failed steps):`\
`# ``✖`` step 'fit' failed: object 'Height' not found`\
`# ``ℹ```  Reports run the pipeline with `on_error = "stop"`; error items are for the viewer. ``

\
`spec`` ``<-`` `[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(``"md"``, error_items ``=`` ``"show"``)`\
[`withCallingHandlers`](https://rdrr.io/r/base/conditions.html)`(`\
`    `[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``draft``, ``"md"``, file ``=`` `[`tempfile`](https://rdrr.io/r/base/tempfile.html)`(``fileext ``=`` ``".md"``)``, spec ``=`` ``spec``)``,`\
`    pubflow_render_warning ``=`` ``function``(``w``)`` ``{`\
`        `[`cat`](https://rdrr.io/r/base/cat.html)`(``"Warning:"``, `[`conditionMessage`](https://rdrr.io/r/base/conditions.html)`(``w``)``, ``"\n"``)`\
`        `[`invokeRestart`](https://rdrr.io/r/base/conditions.html)`(``"muffleWarning"``)`\
`    ``}`\
`)`` ``|>`\
`    `[`invisible`](https://rdrr.io/r/base/invisible.html)`(``)`\
`# Warning: The report shows error items (failed steps):`\
`# ``✖`` step 'fit' failed: object 'Height' not found`

The file has an error box where the model of the failed step would be,
and the warning names the failed step. Use this for drafts only.

To check a document before rendering it, e.g. to tell the user of an app
why a report can’t be downloaded yet,
[`pub_error_items()`](https://rpahl.github.io/pubflow/reference/pub_error_items.md)
lists its error items:

\
[`vapply`](https://rdrr.io/r/base/lapply.html)`(`[`pub_error_items`](https://rpahl.github.io/pubflow/reference/pub_error_items.md)`(``draft``)``, \``(``x``)`` ``x``$``message``, `[`character`](https://rdrr.io/r/base/character.html)`(``1``)``)`\
`# [1] "object 'Height' not found"`

## Word files

### Header, footer and locks

The Word file of the example above shows the header and footer lines of
the document, with [trace](https://zachariahmclean.github.io/trace/)
expanded. They go into the header and footer part of the reference
document. A look into the file shows them:

\
`docx_text`` ``<-`` ``function``(``file``, ``part``)`` ``{`\
`    ``dir`` ``<-`` `[`tempfile`](https://rdrr.io/r/base/tempfile.html)`(``)`\
`    `[`on.exit`](https://rdrr.io/r/base/on.exit.html)`(`[`unlink`](https://rdrr.io/r/base/unlink.html)`(``dir``, recursive ``=`` ``TRUE``)``)`\
`    ``utils``::`[`unzip`](https://rdrr.io/r/utils/unzip.html)`(``file``, files ``=`` `[`paste0`](https://rdrr.io/r/base/paste.html)`(``"word/"``, ``part``)``, exdir ``=`` ``dir``)`\
`    ``xml`` ``<-`` ``xml2``::`[`read_xml`](http://xml2.r-lib.org/reference/read_xml.md)`(`[`file.path`](https://rdrr.io/r/base/file.path.html)`(``dir``, ``"word"``, ``part``)``)`\
`    ``xml2``::`[`xml_text`](http://xml2.r-lib.org/reference/xml_text.md)`(``xml2``::`[`xml_find_all`](http://xml2.r-lib.org/reference/xml_find_all.md)`(``xml``, ``"//w:t"``)``)`\
`}`\
`docx_text``(``file``, ``"header1.xml"``)`\
`# [1] "Ozone study" ""            "Draft"`\
`docx_text``(``file``, ``"footer1.xml"``)`\
`# [1] "Jane Doe at 14-Nov-2026 08:21:20 UTC (ozone-app v1.2.0)"`\
`# [2] ""                                                       `\
`# [3] "Page "                                                  `\
`# [4] "1"                                                      `\
`# [5] " / "                                                    `\
`# [6] "1"`

The footer line at the left is the trace stamp, and “Page 1 / 1” is the
reference document’s own page number. A footer line at the *right*
replaces the page number, as in PDF.

With `lock = TRUE` in the spec, the file also protects itself from
accidental editing: tables and figures are content controls that can’t
be deleted or changed, and so are the whole header and the whole footer.
An item opts out with `pub_set_meta(locked = FALSE)`. By default, only
the tables and figures with `pub_set_meta(locked = TRUE)` are locked,
and `lock = FALSE` locks nothing. The locks guard against slips only,
since Word lets users remove a lock in the control’s properties. The
report you can rely on is the PDF.

### Post-processors

Two post-processors do the work above,
[`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
and
[`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md).
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
adds the first to every DOCX report, the second with `lock = TRUE`. Add
them to the spec’s `post_process` yourself to give them arguments,
e.g. other header lines than the document’s, or a different place in the
order. Listing
[`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
without `lock = TRUE` locks the header and footer, but only the tables
and figures with `pub_set_meta(locked = TRUE)`.

Your own functions have the form `function(path, doc, spec)`. They
change the finished file in place, are called in order, and a failing
one stops the render, so no file is written. This one adds a note to a
Markdown report:

\
`add_note`` ``<-`` ``function``(``path``, ``doc``, ``spec``)`` ``{`\
`    `[`writeLines`](https://rdrr.io/r/base/writeLines.html)`(`[`c`](https://rdrr.io/r/base/c.html)`(`[`readLines`](https://rdrr.io/r/base/readLines.html)`(``path``)``, ``""``, ``"<!-- checked -->"``)``, ``path``)`\
`}`\
`spec`` ``<-`` `[`pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)`(``"md"``, post_process ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``add_note``)``)`\
`path`` ``<-`` `[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``doc``, ``"md"``, file ``=`` `[`tempfile`](https://rdrr.io/r/base/tempfile.html)`(``fileext ``=`` ``".md"``)``, spec ``=`` ``spec``)`\
[`tail`](https://rdrr.io/r/utils/head.html)`(`[`readLines`](https://rdrr.io/r/base/readLines.html)`(``path``)``, ``1L``)`\
`# [1] "<!-- checked -->"`

### The reference document

The look of a Word file comes from its reference document, pubflow’s own
`system.file("templates", "reference.docx", package = "pubflow")` unless
the spec says `reference_docx`: A4, numbered headings, and a header and
footer with bookmarks for the lines. Start your own from a copy of it
and change the styles and the page in Word. The document must keep

- the styles in the table below (pandoc finds them by name; a missing
  one is added unformatted);
- the bookmarks of the header and footer lines that you use:
  `header_left`, `header_center`, `header_right`, `footer_left`,
  `footer_center` and `footer_right` (the last one surrounds “Page x /
  N”). A line without its bookmark is an error, so a stamp is never
  dropped unnoticed.

| Style | Type | Used for |
|----|----|----|
| Heading 1 - Heading 5 | paragraph | numbered section headings (the numbering belongs to the styles) |
| Heading 1 Unnumbered - Heading 5 Unnumbered | paragraph | unnumbered sections (they keep the outline level, so they appear in the table of contents) |
| Item Title | paragraph | title line above an item |
| Table Caption, Image Caption | paragraph | numbered captions (before tables, after figures) |
| Figure | paragraph | the paragraph that holds an image |
| Placeholder | character | `[text]{.placeholder}` spans |
| Error | paragraph | error items (failed steps) |
| Title, Subtitle, Author, Date | paragraph | pandoc’s title block |

The page setup, header and footer of the reference document apply to
every section, also to landscape pages. An explicit `page` in the spec
overrides the page of the reference document.

## PDF output

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
takes the engine in `pdf_engine`:

\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``doc``, ``"pdf"``, file ``=`` ``"ozone.pdf"``, meta ``=`` ``meta``)`` ``# xelatex`\
[`pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md)`(``doc``, ``"pdf"``, file ``=`` ``"ozone.pdf"``, meta ``=`` ``meta``, pdf_engine ``=`` ``"typst"``)`

To change the look of a PDF, use `latex_preamble` (a file that is
included after pubflow’s own header, so it can load packages and change
the page style) or `typst_template` (start from
`system.file("templates", "pubflow.typ", package = "pubflow")`). A
custom Typst template must write `$header-includes$` and the title
block, and take the lines of the header and footer from `$header-left$`
to `$footer-right$`.

## Where next

- [Documents and layout
  steps](https://rpahl.github.io/pubflow/articles/v04-documents.md)
  builds the documents that reports are made of, [Parameter UI and
  viewer in
  Shiny](https://rpahl.github.io/pubflow/articles/v05-shiny.md) shows
  them in an app with a download button.
- The help pages describe the options in detail:
  [`?pub_render`](https://rpahl.github.io/pubflow/reference/pub_render.md),
  [`?pub_report_spec`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md),
  [`?pub_trace_stamp`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md),
  [`?pub_pp_docx_header_footer`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md),
  [`?pub_pp_docx_lock`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md).
