# Convert an object into a supported output

A document only knows a few kinds of outputs (see
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)).
If you put an object of another class into a document, pubflow calls
`as_pub_output()` to turn it into one it knows. By default this signals
an error. To make a class of your own usable in documents, write a
method for it (see Examples).

## Usage

``` r
as_pub_output(x, ...)

# Default S3 method
as_pub_output(x, ...)
```

## Arguments

- x:

  An object.

- ...:

  Passed on to methods.

## Value

A supported output (see
[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)).

## Details

A method must return a supported output, typically a table, a ggplot, a
character string or a list of those.

## See also

[`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)

## Examples

``` r
# A client class and its method
as_pub_output.my_result <- function(x, ...) {
    pub_table(x$table, caption = x$label)
}
res <- structure(
    list(table = data.frame(a = 1), label = "Result"),
    class = "my_result"
)
registerS3method("as_pub_output", "my_result", as_pub_output.my_result)
pub_type(res)
#> [1] "table"

try(as_pub_output(structure(1, class = "unknown")))
#> Error : unsupported output of class <unknown>; provide an as_pub_output() method
```
