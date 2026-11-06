# Shared pipeline fixtures, built with pipeflow + pubflow:
# - demo_pipeline(): config with all param types and a param_group with a cross-field
#   rule (lower < upper), tags, a step using `.self` (setting the derived param `xlab`
#   via `pipeflow::pip_set_params(.self, ...)`), a step that fails on request
#   (`failCheck = "yes"`), and a step whose plain default (`yUnit` of step 'data')
#   shadows the param of a later step ('plot');
# - demo_combined_pipeline(): rbind() of two pipelines with own configs, merged config
#   applied afterwards (without it, `apply_config = FALSE`, it warns
#   `pipeflow_param_conflict`);
# - demo_split_pipeline(): split/reduce exec modes;
# - demo_nested_pipeline(): nested pipeline (sub-pipeline factory demo_inner_pipeline()
#   with its own config; the outer step is the inner pipeline as a function
#   (as.function()), mapped over the batches, so the inner params are params of the
#   outer pipeline; a combination step);
# - demo_report_pipeline(): demo_pipeline() plus steps producing styled tables
#   (coloured, merged, spanner, footnote, struck-through rows), a figure, Markdown text
#   and a named list of outputs, and a layout step "doc" returning a document; "doc" is
#   a layout step that takes failures: with `failCheck = "yes"` step 'check' fails, so
#   'check_text' (placed in section "Criteria") is not run;
# - demo_split_report_pipeline(), demo_inner_report_pipeline(),
#   demo_nested_report_pipeline(), demo_test_pipelines(): the split and nested pipelines
#   with displayable outputs per partition or inner pipeline and layout steps, and one
#   pipeline per test; the table step of the split report fails for the batch
#   `failBatch`;
# - demo_tests_report_pipeline(): a report pipeline over the test pipelines (fed with
#   demo_test_parts());
# - the documents of these pipelines (run): demo_report_doc(), demo_split_doc(),
#   demo_nested_doc(), demo_tests_doc(), demo_tests_report_doc(); with failures (run
#   with `on_error = "continue"`): demo_failed_report_doc().

demo_data <- function() {
    data.frame(
        batch = rep(c("A", "B", "C"), each = 4L),
        time = rep(c(0, 3, 6, 12), times = 3L),
        y = c(
            100.0,
            99.1,
            98.4,
            96.9,
            100.4,
            99.8,
            98.7,
            97.5,
            99.6,
            98.9,
            97.8,
            96.2
        )
    )
}

demo_trans_choices <- c("none", "log", "sqrt")

demo_trans <- function(x, trans) {
    switch(
        as.character(trans),
        none = x,
        log = log(x + 1),
        sqrt = sqrt(x)
    )
}

# Slope of y over transformed time per batch, with confidence limits
demo_fit <- function(data, xTrans, alpha) {
    fits <- lapply(split(data, data$batch), \(d) {
        d$x <- demo_trans(d$time, xTrans)
        fit <- stats::lm(y ~ x, data = d)
        ci <- stats::confint(fit, level = 1 - alpha)
        data.frame(
            batch = d$batch[[1L]],
            intercept = stats::coef(fit)[["(Intercept)"]],
            slope = stats::coef(fit)[["x"]],
            lower = ci["x", 1L],
            upper = ci["x", 2L]
        )
    })
    do.call(rbind, unname(fits))
}

ensure_lower_lt_upper <- function(x) {
    lower <- suppressWarnings(as.numeric(x$lower))
    upper <- suppressWarnings(as.numeric(x$upper))
    if (isTRUE(lower < upper)) "" else "lower limit must be below upper limit"
}

demo_limits_param <- function() {
    param_group(
        list(
            lower = numeral_param("95", label = "LSL"),
            upper = numeral_param("105", label = "USL")
        ),
        label = "Specification limits",
        source = "user",
        area = "criteria"
    ) |>
        add_validity(ensure_lower_lt_upper)
}

