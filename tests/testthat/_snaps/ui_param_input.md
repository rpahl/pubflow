# UI snapshots / renders the parameter table with Bootstrap 3

    Code
      cat(as.character(rendered$html))
    Output
      <div class="container-fluid">
        <div class="pubflow-params-table">
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">Other</legend>
            <table class="pubflow-params-rows">
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-factor_single" title="Factor parameter (single select)">Factor parameter (single select)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Factor parameter (single select)">
                    <label class="control-label shiny-label-null" for="params-factor_single" id="params-factor_single-label"></label>
                    <div>
                      <select id="params-factor_single" class="shiny-input-select"><option value="log2" selected>log2</option>
      <option value="log10">log10</option>
      <option value="identity">identity</option>
      <option value="don&#39;t select me">don't select me</option></select>
                      <script type="application/json" data-for="params-factor_single" data-nonempty="">{"plugins":["selectize-plugin-a11y"]}</script>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-factor_multi" title="Factor parameter (multi-select)">Factor parameter (multi-select)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Factor parameter (multi-select)">
                    <label class="control-label shiny-label-null" for="params-factor_multi" id="params-factor_multi-label"></label>
                    <div>
                      <select id="params-factor_multi" class="shiny-input-select" multiple="multiple"><option value="brief">brief</option>
      <option value="detailed">detailed</option>
      <option value="standard" selected>standard</option></select>
                      <script type="application/json" data-for="params-factor_multi">{"plugins":["selectize-plugin-a11y"]}</script>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-group-param-label" title="Group of parameters">Group of parameters</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-group-param-label">
                    <div class="pubflow-param-group" style="width:15ch;">
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_lower">Lower bound</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Lower bound">
                          <label class="control-label shiny-label-null" for="params-group_lower" id="params-group_lower-label"></label>
                          <input id="params-group_lower" type="text" class="shiny-input-text form-control" value="0.80" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_upper">Upper bound</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Upper bound">
                          <label class="control-label shiny-label-null" for="params-group_upper" id="params-group_upper-label"></label>
                          <input id="params-group_upper" type="text" class="shiny-input-text form-control" value="1.25" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_use">Use</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Use">
                          <div class="pretty p-default p-switch">
                            <input id="params-group_use" type="checkbox" checked="checked"/>
                            <div class="state p-info">
                              <label>
                                <span></span>
                              </label>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-num" title="Numeric parameter">Numeric parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Input for numeric parameter">
                    <label class="control-label shiny-label-null" for="params-num" id="params-num-label"></label>
                    <input id="params-num" type="number" class="shiny-input-number form-control" value="0.05" data-update-on="blur" min="0" max="1" step="0.01"/>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-num_slider" title="Numeric parameter (slider widget)">Numeric parameter (slider widget)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <style>#params-num_slider {font-size: 12px; height: 40px;}</style>
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Input for numeric parameter with slider UI">
                    <label class="control-label shiny-label-null" for="params-num_slider" id="params-num_slider-label"></label>
                    <input class="js-range-slider" id="params-num_slider" data-skin="shiny" data-min="1" data-max="8" data-from="5" data-step="1" data-grid="false" data-grid-snap="false" data-prettify-separator="," data-prettify-enabled="true" data-keyboard="true" data-data-type="number"/>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-on_off-param-label" title="On/Off parameter">On/Off parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-on_off-param-label">
                    <div class="form-group shiny-input-container shiny-input-radiogroup shiny-input-container-inline pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Binary On/Off parameter">
                      <label class="control-label shiny-label-null" for="params-on_off" id="params-on_off-label"></label>
                      <div id="params-on_off" class="radio-group-buttons">
                        <div aria-labelledby="params-on_off-label" class="btn-group btn-group-xs btn-group-container-sw" data-toggle="buttons" role="group">
                          <div class="btn-group btn-group-toggle btn-group-xs" role="group">
                            <button class="btn radiobtn btn-default">
                              <input type="radio" autocomplete="off" name="params-on_off" value="on"/>
                              on
                            </button>
                          </div>
                          <div class="btn-group btn-group-toggle btn-group-xs" role="group">
                            <button class="btn radiobtn btn-default active">
                              <input type="radio" autocomplete="off" name="params-on_off" value="off" checked="checked"/>
                              off
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-switch" title="TRUE/FALSE switch">TRUE/FALSE switch</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Boolean TRUE/FALSE switch">
                    <div class="pretty p-default p-switch">
                      <input id="params-switch" type="checkbox"/>
                      <div class="state p-info">
                        <label>
                          <span></span>
                        </label>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-txt" title="Text parameter">Text parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Text parameter">
                    <label class="control-label shiny-label-null" for="params-txt" id="params-txt-label"></label>
                    <input id="params-txt" type="text" class="shiny-input-text form-control" value="Theoretical Concentration" data-update-on="blur"/>
                  </div>
                </td>
              </tr>
            </table>
          </fieldset>
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">criteria</legend>
            <table class="pubflow-params-rows">
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-limits-param-label" title="Specification limits">Specification limits</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-limits-param-label">
                    <div class="pubflow-param-group" style="width:15ch;">
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-limits_lower">LSL</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="LSL">
                          <label class="control-label shiny-label-null" for="params-limits_lower" id="params-limits_lower-label"></label>
                          <input id="params-limits_lower" type="text" class="shiny-input-text form-control" value="95" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-limits_upper">USL</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="USL">
                          <label class="control-label shiny-label-null" for="params-limits_upper" id="params-limits_upper-label"></label>
                          <input id="params-limits_upper" type="text" class="shiny-input-text form-control" value="105" data-update-on="blur"/>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </table>
          </fieldset>
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">extra</legend>
            <details class="pubflow-params-advanced">
              <summary>Advanced</summary>
              <table class="pubflow-params-rows">
                <tr class="pubflow-param-row">
                  <td class="pubflow-param-label-cell">
                    <label class="pubflow-param-label" for="params-area" title="With area">With area</label>
                  </td>
                  <td class="pubflow-param-input-cell">
                    <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="With area">
                      <label class="control-label shiny-label-null" for="params-area" id="params-area-label"></label>
                      <input id="params-area" type="text" class="shiny-input-text form-control" value="a" data-update-on="blur"/>
                    </div>
                  </td>
                </tr>
              </table>
            </details>
          </fieldset>
        </div>
      </div>

