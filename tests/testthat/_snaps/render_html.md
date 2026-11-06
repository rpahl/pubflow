# pub_html() / renders every node type (snapshot)

    Code
      cat(without_images(html))
    Output
      <div class="pubflow-doc">
      <header class="pubflow-doc-header">
      <h1 class="pubflow-title">Every node</h1>
      <p class="pubflow-subtitle">Subtitle &amp; more</p>
      <p class="pubflow-doc-meta">A. User &middot; 2026-10-05 12:00:00 UTC &middot; tests 1.0</p>
      </header>
      <nav class="pubflow-toc">
      <ul>
      <li><a href="#pubflow-sec-1"><span class="pubflow-section-number">1</span> Text</a>
      </li>
      <li><a href="#pubflow-sec-2"><span class="pubflow-section-number">2</span> Tables</a>
      </li>
      <li><a href="#pubflow-sec-3">Figures</a>
      <ul>
      <li><a href="#pubflow-sec-3-1">Nested</a>
      </li>
      </ul></li>
      <li><a href="#pubflow-sec-4"><span class="pubflow-section-number">3</span> Results</a>
      <ul>
      <li><a href="#pubflow-sec-4-1"><span class="pubflow-section-number">3.1</span> Fit</a>
      </li>
      <li><a href="#pubflow-sec-4-2"><span class="pubflow-section-number">3.2</span> Check</a>
      </li>
      </ul></li>
      </ul>
      </nav>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-1">
      <h2><span class="pubflow-section-number">1</span> Text</h2>
      <div class="pubflow-item pubflow-text">
      <div class="pubflow-item-title">Note</div>
      <p>Some <strong>bold</strong> text, <span class="pubflow-math">\(x^2\)</span> and
      <span class="pubflow-placeholder">todo</span>.</p>
      <p>&lt;b&gt;not bold&lt;/b&gt;</p>
      </div>
      <div class="pubflow-item pubflow-raw">
      <hr class="custom">
      </div>
      <div class="pubflow-item pubflow-toc">
      <nav class="pubflow-toc">
      <ul>
      <li><a href="#pubflow-sec-1"><span class="pubflow-section-number">1</span> Text</a>
      </li>
      <li><a href="#pubflow-sec-2"><span class="pubflow-section-number">2</span> Tables</a>
      </li>
      <li><a href="#pubflow-sec-3">Figures</a>
      </li>
      <li><a href="#pubflow-sec-4"><span class="pubflow-section-number">3</span> Results</a>
      </li>
      </ul>
      </nav>
      </div>
      <div class="pubflow-item pubflow-widget">
      <div class="fake-widget"></div>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-2">
      <h2><span class="pubflow-section-number">2</span> Tables</h2>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 1: A &amp; B</caption>
      <col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">a</th><th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">b</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">1.3</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">x</td></tr>
      <tr>
      <td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"></td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">&lt;y&gt;</td></tr>
      </tbody>
      </table>
      </div>
      <div class="pubflow-item pubflow-table">
      <div class="pubflow-item-title">No caption</div>
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">z</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.8pt 0pt;         font-size: 9pt;">1</td></tr>
      </tbody>
      </table>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-3">
      <h2>Figures</h2>
      <div class="pubflow-item pubflow-figure" id="pubflow-figure-fig-points">
      <figure>
      <img src="data:image/png;..." alt="Points" style="width: 50%;">
      <figcaption>Figure 1: Points</figcaption>
      </figure>
      </div>
      <div class="pubflow-item pubflow-figure">
      <figure>
      <img src="data:image/png;..." alt="Figure" style="width: 90%;">
      </figure>
      </div>
      <section class="pubflow-section pubflow-level-2" id="pubflow-sec-3-1">
      <h3>Nested</h3>
      <div class="pubflow-item pubflow-text">
      <p>Text of an unnumbered section.</p>
      </div>
      </section>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-4">
      <h2><span class="pubflow-section-number">3</span> Results</h2>
      <section class="pubflow-section pubflow-level-2" id="pubflow-sec-4-1">
      <h3><span class="pubflow-section-number">3.1</span> Fit</h3>
      <div class="pubflow-item pubflow-figure">
      <figure>
      <img src="data:image/png;..." alt="Fit" style="width: 90%;">
      <figcaption>Figure 2: Fit</figcaption>
      </figure>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-2" id="pubflow-sec-4-2">
      <h3><span class="pubflow-section-number">3.2</span> Check</h3>
      <div class="pubflow-item pubflow-error">
      <div class="pubflow-error-title">Step 'fit' failed</div>
      <div class="pubflow-error-message">singular fit</div>
      <div class="pubflow-error-detail">Step 'table' was not run.</div>
      </div>
      </section>
      </section>
      </div>

