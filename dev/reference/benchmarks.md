# Benchmarks behind the design decisions

Measured 2026-10-03 on the development machine (WSL2 Ubuntu 24.04), R 4.3.2,
huxtable 6.0.2, flextable 0.9.10, officer 0.7.0, ragg 1.2.5, svglite 2.1.3,
pandoc 3.8.3. Times are per call after warm-up (the very first call of a
session can be several times slower). Treat them as orders of magnitude.

## Tables

| Operation | small (3x4) | big (40x8) |
|---|---|---|
| `huxtable::to_html()` | 7 ms | ~40 ms |
| `huxtable::to_typst()` | 13 ms | ~200 ms |
| `huxtable::to_latex()` | 6 ms | — |
| `huxtable::as_flextable()` | 120 ms | 160 ms |
| `flextable::flextable()` (+ a few styles) | 70 ms | 170 ms |
| `officer::to_wml(<flextable>)` (Word XML) | ~80 ms per table | |

=> huxtable -> flextable -> Word XML costs ~200 ms per table (60 tables =
12 s). **pubflow writes Word table XML natively from huxtable properties**
(target < 10 ms for 40x8).

huxtable behaviour verified (6.0.2):
- `rbind()`/`cbind()` keep cell styles (background, text colour) and the
  caption of the first table. Custom attributes (`pubflow`): `rbind()`
  keeps the first table's, `cbind()` and `[` drop them (rechecked in M5,
  2026-10-04; the first note said `cbind()` kept them).
- Header rows are data rows: `as_hux(df, add_colnames = TRUE)` turns numeric
  columns into character (header string in row 1). Compute on data.frames,
  convert to tables at the end (D18: combine the data, build the
  table once; built tables can still be combined with huxtable's own
  `rbind()`/`cbind()`/`[`, see for what they keep and drop).
- Name clashes with flextable when both attached: `set_caption`, `to_html`
  (use `huxtable::` prefixes internally).
- Typst output exists since huxtable 5.7.0 (`to_typst`, `print_typst`,
  `quick_typst*`). Since 5.7.0 huxtable functions are not generic
  ("you can't subclass a huxtable object") — do not subclass huxtables.

## Figures

| Operation | Time | Size |
|---|---|---|
| ggplot (50 points + lm smooth) -> PNG 7x4 in @150 dpi via `ragg::agg_png` | ~77 ms | 28 KB |
| same -> SVG via `svglite` | ~220 ms | — |
| `officer::body_add_gg` x 20 + write docx | 2.4 s total | |

ggplot (50 points + lm smooth) -> PNG 8x6 in via `ragg::agg_png`, median
of 15 runs (2026-10-22, R 4.5.3), behind D40 (one default, PNG 200 dpi,
for the viewer and all formats):

| Resolution | Time | Size |
|---|---|---|
| 150 dpi | 95 ms | 32 KB |
| 200 dpi | 114 ms | 42 KB |
| 300 dpi | 165 ms | 66 KB |

=> PNG via ragg for UI/HTML/DOCX (since D40 for PDF too); cache rendered
figures (keyed by step and run time) so unchanged figures are never
re-rendered.

## DOCX assembly

| Approach | Result |
|---|---|
| officer `body_add_flextable` x 40 (incremental) | 3.7 s; per-insert time grows from 60 ms (first) to 220 ms (last) |
| `officer::to_wml` x 40 + `body_add_xml` x 40 + write | 4.0 s (XML generation dominates: 3.3 s) |
| **pandoc** Markdown (60 raw `{=openxml}` tables, 100 images, 60 display equations, inline math, lists) -> DOCX | **0.81 s**; all 60 tables, 100 images and 60 native Word equations (OMML) present |
| pandoc same Markdown -> Typst | < 1 s |

=> Build Pandoc Markdown with raw format-specific blocks and call pandoc
once. LaTeX math becomes native Word equations only via pandoc.

## pubflow DOCX reports (M8-M9)

`pub_render(format = "docx")` of the R15 workload (`inst/bench/docx.R`,
DESIGN.md §4), R 4.5.3, pandoc 3.8.3, warm figure cache, two runs each:

| Version | Warm total | Parts |
|---|---|---|
| M8 PR B (no post-processors) | 3.1-3.9 s | pandoc 1.9-2.7 s, `pub_markdown()` 0.8-1.0 s, section breaks 0.1 s |
| M9 PR B (2026-10-08; header with `{trace}` footer, lock) | 3.9-4.2 s | pandoc 2.4-2.6 s, `pub_markdown()` 0.9-1.0 s, section breaks 0.1 s, header/footer 0.19-0.21 s, lock 0.39 s |
| M9 PR B, headers and footers locked too (another process busy, load ~1.5 of 4 cores) | 4.2-4.9 s (three runs) | pandoc 2.2-2.9 s, `pub_markdown()` 0.7-0.9 s, section breaks 0.1 s, header/footer 0.17-0.22 s, lock 0.46-0.49 s |
| Native locks, no markers (2026-10-30, load ~2.4) | 3.8 s (one run) | pandoc 1.8 s, `pub_markdown()` 0.7 s, section breaks 0.1 s, header/footer 0.18 s, lock (headers and footers only) 0.33 s |