demo_config <- function() {
    param_config(
        title = param(
            "Quality demo",
            label = "Report title",
            source = "user",
            area = "report"
        ),
        alpha = numeric_param(
            0.05,
            label = "Significance level",
            min = 0,
            max = 0.5,
            source = "user",
            area = "analysis"
        ),
        xTrans = choice_param(
            "none",
            choices = demo_trans_choices,
            label = "x transformation",
            source = "user",
            area = "analysis"
        ),
        exclude = param(
            FALSE,
            label = "Exclude the first time point?",
            source = "user",
            area = "analysis"
        ),
        decimals = numeral_param(
            "2",
            label = "Decimal places",
            min = 0,
            max = 6,
            source = "user",
            area = "report"
        ),
        limits = demo_limits_param(),
        ylab = param(
            "Assay",
            label = "y-axis label",
            source = "user",
            area = "plot"
        ),
        yUnit = param("%", label = "Unit of y", source = "user", area = "plot"),
        showPoints = choice_param(
            "yes",
            c("yes", "no"),
            label = "Show data points?",
            source = "user",
            area = "plot"
        ),
        smooth = choice_param(
            "off",
            c("on", "off"),
            label = "Smoother",
            source = "user",
            area = "plot",
            advanced = TRUE,
            ui_widget = "radio",
            ui_args = list(size = "xs")
        ),
        xlab = param("Time", label = "x-axis label", source = "internal"),
        failCheck = choice_param(
            "no",
            c("yes", "no"),
            label = "Let the check step fail?",
            source = "internal"
        )
    )
}

demo_pipeline <- function(name = "demo") {
    pip <- pipeflow::pip_new(name) |>
        pipeflow::pip_add(
            "data",
            \(data = demo_data(), yUnit = "", exclude = FALSE) {
                stopifnot(is.character(yUnit))
                if (exclude) data[data$time > 0, ] else data
            },
            tags = "data"
        ) |>
        pipeflow::pip_add(
            "settings",
            \(
                xTrans = factor("none", demo_trans_choices)
            ) {
                xlab <- if (xTrans == "none") {
                    "Time"
                } else {
                    sprintf("%s(Time)", as.character(xTrans))
                }
                pip <- .self # nolint: object_usage_linter. (set by pipeflow)
                pipeflow::pip_set_params(pip, list(xlab = xlab))
                xlab
            },
            tags = "settings"
        ) |>
        pipeflow::pip_add(
            "fit",
            \(
                data = ~data,
                xTrans = factor("none", demo_trans_choices),
                alpha = 0.05
            ) {
                demo_fit(data, xTrans, alpha)
            },
            tags = "analysis"
        ) |>
        pipeflow::pip_add(
            "slope_table",
            \(fit = ~fit, decimals = "2", title = "") {
                d <- as.integer(decimals)
                pub_table(
                    fit,
                    caption = sprintf("%s: slopes", title),
                    digits = c(intercept = d, slope = d, lower = d, upper = d)
                )
            },
            tags = c("analysis", "report")
        ) |>
        pipeflow::pip_add(
            "limits_check",
            \(
                fit = ~fit,
                xTrans = factor("none", demo_trans_choices),
                limits = list(lower = "95", upper = "105")
            ) {
                predicted <- fit$intercept + fit$slope * demo_trans(12, xTrans)
                data.frame(
                    batch = fit$batch,
                    predicted = predicted,
                    pass = predicted >= as.numeric(limits$lower) &
                        predicted <= as.numeric(limits$upper)
                )
            },
            tags = c("analysis", "criteria")
        ) |>
        pipeflow::pip_add(
            "plot",
            \(
                data = ~data,
                xlab = "Time",
                ylab = "Assay",
                yUnit = "",
                showPoints = factor("yes", c("yes", "no")),
                smooth = factor("off", c("on", "off"))
            ) {
                list(
                    xlab = xlab,
                    ylab = if (nzchar(yUnit)) sprintf("%s [%s]", ylab, yUnit),
                    points = showPoints == "yes",
                    smooth = smooth == "on",
                    n = nrow(data)
                )
            },
            tags = c("report", "figure")
        ) |>
        pipeflow::pip_add(
            "summary",
            \(fit = ~fit, title = "") {
                sprintf("%s: %d batches analysed.", title, nrow(fit))
            },
            tags = "report"
        ) |>
        pipeflow::pip_add(
            "check",
            \(
                check = ~limits_check,
                failCheck = factor("no", c("yes", "no"))
            ) {
                if (failCheck == "yes") {
                    stop("check failed on request")
                }
                all(check$pass)
            },
            tags = "criteria"
        )

    # The unit is declared for step 'plot' only (`scope = "view"`), so the plain default
    # of step 'data' comes first.
    cfg <- demo_config()
    isUnit <- names(cfg) == "yUnit"
    pipeflow::pip_set_params(pip, cfg[!isUnit], unknown = "error")
    pipeflow::pip_set_params(
        pipeflow::pip_view(pip, step = "plot"),
        cfg[isUnit],
        unknown = "error",
        scope = "view"
    )
    pip
}

