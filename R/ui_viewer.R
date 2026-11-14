# Viewer module: shows a document as one scrollable page with a sticky table of
# contents. The server renders the document with the HTML renderer (figures and tables
# from the render cache) into one output and the table of contents, from the same
# outline, into another; the client side (inst/www/pubflow-viewer.js) only highlights
# the current section (scrollspy) and typesets math after each update. No per-item
# modules or observers: a changed document is rendered again as a whole.

# ------
# Module
# ------
#' Document viewer (Shiny module)
#'
#' Shows a document (see [pub_doc()]) in a Shiny app as one scrollable, report-like
#' page. A table of contents stays visible next to it and highlights the section being
#' read.
#'
#' @details
#' ## Document and failed steps
#'
#' `doc` is usually the output of a layout step (see [pub_doc()]). An app should run the
#' pipeline with `pipeflow::pip_run(on_error = "continue")`, so that a failing step does
#' not stop the document: failed steps show as error boxes where the layout step places
#' them (see Examples).
#'
#' If the layout step itself failed, its output is the error. Pass it on as `doc`: the
#' viewer shows it as one error box.
#'
#' ## Updates
#'
#' The document is rendered again as a whole when `doc` changes. Figures and tables come
#' from the render `cache` ([pub_cache()]), which can be shared with report rendering.
#'
#' @param id Module id.
#' @param toc `TRUE`: show the table of contents (sections up to level 3) next to the
#'   document.
#' @param height `NULL`: the viewer grows with the document and the page scrolls. A CSS
#'   height (e.g. `"600px"` or `"80vh"`): the viewer has that height and scrolls itself.
#' @param doc A reactive returning a document, `NULL` (shows "No results") or a
#'   condition (shows an error box).
#' @param cache A [pub_cache()].
#' @return `pub_viewer_ui()`: a tag list. `pub_viewer_server()`: `NULL`, invisibly.
#' @seealso [pub_html()], [pub_cache()], [pub_doc()]
#' @examples
#' p <- pipeflow::pip_new("demo") |>
#'     pipeflow::pip_add("data", \(n = 10) {
#'         data.frame(x = seq_len(n), y = sqrt(n))
#'     }) |>
#'     pipeflow::pip_add("table", \(data = ~data) {
#'         pub_table(data, caption = "Data")
#'     }) |>
#'     pipeflow::pip_add("check", \(data = ~data, fail = FALSE) {
#'         if (fail) stop("check failed") else "All values are positive."
#'     }) |>
#'     pipeflow::pip_add("doc", \(table = ~try(table), check = ~try(check)) {
#'         pub_doc(pub_section("Data", table), pub_section("Check", check),
#'                 title = "Demo")
#'     })
#'
#' ui <- shiny::fluidPage(
#'     shiny::checkboxInput("fail", "Let the check fail"),
#'     pub_viewer_ui("viewer", height = "500px")
#' )
#' server <- function(input, output, session) {
#'     doc <- shiny::reactive({
#'         pipeflow::pip_set_params(p, list(fail = input$fail))
#'         withCallingHandlers(
#'             pipeflow::pip_run(p, lgr = NULL, on_error = "continue"),
#'             pipeflow_run_failed = function(w) {
#'                 message(conditionMessage(w))  # log it
#'                 invokeRestart("muffleWarning")
#'             }
#'         )
#'         p[["doc", "out"]]  # a document, or the condition if 'doc' failed
#'     })
#'     pub_viewer_server("viewer", doc)
#' }
#' if (interactive()) shiny::shinyApp(ui, server)
#' @export
pub_viewer_ui <- function(id, toc = TRUE, height = NULL) {
    if (!rlang::is_bool(toc)) {
        rlang::abort("`toc` must be `TRUE` or `FALSE`.")
    }
    ns <- shiny::NS(id)
    fixed <- !is.null(height)
    htmltools::tagList(
        .viewer_dependency(),
        .pubflow_doc_dependency(),
        htmltools::div(
            id = ns("viewer"),
            class = paste(
                c("pubflow-viewer", if (fixed) "pubflow-viewer-fixed"),
                collapse = " "
            ),
            style = if (fixed) {
                sprintf("height: %s;", shiny::validateCssUnit(height))
            },
            if (toc) {
                htmltools::tags$aside(
                    class = "pubflow-viewer-toc",
                    `aria-label` = "Table of contents",
                    shiny::uiOutput(ns("toc"))
                )
            },
            # scrolls on its own with a fixed height: focusable for the keyboard
            htmltools::div(
                class = "pubflow-viewer-content",
                role = if (fixed) "region",
                `aria-label` = if (fixed) "Document",
                tabindex = if (fixed) "0",
                shiny::uiOutput(ns("doc"))
            )
        )
    )
}

