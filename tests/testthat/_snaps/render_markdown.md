# pub_markdown() / writes Markdown for Word (snapshot)

    Code
      cat(markdown(doc, "docx", spec = spec))
    Output
      ```{=openxml}
      <w:p><w:r><w:br w:type="page"/></w:r></w:p>
      ```
      
      # Text
      
      ::: {custom-style="Item Title"}
      Note
      :::
      
      Some **bold** text, $x^2$ and [todo]{custom-style="Placeholder"}.
      
      &lt;b>not bold&lt;/b> and `x`\{=latex}
      
      See `<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> REF _Ref_pubflow_1 \h \* MERGEFORMAT </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r>`{=openxml}Table 1`<w:r><w:fldChar w:fldCharType="end"/></w:r>`{=openxml} and `<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> REF _Ref_pubflow_2 \h \* MERGEFORMAT </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r>`{=openxml}Figure 2`<w:r><w:fldChar w:fldCharType="end"/></w:r>`{=openxml}, not `@fig:points`.
      
      $$
      \frac{a}{b}
      $$
      
      ```{=openxml}
      <w:p><w:r><w:t>raw</w:t></w:r></w:p>
      ```
      
      ```{=openxml}
      <w:p><w:r><w:br w:type="page"/></w:r></w:p>
      ```
      
      ```{=openxml}
      <w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-2" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Update the field to show the table of contents.</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
      ```
      
      ```{=openxml}
      <w:sdt><w:sdtPr><w:tag w:val="locked-figure"/><w:lock w:val="sdtContentLocked"/></w:sdtPr><w:sdtContent>
      ```
      
      ::: {custom-style="Figure"}
      ![Widget](<doc_files/figure-1.png>){width=5.67in}
      :::
      
      ```{=openxml}
      </w:sdtContent></w:sdt>
      ```
      
      ::: {custom-style="Image Caption"}
      Figure `<w:fldSimple w:instr=" SEQ Figure \* ARABIC "><w:r><w:t>1</w:t></w:r></w:fldSimple>`{=openxml}: Widget
      :::
      
      ```{=openxml}
      <w:p><w:r><w:br w:type="page"/></w:r></w:p>
      ```
      
      # Tables
      
      ::: {custom-style="Table Caption"}
      `<w:bookmarkStart w:id="90001" w:name="_Ref_pubflow_1"/>`{=openxml}Table `<w:fldSimple w:instr=" SEQ Table \* ARABIC "><w:r><w:t>1</w:t></w:r></w:fldSimple>`{=openxml}`<w:bookmarkEnd w:id="90001"/>`{=openxml}: A \& B
      :::
      
      ```{=openxml}
      <w:sdt><w:sdtPr><w:tag w:val="locked-table"/><w:lock w:val="sdtContentLocked"/></w:sdtPr><w:sdtContent>
      <w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:jc w:val="center"/><w:tblLayout w:type="autofit"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr><w:tblGrid><w:gridCol w:w="4536"/><w:gridCol w:w="4536"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">a</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">b</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">1.3</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">x</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve"></w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">&lt;y&gt;</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      </w:sdtContent></w:sdt>
      ```
      
      ::: {custom-style="Item Title"}
      Unlocked
      :::
      
      ```{=openxml}
      <w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:jc w:val="center"/><w:tblLayout w:type="autofit"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr><w:tblGrid><w:gridCol w:w="9072"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">z</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      ```
      
      ```{=openxml}
      <w:p><w:r><w:br w:type="page"/></w:r></w:p>
      ```
      
      ::: {custom-style="Heading 1 Unnumbered"}
      Figures
      :::
      
      ```{=openxml}
      <w:sdt><w:sdtPr><w:tag w:val="locked-figure"/><w:lock w:val="sdtContentLocked"/></w:sdtPr><w:sdtContent>
      ```
      
      ::: {custom-style="Figure"}
      ![Points](<doc_files/figure-2.png>){width=3.15in}
      :::
      
      ```{=openxml}
      </w:sdtContent></w:sdt>
      ```
      
      ::: {custom-style="Image Caption"}
      `<w:bookmarkStart w:id="90002" w:name="_Ref_pubflow_2"/>`{=openxml}Figure `<w:fldSimple w:instr=" SEQ Figure \* ARABIC "><w:r><w:t>2</w:t></w:r></w:fldSimple>`{=openxml}`<w:bookmarkEnd w:id="90002"/>`{=openxml}: Points
      :::
      
      ```{=openxml}
      <w:p><w:pPr><w:sectPr></w:sectPr></w:pPr></w:p>
      ```
      
      ```{=openxml}
      <w:sdt><w:sdtPr><w:tag w:val="locked-figure"/><w:lock w:val="sdtContentLocked"/></w:sdtPr><w:sdtContent>
      ```
      
      ::: {custom-style="Figure"}
      ![Figure](<doc_files/figure-3.png>){width=8.75in}
      :::
      
      ```{=openxml}
      </w:sdtContent></w:sdt>
      ```
      
      ```{=openxml}
      <w:p><w:pPr><w:sectPr><w:pgSz w:orient="landscape"/></w:sectPr></w:pPr></w:p>
      ```
      
      ::: {custom-style="Heading 2 Unnumbered"}
      Nested
      :::
      
      Text of an unnumbered section.
      
      ```{=openxml}
      <w:p><w:pPr><w:sectPr></w:sectPr></w:pPr></w:p>
      ```
      
      # Wide
      
      ::: {custom-style="Table Caption"}
      Table `<w:fldSimple w:instr=" SEQ Table \* ARABIC "><w:r><w:t>2</w:t></w:r></w:fldSimple>`{=openxml}: Wide
      :::
      
      ```{=openxml}
      <w:sdt><w:sdtPr><w:tag w:val="locked-table"/><w:lock w:val="sdtContentLocked"/></w:sdtPr><w:sdtContent>
      <w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:jc w:val="center"/><w:tblLayout w:type="autofit"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr><w:tblGrid><w:gridCol w:w="14004"/></w:tblGrid><w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">w</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/><w:tcBorders><w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/></w:tcBorders><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="top"/></w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="right"/><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr><w:t xml:space="preserve">1.0000</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      </w:sdtContent></w:sdt>
      ```
      
      ```{=openxml}
      <w:p><w:pPr><w:sectPr><w:pgSz w:orient="landscape"/></w:sectPr></w:pPr></w:p>
      ```
      
      # Results
      
      ## Check
      
      Checked.
      
      ::: {custom-style="Error"}
      **Step 'fit' failed**\
      singular fit\
      Step 'table' was not run.
      :::