# Combined pipeline --------------------------------------------------------

demo_prep_config <- function() {
    param_config(
        yUnit = param("%", label = "Unit of y (data)", source = "data"),
        exclude = param(FALSE, label = "Exclude the first time point?")
    )
}

demo_stats_config <- function() {
    param_config(
        yUnit = param("mg", label = "Unit of y (stats)", source = "user"),
        alpha = numeric_param(0.05, label = "Alpha", min = 0, max = 0.5)
    )
}

demo_prep_pipeline <- function() {
    pip <- pipeflow::pip_new("prep") |>
        pipeflow::pip_add("data", \(data = demo_data(), yUnit = "") {
            stopifnot(is.character(yUnit))
            data
        }) |>
        pipeflow::pip_add("clean", \(data = ~data, exclude = FALSE) {
            if (exclude) data[data$time > 0, ] else data
        })
    pipeflow::pip_set_params(pip, demo_prep_config(), unknown = "error")
}

demo_stats_pipeline <- function() {
    pip <- pipeflow::pip_new("stats") |>
        pipeflow::pip_add("data", \(data = NULL) data) |>
        pipeflow::pip_add("fit", \(data = ~data, alpha = 0.05) {
            demo_fit(data, "none", alpha)
        }) |>
        pipeflow::pip_add("label", \(yUnit = "") sprintf("y [%s]", yUnit))
    pipeflow::pip_set_params(pip, demo_stats_config(), unknown = "error")
}

# rbind() renames the 'data' step of the stats pipeline to 'data2', which is then
# rewired to the output of 'clean'.
demo_combined_pipeline <- function(apply_config = TRUE) {
    # rbind() warns (class pipeflow_param_conflict) that 'yUnit' is "mg" in step 'label'
    # but "%" in step 'data', and that 'data' differs between 'data2' and 'data'; the
    # merged config settles 'yUnit' and 'data2' is replaced below, so only the pipeline
    # without the config keeps the warning (other conflicts pass through)
    combine <- \() rbind(demo_prep_pipeline(), demo_stats_pipeline())
    known <- \(w) all(w$conflicts$param %in% c("data", "yUnit"))
    full <- if (apply_config) {
        withCallingHandlers(
            combine(),
            pipeflow_param_conflict = \(w) {
                if (known(w)) tryInvokeRestart("muffleWarning")
            }
        )
    } else {
        combine()
    }
    pipeflow::pip_replace(full, "data2", \(data = ~clean) data)
    if (apply_config) {
        cfg <- param_config(
            demo_prep_config(),
            demo_stats_config(),
            .duplicates = "first"
        )
        pipeflow::pip_set_params(full, cfg, unknown = "error")
    }
    full
}

# Split/reduce pipeline ----------------------------------------------------

demo_split_config <- function() {
    param_config(
        byVar = param("batch", label = "Group column", source = "data"),
        xTrans = choice_param(
            "none",
            choices = demo_trans_choices,
            label = "x transformation"
        ),
        decimals = numeral_param("2", label = "Decimal places", min = 0)
    )
}

