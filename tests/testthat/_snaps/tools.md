# .find_pandoc() / explains how to install pandoc if none is found

    Code
      .find_pandoc(call = quote(pub_render()))
    Condition
      Error in `pub_render()`:
      ! pandoc (>= 3.6) is required but was not found.
      i Install pandoc >= 3.6 (https://pandoc.org/installing.html) and add it to the PATH, or set the environment variable PUBFLOW_PANDOC to the pandoc executable.

# .find_typst() / explains how to install typst if none is found

    Code
      .find_typst(call = quote(pub_render()))
    Condition
      Error in `pub_render()`:
      ! typst is required for PDF output via Typst but was not found.
      i Install typst (https://github.com/typst/typst/releases) or Quarto (https://quarto.org, bundles typst), or set the environment variable PUBFLOW_TYPST to the typst executable.

