# File name of a rendered document

Makes a file name from the time and the title of a document.

## Usage

``` r
pub_output_filename(meta, ext)
```

## Arguments

- meta:

  Document metadata (`doc$meta`, see
  [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md))
  or a document.

- ext:

  `character(1)` file extension without the dot, e.g. `"docx"`.

## Value

`character(1)` file name.

## Details

### Format

The name has the form `<YYYYMMDDTHHMMSSZ>_<title>.<ext>`:

- the time (`time` in the metadata, else now) in UTC;

- the title in lower case, where every run of characters other than
  ASCII letters and digits is replaced by `_` (`"document"` without a
  title). Other letters, e.g. accented ones, are dropped, as their
  transliteration depends on the platform.

## See also

[`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)

## Examples

``` r
meta <- list(title = "Ozone report: May",
             time = as.POSIXct("2026-10-05 14:30:00", tz = "UTC"))
pub_output_filename(meta, "docx")
#> [1] "20261005T143000Z_ozone_report_may.docx"
```