demo_split_pipeline <- function() {
    pip <- pipeflow::pip_new("split") |>
        pipeflow::pip_add("data", \(data = demo_data()) data) |>
        pipeflow::pip_add(
            "split_data",
            \(data = ~data, byVar = "batch") {
                split(data, data[[byVar]])
            },
            exec = "split"
        ) |>
        pipeflow::pip_add(
            "fit",
            \(
                data = ~split_data,
                xTrans = factor("none", demo_trans_choices)
            ) {
                data$x <- demo_trans(data$time, xTrans)
                stats::lm(y ~ x, data = data)
            }
        ) |>
        pipeflow::pip_add("coefs", \(fit = ~fit, decimals = "2") {
            pub_round(stats::coef(fit), as.integer(decimals))
        }) |>
        pipeflow::pip_add(
            "combine",
            \(coefs = ~coefs) {
                data.frame(batch = names(coefs), do.call(rbind, unname(coefs)))
            },
            exec = "reduce"
        )
    pipeflow::pip_set_params(pip, demo_split_config(), unknown = "error")
}

# Nested pipeline ----------------------------------------------------------------------

demo_inner_config <- function() {
    param_config(
        xTrans = choice_param(
            "none",
            choices = demo_trans_choices,
            label = "x transformation",
            source = "user"
        ),
        alpha = numeric_param(
            0.05,
            label = "Significance level",
            min = 0,
            max = 0.5,
            source = "user"
        ),
        decimals = numeral_param(
            "2",
            label = "Decimal places",
            min = 0,
            source = "user"
        )
    )
}

# Sub-pipeline factory: analysis of one batch
demo_inner_pipeline <- function(data = NULL, name = "inner") {
    pip <- pipeflow::pip_new(name) |>
        pipeflow::pip_add("data", \(data = NULL) data) |>
        pipeflow::pip_add(
            "settings",
            \(
                xTrans = factor("none", demo_trans_choices),
                alpha = 0.05
            ) {
                list(xTrans = xTrans, alpha = alpha)
            }
        ) |>
        pipeflow::pip_add(
            "fit",
            \(
                data = ~data,
                xTrans = factor("none", demo_trans_choices),
                alpha = 0.05
            ) {
                demo_fit(data, xTrans, alpha)
            }
        ) |>
        pipeflow::pip_add("coefs", \(fit = ~fit, decimals = "2") {
            d <- as.integer(decimals)
            c(slope = pub_round(fit$slope, d), lower = pub_round(fit$lower, d))
        })
    if (!is.null(data)) {
        pipeflow::pip_set_params(pip, list(data = data))
    }
    pipeflow::pip_set_params(pip, demo_inner_config(), unknown = "error")
}

demo_nested_config <- function() {
    param_config(
        byVar = param("batch", label = "Group column", source = "data"),
        demo_inner_config()
    )
}

# The inner pipeline as a function of the outer step 'inner_run', mapped over the
# batches: one inner pipeline per batch, whose outputs `out` it returns
demo_nested_pipeline <- function(
    inner = demo_inner_pipeline(),
    out = c("settings", "coefs")
) {
    pip <- pipeflow::pip_new("nested") |>
        pipeflow::pip_add("data", \(data = demo_data()) data) |>
        pipeflow::pip_add(
            "split_data",
            \(data = ~data, byVar = "batch") {
                split(data, data[[byVar]])
            },
            exec = "split"
        ) |>
        pipeflow::pip_add(
            "inner_run",
            as.function(inner, out = out),
            params = list(data = ~split_data)
        ) |>
        pipeflow::pip_add(
            "coef_table",
            \(res = ~inner_run) {
                coefs <- lapply(res, `[[`, "coefs")
                data.frame(batch = names(coefs), do.call(rbind, unname(coefs)))
            },
            exec = "reduce"
        )
    pipeflow::pip_set_params(pip, demo_nested_config(), unknown = "error")
}

# Report pipeline --------------------------------------------

# Wide data table: one row per batch, time points under a spanner, values below 98 in
# red (out-of-trend style), footnote on the batch column
demo_data_table <- function(data, decimals) {
    wide <- stats::reshape(
        data[c("batch", "time", "y")],
        idvar = "batch",
        timevar = "time",
        direction = "wide"
    )
    times <- as.character(sort(unique(data$time)))
    names(wide) <- c("batch", times)
    rownames(wide) <- NULL
    low <- as.matrix(wide[times]) < 98
    ht <- pub_table(
        wide,
        caption = "Data table",
        labels = c(batch = "Batch"),
        digits = rlang::set_names(rep(decimals, length(times)), times),
        header = rlang::set_names(rep("Time [months]", length(times)), times),
        footnotes = c(batch = "Batches of the demo study.")
    )
    rows <- sum(huxtable::header_rows(ht)) + seq_len(nrow(wide))
    huxtable::set_text_color(ht, rows, times, ifelse(low, "red", "black"))
}

