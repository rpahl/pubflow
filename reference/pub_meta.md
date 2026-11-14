# Metadata of an output

Outputs are ordinary R objects (data.frames, ggplots, texts, ...).
pubflow can attach extra information to them, e.g. a caption or an id,
called *metadata*.

## Usage

``` r
pub_meta(x, key = NULL)

pub_set_meta(x, ...)

pub_meta(x) <- value
```

## Arguments

- x:

  An R object (not `NULL`).

- key:

  `character(1)` name of an entry or `NULL` for the whole list.

- ...:

  Named entries to set; `NULL` removes an entry.

- value:

  Named list of metadata (or `NULL` to remove all).

## Value

- `pub_meta()`: the named list of metadata (empty if there is none) or
  the entry `key` (`NULL` if absent).

- `pub_set_meta()`: `x` with the new metadata.

- `pub_meta<-`: `x` with the new metadata.

## Details

### Functions

- `pub_meta()` reads the metadata;

- `pub_set_meta()` sets or removes single entries;

- `pub_meta<-` replaces all of it.

Functions such as
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
and
[`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md)
set metadata for you; use these functions to read or change it
afterwards.

### Keys

|  |  |  |
|----|----|----|
| Key | Applies to | Meaning |
| `title` | any item | heading above the item |
| `caption` | table, figure | numbered caption ("Table 1: ..."); `""` for none |
| `id` | table, figure | name for cross-references (see [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)) |
| `width`, `height` | figure | size in inches (default 8 x 6) |
| `out_width` | figure | width relative to the text width, e.g. `"90%"` |
| `font_size` | table | font size in pt |
| `landscape` | table, figure | place on landscape pages (DOCX, PDF) |
| `locked` | table, figure | lock in DOCX against accidental edits |
| `fallback` | widget | static figure shown where HTML is not available |
| `stamp` | figure | set when a step returns a plot, not a rendered one |

An `id` must be unique in a document. It starts with a letter, ends with
a letter or digit and has only letters, digits, `_` and `-` in between,
e.g. `"ozone-1"`.

You can also add keys of your own. pubflow keeps them but does not use
them.

### Huxtables

The caption of a huxtable lives in huxtable's own caption
([`huxtable::caption()`](https://hughjonesd.github.io/huxtable/reference/caption.html)),
and `pub_meta()` and friends read and write it there. Subsetting with
`[` and [`cbind()`](https://rdrr.io/r/base/cbind.html) keep this caption
but drop all other metadata. So set the metadata on the final table.

## See also

[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md),
[`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md),
[`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md),
[`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)

## Examples

``` r
x <- pub_set_meta(data.frame(a = 1:2), title = "Raw data", locked = TRUE)
pub_meta(x)
#> $title
#> [1] "Raw data"
#> 
#> $locked
#> [1] TRUE
#> 
pub_meta(x, "title")
#> [1] "Raw data"

x <- pub_set_meta(x, locked = NULL)
names(pub_meta(x))
#> [1] "title"

pub_meta(x) <- list(title = "Data")
pub_meta(x)
#> $title
#> [1] "Data"
#> 

# the target of the cross-reference `@tab:ozone` in a text
tab <- pub_table(airquality[1:4, c("Month", "Day", "Ozone")], caption = "Ozone")
tab <- pub_set_meta(tab, id = "ozone")
pub_meta(tab, "id")
#> [1] "ozone"
```
