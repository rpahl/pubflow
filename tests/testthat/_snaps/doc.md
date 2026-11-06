# print() / shows an indented tree with item types and labels

    Code
      print(doc)
    Output
      <pubflow document> "Report"
      # Introduction [on empty: stop]
        text "A first line that is longer than fort..."
        table "Data"
        ## Details [unnumbered, landscape, page break]
          text "text"
      # Annex [no page break]
        text "With \"quotes\""
      pagebreak

---

    Code
      print(doc$children[[2L]])
    Output
      # Annex [no page break]
        text "With \"quotes\""

---

    Code
      print(doc$children[[2L]]$children[[1L]])
    Output
      <pubflow item> text "With \"quotes\""

---

    Code
      print(pub_doc())
    Output
      <pubflow document>

# documents made by layout steps (fixtures) / builds the report document

    Code
      print(doc)
    Output
      <pubflow document> "Quality demo"
      # Introduction [unnumbered]
        text "Quality of three batches ([demo]{.pla..."
      # Data
        table "Data table"
        table "Predicted values at 12 months"
      # Analysis
        table "Fit summary"
        figure "Assay over time"
        ## Fit
          table "Fit summary"
          figure "Assay over time"
        ## Conclusion
          text "Conclusion"
      # Criteria [landscape]
        table "Acceptance criteria"
        text "All batches meet the limits."
      # Summary
        text "Quality demo: 3 batches analysed."
        text "Conclusion"
      # Notes [on empty: keep]

# documents made by layout steps (fixtures) / places the outputs of several partitioned steps per batch (split)

    Code
      print(doc)
    Output
      <pubflow document> "Split demo"
      # Overview
        table "Coefficients per batch"
      # Batches
        ## Batch A (4 values)
          table "Data of batch A"
          figure "Assay over time"
          text "Slope: -0.26 per month."
        ## Batch B (4 values)
          table "Data of batch B"
          figure "Assay over time"
          text "Slope: -0.25 per month."
        ## Batch C (4 values)
          table "Data of batch C"
          figure "Assay over time"
          text "Slope: -0.29 per month."
      # All slopes
        ## A
          text "Slope: -0.26 per month."
        ## B
          text "Slope: -0.25 per month."
        ## C
          text "Slope: -0.29 per month."

# documents made by layout steps (fixtures) / places one section per inner pipeline (nested)

    Code
      print(doc)
    Output
      <pubflow document> "Nested demo"
      # Summary
        table "Slopes per batch"
      # Batch A [page break]
        table "Fit summary"
        figure "Assay over time"
        text "Slope: -0.255."
      # Batch B [page break]
        table "Fit summary"
        figure "Assay over time"
        text "Slope: -0.248."
      # Batch C [page break]
        table "Fit summary"
        figure "Assay over time"
        text "Slope: -0.289."
      # Results per batch
        ## A
          text "Slope: -0.255."
          table "Fit summary"
        ## B
          text "Slope: -0.248."
          table "Fit summary"
        ## C
          text "Slope: -0.289."
          table "Fit summary"

# documents made by layout steps (fixtures) / assembles one section per pipeline of a list (one per test)

    Code
      print(doc)
    Output
      <pubflow document> "Tests"
      # Assay
        table "Fit summary"
        figure "Assay over time"
        text "Slope: -0.255, -0.248, -0.289."
      # Water
        table "Fit summary"
        figure "Assay over time"
        text "Slope: -0.006, -0.006, -0.007."

# documents made by layout steps (fixtures) / builds a report across the test pipelines

    Code
      print(doc)
    Output
      <pubflow document> "Tests report"
      # Results
        ## Assay
          table "Fit summary"
          figure "Assay over time"
          text "Slope: -0.255, -0.248, -0.289."
        ## Water
          table "Fit summary"
          figure "Assay over time"
          text "Slope: -0.006, -0.006, -0.007."
      # Summary
        table "Slopes per test"

# documents made by layout steps (fixtures) / places the failures of a report run with on_error = "continue"

    Code
      print(doc)
    Output
      <pubflow document> "Quality demo"
      # Introduction [unnumbered]
        text "Quality of three batches ([demo]{.pla..."
      # Data
        table "Data table"
        table "Predicted values at 12 months"
      # Analysis
        table "Fit summary"
        figure "Assay over time"
        ## Fit
          table "Fit summary"
          figure "Assay over time"
        ## Conclusion
          text "Conclusion"
      # Criteria [landscape]
        table "Acceptance criteria"
        error "step 'check' failed: check failed on request"
      # Summary
        text "Quality demo: 3 batches analysed."
        text "Conclusion"
      # Notes [on empty: keep]

