# Package index

## Params: constructors

Create parameter objects and collect them into the config of a pipeline.

- [`param()`](https://rpahl.github.io/pubflow/reference/param.md)
  [`numeric_param()`](https://rpahl.github.io/pubflow/reference/param.md)
  [`numeral_param()`](https://rpahl.github.io/pubflow/reference/param.md)
  [`choice_param()`](https://rpahl.github.io/pubflow/reference/param.md)
  [`param_group()`](https://rpahl.github.io/pubflow/reference/param.md)
  : Parameter objects
- [`param_config()`](https://rpahl.github.io/pubflow/reference/param_config.md)
  [`c(`*`<param_config>`*`)`](https://rpahl.github.io/pubflow/reference/param_config.md)
  [`` `[`( ``*`<param_config>`*`)`](https://rpahl.github.io/pubflow/reference/param_config.md)
  : Parameter configs
- [`print(`*`<param_config>`*`)`](https://rpahl.github.io/pubflow/reference/print.param_config.md)
  : Print a param config

## Params: access

Test, read and set params.

- [`is_param()`](https://rpahl.github.io/pubflow/reference/is_param.md)
  [`param_type()`](https://rpahl.github.io/pubflow/reference/is_param.md)
  : Type and class of param objects
- [`param_value()`](https://rpahl.github.io/pubflow/reference/param_value.md)
  [`` `param_value<-`() ``](https://rpahl.github.io/pubflow/reference/param_value.md)
  : Get or set the value of a param
- [`param_attr()`](https://rpahl.github.io/pubflow/reference/param_attr.md)
  : Retrieve an attribute of a param
- [`print(`*`<param>`*`)`](https://rpahl.github.io/pubflow/reference/print.param.md)
  : Print a param object

## Params: validity

Check param values and add validity rules.

- [`param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
  [`param_validity_assert()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
  [`add_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
  [`default_param_validity()`](https://rpahl.github.io/pubflow/reference/param_validity.md)
  : Validity checks of params

## Params: pipelines

Read the params of a pipeline and list them in a report.

- [`pub_get_params()`](https://rpahl.github.io/pubflow/reference/pub_get_params.md)
  : Get the param objects of a pipeline
- [`pub_params_table()`](https://rpahl.github.io/pubflow/reference/pub_params_table.md)
  : Table of parameters

## Shiny

Shiny modules for the parameter UI and the document viewer.

- [`pub_param_input()`](https://rpahl.github.io/pubflow/reference/pub_param_input.md)
  : Input widget for a param
- [`pub_params_ui()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)
  [`pub_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)
  [`pub_pipeline_params_server()`](https://rpahl.github.io/pubflow/reference/pub_params_ui.md)
  : Parameter UI module
- [`pub_viewer_ui()`](https://rpahl.github.io/pubflow/reference/pub_viewer_ui.md)
  [`pub_viewer_server()`](https://rpahl.github.io/pubflow/reference/pub_viewer_ui.md)
  : Document viewer (Shiny module)

## Document structure

Arrange step outputs into documents in layout steps.

- [`pub_doc()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)
  [`pub_section()`](https://rpahl.github.io/pubflow/reference/pub_doc.md)
  : Documents and sections
- [`pub_error_items()`](https://rpahl.github.io/pubflow/reference/pub_error_items.md)
  : Error items of a document or of step outputs
- [`pub_layout_inputs()`](https://rpahl.github.io/pubflow/reference/pub_layout_inputs.md)
  : Inputs of a layout step: the steps of a view
- [`pub_out()`](https://rpahl.github.io/pubflow/reference/pub_out.md) :
  Get up-to-date step outputs from outside pipelines
- [`pub_pagebreak()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
  [`pub_toc()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
  [`pub_raw()`](https://rpahl.github.io/pubflow/reference/pub_pagebreak.md)
  : Page break, table of contents and raw content
- [`pub_session_info()`](https://rpahl.github.io/pubflow/reference/pub_session_info.md)
  : Session info section

## Outputs

Step outputs that documents show.

- [`pub_text()`](https://rpahl.github.io/pubflow/reference/pub_text.md)
  : Text output
- [`pub_figure()`](https://rpahl.github.io/pubflow/reference/pub_figure.md)
  : Figure output
- [`pub_type()`](https://rpahl.github.io/pubflow/reference/pub_type.md)
  : Type of an output
- [`as_pub_output()`](https://rpahl.github.io/pubflow/reference/as_pub_output.md)
  : Convert an object into a supported output

## Metadata

Read and set the metadata of step outputs.

- [`pub_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)
  [`pub_set_meta()`](https://rpahl.github.io/pubflow/reference/pub_meta.md)
  [`` `pub_meta<-`() ``](https://rpahl.github.io/pubflow/reference/pub_meta.md)
  : Metadata of an output

## Tables

Build, style and display tables.

- [`pub_table()`](https://rpahl.github.io/pubflow/reference/pub_table.md)
  : Create a pubflow table
- [`pub_table_rows()`](https://rpahl.github.io/pubflow/reference/pub_table_rows.md)
  : Rows of a table by role
- [`pub_table_theme()`](https://rpahl.github.io/pubflow/reference/pub_table_theme.md)
  : Table theme
- [`pub_cell_text()`](https://rpahl.github.io/pubflow/reference/pub_cell_text.md)
  : Display text of table cells
- [`pub_strikeout()`](https://rpahl.github.io/pubflow/reference/pub_strikeout.md)
  : Strike table cells through

## Number formatting

Round and format numbers as GMP reports require.

- [`pub_round()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
  [`pub_format_num()`](https://rpahl.github.io/pubflow/reference/pub_round.md)
  : Round numbers half away from zero

## Rendering

Render documents to HTML, Markdown and report files.

- [`pub_html()`](https://rpahl.github.io/pubflow/reference/pub_html.md)
  : Render a document to HTML
- [`pub_markdown()`](https://rpahl.github.io/pubflow/reference/pub_markdown.md)
  : Render a document to Pandoc Markdown
- [`pub_render()`](https://rpahl.github.io/pubflow/reference/pub_render.md)
  : Render a document to a file
- [`pub_cache()`](https://rpahl.github.io/pubflow/reference/pub_cache.md)
  : Define cache for figures and tables

## Report

Formats, pages, post-processors and traceability of reports.

- [`pub_report_spec()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  [`pub_page()`](https://rpahl.github.io/pubflow/reference/pub_report_spec.md)
  : Report specs and pages
- [`pub_pp_docx_header_footer()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
  [`pub_pp_docx_lock()`](https://rpahl.github.io/pubflow/reference/pub_pp_docx.md)
  : DOCX post-processors
- [`pub_trace_stamp()`](https://rpahl.github.io/pubflow/reference/pub_trace_stamp.md)
  : Trace stamp of a report
- [`pub_output_filename()`](https://rpahl.github.io/pubflow/reference/pub_output_filename.md)
  : File name of a rendered document