# Fit summary: two rows per batch, merged batch column, bold slopes
demo_fit_table <- function(fit, decimals) {
    long <- data.frame(
        batch = rep(fit$batch, each = 2L),
        term = rep(c("Intercept", "Slope"), times = nrow(fit)),
        estimate = c(rbind(fit$intercept, fit$slope)),
        lower = c(rbind(NA, fit$lower)),
        upper = c(rbind(NA, fit$upper))
    )
    ht <- pub_table(
        long,
        caption = "Fit summary",
        labels = c(
            batch = "Batch",
            term = "Parameter",
            estimate = "Estimate",
            lower = "Lower",
            upper = "Upper"
        ),
        digits = c(estimate = decimals, lower = decimals, upper = decimals),
        header = c(lower = "Confidence interval", upper = "Confidence interval"),
        merge = "batch",
        na = "-"
    )
    slopes <- sum(huxtable::header_rows(ht)) + which(long$term == "Slope")
    huxtable::set_bold(ht, slopes, "estimate")
}

# Criteria table: deactivated criteria grey and struck through
demo_criteria_table <- function(check, limits) {
    criteria <- data.frame(
        criterion = c("Prediction >= LSL", "Prediction <= USL", "Slope below zero"),
        limit = c(limits$lower, limits$upper, "0"),
        passed = c(
            sum(check$predicted >= as.numeric(limits$lower)),
            sum(check$predicted <= as.numeric(limits$upper)),
            NA
        )
    )
    active <- c(TRUE, TRUE, FALSE)
    ht <- pub_table(
        criteria,
        caption = "Acceptance criteria",
        labels = c(
            criterion = "Criterion",
            limit = "Limit",
            passed = "Batches passing"
        ),
        na = "-"
    )
    rows <- sum(huxtable::header_rows(ht)) + which(!active)
    ht |>
        huxtable::set_text_color(rows, huxtable::everywhere, "#d3c8c8") |>
        pub_strikeout(rows)
}

# Trend plot: ggplot if available, otherwise a recorded base plot
demo_trend_plot <- function(data, xlab, ylab) {
    p <- if (requireNamespace("ggplot2", quietly = TRUE)) {
        # nolint start: object_usage_linter. (columns of `data`)
        ggplot2::ggplot(data, ggplot2::aes(time, y, colour = batch)) +
            # nolint end
            ggplot2::geom_point() +
            ggplot2::geom_line() +
            ggplot2::labs(x = xlab, y = ylab, colour = "Batch")
    } else {
        grDevices::pdf(NULL)
        on.exit(grDevices::dev.off())
        grDevices::dev.control("enable")
        graphics::plot(data$time, data$y, xlab = xlab, ylab = ylab)
        grDevices::recordPlot()
    }
    pub_figure(p, caption = sprintf("%s over time", ylab), width = 6, height = 4)
}

demo_conclusion <- function(fit, title) {
    pub_text(
        c(
            sprintf("**%s**: %d batches analysed.", title, nrow(fit)),
            "",
            pub_format_num(min(fit$slope), "- steepest slope: *%.3f*"),
            pub_format_num(max(fit$slope), "- flattest slope: *%.3f*"),
            "",
            "Model: $y = a + b \\cdot t$. See [<insert link>]{.placeholder}."
        ),
        title = "Conclusion"
    )
}

demo_report_steps <- c(
    "data_table",
    "fit_table",
    "criteria_table",
    "trend_plot",
    "conclusion",
    "results"
)

