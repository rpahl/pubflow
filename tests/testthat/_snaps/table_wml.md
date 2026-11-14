# .huxtable_to_wml() / signals an error for other Markdown in cells

    Code
      .huxtable_to_wml(ht)
    Condition
      Error:
      ! Can't write table cell [1, 1] to Word: Markdown cells may only use strong, emphasis and strikethrough (found link).

# .huxtable_to_wml() / writes the XML of a small table

    Code
      cat(as.character(xml, options = "format"))
    Output
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tbl>
          <w:tblPr>
            <w:tblW w:w="0" w:type="auto"/>
            <w:jc w:val="center"/>
            <w:tblLayout w:type="autofit"/>
            <w:tblCellMar>
              <w:top w:w="0" w:type="dxa"/>
              <w:left w:w="0" w:type="dxa"/>
              <w:bottom w:w="0" w:type="dxa"/>
              <w:right w:w="0" w:type="dxa"/>
            </w:tblCellMar>
            <w:tblLook w:val="0000"/>
          </w:tblPr>
          <w:tblGrid>
            <w:gridCol w:w="4535"/>
            <w:gridCol w:w="4535"/>
          </w:tblGrid>
          <w:tr>
            <w:trPr>
              <w:cantSplit/>
              <w:tblHeader/>
            </w:trPr>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="center"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:b/>
                    <w:bCs/>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve"/>
                </w:r>
              </w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="center"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:b/>
                    <w:bCs/>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">Results</w:t>
                </w:r>
              </w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:trPr>
              <w:cantSplit/>
              <w:tblHeader/>
            </w:trPr>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="left"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:b/>
                    <w:bCs/>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">site</w:t>
                </w:r>
              </w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="right"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:b/>
                    <w:bCs/>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">value</w:t>
                </w:r>
              </w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:trPr>
              <w:cantSplit/>
            </w:trPr>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="left"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">A</w:t>
                </w:r>
              </w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:top w:val="single" w:sz="3" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="right"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">1.5</w:t>
                </w:r>
              </w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:trPr>
              <w:cantSplit/>
            </w:trPr>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="left"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">B</w:t>
                </w:r>
              </w:p>
            </w:tc>
            <w:tc>
              <w:tcPr>
                <w:tcW w:w="0" w:type="auto"/>
                <w:tcBorders>
                  <w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/>
                </w:tcBorders>
                <w:tcMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tcMar>
                <w:vAlign w:val="top"/>
              </w:tcPr>
              <w:p>
                <w:pPr>
                  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
                  <w:jc w:val="right"/>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                </w:pPr>
                <w:r>
                  <w:rPr>
                    <w:sz w:val="18"/>
                    <w:szCs w:val="18"/>
                  </w:rPr>
                  <w:t xml:space="preserve">-</w:t>
                </w:r>
              </w:p>
            </w:tc>
          </w:tr>
        </w:tbl>
      </w:document>

