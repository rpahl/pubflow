# Benchmark (DESIGN.md §4): pub_html() of the R15 workload (inst/bench/r15.R),
# targets: warm figure cache < 500 ms; cold: figures dominate (~80 ms each),
# everything else < 1 s. Not run on CI; record results in the PR. Needs
# ggplot2.
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE); source('inst/bench/html.R')"
# or with pubflow installed:
#   Rscript -e "library(pubflow); source(system.file('bench', 'html.R',
#               package = 'pubflow'))"

local({
    file <- "inst/bench/r15.R"
    if (!file.exists(file)) {
        file <- system.file("bench", "r15.R", package = "pubflow")
    }
    source(file, local = parent.frame(2L))
})

# Median time in ms of `n` evaluations of `expr` (after one warm-up run)
time_ms <- function(expr, n = 10L) {
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

doc <- r15_doc()

# Cold: a new cache, every figure is rendered
cold <- system.time(pub_html(doc, cache = pub_cache()))[["elapsed"]] * 1000

# Warm: the figures come from the cache
cache <- pub_cache()
pub_html(doc, cache = cache)
warm <- time_ms(pub_html(doc, cache = cache))

# Without a cache: tables (formatter + huxtable::to_html()), texts
is_type <- function(type) function(x) x$type == type
items <- function(nodes) {
    unlist(lapply(nodes, function(x) {
        if (inherits(x, "pub_section")) items(x$children) else list(x)
    }), recursive = FALSE)
}
all <- items(doc$children)
tables <- Filter(is_type("table"), all)
texts <- Filter(is_type("text"), all)
tableDoc <- do.call(pub_doc, lapply(tables, function(x) x$object))
textDoc <- do.call(pub_doc, lapply(texts, function(x) x$object))
tablesMs <- time_ms(pub_html(tableDoc))
textsMs <- time_ms(pub_html(textDoc))

cat(sprintf(
    paste0(
        "R15 pub_html(): %d figures, %d tables, %d texts\n",
        "cold (new cache): %7.1f ms\n",
        "warm (cached):    %7.1f ms (target < 500 ms)\n",
        "no cache, tables: %7.1f ms\n",
        "no cache, texts:  %7.1f ms\n"
    ),
    length(Filter(is_type("figure"), all)), length(tables), length(texts),
    cold, warm, tablesMs, textsMs
))
