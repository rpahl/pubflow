# Table fixtures modelled on typical report tables, built the recommended way:
# combine the data, build the table once, style it with huxtable and strike cells
# through last. Plus the numeric edge-case table of the cross-format consistency tests.

# Cell text of a table without dimnames
cell_text <- function(ht) {
    pub_cell_text(ht)
}

# Numeric edge cases: ties, negatives rounding to zero, NA, large and small magnitudes,
# a carry, integers and dates (expected text in edge_case_text()); one cell
# is struck through (edge_case_struck())
edge_case_data <- function() {
    data.frame(
        case = c(
            "tie 0.125",
            "tie 2.675",
            "tie 2.705",
            "tie 0.065",
            "tie 0.285",
            "negative",
            "rounds to 0",
            "missing",
            "large",
            "small",
            "carry 9.995"
        ),
        value = c(
            0.125,
            2.675,
            2.705,
            0.065,
            0.285,
            -1.005,
            -0.001,
            NA,
            123456789.125,
            0.000123,
            9.995
        ),
        whole = c(0.5, 1.5, 2.5, -0.5, 3, -2.5, 0, NA, 1e6, 1, 9.5),
        count = c(1L, 2L, NA, 4L, 5L, -6L, 0L, 8L, 100000L, 10L, 11L),
        date = as.Date("2024-02-28") + 0:10
    )
}

# Table position (row, column) of the struck-through cell
edge_case_struck <- function() {
    cbind(row = 7L, col = 2L)
}

edge_case_table <- function() {
    ht <- pub_table(
        edge_case_data(),
        caption = "Numeric edge cases",
        digits = c(value = 2, whole = 0),
        na = "n/a"
    )
    struck <- edge_case_struck()
    pub_strikeout(ht, struck[[1L]], struck[[2L]])
}

# Expected text in every output format (struck cells without Markdown; pub_cell_text()
# shows them between "~~")
edge_case_text <- function() {
    rbind(
        c("case", "value", "whole", "count", "date"),
        cbind(
            edge_case_data()$case,
            c(
                "0.13",
                "2.68",
                "2.71",
                "0.07",
                "0.29",
                "-1.01",
                "0.00",
                "n/a",
                "123456789.13",
                "0.00",
                "10.00"
            ),
            c("1", "2", "3", "-1", "3", "-3", "0", "n/a", "1000000", "1", "10"),
            c("1", "2", "n/a", "4", "5", "-6", "0", "8", "100000", "10", "11"),
            format(as.Date("2024-02-28") + 0:10)
        )
    )
}

# Report table: data table with test-status font colours and a time spanner ------------

report_status_colors <- c(
    validated = "black",
    verified = "blue",
    recorded = "#00B050"
)

report_data_table <- function() {
    wide <- data.frame(
        batch = c("A", "B", "C"),
        `0` = c(100.0, 100.4, 99.6),
        `3` = c(99.1, 99.8, 98.9),
        `6` = c(98.4, NA, 97.8),
        check.names = FALSE
    )
    status <- matrix(
        c(
            "validated",
            "verified",
            "recorded",
            "validated",
            "validated",
            "verified",
            "recorded",
            NA,
            "validated"
        ),
        nrow = 3L
    )
    colors <- report_status_colors[status]
    colors[is.na(colors)] <- "black"
    times <- names(wide)[-1L]
    ht <- pub_table(
        wide,
        caption = "Data table for Assay",
        labels = c(batch = "Batch number"),
        digits = rlang::set_names(rep(1L, 3L), times),
        header = rlang::set_names(rep("Time [months]", 3L), times),
        na = "-"
    )
    rows <- sum(huxtable::header_rows(ht)) + seq_len(nrow(wide))
    huxtable::set_text_color(ht, rows, times, matrix(colors, nrow = 3L))
}

# Report table: batch summary = per-batch summaries stacked, coloured merged batch -----

report_batch_colors <- c(A = "#1B9E77", B = "#D95F02", C = "#7570B3")

report_batch_summary <- function(batch, slope) {
    data.frame(
        Batch = batch,
        term = c("Intercept", "Slope"),
        estimate = c(100.12345, slope),
        std.error = c(0.41234, 0.05432),
        df = c(10L, 10L),
        p.value = c("<1e-04", "0.0123")
    )
}

report_summary_table <- function() {
    slopes <- c(A = -0.2512, B = -0.3, C = -0.1257)
    data <- do.call(rbind, unname(Map(report_batch_summary, names(slopes), slopes)))
    ht <- pub_table(
        data,
        caption = paste(
            "Summary of linear regression based on separate slopes and",
            "separate intercepts with 95% confidence interval."
        ),
        labels = c(
            Batch = "Batch number",
            term = "Parameter",
            estimate = "Estimate",
            std.error = "Standard error",
            p.value = "p-value"
        ),
        digits = c(estimate = 3, std.error = 3),
        merge = "Batch"
    )
    rows <- sum(huxtable::header_rows(ht)) + seq_len(nrow(data))
    huxtable::set_text_color(
        ht,
        rows,
        "Batch",
        unname(report_batch_colors[data$Batch])
    )
}

# Report table: trend assessment, data combined across tests, split by batch -----------