Target < 5 s; cold 10.6-10.7 s (45 figures at 200 dpi). The file is
2.8 MB with a 4.8 MB `document.xml`. Locking the headers and footers adds
no measurable time: the lock pass on identical copies of R15 took 381 vs
399 ms (medians of ten alternating runs with `gc()` before each) with and
without it.

DOCX post-processors on R15 (M9 step 0, 2026-10-07):

| Approach | Result |
|---|---|
| officer header/footer (`docx_update_header_and_footer()` of an earlier app) | `print()` 10.1 s; text outside `w:t` with pubflow's empty bookmark run; rewrites 12 of 18 parts |
| xml2 header/footer (unzip, replace, rezip) | 0.18 s |
| an earlier app's `lock_docx()` (copies the nodes) | 420 extra `xmlns` declarations, duplicate `w:id`s |
| xml2 lock, SDT built in place (design (b)) | 0.65 s in step 0, 0.39 s as shipped; no extra declarations |

=> xml2 for both post-processors (D33); officer left the
dependencies.

## pandoc 3.8.3 vs 3.13 (2026-10-30)

R15 with `inst/bench/docx.R` and `inst/bench/pdf.R`, R 4.5.3, warm figure cache,
the versions alternating (machine busy, load ~2.5-3 of 4 cores):

| Render | pandoc 3.8.3 | pandoc 3.13 |
|---|---|---|
| DOCX warm (two runs) | 5.8-6.6 s (pandoc 2.5-3.4 s) | 4.4-4.6 s (pandoc 2.5-2.6 s) |
| PDF xelatex warm / cold | 26.2 / 33.0 s | 25.2 / 32.9 s |
| PDF Typst warm / cold | 8.7 / 13.9 s | 8.1 / 13.6 s |

=> No slowdown; the DOCX gap is within the noise of the busy machine (the pandoc
step itself is the same).

## Outputs that reach their pipeline (D20)

Measured 2026-10-23, R 4.5.3, ggplot2 4.0.3, pipeflow 0.5.0.9012. A
pipeline constructor holding a 40 MB data.frame, one plot step, run;
`length(serialize(x, NULL))`:

| | saved pipeline | figure saved alone |
|---|---|---|
| ggplot made inline in the step | 40.8 MB | 40.8 MB |
| ggplot made by a top-level helper (inline wrapper) | 40.8 MB | 0.77 MB |

The pipeline holds the constructor's frame through its inline step
functions either way. Costs of checking a figure for a reachable
pipeline (class `pipeflow`), per ggplot:

| Check | nothing found | pipeline found |
|---|---|---|
| `serialize(refhook = )` | 40-70 ms (300-640 ms with the 40 MB in reach) | same |
| full walk (lists, attributes, functions, environments) | ~65 ms | ~7 ms |
| chains of `plot_env` and mapping quosures, bindings only | 0.14 ms | 0.09 ms |

=> no run-time check (D20); the targeted check is parked as an
opt-in diagnostic (PLAN.md).

## Figures across processes (D43)

Measured 2026-10-23, R 4.5.3, ggplot2 4.0.3. After `serialize()` /
`unserialize()` a ggplot keeps pubflow's stamp, but `rlang::hash()` and
`identical()` change; a hash of `serialize()` is equal for two identical
builds in one process but changes after a roundtrip too. data.frames keep
`rlang::hash()` and `identical()`. pubflow's metadata attribute survives
`+ theme_bw()`, `+ geom_line()`, `+ labs()`, `@labels<-` and `$data<-`.

A faceted ggplot (200 points, 4 panels, smooths), 8 x 6 in at 200 dpi:
PNG 116 KB against 1019 KB for the serialized ggplot; `rlang::hash()` of
the PNG bytes 0.03 ms, equal after a roundtrip. R15 (45 figures):
~5 MB of PNG in the pipelines.

## Baseline of an earlier report generator

A 15-section report with officer and flextable: PDF 23.6 s, Word 34.6 s end-to-end.

## Tooling

pandoc 3.6 and 3.13, TeX Live 2026 (xelatex), typst 0.15.1 (standalone binary), LibreOffice 24.2. A typst
installed as a snap can't start inside sandboxed environments (it needs `~/snap`); use the release binary.
