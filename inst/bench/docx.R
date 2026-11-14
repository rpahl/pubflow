# Benchmark (DESIGN.md §4): pub_render(format = "docx") of the R15 workload
# (inst/bench/r15.R), target: warm figure cache < 5 s (an
# officer-based Word report took ~35 s). Not run on CI; record results in the
# PR. Needs ggplot2 and pandoc.
#
# Run from the package root:
#   Rscript -e "pkgload::load_all(quiet = TRUE); source('inst/bench/docx.R')"
# or with pubflow installed:
#   Rscript -e "library(pubflow); source(system.file('bench', 'docx.R',
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
file <- tempfile(fileext = ".docx")
# render-time metadata of a report with header and footer (trace stamp)
meta <- list(
    author = "A. User",
    app = "demo",
    version = "1.2.0",
    header = c(left = "R15 benchmark report"),
    footer = c(left = "{trace}")
)
# the workload of the recorded timings: everything locked
spec <- pub_report_spec("docx", lock = TRUE)

# Cold: a new cache, every figure is rendered (PNG, 200 dpi)
cache <- pub_cache()
cold <- elapsed_ms(pub_render(
    doc,
    "docx",
    file = file,
    spec = spec,
    cache = cache,
    meta = meta
))

# Warm: the figures come from the cache (median of 3 runs)
warm <- stats::median(vapply(
    1:3,
    \(i) {
        elapsed_ms(pub_render(
            doc,
            "docx",
            file = file,
            spec = spec,
            cache = cache,
            meta = meta
        ))
    },
    numeric(1)
))

# The parts of a warm run
assets <- tempfile()
markdown <- elapsed_ms(
    md <- pub_markdown(doc, "docx", assets, spec = spec, cache = cache)
)
input <- file.path(dirname(assets), "bench.md")
writeLines(md, input)
output <- tempfile(fileext = ".docx")
pandoc <- elapsed_ms(system2(
    pubflow:::.find_pandoc(),
    c(
        "-f",
        pubflow:::.pandoc_reader(),
        "-o",
        shQuote(output),
        "--reference-doc",
        shQuote(system.file("templates", "reference.docx", package = "pubflow")),
        "--resource-path",
        shQuote(dirname(assets)),
        shQuote(input)
    )
))
sections <- elapsed_ms(pubflow:::.docx_complete_sections(output))
merged <- pubflow:::.render_doc(doc, meta)
header_footer <- elapsed_ms(pub_pp_docx_header_footer()(output, merged, spec))
lock <- elapsed_ms(pub_pp_docx_lock()(output, merged, spec))

cat(sprintf(
    paste0(
        "R15 pub_render(format = \"docx\"): %.1f MB\n",
        "cold (new cache): %7.0f ms\n",
        "warm (cached):    %7.0f ms (target < 5000 ms)\n",
        "  pub_markdown(): %7.0f ms\n",
        "  pandoc:         %7.0f ms\n",
        "  section breaks: %7.0f ms\n",
        "  header/footer:  %7.0f ms\n",
        "  lock:           %7.0f ms\n"
    ),
    file.size(file) / 1e6,
    cold,
    warm,
    markdown,
    pandoc,
    sections,
    header_footer,
    lock
))
