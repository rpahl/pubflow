# Documents and sections

`pub_doc()` creates a document and `pub_section()` is used to create
sections within a document. Documents are usually created as part of a
pipeflow pipeline: first, the parts of the document (tables, figures,
text) are created in separate steps, and then a *layout step* arranges
them into sections (see Examples).

## Usage

``` r
pub_doc(..., title = NULL, subtitle = NULL, meta = list())

pub_section(
  title,
  ...,
  numbered = TRUE,
  landscape = FALSE,
  page_break = NULL,
  on_empty = c("drop", "keep", "stop")
)
```

## Arguments

- ...:

  Children: sections and outputs (see "Children" in Details).

- title:

  `character(1)` title of the document or section.

- subtitle:

  `character(1)` subtitle of the document or `NULL`.

- meta:

  Named list of document metadata (see "Metadata" in Details).

- numbered:

  `TRUE`: the section is numbered (children of unnumbered sections are
  unnumbered).

- landscape:

  `TRUE`: the section is placed on landscape pages (DOCX, PDF).

- page_break:

  `NULL`: level-1 sections start on a new page in paged formats;
  `TRUE`/`FALSE` override this.

- on_empty:

  when an empty section is placed into a document or section, it is
  dropped (`"drop"`, default), kept (`"keep"`) or an error is signalled
  (`"stop"`).

## Value

A `pub_doc` or `pub_section` object.

## Details

### Children

The children (`...`) are interpreted as follows:

|  |  |
|----|----|
| Child | Becomes |
| section | a section |
| list | one sub-section per named element (see below) |
| data.frame, matrix | a table with default settings (see [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)) |
| huxtable | a table |
| character vector | Markdown text (see [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)) |
| ggplot, [`grDevices::recordPlot()`](https://rdrr.io/r/grDevices/recordplot.html), [`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md) | a figure |
| htmlwidget | an interactive widget |
| [`pub_raw()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md) | your own code, inserted as-is |
| [`pub_pagebreak()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md) | a page break (DOCX, PDF) |
| [`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md) | a table of contents |
| failed step, error item of [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md) | an error box |
| `NULL`, empty text | nothing |
| pipeline | an error (place the outputs of its steps instead) |

Names of list elements become the titles of their sub-sections while
unnamed elements are placed directly (no sub-section). To define the
caption, digits and other settings of a table, use
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md).
Any other classes are converted with
[`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md)
(see
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)).

### Metadata

Metadata of a document:

|                     |                                                 |
|---------------------|-------------------------------------------------|
| Key                 | Meaning                                         |
| `title`, `subtitle` | title lines (also arguments)                    |
| `author`            | user name, e.g. for the trace stamp             |
| `time`              | time of the document (POSIXct)                  |
| `app`, `version`    | name and version of the application             |
| `header`, `footer`  | named character, keys `left`, `center`, `right` |

A blank string (`""` or only whitespace) as title, subtitle, author, app
or version counts as not given. You can add keys of your own: pubflow
keeps them but doesn't check or use them.

### Failed steps

A failed step does not have to stop the document: write the inputs of a
layout step as `~try(step)` and run the pipeline with
`pipeflow::pip_run(x, on_error = "continue")`. The document can then
still be rendered and shows an error box with the step's error message
where the step's output would be (also for steps that did not run). In
contrast, with a plain `~step` the layout step is skipped if the step
fails, so there is no document. With the default
`pipeflow::pip_run(x, on_error = "stop")` the run stops immediately at
the first failure.

### Saving documents

A document holds only the outputs, not the pipeline, so it can be saved
with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) and rendered
later or in another R session. One pitfall: a ggplot remembers where it
was made. If a plot step is written as a lambda inside the function that
builds the pipeline (`\(data = ~data) ggplot(...)`), the saved document
includes the whole pipeline. To avoid this, define plot functions
outside the function that builds the pipeline. Plots that a step renders
itself (`pub_figure(render = TRUE)`) have no such problem.

## See also

[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md),
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md),
[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md),
[`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md)

## Examples

``` r
p <- pipeflow::pip_new("demo") |>
    # Steps that make the content
    pipeflow::pip_add("data", \(n = 4) {
        data.frame(x = seq_len(n), y = seq_len(n)^2)
    }) |>
    pipeflow::pip_add("table", \(data = ~data) {
        pub_table(data, caption = "Data")
    }) |>
    pipeflow::pip_add("mean", \(data = ~data) {
        pub_format_num(mean(data$y), "Mean: %.2f")
    }) |>
    # The layout step arranges their outputs into a document
    pipeflow::pip_add("report", \(table = ~table, mean = ~mean) {
        pub_doc(
            pub_section("Data", table),
            pub_section("Results", mean),
            title = "Demo"
        )
    })

# Run the pipeline and take the document from the layout step
pipeflow::pip_run(p, lgr = NULL)
doc <- p[["report", "out"]]
doc
#> <pubflow document> "Demo"
#> # Data
#>   table "Data"
#> # Results
#>   text "Mean: 7.50"

# A document can also be made directly, without a pipeline
pub_doc(
    pub_section(
        "Introduction",
        pub_text("The study has **three** batches."),
        data.frame(batch = c("A", "B", "C"), n = c(4L, 4L, 4L))
    ),
    pub_section("Annex", pub_session_info(), numbered = FALSE),
    title = "Analysis report",
    meta = list(author = "Jane Doe", app = "demo", version = "1.0")
)
#> <pubflow document> "Analysis report"
#> # Introduction
#>   text "The study has **three** batches."
#>   table
#> # Annex [unnumbered]
#>   ## Session info
#>     text "```"
```