demo_report_pipeline <- function(name = "report") {
    pip <- demo_pipeline(name) |>
        pipeflow::pip_add(
            "data_table",
            \(data = ~data, decimals = "2") {
                demo_data_table(data, as.integer(decimals))
            },
            tags = c("report", "table")
        ) |>
        pipeflow::pip_add(
            "fit_table",
            \(fit = ~fit, decimals = "2") {
                demo_fit_table(fit, as.integer(decimals))
            },
            tags = c("report", "table")
        ) |>
        pipeflow::pip_add(
            "criteria_table",
            \(
                check = ~limits_check,
                limits = list(lower = "95", upper = "105")
            ) {
                demo_criteria_table(check, limits)
            },
            tags = c("criteria", "table")
        ) |>
        pipeflow::pip_add(
            "trend_plot",
            \(data = ~data, xlab = "Time", ylab = "Assay") {
                demo_trend_plot(data, xlab, ylab)
            },
            tags = c("report", "figure")
        ) |>
        pipeflow::pip_add(
            "conclusion",
            \(fit = ~fit, title = "Quality demo") {
                demo_conclusion(fit, title)
            },
            tags = "report"
        ) |>
        pipeflow::pip_add(
            "check_text",
            \(check = ~check) {
                pub_text(
                    if (isTRUE(check)) {
                        "All batches meet the limits."
                    } else {
                        "Some batches fail the limits."
                    }
                )
            },
            tags = "criteria"
        ) |>
        pipeflow::pip_add(
            "results",
            \(
                table = ~fit_table,
                plot = ~trend_plot,
                conclusion = ~conclusion
            ) {
                list(Fit = list(table, plot), Conclusion = conclusion)
            },
            tags = "report"
        ) |>
        pipeflow::pip_add("doc", demo_report_layout)
    cfg <- demo_config()[c("decimals", "limits", "xlab", "ylab", "title")]
    pipeflow::pip_set_params(pip, cfg, unknown = "error")
    pip
}

# Report variants of the split and nested pipelines -------------------------------

# Split pipeline plus steps with outputs per partition (a table, a figure and a text for
# each batch), a table of the reduced result and the layout steps: one section per
# batch, then the document
demo_split_report_pipeline <- function() {
    pip <- demo_split_pipeline() |>
        pipeflow::pip_add("partition_table", \(data = ~split_data, failBatch = "") {
            if (data$batch[[1L]] == failBatch) {
                stop(sprintf("no table for batch %s", failBatch))
            }
            pub_table(
                data[c("time", "y")],
                caption = sprintf("Data of batch %s", data$batch[[1L]]),
                labels = c(time = "Time", y = "Assay"),
                digits = c(time = 0L, y = 1L)
            )
        }) |>
        pipeflow::pip_add("trend_plot", \(data = ~split_data) {
            demo_trend_plot(data, "Time", "Assay")
        }) |>
        pipeflow::pip_add("coef_text", \(coefs = ~coefs) {
            pub_text(sprintf("Slope: %s per month.", coefs[["x"]]))
        }) |>
        pipeflow::pip_add("summary_table", \(combined = ~combine) {
            pub_table(
                combined,
                caption = "Coefficients per batch",
                labels = c(batch = "Batch", X.Intercept. = "Intercept", x = "Slope")
            )
        }) |>
        pipeflow::pip_add("batch_section", demo_batch_layout) |>
        pipeflow::pip_add("doc", demo_split_layout, exec = "reduce")
    pipeflow::pip_set_params(pip, demo_split_config(), unknown = "error")
}

# Inner pipeline plus a table, a figure, a text and a layout step listing them (the
# content of the inner pipeline's section)
demo_inner_report_pipeline <- function(data = NULL, name = "inner") {
    pip <- demo_inner_pipeline(data, name) |>
        pipeflow::pip_add("fit_table", \(fit = ~fit, decimals = "2") {
            d <- as.integer(decimals)
            pub_table(
                fit,
                caption = "Fit summary",
                digits = c(intercept = d, slope = d, lower = d, upper = d)
            )
        }) |>
        pipeflow::pip_add("trend_plot", \(data = ~data) {
            demo_trend_plot(data, "Time", "Assay")
        }) |>
        pipeflow::pip_add("note", \(fit = ~fit) {
            slopes <- toString(pub_format_num(fit$slope, 3))
            pub_text(sprintf("Slope: %s.", slopes))
        }) |>
        pipeflow::pip_add(
            "content",
            \(table = ~fit_table, plot = ~trend_plot, note = ~note) {
                list(table, plot, note)
            }
        )
    pipeflow::pip_set_params(pip, demo_inner_config(), unknown = "error")
}