# pub_markdown() / writes a Markdown document (snapshot)

    Code
      cat(markdown(doc, "md"))
    Output
      ---
      title: "Every node"
      subtitle: "Subtitle & \"more\""
      author: "A. User"
      date: "2026-10-05 12:00:00 UTC"
      ---
      
      # 1 Text
      
      **Note**
      
      Some **bold** text, $x^2$ and [todo]{.placeholder}.
      
      &lt;b>not bold&lt;/b> and `x`\{=latex}
      
      See Table 1 and Figure 2, not `@fig:points`.
      
      $$
      \frac{a}{b}
      $$
      
      Raw *md*
      
      ![Widget](<doc_files/figure-1.png>)
      
      Figure 1: Widget
      
      # 2 Tables
      
      Table 1: A \& B
      
      -----------------------
            **a** **b**      
      ----------- -----------
              1.3 x          
                             
                  \<y\>      
      -----------------------
      
      **Unlocked**
      
      ----------------------
                      **z** 
                            
                          1 
      ----------------------
      
      # Figures
      
      ![Points](<doc_files/figure-2.png>)
      
      Figure 2: Points
      
      ![Figure](<doc_files/figure-3.png>)
      
      ## Nested
      
      Text of an unnumbered section.
      
      # 3 Wide
      
      Table 2: Wide
      
      ----------------------
                      **w** 
                            
                     1.0000 
      ----------------------
      
      # 4 Results
      
      ## 4.1 Check
      
      Checked.
      
      > **Step 'fit' failed**\
      > singular fit\
      > Step 'table' was not run.

