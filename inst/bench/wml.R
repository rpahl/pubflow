# Benchmark (DESIGN.md §4): the native Word table writer on a 40x8 table with a
# spanner row, a footnote and a merged column; target < 10 ms. Not run on
# CI; record results in the PR.
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE); source('inst/bench/wml.R')"

local({
    set.seed(1)
    data <- as.data.frame(matrix(stats::rnorm(40 * 7), 40, 7))
    data <- cbind(group = rep(c("A", "B"), each = 20), data)
    cols <- names(data)[-1L]
    ht <- pub_table(
        data,
        digits = rlang::set_names(rep(2L, 7L), cols),
        header = rlang::set_names(rep(c("First", "Second"), c(3L, 4L)),
                                  cols),
        footnotes = c(V1 = "A footnote."),
        merge = "group"
    )
    wml <- getFromNamespace(".huxtable_to_wml", "pubflow")
    wml(ht)
    times <- vapply(seq_len(50L), function(i) {
        system.time(wml(ht))[["elapsed"]]
    }, numeric(1))
    cat(sprintf("WML table 40x8: %.1f ms (median of 50; target < 10 ms)\n",
                stats::median(times) * 1000))
})
