# Define cache for figures and tables

Holds rendered figures and tables for reuse by the render functions that
get it as their `cache` argument
([`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md),
[`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
and the viewer).

## Usage

``` r
pub_cache(dir = NULL, max_entries = 500L)
```

## Arguments

- dir:

  Directory for the image files, or `NULL` for a new temporary directory
  of the R session.

- max_entries:

  Maximum number of cached figures and tables.

## Value

A `pub_cache` object (an environment, so it is updated in place).

## Details

### What is cached

Two kinds of entries are cached:

- figures: image files in `dir`, used by every output format. The key
  combines the figure's stamp (step, partition key and run time, see
  [`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)),
  a hash of the figure and its metadata and the device settings.

- tables: their HTML (in memory), used by HTML output. The key is a hash
  of the table and its font size.

Beyond `max_entries` entries the least recently used ones (and their
files) are removed.

## See also

[`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md),
[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)

## Examples

``` r
cache <- pub_cache()
cache
#> <pubflow render cache> 0 of at most 500 entries, files in '/tmp/Rtmp4Uexz3/pubflow-cache-1c9e5a96a851'
```