# Nested pipeline over the inner report pipeline, plus a step returning a named list (by
# batch) of lists of outputs, a summary table and the layout step
demo_nested_report_pipeline <- function() {
    demo_nested_pipeline(
        inner = demo_inner_report_pipeline(),
        out = c("settings", "coefs", "fit_table", "note", "content")
    ) |>
        pipeflow::pip_add(
            "inner_results",
            \(res = ~inner_run) {
                lapply(res, \(r) list(table = r$fit_table, note = r$note))
            },
            exec = "reduce"
        ) |>
        pipeflow::pip_add("summary_table", \(coefs = ~coef_table) {
            pub_table(coefs, caption = "Slopes per batch")
        }) |>
        pipeflow::pip_add("doc", demo_nested_layout, exec = "reduce")
}

# One pipeline per test: named list of pipelines
demo_test_pipelines <- function() {
    water <- demo_data()
    water$y <- water$y / 40
    list(
        Assay = demo_inner_report_pipeline(demo_data(), name = "test Assay"),
        Water = demo_inner_report_pipeline(water, name = "test Water")
    )
}

# Documents -------------------------------------------------------------- Layout steps
# arrange step outputs into documents; they are defined here, outside the pipeline
# constructors. The renderer tests render the fixture documents demo_*_doc().

# Layout step of demo_report_pipeline(): static content, step outputs, a data.frame
# output with another caption, a named list output (sections), a landscape section and
# an empty section that is kept
demo_report_layout <- function(
    data_table = ~ try(data_table),
    check = ~ try(limits_check),
    fit_table = ~ try(fit_table),
    trend_plot = ~ try(trend_plot),
    results = ~ try(results),
    criteria_table = ~ try(criteria_table),
    summary = ~ try(summary),
    conclusion = ~ try(conclusion),
    check_text = ~ try(check_text)
) {
    pub_doc(
        pub_section(
            "Introduction",
            pub_text("Quality of three batches ([demo]{.placeholder})."),
            numbered = FALSE
        ),
        pub_section(
            "Data",
            data_table,
            pub_set_meta(check, caption = "Predicted values at 12 months")
        ),
        pub_section("Analysis", fit_table, trend_plot, results),
        pub_section("Criteria", criteria_table, check_text, landscape = TRUE),
        pub_section("Summary", summary, conclusion),
        pub_section("Notes", pub_section("Empty"), on_empty = "keep"),
        title = "Quality demo",
        subtitle = "Built by the layout step of demo_report_pipeline()",
        meta = list(author = "Demo user", app = "pubflow tests", version = "0.0.0")
    )
}

# Runs once per batch (downstream of the split step): one section with the outputs of
# several partitioned steps
demo_batch_layout <- function(
    table = ~ try(partition_table),
    plot = ~ try(trend_plot),
    text = ~ try(coef_text),
    data = ~ try(split_data)
) {
    title <- sprintf("Batch %s (%d values)", data$batch[[1L]], nrow(data))
    pub_section(title, table, plot, text)
}

# Reduce step: the batch sections (unnamed, so that they are not wrapped in sections per
# key), the reduced table once, and a partitioned output placed as is (one section per
# key)
demo_split_layout <- function(
    batches = ~ try(batch_section),
    summary = ~ try(summary_table),
    slopes = ~ try(coef_text)
) {
    pub_doc(
        pub_section("Overview", summary),
        pub_section("Batches", unname(batches)),
        pub_section("All slopes", slopes),
        title = "Split demo"
    )
}

# One section per inner pipeline (from its layout step "content"), and the entries of a
# list output selected and ordered per batch
demo_nested_layout <- function(
    res = ~inner_run,
    results = ~inner_results,
    summary = ~summary_table
) {
    batches <- lapply(names(res), \(name) {
        pub_section(sprintf("Batch %s", name), res[[name]]$content, page_break = TRUE)
    })
    pub_doc(
        pub_section("Summary", summary),
        batches,
        pub_section(
            "Results per batch",
            lapply(results, \(r) unname(r[c("note", "table")]))
        ),
        title = "Nested demo"
    )
}

