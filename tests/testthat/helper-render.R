# Helpers of the render tests.

# Render settings of a target with the default report spec of its format.
default_settings <- function(target) {
    .render_settings(pub_report_spec(.target_format(target)), target)
}