# pub_markdown() / writes Markdown for LaTeX (snapshot)

    Code
      cat(markdown(doc, "latex"))
    Output
      ```{=latex}
      \clearpage
      ```
      
      # Text
      
      **Note**
      
      Some **bold** text, $x^2$ and `\textcolor[HTML]{0083C0}{`{=latex}todo`}`{=latex}.
      
      &lt;b>not bold&lt;/b> and `x`\{=latex}
      
      See `\hyperref[ab]{\tablename~\ref*{ab}}`{=latex} and `\hyperref[points]{\figurename~\ref*{points}}`{=latex}, not `@fig:points`.
      
      $$
      \frac{a}{b}
      $$
      
      ```{=latex}
      \clearpage
      ```
      
      ```{=latex}
      \setcounter{tocdepth}{2}
      \tableofcontents
      ```
      
      ![Widget](<doc_files/figure-1.png>){width=5.67in}
      
      ```{=latex}
      \clearpage
      ```
      
      # Tables
      
      ```{=latex}
      \begingroup
      
        \providecommand{\huxb}[2]{\arrayrulecolor[RGB]{#1}\global\arrayrulewidth=#2pt}
        \providecommand{\huxvb}[2]{\color[RGB]{#1}\vrule width #2pt}
        \providecommand{\huxtpad}[1]{\rule{0pt}{#1}}
        \providecommand{\huxbpad}[1]{\rule[-#1]{0pt}{#1}}
      \setlength{\tabcolsep}{0pt}
      {
      \setlength{\LTcapwidth}{\linewidth}
      \begin{longtable}[c]{l l}
      \captionsetup{justification=centering,singlelinecheck=off}
      \caption{A \& B}
       \label{ab}
      \tabularnewline
      
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}->{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont a}} \hspace{6pt}\huxbpad{6pt}} &
      \multicolumn{1}{l!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedright \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont b}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}->{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endfirsthead
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}->{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont a}} \hspace{6pt}\huxbpad{6pt}} &
      \multicolumn{1}{l!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedright \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont b}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}->{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endhead
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont 1.3} \hspace{6pt}\huxbpad{6pt}} &
      \multicolumn{1}{l!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedright \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont x} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont } \hspace{6pt}\huxbpad{6pt}} &
      \multicolumn{1}{l!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedright \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont \textless{}y\textgreater{}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}->{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      \end{longtable}
      }
      \endgroup
      ```
      
      **Unlocked**
      
      ```{=latex}
      \begingroup
      \def\LTcaptype{none}
      
        \providecommand{\huxb}[2]{\arrayrulecolor[RGB]{#1}\global\arrayrulewidth=#2pt}
        \providecommand{\huxvb}[2]{\color[RGB]{#1}\vrule width #2pt}
        \providecommand{\huxtpad}[1]{\rule{0pt}{#1}}
        \providecommand{\huxbpad}[1]{\rule[-#1]{0pt}{#1}}
      \setlength{\tabcolsep}{0pt}
      {
      \setlength{\LTcapwidth}{\linewidth}
      \begin{longtable}[c]{l}
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont z}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endfirsthead
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont z}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endhead
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont 1} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      \end{longtable}
      }
      \endgroup
      ```
      
      ```{=latex}
      \clearpage
      ```
      
      # Figures {.unnumbered}
      
      ![Points](<doc_files/figure-2.png>){#points width=3.15in}
      
      ```{=latex}
      \begin{landscape}
      ```
      
      ```{=latex}
      \begingroup\centering
      ```
      
      ![](<doc_files/figure-3.png>){width=5.35in}
      
      ```{=latex}
      \par\endgroup
      ```
      
      ```{=latex}
      \end{landscape}
      ```
      
      ## Nested {.unnumbered}
      
      Text of an unnumbered section.
      
      ```{=latex}
      \begin{landscape}
      ```
      
      # Wide
      
      ```{=latex}
      \begingroup
      
        \providecommand{\huxb}[2]{\arrayrulecolor[RGB]{#1}\global\arrayrulewidth=#2pt}
        \providecommand{\huxvb}[2]{\color[RGB]{#1}\vrule width #2pt}
        \providecommand{\huxtpad}[1]{\rule{0pt}{#1}}
        \providecommand{\huxbpad}[1]{\rule[-#1]{0pt}{#1}}
      \setlength{\tabcolsep}{0pt}
      {
      \setlength{\LTcapwidth}{\linewidth}
      \begin{longtable}[c]{l}
      \captionsetup{justification=centering,singlelinecheck=off}
      \caption{Wide}
       \tabularnewline
      
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont w}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endfirsthead
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} \textbf{{\fontsize{9pt}{10.8pt}\selectfont w}} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.4}}-}
      \arrayrulecolor{black}
      
      \endhead
      
      \multicolumn{1}{!{\huxvb{0, 0, 0}{0}}r!{\huxvb{0, 0, 0}{0}}}{\huxtpad{6pt + 1em}\raggedleft \hspace{6pt} {\fontsize{9pt}{10.8pt}\selectfont 1.0000} \hspace{6pt}\huxbpad{6pt}} \tabularnewline[-0.5pt]
      
      
      \hhline{>{\huxb{0, 0, 0}{0.8}}-}
      \arrayrulecolor{black}
      \end{longtable}
      }
      \endgroup
      ```
      
      ```{=latex}
      \end{landscape}
      ```
      
      # Results
      
      ## Check
      
      Checked.
      
      ```{=latex}
      \begin{pubflowerror}
      ```
      
      **Step 'fit' failed**\
      singular fit\
      Step 'table' was not run.
      
      ```{=latex}
      \end{pubflowerror}
      ```

# pub_markdown() / writes Markdown for Typst (snapshot)

    Code
      cat(markdown(doc, "typst"))
    Output
      ```{=typst}
      #pagebreak(weak: true)
      ```
      
      # Text
      
      **Note**
      
      Some **bold** text, $x^2$ and `#text(fill: rgb("#0083c0"))[`{=typst}todo`]`{=typst}.
      
      &lt;b>not bold&lt;/b> and `x`\{=latex}
      
      See `#ref(<ab>)`{=typst} and `#ref(<points>)`{=typst}, not `@fig:points`.
      
      $$
      \frac{a}{b}
      $$
      
      ```{=typst}
      #pagebreak(weak: true)
      ```
      
      ```{=typst}
      #outline(depth: 2)
      ```
      
      ![Widget](<doc_files/figure-1.png>){width=5.67in}
      
      ```{=typst}
      #pagebreak(weak: true)
      ```
      
      # Tables
      
      ```{=typst}
      #[
      #show figure: set block(breakable: true)
      #show table.cell: set table.cell(breakable: false)
      #figure(
      table(
        columns: (auto, auto),
        stroke: none,
        table.header(
          table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(weight: "bold", size: 9pt)[a]], table.cell(align: (left + top), stroke: (top: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(weight: "bold", size: 9pt)[b]]
        ),
        table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[1\.3]], table.cell(align: (left + top), stroke: (top: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[x]],
        table.cell(align: (right + top), stroke: (bottom: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[]], table.cell(align: (left + top), stroke: (bottom: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[\<y\>]]
      ),
      caption: [A & B]
      ) <ab>
      ]
      ```
      
      **Unlocked**
      
      ```{=typst}
      #[
      #set figure(numbering: none)
      #[
      #show figure: set block(breakable: true)
      #show table.cell: set table.cell(breakable: false)
      #figure(
      table(
        columns: (auto),
        stroke: none,
        table.header(
          table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(weight: "bold", size: 9pt)[z]]
        ),
        table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[1]]
      ),
      caption: none
      )
      ]
      ]
      ```
      
      ```{=typst}
      #pagebreak(weak: true)
      ```
      
      # Figures {.unnumbered}
      
      ![Points](<doc_files/figure-2.png>){#points width=3.15in}
      
      ```{=typst}
      #set page(flipped: true)
      ```
      
      ```{=typst}
      #align(center)[
      ```
      
      ![](<doc_files/figure-3.png>){width=5.52in}
      
      ```{=typst}
      ]
      ```
      
      ```{=typst}
      #set page(flipped: false)
      ```
      
      ## Nested {.unnumbered}
      
      Text of an unnumbered section.
      
      ```{=typst}
      #set page(flipped: true)
      ```
      
      # Wide
      
      ```{=typst}
      #[
      #show figure: set block(breakable: true)
      #show table.cell: set table.cell(breakable: false)
      #figure(
      table(
        columns: (auto),
        stroke: none,
        table.header(
          table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0))))[#text(weight: "bold", size: 9pt)[w]]
        ),
        table.cell(align: (right + top), stroke: (top: stroke(thickness: 0.4pt, paint: rgb(0, 0, 0)), bottom: stroke(thickness: 0.8pt, paint: rgb(0, 0, 0))))[#text(size: 9pt)[1\.0000]]
      ),
      caption: [Wide]
      )
      ]
      ```
      
      ```{=typst}
      #set page(flipped: false)
      ```
      
      # Results
      
      ## Check
      
      Checked.
      
      ```{=typst}
      #block(stroke: 0.75pt + rgb("#c00000"), inset: 6pt, width: 100%)[
      ```
      
      **Step 'fit' failed**\
      singular fit\
      Step 'table' was not run.
      
      ```{=typst}
      ]
      ```

