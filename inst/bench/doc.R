# Benchmark (DESIGN.md §4): making the document of the R15 workload
# (inst/bench/r15.R) from outputs already computed, target < 200 ms. Not
# run on CI; record results in the PR. Needs ggplot2.
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE); source('inst/bench/doc.R')"
# or with pubflow installed:
#   Rscript -e "library(pubflow); source(system.file('bench', 'doc.R',
#               package = 'pubflow'))"

local({
    file <- "inst/bench/r15.R"
    if (!file.exists(file)) {
        file <- system.file("bench", "r15.R", package = "pubflow")
    }
    source(file, local = parent.frame(2L))
})

# Median time in ms of `n` evaluations of `expr` (after one warm-up run)
time_ms <- function(expr, n = 20L) {
    expr <- substitute(expr)
    env <- parent.frame()
    eval(expr, env)
    times <- vapply(seq_len(n), function(i) {
        start <- proc.time()[["elapsed"]]
        eval(expr, env)
        proc.time()[["elapsed"]] - start
    }, numeric(1))
    stats::median(times) * 1000
}

count_items <- function(nodes) {
    sum(vapply(nodes, function(x) {
        if (inherits(x, "pub_section")) count_items(x$children) else 1L
    }, integer(1)))
}

pipelines <- r15_pipelines()
annex <- r15_annex_pipeline()
setup <- system.time(r15_run(c(pipelines, list(annex))))[["elapsed"]]
doc <- r15_assemble(pipelines, annex)

# The document from the stored outputs (the DESIGN.md §4 target): places every
# output (items, sections, tables from data.frames, text checks)
assemble <- time_ms(r15_assemble(pipelines, annex))

cat(sprintf(
    paste0(
        "R15: %d sections, %d items (computing the outputs took %.1f s)\n",
        "making the document: %6.1f ms (target < 200 ms)\n"
    ),
    length(doc$children), count_items(doc$children), setup, assemble
))