demo_report_doc <- function() {
    p <- demo_report_pipeline()
    run_quietly(p)
    p[["doc", "out"]]
}

demo_split_doc <- function() {
    p <- demo_split_report_pipeline()
    run_quietly(p)
    p[["doc", "out"]]
}

demo_nested_doc <- function() {
    p <- demo_nested_report_pipeline()
    run_quietly(p)
    p[["doc", "out"]]
}

# Report with a failure: 'check' fails, so 'check_text' is not run and the layout step
# places a failure object (an error item) instead
demo_failed_report_doc <- function() {
    p <- demo_report_pipeline()
    pipeflow::pip_set_params(p, list(failCheck = "yes"))
    suppressWarnings(
        run_quietly(p, on_error = "continue"),
        classes = "pipeflow_run_failed"
    )
    p[["doc", "out"]]
}

# Failure objects: step 'fit' fails, so 'table' is not run; the layout step receives
# both as failure objects (run with on_error = "continue")
demo_failure_pipeline <- function() {
    pipeflow::pip_new("failing") |>
        pipeflow::pip_add("data", \(n = 3) data.frame(x = seq_len(n))) |>
        pipeflow::pip_add("fit", \(data = ~data) stop("singular fit")) |>
        pipeflow::pip_add("table", \(fit = ~fit) pub_table(fit)) |>
        pipeflow::pip_add("doc", \(fit = ~ try(fit), table = ~ try(table)) {
            list(fit = fit, table = table)
        })
}

# list(fit = <failure of 'fit'>, table = <failure: 'table' not run>)
demo_failures <- function() {
    p <- demo_failure_pipeline()
    suppressWarnings(
        run_quietly(p, on_error = "continue"),
        classes = "pipeflow_run_failed"
    )
    p[["doc", "out"]]
}

# One pipeline per test, assembled by the app: one section per test
demo_tests_doc <- function(pipelines = demo_test_pipelines()) {
    for (p in pipelines) {
        run_quietly(p)
    }
    pub_doc(lapply(pipelines, pub_out, step = "content"), title = "Tests")
}

# Report pipeline over one pipeline per test: the parts of the test pipelines come in as
# param values (demo_test_parts()), and a step computes across the tests
demo_tests_report_pipeline <- function() {
    pipeflow::pip_new("tests report") |>
        pipeflow::pip_add("tests", \(testParts = list()) testParts) |>
        pipeflow::pip_add("fits", \(testFits = list()) testFits) |>
        pipeflow::pip_add("slope_table", \(fits = ~fits) {
            slopes <- Map(
                \(test, fit) data.frame(test = test, fit[c("batch", "slope")]),
                names(fits),
                fits
            )
            pub_table(
                do.call(rbind, unname(slopes)),
                caption = "Slopes per test",
                labels = c(test = "Test", batch = "Batch", slope = "Slope"),
                digits = c(slope = 3L),
                merge = "test"
            )
        }) |>
        pipeflow::pip_add("doc", demo_tests_report_layout)
}

demo_tests_report_layout <- function(
    tests = ~ try(tests),
    slopes = ~ try(slope_table)
) {
    pub_doc(
        pub_section("Results", tests),
        pub_section("Summary", slopes),
        title = "Tests report"
    )
}

# Param values of the report pipeline: the parts of the test pipelines
demo_test_parts <- function(pipelines, on_error = "stop") {
    list(
        testParts = lapply(
            pipelines,
            pub_out,
            step = "content",
            on_error = on_error
        ),
        testFits = lapply(pipelines, pub_out, step = "fit")
    )
}

# Document of the report pipeline over the test pipelines
demo_tests_report_doc <- function(pipelines = demo_test_pipelines()) {
    for (p in pipelines) {
        run_quietly(p)
    }
    report <- demo_tests_report_pipeline()
    pipeflow::pip_set_params(report, demo_test_parts(pipelines))
    run_quietly(report)
    report[["doc", "out"]]
}

# Run a pipeline (or view) without logging
run_quietly <- function(x, ...) {
    pipeflow::pip_run(x, lgr = NULL, ...)
}
