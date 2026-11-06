# Benchmark (DESIGN.md §4): pub_render(format = "pdf") of the R15 workload
# (inst/bench/r15.R) via xelatex and, if it runs, Typst. Not run on CI;
# record results in the PR. Needs ggplot2, pandoc and xelatex (a typst snap
# can't read the session's temporary directory: set TMPDIR to a directory
# under the home directory).
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE); source('inst/bench/pdf.R')"
# or with pubflow installed:
#   Rscript -e "library(pubflow); source(system.file('bench', 'pdf.R',
#               package = 'pubflow'))"

local({
    file <- "inst/bench/r15.R"
    if (!file.exists(file)) {
        file <- system.file("bench", "r15.R", package = "pubflow")
    }
    source(file, local = parent.frame(2L))
})

# Elapsed time in ms of one evaluation of `expr`
elapsed_ms <- function(expr) {
    start <- proc.time()[["elapsed"]]
    force(expr)
    (proc.time()[["elapsed"]] - start) * 1000
}

doc <- r15_doc()
typst <- tryCatch(pubflow:::.find_typst(), error = function(e) NULL)
engines <- c("xelatex",
             if (!is.null(typst) && !is.null(pubflow:::.tool_version(typst))) {
                 "typst"
             })

for (engine in engines) {
    target <- if (engine == "xelatex") "latex" else "typst"
    file <- tempfile(fileext = ".pdf")
    # Cold: a new cache, every figure is rendered (PNG, 200 dpi)
    cache <- pub_cache()
    cold <- elapsed_ms(pub_render(doc, "pdf", file = file, cache = cache,
                                  pdf_engine = engine))
    # Warm: the figures come from the cache (median of 3 runs)
    warm <- stats::median(vapply(1:3, \(i) {
        elapsed_ms(pub_render(doc, "pdf", file = file, cache = cache,
                              pdf_engine = engine))
    }, numeric(1)))
    markdown <- elapsed_ms(pub_markdown(doc, target, tempfile(),
                                        cache = cache))
    cat(sprintf(
        paste0(
            "R15 pub_render(format = \"pdf\", pdf_engine = \"%s\"): ",
            "%.1f MB, %d pages\n",
            "cold (new cache): %7.0f ms\n",
            "warm (cached):    %7.0f ms\n",
            "  pub_markdown(): %7.0f ms\n"
        ),
        engine, file.size(file) / 1e6,
        length(pdftools::pdf_text(file)), cold, warm, markdown
    ))
}