report_trend_data <- function() {
    rbind(
        data.frame(Batch = c("A", "B"), Test = "Assay", finalTrend = 36),
        data.frame(Batch = c("A", "B"), Test = "Impurity A", finalTrend = 24.4)
    )
}

report_trend_by_batch <- function() {
    data <- report_trend_data()
    lapply(split(data, data$Batch), \(d) {
        pub_table(
            d,
            caption = sprintf(
                "Current trend assessment of batch %s",
                d$Batch[[1L]]
            ),
            labels = c(finalTrend = "Estimated trend (months)"),
            digits = c(finalTrend = 0),
            align = c(Test = "center")
        )
    })
}

# Report table: p-value in bold, coloured by the decision ------------------------------

report_pvalue_table <- function(pInteraction = 0.31, alpha = 0.25) {
    df <- data.frame(
        Source = c("Batch", "Slope", "Batch:Slope", "Residuals"),
        Df = c(2L, 1L, 2L, 6L),
        `F value` = c(1.234, 45.678, 1.3, NA),
        `Pr(>F)` = c("0.3501", "<1e-04", pub_format_num(pInteraction, 4), ""),
        check.names = FALSE
    )
    color <- if (pInteraction > alpha) "#006400" else "#8B0000"
    ht <- pub_table(df, digits = c(`F value` = 3))
    row <- sum(huxtable::header_rows(ht)) + which(df$Source == "Batch:Slope")
    ht |>
        huxtable::set_text_color(row, "Pr(>F)", color) |>
        huxtable::set_bold(row, "Pr(>F)")
}

# Report table: deviation table with wrapping "auto" columns and small font ------------

report_wrapped_table <- function() {
    df <- data.frame(
        deviation_number = c("DEV-1", "DEV-2"),
        description = c("Sample stored at the wrong temperature.", "Late."),
        root_cause = c("Freezer failure.", "Holiday."),
        status = c("closed", "open")
    )
    pub_table(
        df,
        labels = c(
            deviation_number = "Deviation ID",
            description = "Description",
            root_cause = "Root Cause",
            status = "Status"
        ),
        widths = c(
            deviation_number = "2.5cm",
            description = "auto",
            root_cause = "auto",
            status = 1
        ),
        font_size = 8
    )
}

# Report table: footnote on the first column ---------------------------

report_footnote_table <- function() {
    pub_table(
        data.frame(term = c("Intercept", "Slope"), estimate = c(100.12345, -0.25)),
        caption = paste(
            "Summary of linear regression based on common slope and",
            "common intercept with 95% confidence interval."
        ),
        labels = c(term = "Parameter", estimate = "Estimate"),
        digits = c(estimate = 3),
        footnotes = c(term = "Batch numbers: A, B, C")
    )
}

# Slope summary: separate | common fits, serotype column, criteria ---------------------

slopes_separate_data <- function() {
    data.frame(
        sample = c("Ref", "S1", "S2"),
        intercept = c(1.2345, 1.3012, 1.1987),
        slope = c(0.98765, 1.01234, 0.95),
        r2 = c(0.991, 0.987, 0.995),
        slope_ratio = c(NA, 1.025, 0.962)
    )
}

slopes_common_data <- function() {
    data.frame(
        slope_common = c(NA, 0.991, 0.991),
        r2_common = c(NA, 0.982, 0.979),
        rel_pot_pct = c(NA, 104.6, 97.5)
    )
}

# Both fits side by side under their spanners; with `serotype` a merged serotype column
# in front
slopes_summary_table <- function(serotype = NULL) {
    data <- cbind(slopes_separate_data(), slopes_common_data())
    if (!is.null(serotype)) {
        data <- cbind(Serotype = serotype, data)
    }
    separate <- c("intercept", "slope", "r2", "slope_ratio")
    common <- c("slope_common", "r2_common", "rel_pot_pct")
    pub_table(
        data,
        caption = "Overall summary of separate and common slope fits.",
        labels = c(
            sample = "Sample",
            intercept = "Intercept",
            slope = "Slope",
            r2 = "R\u00b2",
            slope_ratio = "Slope Ratio",
            slope_common = "Slope",
            r2_common = "R\u00b2",
            rel_pot_pct = "Rel. Potency [%]"
        ),
        digits = c(
            intercept = 3,
            slope = 3,
            r2 = 2,
            slope_ratio = 2,
            slope_common = 3,
            r2_common = 2,
            rel_pot_pct = 0
        ),
        header = c(
            rlang::set_names(rep("Separate slope", 4L), separate),
            rlang::set_names(rep("Common slope", 3L), common)
        ),
        merge = if (!is.null(serotype)) "Serotype"
    )
}

slopes_criteria_active <- c(TRUE, FALSE, TRUE, FALSE)

slopes_criteria_table <- function() {
    criteria <- data.frame(
        Name = c("Slope ratio", "R\u00b2", "Relative potency", "Parallelism"),
        Min = c("0.80", "0.95", "50", ""),
        Max = c("1.25", "", "200", "0.05")
    )
    ht <- pub_table(criteria, caption = "Validity Criteria")
    rows <- sum(huxtable::header_rows(ht)) + which(!slopes_criteria_active)
    ht |>
        huxtable::set_text_color(rows, huxtable::everywhere, "#d3c8c8") |>
        pub_strikeout(rows)
}
