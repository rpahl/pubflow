# Document viewer (Shiny module)

Shows a document (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)) in
a Shiny app as one scrollable, report-like page. A table of contents
stays visible next to it and highlights the section being read.

## Usage

``` r
pub_viewer_ui(id, toc = TRUE, height = NULL)

pub_viewer_server(id, doc, cache = pub_cache())
```

## Arguments

- id:

  Module id.

- toc:

  `TRUE`: show the table of contents (sections up to level 3) next to
  the document.

- height:

  `NULL`: the viewer grows with the document and the page scrolls. A CSS
  height (e.g. `"600px"` or `"80vh"`): the viewer has that height and
  scrolls itself.

- doc:

  A reactive returning a document, `NULL` (shows "No results") or a
  condition (shows an error box).

- cache:

  A
  [`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md).

## Value

`pub_viewer_ui()`: a tag list. `pub_viewer_server()`: `NULL`, invisibly.

## Details

### Document and failed steps

`doc` is usually the output of a layout step (see
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)). An
app should run the pipeline with
`pipeflow::pip_run(on_error = "continue")`, so that a failing step does
not stop the document: failed steps show as error boxes where the layout
step places them (see Examples).

If the layout step itself failed, its output is the error. Pass it on as
`doc`: the viewer shows it as one error box.

### Updates

The document is rendered again as a whole when `doc` changes. Figures
and tables come from the render `cache`
([`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md)),
which can be shared with report rendering.

## See also

[`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
[`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md),
[`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)

## Examples

``` r
p <- pipeflow::pip_new("demo") |>
    pipeflow::pip_add("data", \(n = 10) {
        data.frame(x = seq_len(n), y = sqrt(n))
    }) |>
    pipeflow::pip_add("table", \(data = ~data) {
        pub_table(data, caption = "Data")
    }) |>
    pipeflow::pip_add("check", \(data = ~data, fail = FALSE) {
        if (fail) stop("check failed") else "All values are positive."
    }) |>
    pipeflow::pip_add("doc", \(table = ~try(table), check = ~try(check)) {
        pub_doc(pub_section("Data", table), pub_section("Check", check),
                title = "Demo")
    })

ui <- shiny::fluidPage(
    shiny::checkboxInput("fail", "Let the check fail"),
    pub_viewer_ui("viewer", height = "500px")
)
server <- function(input, output, session) {
    doc <- shiny::reactive({
        pipeflow::pip_set_params(p, list(fail = input$fail))
        withCallingHandlers(
            pipeflow::pip_run(p, lgr = NULL, on_error = "continue"),
            pipeflow_run_failed = function(w) {
                message(conditionMessage(w))  # log it
                invokeRestart("muffleWarning")
            }
        )
        p[["doc", "out"]]  # a document, or the condition if 'doc' failed
    })
    pub_viewer_server("viewer", doc)
}
if (interactive()) shiny::shinyApp(ui, server)
```