# UI snapshots / renders the parameter table with Bootstrap 5

    Code
      cat(as.character(rendered$html))
    Output
      <div class="container-fluid">
        <div class="pubflow-params-table">
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">Other</legend>
            <table class="pubflow-params-rows">
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-factor_single" title="Factor parameter (single select)">Factor parameter (single select)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Factor parameter (single select)">
                    <label class="control-label shiny-label-null" for="params-factor_single" id="params-factor_single-label"></label>
                    <div>
                      <select id="params-factor_single" class="shiny-input-select"><option value="log2" selected>log2</option>
      <option value="log10">log10</option>
      <option value="identity">identity</option>
      <option value="don&#39;t select me">don't select me</option></select>
                      <script type="application/json" data-for="params-factor_single" data-nonempty="">{"plugins":["selectize-plugin-a11y"]}</script>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-factor_multi" title="Factor parameter (multi-select)">Factor parameter (multi-select)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Factor parameter (multi-select)">
                    <label class="control-label shiny-label-null" for="params-factor_multi" id="params-factor_multi-label"></label>
                    <div>
                      <select id="params-factor_multi" class="shiny-input-select" multiple="multiple"><option value="brief">brief</option>
      <option value="detailed">detailed</option>
      <option value="standard" selected>standard</option></select>
                      <script type="application/json" data-for="params-factor_multi">{"plugins":["selectize-plugin-a11y"]}</script>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-group-param-label" title="Group of parameters">Group of parameters</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-group-param-label">
                    <div class="pubflow-param-group" style="width:15ch;">
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_lower">Lower bound</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Lower bound">
                          <label class="control-label shiny-label-null" for="params-group_lower" id="params-group_lower-label"></label>
                          <input id="params-group_lower" type="text" class="shiny-input-text form-control" value="0.80" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_upper">Upper bound</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Upper bound">
                          <label class="control-label shiny-label-null" for="params-group_upper" id="params-group_upper-label"></label>
                          <input id="params-group_upper" type="text" class="shiny-input-text form-control" value="1.25" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-group_use">Use</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="Use">
                          <div class="pretty p-default p-switch">
                            <input id="params-group_use" type="checkbox" checked="checked"/>
                            <div class="state p-info">
                              <label>
                                <span></span>
                              </label>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-num" title="Numeric parameter">Numeric parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Input for numeric parameter">
                    <label class="control-label shiny-label-null" for="params-num" id="params-num-label"></label>
                    <input id="params-num" type="number" class="shiny-input-number form-control" value="0.05" data-update-on="blur" min="0" max="1" step="0.01"/>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-num_slider" title="Numeric parameter (slider widget)">Numeric parameter (slider widget)</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <style>#params-num_slider {font-size: 12px; height: 40px;}</style>
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Input for numeric parameter with slider UI">
                    <label class="control-label shiny-label-null" for="params-num_slider" id="params-num_slider-label"></label>
                    <input class="js-range-slider" id="params-num_slider" data-skin="shiny" data-min="1" data-max="8" data-from="5" data-step="1" data-grid="false" data-grid-snap="false" data-prettify-separator="," data-prettify-enabled="true" data-keyboard="true" data-data-type="number"/>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-on_off-param-label" title="On/Off parameter">On/Off parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-on_off-param-label">
                    <div class="form-group shiny-input-container shiny-input-radiogroup shiny-input-container-inline pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Binary On/Off parameter">
                      <label class="control-label shiny-label-null" for="params-on_off" id="params-on_off-label"></label>
                      <div id="params-on_off" class="radio-group-buttons">
                        <div aria-labelledby="params-on_off-label" class="btn-group btn-group-xs btn-group-container-sw" data-toggle="buttons" role="group">
                          <div class="btn-group btn-group-toggle btn-group-xs" role="group">
                            <button class="btn radiobtn btn-default">
                              <input type="radio" autocomplete="off" name="params-on_off" value="on"/>
                              on
                            </button>
                          </div>
                          <div class="btn-group btn-group-toggle btn-group-xs" role="group">
                            <button class="btn radiobtn btn-default active">
                              <input type="radio" autocomplete="off" name="params-on_off" value="off" checked="checked"/>
                              off
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-switch" title="TRUE/FALSE switch">TRUE/FALSE switch</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Boolean TRUE/FALSE switch">
                    <div class="pretty p-default p-switch">
                      <input id="params-switch" type="checkbox"/>
                      <div class="state p-info">
                        <label>
                          <span></span>
                        </label>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" for="params-txt" title="Text parameter">Text parameter</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="Text parameter">
                    <label class="control-label shiny-label-null" for="params-txt" id="params-txt-label"></label>
                    <input id="params-txt" type="text" class="shiny-input-text form-control" value="Theoretical Concentration" data-update-on="blur"/>
                  </div>
                </td>
              </tr>
            </table>
          </fieldset>
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">criteria</legend>
            <table class="pubflow-params-rows">
              <tr class="pubflow-param-row">
                <td class="pubflow-param-label-cell">
                  <label class="pubflow-param-label" id="params-limits-param-label" title="Specification limits">Specification limits</label>
                </td>
                <td class="pubflow-param-input-cell">
                  <div role="group" aria-labelledby="params-limits-param-label">
                    <div class="pubflow-param-group" style="width:15ch;">
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-limits_lower">LSL</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="LSL">
                          <label class="control-label shiny-label-null" for="params-limits_lower" id="params-limits_lower-label"></label>
                          <input id="params-limits_lower" type="text" class="shiny-input-text form-control" value="95" data-update-on="blur"/>
                        </div>
                      </div>
                      <div class="pubflow-param-item">
                        <label class="pubflow-visually-hidden" for="params-limits_upper">USL</label>
                        <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:100%;" title="USL">
                          <label class="control-label shiny-label-null" for="params-limits_upper" id="params-limits_upper-label"></label>
                          <input id="params-limits_upper" type="text" class="shiny-input-text form-control" value="105" data-update-on="blur"/>
                        </div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </table>
          </fieldset>
          <fieldset class="pubflow-params-section">
            <legend class="pubflow-params-heading">extra</legend>
            <details class="pubflow-params-advanced">
              <summary>Advanced</summary>
              <table class="pubflow-params-rows">
                <tr class="pubflow-param-row">
                  <td class="pubflow-param-label-cell">
                    <label class="pubflow-param-label" for="params-area" title="With area">With area</label>
                  </td>
                  <td class="pubflow-param-input-cell">
                    <div class="form-group shiny-input-container pubflow-tooltip" data-bs-container="body" data-bs-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-bs-toggle="tooltip" data-bs-trigger="hover" data-container="body" data-delay="{&quot;show&quot;:1500,&quot;hide&quot;:100}" data-pubflow-tooltip-autohide-ms="7000" data-toggle="tooltip" data-trigger="hover" style="width:15ch;" title="With area">
                      <label class="control-label shiny-label-null" for="params-area" id="params-area-label"></label>
                      <input id="params-area" type="text" class="shiny-input-text form-control" value="a" data-update-on="blur"/>
                    </div>
                  </td>
                </tr>
              </table>
            </details>
          </fieldset>
        </div>
      </div>

