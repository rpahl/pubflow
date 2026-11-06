# print.param_config() / prints a table with one row per param in the config order

    Code
      print(cfg)
    Output
      <param_config: 3 params>
       name  type      value          label    
       alpha numeric   0.05           Alpha    
       unit  character %              Unit of y
       pick  factor    <factor[1]: a> Pick     

# print.param_config() / lists group children indented below their group and shortens values

    Code
      print(cfg)
    Output
      <param_config: 2 params>
       name  type      value                          label          
       grp   list      <list[3]: a=1, g=<list[1]: ... Group          
         a   numeric   1                              A              
         g   list      <list[1]: x=2>                 Parameter group
           x numeric   2                              parameter      
         b             2                                             
       long  character xxxxxxxxxxxxxxxxxxxxxxxxxxx... parameter      

