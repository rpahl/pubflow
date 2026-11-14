# pub_report_spec() / prints the fields of its format

    Code
      pub_report_spec("docx")
    Output
      <pubflow report spec: docx>
        reference_docx    default
        front_matter      document's or title block
        toc               depth 3
        number_sections   yes
        page              reference document
        figure            default
        labels            Table, Figure
        lock              marked items
        error_items       refuse
        post_process      none
        pandoc_args       none
    Code
      pub_report_spec("pdf", page = pub_page("letter"), toc = FALSE, figure = list(
        device = "png", res = 300), labels = list(table = "Tab."), placeholder_color = "#123456",
      pandoc_args = c("--dpi", "300"))
    Output
      <pubflow report spec: pdf>
        latex_preamble    none
        typst_template    default
        front_matter      document's or title block
        toc               no
        number_sections   yes
        page              Letter portrait, margins top 2.5, bottom 2, left 2.5, right 2.5 cm
        figure            device = png, res = 300
        labels            Tab., Figure
        placeholder_color #123456
        error_items       refuse
        post_process      none
        pandoc_args       --dpi 300
    Code
      pub_report_spec("md", front_matter = function(doc, format) NULL, error_items = "show",
      post_process = function(path, doc, spec) NULL)
    Output
      <pubflow report spec: md>
        front_matter      function
        toc               no
        number_sections   yes
        figure            default
        labels            Table, Figure
        error_items       show
        post_process      1 function(s)

# pub_page() / prints its size and margins

    Code
      pub_page("letter", "landscape", c(bottom = 1.5))
    Output
      <pubflow page: Letter landscape, margins top 2.5, bottom 1.5, left 2.5, right 2.5 cm>