# pub_html() of the fixture documents / renders the report document (snapshot)

    Code
      cat(without_images(pub_html(demo_report_doc())))
    Output
      <div class="pubflow-doc">
      <header class="pubflow-doc-header">
      <h1 class="pubflow-title">Quality demo</h1>
      <p class="pubflow-subtitle">Built by the layout step of demo_report_pipeline()</p>
      <p class="pubflow-doc-meta">Demo user &middot; pubflow tests 0.0.0</p>
      </header>
      <nav class="pubflow-toc">
      <ul>
      <li><a href="#pubflow-sec-1">Introduction</a>
      </li>
      <li><a href="#pubflow-sec-2"><span class="pubflow-section-number">1</span> Data</a>
      </li>
      <li><a href="#pubflow-sec-3"><span class="pubflow-section-number">2</span> Analysis</a>
      <ul>
      <li><a href="#pubflow-sec-3-1"><span class="pubflow-section-number">2.1</span> Fit</a>
      </li>
      <li><a href="#pubflow-sec-3-2"><span class="pubflow-section-number">2.2</span> Conclusion</a>
      </li>
      </ul></li>
      <li><a href="#pubflow-sec-4"><span class="pubflow-section-number">3</span> Criteria</a>
      </li>
      <li><a href="#pubflow-sec-5"><span class="pubflow-section-number">4</span> Summary</a>
      </li>
      <li><a href="#pubflow-sec-6"><span class="pubflow-section-number">5</span> Notes</a>
      </li>
      </ul>
      </nav>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-1">
      <h2>Introduction</h2>
      <div class="pubflow-item pubflow-text">
      <p>Quality of three batches (<span class="pubflow-placeholder">demo</span>).</p>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-2">
      <h2><span class="pubflow-section-number">1</span> Data</h2>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 1: Data table</caption>
      <col><col><col><col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" colspan="4" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Time [months]</th></tr>
      <tr>
      <th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Batch¹</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">0</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">3</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">6</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">12</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">A</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">100.00</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">99.10</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">98.40</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(255, 0, 0);">96.90</span></td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">B</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">100.40</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">99.80</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">98.70</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;"><span style="color: rgb(255, 0, 0);">97.50</span></td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">C</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">99.60</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(0, 0, 0);">98.90</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(255, 0, 0);">97.80</span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(255, 0, 0);">96.20</span></td></tr>
      <tr>
      <td class="huxtable-cell" colspan="5" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;">¹ Batches of the demo study.</td></tr>
      </tbody>
      </table>
      </div>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 2: Predicted values at 12 months</caption>
      <col><col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">batch</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">predicted</th><th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">pass</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">A</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">96.8771</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">TRUE</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">B</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">97.4286</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">TRUE</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">C</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">96.1771</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">TRUE</td></tr>
      </tbody>
      </table>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-3">
      <h2><span class="pubflow-section-number">2</span> Analysis</h2>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 3: Fit summary</caption>
      <col><col><col><col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" colspan="2" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Confidence interval</th></tr>
      <tr>
      <th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Batch</th><th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Parameter</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Estimate</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">Lower</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">Upper</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">A</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">99.94</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.26</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.29</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.22</td></tr>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">B</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">100.40</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.25</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.34</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.16</td></tr>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">C</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">99.64</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.29</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">-0.35</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">-0.23</td></tr>
      </tbody>
      </table>
      </div>
      <div class="pubflow-item pubflow-figure">
      <figure>
      <img src="data:image/png;..." alt="Assay over time" style="width: 90%;">
      <figcaption>Figure 1: Assay over time</figcaption>
      </figure>
      </div>
      <section class="pubflow-section pubflow-level-2" id="pubflow-sec-3-1">
      <h3><span class="pubflow-section-number">2.1</span> Fit</h3>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 4: Fit summary</caption>
      <col><col><col><col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0pt 0pt;         font-size: 9pt;"></th><th class="huxtable-cell huxtable-header" colspan="2" style="text-align: center;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Confidence interval</th></tr>
      <tr>
      <th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Batch</th><th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Parameter</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.4pt 0pt;         font-size: 9pt;">Estimate</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">Lower</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0.4pt 0pt;         font-size: 9pt;">Upper</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">A</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">99.94</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.26</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.29</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.22</td></tr>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">B</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">100.40</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.25</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.34</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-0.16</td></tr>
      <tr>
      <td class="huxtable-cell" rowspan="2" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">C</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Intercept</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">99.64</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">-</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">Slope</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;      font-weight: bold;   font-size: 9pt;">-0.29</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">-0.35</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;">-0.23</td></tr>
      </tbody>
      </table>
      </div>
      <div class="pubflow-item pubflow-figure">
      <figure>
      <img src="data:image/png;..." alt="Assay over time" style="width: 90%;">
      <figcaption>Figure 2: Assay over time</figcaption>
      </figure>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-2" id="pubflow-sec-3-2">
      <h3><span class="pubflow-section-number">2.2</span> Conclusion</h3>
      <div class="pubflow-item pubflow-text">
      <div class="pubflow-item-title">Conclusion</div>
      <p><strong>Quality demo</strong>: 3 batches analysed.</p>
      <ul>
      <li>steepest slope: <em>-0.289</em></li>
      <li>flattest slope: <em>-0.248</em></li>
      </ul>
      <p>Model: <span class="pubflow-math">\(y = a + b \cdot t\)</span>. See <span class="pubflow-placeholder">&lt;insert link&gt;</span>.</p>
      </div>
      </section>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-4">
      <h2><span class="pubflow-section-number">3</span> Criteria</h2>
      <div class="pubflow-item pubflow-table">
      <table class="huxtable" data-quarto-disable-processing="true"  style="margin-left: auto; margin-right: auto;   break-inside: avoid; page-break-inside: avoid;">
      <caption>Table 5: Acceptance criteria</caption>
      <col><col><col><thead>
      <tr>
      <th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Criterion</th><th class="huxtable-cell huxtable-header" style="border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Limit</th><th class="huxtable-cell huxtable-header" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.8pt 0pt 0.4pt 0pt;         font-size: 9pt;">Batches passing</th></tr>
      </thead>
      <tbody>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">Prediction &gt;= LSL</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">95</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0.4pt 0pt 0pt 0pt;         font-size: 9pt;">3</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">Prediction &lt;= USL</td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">105</td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0pt 0pt;         font-size: 9pt;">3</td></tr>
      <tr>
      <td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(211, 200, 200);"><p><del>Slope below zero</del></p>
      </span></td><td class="huxtable-cell" style="border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(211, 200, 200);"><p><del>0</del></p>
      </span></td><td class="huxtable-cell" style="text-align: right;  border-style: solid solid solid solid; border-width: 0pt 0pt 0.8pt 0pt;         font-size: 9pt;"><span style="color: rgb(211, 200, 200);"><p><del>-</del></p>
      </span></td></tr>
      </tbody>
      </table>
      </div>
      <div class="pubflow-item pubflow-text">
      <p>All batches meet the limits.</p>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-5">
      <h2><span class="pubflow-section-number">4</span> Summary</h2>
      <div class="pubflow-item pubflow-text">
      <p>Quality demo: 3 batches analysed.</p>
      </div>
      <div class="pubflow-item pubflow-text">
      <div class="pubflow-item-title">Conclusion</div>
      <p><strong>Quality demo</strong>: 3 batches analysed.</p>
      <ul>
      <li>steepest slope: <em>-0.289</em></li>
      <li>flattest slope: <em>-0.248</em></li>
      </ul>
      <p>Model: <span class="pubflow-math">\(y = a + b \cdot t\)</span>. See <span class="pubflow-placeholder">&lt;insert link&gt;</span>.</p>
      </div>
      </section>
      <section class="pubflow-section pubflow-level-1" id="pubflow-sec-6">
      <h2><span class="pubflow-section-number">5</span> Notes</h2>
      </section>
      </div>

