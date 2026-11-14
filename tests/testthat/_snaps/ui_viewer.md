# pub_viewer_ui() / has a table of contents and a document output (snapshot)

    Code
      cat(as.character(pub_viewer_ui("viewer")))
    Output
      <div id="viewer-viewer" class="pubflow-viewer">
        <aside class="pubflow-viewer-toc" aria-label="Table of contents">
          <div id="viewer-toc" class="shiny-html-output"></div>
        </aside>
        <div class="pubflow-viewer-content">
          <div class="pubflow-viewer-status" role="status" aria-live="polite"></div>
          <div class="shiny-html-output pubflow-viewer-doc" id="viewer-doc"></div>
        </div>
      </div>

---

    Code
      cat(as.character(pub_viewer_ui("viewer", toc = FALSE, height = "600px")))
    Output
      <div id="viewer-viewer" class="pubflow-viewer pubflow-viewer-fixed" style="height: 600px;">
        <div class="pubflow-viewer-content" role="region" aria-label="Document" tabindex="0">
          <div class="pubflow-viewer-status" role="status" aria-live="polite"></div>
          <div class="shiny-html-output pubflow-viewer-doc" id="viewer-doc"></div>
        </div>
      </div>

