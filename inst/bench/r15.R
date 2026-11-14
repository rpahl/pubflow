# Workload "R15" (DESIGN.md §4): a report of 15 sections, one per test
# (one pipeline per test), each with 4 texts, 3 tables
# (10 x 6, coloured cells) and 3 figures (ggplot, 50 points + smooth), plus
# an annex of 30 extra tables (20 x 8). Needs ggplot2.
#
# Sourcing this file only defines the generators; the benchmarks source it
# (inst/bench/doc.R, M6). r15_pipelines() returns the named list of test
# pipelines (each with a layout step "content"), r15_annex_pipeline() the
# pipeline with the annex tables, r15_run() computes their outputs and
# r15_assemble() makes the document from them, as an app does with one
# pipeline per test; r15_doc() does all of this and returns the document.

r15_n_tests <- 15L

# Table of random numbers; values above 1 have a coloured background
r15_table <- function(nrow, ncol, seed, caption) {
    set.seed(seed)
    values <- matrix(stats::rnorm(nrow * ncol), nrow, ncol)
    data <- data.frame(
        batch = sprintf("B%02d", seq_len(nrow)),
        as.data.frame(values[, -1L, drop = FALSE])
    )
    names(data)[-1L] <- sprintf("t%d", seq_len(ncol - 1L))
    cols <- names(data)[-1L]
    ht <- pub_table(
        data,
        caption = caption,
        digits = rlang::set_names(rep(2L, length(cols)), cols),
        header = rlang::set_names(rep("Time point", length(cols)), cols)
    )
    rows <- sum(huxtable::header_rows(ht)) + seq_len(nrow)
    high <- as.matrix(data[cols]) > 1
    huxtable::set_background_color(
        ht,
        rows,
        cols,
        ifelse(high, "#f4cccc", "white")
    )
}

# ggplot with 50 points and a linear smoother
r15_figure <- function(seed, caption) {
    set.seed(seed)
    data <- data.frame(x = seq_len(50L))
    data$y <- 100 - 0.2 * data$x + stats::rnorm(50L)
    # nolint start: object_usage_linter. (columns of `data`)
    p <- ggplot2::ggplot(data, ggplot2::aes(x, y)) +
        ggplot2::geom_point() +
        ggplot2::geom_smooth(method = "lm", formula = y ~ x)
    # nolint end
    pub_figure(p, caption = caption, width = 6, height = 4)
}

r15_texts <- function(test) {
    list(
        pub_text(sprintf(
            paste(
                "This section summarises the data of **%s**. The",
                "results of all batches were analysed with a linear model",
                "of the response over time ($y = a + b \\cdot t$)."
            ),
            test
        )),
        pub_text(c(
            "Findings:",
            "",
            "- no batch is out of trend;",
            "- the slopes are similar across batches;",
            "- the shelf life is supported by the data."
        )),
        pub_text(sprintf(
            "See [<insert reference for %s>]{.placeholder}.",
            test
        )),
        pub_text(
            paste(
                "The tables below show the data per time point; values above",
                "one are highlighted. The figures show the trend per batch."
            ),
            title = "Data and figures"
        )
    )
}

# One pipeline per test: steps returning lists of texts, tables, figures,
# and a layout step listing them (the content of the test's section)
r15_test_pipeline <- function(i) {
    test <- sprintf("Test %02d", i)
    pipeflow::pip_new(test) |>
        pipeflow::pip_add("texts", \(name = test) r15_texts(name)) |>
        pipeflow::pip_add("tables", \(seed = i) {
            lapply(1:3, \(k) {
                r15_table(10L, 6L, 100L * seed + k, sprintf("Table %d", k))
            })
        }) |>
        pipeflow::pip_add("figures", \(seed = i) {
            lapply(1:3, \(k) {
                r15_figure(100L * seed + k, sprintf("Figure %d", k))
            })
        }) |>
        pipeflow::pip_add(
            "content",
            \(texts = ~texts, tables = ~tables, figures = ~figures) {
                list(texts, tables, figures)
            }
        )
}

r15_pipelines <- function(n = r15_n_tests) {
    pipelines <- lapply(seq_len(n), r15_test_pipeline)
    names(pipelines) <- sprintf("Test %02d", seq_len(n))
    pipelines
}

# Pipeline of the annex: one step returning 30 tables
r15_annex_pipeline <- function() {
    pipeflow::pip_new("annex") |>
        pipeflow::pip_add("tables", \(n = 30L) {
            lapply(seq_len(n), \(k) {
                r15_table(20L, 8L, 10000L + k, sprintf("Annex table %d", k))
            })
        })
}

r15_run <- function(pipelines) {
    for (p in pipelines) {
        pipeflow::pip_run(p, lgr = NULL)
    }
    invisible(pipelines)
}

# The document from the computed outputs: one section per test, the annex
r15_assemble <- function(pipelines, annex) {
    pub_doc(
        lapply(pipelines, \(p) p[["content", "out"]]),
        pub_section("Annex", annex[["tables", "out"]]),
        title = "R15 benchmark report"
    )
}

# The document (all outputs computed)
r15_doc <- function() {
    pipelines <- r15_pipelines()
    annex <- r15_annex_pipeline()
    r15_run(c(pipelines, list(annex)))
    r15_assemble(pipelines, annex)
}