#' @rdname pub_viewer_ui
#' @export
pub_viewer_server <- function(id, doc, cache = pub_cache()) {
    if (!shiny::is.reactive(doc)) {
        rlang::abort("`doc` must be a reactive (e.g. `shiny::reactive()`).")
    }
    .check_cache(cache)
    shiny::moduleServer(id, function(input, output, session) {
        rendered <- shiny::reactive({
            .viewer_render(doc(), cache, prefix = session$ns("doc"))
        })
        output$doc <- shiny::renderUI(rendered()$doc)
        output$toc <- shiny::renderUI(rendered()$toc)
        invisible(NULL)
    })
}


# ---------
# Rendering
# ---------
#' Document and table of contents for the viewer
#'
#' @param x the value of the viewer's `doc` reactive.
#' @param cache a `pub_cache`.
#' @param prefix prefix of the element ids (unique per module).
#' @return `list(doc, toc)` of HTML (`toc` may be `NULL`).
#' @noRd
.viewer_render <- function(x, cache, prefix) {
    if (is.null(x)) {
        return(list(
            doc = htmltools::div(class = "pubflow-viewer-empty", "No results"),
            toc = NULL
        ))
    }
    if (!inherits(x, "pub_doc")) {
        return(list(doc = .viewer_error(x), toc = NULL))
    }
    parts <- .html_parts(
        x,
        cache,
        math = "mathjax",
        figure = .figure_default,
        prefix = prefix,
        front = x$front_matter
    )
    toc <- .html_toc(parts$outline, depth = 3L)
    list(
        doc = htmltools::attachDependencies(
            htmltools::HTML(.wrap_doc(c(parts$header, parts$body))),
            parts$deps
        ),
        toc = if (!is.null(toc)) htmltools::HTML(paste(toc, collapse = "\n"))
    )
}

#' One error box instead of the document
#'
#' For a condition (the layout step failed) or a `try-error` its message; for any other
#' object a note that it is not a document.
#' @param x a condition or any other object that is not a `pub_doc`.
#' @return HTML with the document dependency.
#' @noRd
.viewer_error <- function(x) {
    if (inherits(x, "try-error") && inherits(attr(x, "condition"), "condition")) {
        x <- attr(x, "condition")
    }
    message <- if (inherits(x, "condition")) {
        .cnd_message(x)
    } else {
        sprintf(
            "The output is not a document (class <%s>).",
            paste(class(x), collapse = "/")
        )
    }
    html <- sprintf(
        paste0(
            "<div class=\"pubflow-item pubflow-error\" role=\"alert\">\n",
            "<div class=\"pubflow-error-title\">The document could not be ",
            "built</div>\n",
            "<div class=\"pubflow-error-message\">%s</div>\n</div>"
        ),
        .esc(message)
    )
    htmltools::attachDependencies(
        htmltools::HTML(.wrap_doc(html)),
        .pubflow_doc_dependency()
    )
}

#' HTML dependency with the viewer's JavaScript and CSS (inst/www)
#' @return an `html_dependency`.
#' @noRd
.viewer_dependency <- function() {
    htmltools::htmlDependency(
        name = "pubflow-viewer",
        version = unname(getNamespaceVersion("pubflow")),
        src = "www",
        package = "pubflow",
        script = "pubflow-viewer.js",
        stylesheet = "pubflow-viewer.css",
        all_files = FALSE
    )
}
