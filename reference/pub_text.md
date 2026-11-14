# Text output

Joins lines into one Markdown text and checks that it has no headings
(use sections for structure). Steps may also return plain character
vectors, which the document builder checks in the same way.

## Usage

``` r
pub_text(x, title = NULL)
```

## Arguments

- x:

  Character vector of lines.

- title:

  `character(1)` heading line shown above the text (not a section) or
  `NULL` (as is a blank string).

## Value

`character(1)` with metadata (see
[`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)).

## Details

### Supported Markdown

The same in HTML, DOCX and PDF:

|                                       |                             |
|---------------------------------------|-----------------------------|
| Markdown                              | Result                      |
| blank line                            | new paragraph               |
| `*italic*`, `**bold**`, `` `code` ``  | emphasis and code           |
| `[link](url)`                         | link                        |
| `- item`, `1. item`                   | bullet and numbered lists   |
| backslash at the end of a line        | line break                  |
| `$...$`, `$$...$$` (on its own lines) | inline and display math     |
| fenced code block                     | code block                  |
| `[<insert value>]{.placeholder}`      | highlighted text to fill in |

A placeholder marks a gap that someone fills in by hand later, e.g. in
the Word report. It is highlighted in every format, so it is not
overlooked.

### Cross-references

`@fig:<id>` and `@tab:<id>` refer to the figure or table with that `id`
(see
[`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)
and
[`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md))
and become a link "Figure 1" or "Table 2". The word is set by `labels`
in the report spec. In Word they are cross-reference fields.

- The figure or table needs a caption (only captions are numbered) and
  its `id` must be unique in the document.

- References in code, math, placeholders, links and image descriptions
  stay text, as do `\@fig:x` and `a@fig:x`.

- A reference that can't be resolved is an error in
  [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  and
  [`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md).
  [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md)
  and the viewer warn and mark it, so a draft still displays.

## See also

[`pub_md_escape()`](https://rpahl.github.io/pubflow/reference/pub_md_escape.md)
for data in the text,
[`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md),
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)

## Examples

``` r
txt <- pub_text(
    c(
        "The mean difference is **2.5 units** ($p = 0.03$).",
        "",
        "- group A",
        "- group B",
        "",
        "See [<insert link>]{.placeholder} and @fig:trend."
    ),
    title = "Summary"
)
writeLines(txt)
#> The mean difference is **2.5 units** ($p = 0.03$).
#> 
#> - group A
#> - group B
#> 
#> See [<insert link>]{.placeholder} and @fig:trend.
pub_meta(txt)
#> $title
#> [1] "Summary"
#> 

# Display math, numbered list and code block
writeLines(pub_text(c(
    "The fitted model is",
    "",
    "$$",
    "y = a + b x",
    "$$",
    "",
    "1. fit the model",
    "2. check the residuals",
    "",
    "```",
    "lm(y ~ x)",
    "```"
)))
#> The fitted model is
#> 
#> $$
#> y = a + b x
#> $$
#> 
#> 1. fit the model
#> 2. check the residuals
#> 
#> ```
#> lm(y ~ x)
#> ```

try(pub_text(c("# Results", "Text")))
#> Error in pub_text(c("# Results", "Text")) : 
#>   Text must not contain headings (use sections):
#> ✖ line 1: "# Results"
```
