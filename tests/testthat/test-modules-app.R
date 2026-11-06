# The modules app (inst/examples/modules-app) is checked manually in a browser; these
# tests only make sure that its UI and server run.

describe("modules app", {
    it("has a Bootstrap 3 and a Bootstrap 5 page", {
        skip_if_not_installed("bslib")
        env <- example_app_env("modules-app")

        for (bs in c("3", "5")) {
            page <- env$ui(list(QUERY_STRING = paste0("?bs=", bs)))
            rendered <- htmltools::renderTags(page)
            expect_match(bootstrap_version(rendered), paste0("^", bs, "\\."))
            expect_match(
                as.character(rendered$html),
                'id="pipeline-pubflow-params".*id="standalone-pubflow-params"'
            )
        }
    })

    it("runs the pipeline after valid parameter changes", {
        env <- example_app_env("modules-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            expect_equal(output$revision, "revision: 0")
            expect_match(output$summary, "^Ozone in New York: Temp.Celsius explains")

            session$setInputs(`pipeline-title` = "Ozone in New York")
            session$setInputs(`pipeline-title` = "New title")
            expect_equal(output$revision, "revision: 1")
            expect_match(output$summary, "^New title:")
            expect_match(output$pipelineChanged, "title")

            window <- pub_get_params(pip)$window
            expect_equal(param_value(window), list(from = 19, to = 34))
            expect_match(output$data, "Temp.Celsius")

            # The range of the selected months
            session$setInputs(`pipeline-months` = month.name[5:9])
            session$setInputs(`pipeline-months` = c("May", "June"))
            session$setInputs(derive = 1)
            window <- param_value(pub_get_params(pip)$window)
            expect_equal(window, list(from = 19, to = 33))
            expect_equal(params$values()$window, window)

            # A change in the inputs, then the range from the data again: values()
            # follows the pipeline, changed() keeps the change made in the inputs
            session$setInputs(
                `pipeline-window_from` = "19",
                `pipeline-window_to` = "33"
            )
            session$setInputs(`pipeline-window_from` = "21")
            expect_equal(params$changed()$window, list(from = 21, to = 33))
            session$setInputs(derive = 2)
            expect_equal(param_value(pub_get_params(pip)$window), window)
            expect_equal(params$values()$window, window)
            expect_equal(params$changed()$window, list(from = 21, to = 33))

            # A new predictor: a new range param, rendered again
            session$setInputs(`pipeline-xVar` = "Temp.Celsius")
            session$setInputs(`pipeline-xVar` = "Wind")
            window <- pub_get_params(pip)$window
            expect_equal(param_value(window), list(from = 4, to = 14))
            expect_equal(param_attr(window, "label"), "Range of Wind")
            table <- as.character(output$`pipeline-pubflow-params`$html)
            expect_match(table, "Range of Wind", fixed = TRUE)
            expect_match(output$summary, "Wind explains")

            session$setInputs(structure = "large")
            expect_named(
                standalone$values(),
                c("name", "count", "ratio", "choice", "level", "method")
            )
        })
    })

    it("shows the params of the locked step 'fit' disabled", {
        env <- example_app_env("modules-app")
        shiny::testServer(shiny::shinyApp(env$ui, env$server), {
            session$flushReact()
            disabled <- function(id) {
                html <- as.character(output$`pipeline-pubflow-params`$html)
                grepl(sprintf('id="pipeline-%s"[^>]* disabled', id), html)
            }
            expect_false(disabled("xVar"))

            session$setInputs(lockFit = TRUE)
            expect_true(pip[["fit", "locked"]])
            expect_true(disabled("xVar"))
            expect_false(disabled("months"))
            expect_false(disabled("window_from"))

            session$setInputs(lockFit = FALSE)
            expect_false(disabled("xVar"))
        })
    })
})
