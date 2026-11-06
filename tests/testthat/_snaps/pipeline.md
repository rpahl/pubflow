# pub_layout_inputs() / makes a layout step that runs only the steps it needs

    Code
      print(p[["short", "out"]])
    Output
      <pubflow document>
      # table
        table
      # mean
        text "Mean: 7.5"

# pub_layout_inputs() / places partitioned and other outputs once with exec = 'reduce'

    Code
      print(p[["doc", "out"]])
    Output
      <pubflow document>
      # table
        ## A
          table
        ## B
          table
      # mean
        text "Mean: 2.5"

