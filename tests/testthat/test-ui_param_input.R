# ======================================================================================
# Input widgets
# ======================================================================================

# -------
# Widgets
# -------

describe("pub_param_input()", {
    it("builds the default widget of each param type", {
        expect_match(
            html_of(pub_param_input(param("abc", label = "Name"), "txt")),
            '<input id="txt" type="text"[^>]*value="abc"'
        )
        expect_match(
            html_of(pub_param_input(numeric_param(2, label = "N"), "n")),
            '<input id="n" type="number"[^>]*value="2"'
        )
        sel <- html_of(pub_param_input(choice_param("b", c("a", "b")), "sel"))
        expect_match(sel, '<select id="sel"')
        expect_match(sel, '<option value="b" selected>b</option>')
        expect_match(
            html_of(pub_param_input(param(TRUE), "sw")),
            '<div class="pretty p-default p-switch">\\s*<input id="sw" '
        )
    })

    it("uses the widget given by the attribute ui_widget", {
        radio <- html_of(pub_param_input(
            choice_param("on", c("on", "off"), ui_widget = "radio"),
            "oo"
        ))
        expect_match(radio, 'id="oo" class="radio-group-buttons"')
        expect_match(radio, 'value="on" checked="checked"')

        slider <- numeric_param(3, min = 1, max = 9, ui_widget = "slider")
        html <- html_of(pub_param_input(slider, "sl"))
        expect_match(html, 'class="js-range-slider" id="sl"')
        expect_match(html, 'data-min="1" data-max="9" data-from="3"')

        day <- param(as.Date("2026-10-04"), ui_widget = shiny::dateInput)
        expect_match(
            html_of(pub_param_input(day, "day")),
            'id="day".*data-initial-date="2026-10-04"'
        )
    })

    it("passes min, max and step of numeric params", {
        p <- numeric_param(0.05, min = 0, max = 0.5, step = 0.01)
        expect_match(
            html_of(pub_param_input(p, "a")),
            'min="0" max="0.5" step="0.01"'
        )

        # default step: a tenth of the range; infinite bounds are left out
        p <- numeric_param(1, min = 0, max = 2)
        html <- html_of(pub_param_input(p, "b"))
        expect_match(html, 'step="0.2"')
        html <- html_of(pub_param_input(numeric_param(1), "c"))
        expect_no_match(html, "min=|max=|step=")
    })

    it("leaves out a step that isn't positive", {
        # only a plain param() can have such attributes
        for (p in list(
            param(1, min = 1, max = 1),
            param(1, min = 2, max = 1),
            param(1, step = 0),
            param(1, step = -1)
        )) {
            expect_no_match(html_of(pub_param_input(p, "a")), "step=")
        }
    })

    it("passes only the arguments in ... that the widget accepts", {
        args <- list(updateOn = "blur", width = "10ch")
        txt <- do.call(pub_param_input, c(list(param("a"), "t"), args))
        expect_match(html_of(txt), 'style="width:10ch;"')
        expect_match(html_of(txt), 'data-update-on="blur"')

        sel <- do.call(
            pub_param_input,
            c(list(choice_param("a", c("a", "b")), "s"), args)
        )
        expect_match(html_of(sel), 'style="width:10ch;"')
        expect_no_match(html_of(sel), "update-on")
    })

    it("lets arguments in ... override those derived from the param", {
        p <- numeric_param(1, min = 0, max = 10)
        pUi <- numeric_param(1, min = 0, max = 10, ui_args = list(step = 5))

        expect_match(html_of(pub_param_input(p, "n", step = 2)), 'step="2"')
        expect_match(html_of(pub_param_input(pUi, "n", step = 2)), 'step="5"')
    })

    it("lets the attribute ui_args override all other arguments", {
        p <- choice_param(
            "a",
            c("a", "b"),
            ui_args = list(
                multiple = TRUE,
                choices = c(First = "a", Second = "b")
            )
        )
        html <- html_of(pub_param_input(p, "s", multiple = FALSE))
        expect_match(html, '<select id="s" class="shiny-input-select" multiple')
        expect_match(html, '<option value="a" selected>First</option>')
    })

    it("selects all values of a multiple choice factor", {
        p <- param(
            factor(c("a", "c"), levels = c("a", "b", "c")),
            ui_args = list(multiple = TRUE)
        )
        html <- html_of(pub_param_input(p, "m"))
        expect_match(html, '<option value="a" selected>')
        expect_match(html, '<option value="b">')
        expect_match(html, '<option value="c" selected>')
    })

    it("gives the children of a param group side by side with own ids", {
        html <- html_of(pub_param_input(demo_limits_param(), "limits"))

        expect_match(
            html,
            '<label class="control-label" id="limits-param-label">Specification limits'
        )
        expect_match(
            html,
            paste0(
                '<div class="pubflow-param-group" role="group" ',
                'aria-labelledby="limits-param-label">'
            )
        )
        expect_match(html, '<input id="limits_lower" type="text"[^>]*"95"')
        expect_match(html, '<input id="limits_upper" type="text"[^>]*"105"')

        html <- html_of(pub_param_input(demo_limits_param(), "x", label = NULL))
        expect_no_match(html, "Specification limits")
        expect_match(html, '<div class="pubflow-param-group">')
    })

    it("labels the children of a group for screen readers only", {
        html <- html_of(pub_param_input(demo_limits_param(), "limits"))
        expect_match(
            html,
            '<label class="pubflow-visually-hidden" for="limits_lower">LSL</label>'
        )
        expect_match(html, 'for="limits_upper">USL</label>')

        # widgets that can't be the target of a label: a named group; the name of
        # the child stands in for a missing label
        g <- param_group(
            list(
                on = param(TRUE, label = "Show"),
                day = structure(
                    param(as.Date("2026-10-04"), ui_widget = shiny::dateInput),
                    label = NULL
                )
            )
        )
        html <- html_of(pub_param_input(g, "g", label = NULL))
        expect_match(html, 'class="pubflow-visually-hidden" for="g_on">Show</label>')
        expect_equal(.child_label(param(1, label = ""), "n"), "n")
        expect_match(html, '<div role="group" aria-label="day">\\s*<div[^>]*id="g_day"')
    })

    it("gives the width to the whole group, shared by its children", {
        html <- html_of(pub_param_input(demo_limits_param(), "x", width = "10ch"))
        expect_match(html, '<div class="pubflow-param-group"[^>]* style="width:10ch;">')
        expect_match(html, 'style="width:100%;"')
        expect_no_match(html, 'style="width:10ch;"[^>]*title')

        html <- html_of(pub_param_input(demo_limits_param(), "x"))
        expect_match(html, '<div class="pubflow-param-group"[^>]*-label">')
        expect_no_match(html, "width:")
    })

    it("keeps the default width of a child's widget without a width", {
        widget <- \(inputId, label, value, width = "8em") {
            shiny::textInput(inputId, label, value, width = width)
        }
        g <- param_group(list(a = param("x", ui_widget = widget)))

        expect_match(html_of(pub_param_input(g, "g")), 'style="width:8em;"')
    })

    it("shows the description as tooltip for Bootstrap 3 and 5", {
        p <- param(1, label = "Alpha", description = "Significance level")
        html <- html_of(pub_param_input(p, "a", tooltip = TRUE))

        expect_match(
            html,
            '<div class="form-group shiny-input-container pubflow-tooltip"'
        )
        expect_match(html, 'title="Significance level"')
        for (attr in c(
            'data-toggle="tooltip"',
            'data-bs-toggle="tooltip"',
            'data-trigger="hover"',
            'data-bs-trigger="hover"',
            'data-container="body"',
            'data-bs-container="body"',
            'data-delay="\\{&quot;show&quot;:1500,&quot;hide&quot;:100\\}"',
            'data-bs-delay="\\{&quot;show&quot;:1500',
            'data-pubflow-tooltip-autohide-ms="7000"'
        )) {
            expect_match(html, attr)
        }
        expect_no_match(html_of(pub_param_input(p, "a")), "tooltip")

        # group children get their own tooltips
        limits <- demo_limits_param()
        html <- html_of(pub_param_input(limits, "l", tooltip = TRUE))
        expect_match(html, 'title="LSL".*title="USL"')
    })

    it("wraps a widget that is no single tag for its tooltip", {
        widget <- function(inputId, label, value) {
            htmltools::tagList(htmltools::span(id = inputId, value))
        }
        p <- param("a", description = "Text", ui_widget = widget)
        html <- html_of(pub_param_input(p, "w", tooltip = TRUE))

        expect_match(
            html,
            '<div class="pubflow-tooltip-wrapper pubflow-tooltip".*id="w">a'
        )
    })

    it("attaches pubflow's html dependency", {
        deps <- htmltools::findDependencies(pub_param_input(param(1), "a"))
        dep <- Filter(\(d) d$name == "pubflow", deps)[[1]]

        expect_equal(dep$script, "pubflow.js")
        expect_equal(dep$stylesheet, "pubflow.css")
        version <- as.character(utils::packageVersion("pubflow"))
        expect_equal(dep$version, version)
        dir <- system.file(dep$src$file, package = dep$package)
        files <- file.path(dir, c("pubflow.js", "pubflow.css"))
        expect_true(all(file.exists(files)))
    })

    it("applies the attribute ui_style", {
        x <- param(1, ui_style = "height: 30px;")

        ui <- pub_param_input(x, "n")

        expect_match(html_of(ui), "<style>#n \\{height: 30px;\\}</style>")
        deps <- htmltools::findDependencies(ui)
        expect_true("pubflow" %in% vapply(deps, \(d) d$name, ""))
    })

    it("builds an input without label and a range slider", {
        html <- html_of(pub_param_input(param(1, label = "Alpha"), "n", label = NULL))
        expect_match(html, '<label class="control-label shiny-label-null"')
        expect_no_match(html, "Alpha")

        range <- numeric_param(c(2, 4), min = 0, max = 10, ui_widget = "slider")
        html <- html_of(pub_param_input(range, "r"))
        expect_match(html, 'data-from="2" data-to="4"')
    })

    it("passes the bounds given, also if only one is finite", {
        html <- html_of(pub_param_input(numeric_param(1, min = 0), "n"))
        expect_match(html, 'min="0"')
        expect_no_match(html, "max=|step=")
    })

    it("gives factors as radio buttons with the value selected", {
        p <- choice_param("b", c("a", "b"), ui_widget = "radio")
        html <- html_of(pub_param_input(p, "r"))
        expect_match(html, 'value="a"/>')
        expect_match(html, 'value="b" checked="checked"')
    })

    it("drops unnamed arguments in ... and accepts empty ui_args", {
        p <- param("a", label = "Name", ui_args = list())
        html <- html_of(pub_param_input(p, "t", "Name", FALSE, "junk"))
        expect_match(html, '<input id="t" type="text"[^>]*value="a"')
        expect_no_match(html, "junk")
    })

    it("links labels to labelable widgets only, not to groups", {
        expect_equal(.label_for(param(1), "a"), "a")
        radio <- choice_param("on", c("on", "off"), ui_widget = "radio")
        expect_null(.label_for(radio, "r"))
        expect_null(.label_for(param_group(list(a = param(1))), "g"))

        # a widget function is not known to be labelable
        day <- param(as.Date("2026-10-04"), ui_widget = shiny::dateInput)
        expect_null(.label_for(day, "d"))
    })

    it("shows the label as tooltip without description, else none", {
        html <- html_of(pub_param_input(param(1, label = "Lab"), "a", tooltip = TRUE))
        expect_match(html, 'class="[^"]*pubflow-tooltip"[^>]*title="Lab"')

        for (p in list(param(1, label = ""), param(1, label = "L", description = ""))) {
            html <- html_of(pub_param_input(p, "a", tooltip = TRUE))
            expect_no_match(html, "tooltip")
        }
    })

    it("disables the inputs of locked params", {
        params <- list(
            txt = param("a", locked = TRUE),
            num = numeric_param(1, locked = TRUE),
            select = choice_param("a", choices = c("a", "b"), locked = TRUE),
            slider = numeric_param(
                1,
                min = 0,
                max = 5,
                ui_widget = "slider",
                locked = TRUE
            ),
            radio = choice_param("a", c("a", "b"), ui_widget = "radio", locked = TRUE),
            switch = param(TRUE, locked = TRUE),
            custom = param(
                "a",
                ui_widget = \(inputId, label, value) {
                    htmltools::tags$textarea(id = inputId, value)
                },
                locked = TRUE
            )
        )
        for (name in names(params)) {
            html <- as.character(pub_param_input(params[[name]], name))
            expect_match(
                html,
                paste0(
                    '^<div class="pubflow-param-locked">\\s*',
                    '<fieldset class="pubflow-param-fieldset" disabled>'
                ),
                info = name
            )
            # the radio buttons' inputs come from a tag function: the fieldset
            # disables them
            controls <- regmatches(
                html,
                gregexpr("<(input|select|textarea|button)\\b[^>]*>", html)
            )[[1]]
            controls <- grep('type="radio"', controls, value = TRUE, invert = TRUE)
            expect_true(length(controls) > 0L, info = name)
            expect_match(controls, "\\bdisabled\\b", info = name)
        }
        html <- as.character(pub_param_input(params$slider, "slider"))
        expect_match(html, 'data-disable="true"')
        # shinyWidgets styles its disabled radio buttons
        html <- as.character(pub_param_input(params$radio, "radio"))
        expect_match(html, '<button class="btn radiobtn [^"]*disabled"')

        # an unlocked param keeps its input enabled
        html <- as.character(pub_param_input(param("a", locked = FALSE), "a"))
        expect_no_match(html, "disabled|pubflow-param-locked")
    })

    it("disables every child of a locked param group", {
        g <- demo_limits_param()
        attr(g, "locked") <- TRUE
        html <- as.character(pub_param_input(g, "g"))

        expect_length(gregexpr("<input[^>]*disabled", html)[[1]], 2L)
        expect_length(gregexpr("pubflow-param-locked", html)[[1]], 2L)

        # the attribute of a child alone does not lock it
        g <- demo_limits_param()
        attr(g$lower, "locked") <- TRUE
        expect_no_match(as.character(pub_param_input(g, "g")), "disabled")
    })

    it("adds '(locked)' to the tooltip of a locked param", {
        x <- param(1, label = "Level", description = "Confidence level", locked = TRUE)
        html <- as.character(pub_param_input(x, "x", tooltip = TRUE))
        expect_match(html, 'class="pubflow-param-locked pubflow-tooltip"')
        expect_match(html, 'title="Confidence level \\(locked\\)"')

        # no tooltip stays no tooltip
        attr(x, "description") <- ""
        html <- as.character(pub_param_input(x, "x", tooltip = TRUE))
        expect_no_match(html, "pubflow-tooltip")
    })

    it("rejects param groups that contain param groups", {
        g <- param_group(list(inner = param_group(list(n = param(1)))))

        expect_error(pub_param_input(g, "g"), "can't contain param groups")
    })

    it("signals errors for unsupported params and widgets", {
        expect_error(pub_param_input(1, "a"), "must be a 'param' object")
        expect_error(pub_param_input(param(1), c("a", "b")), "inputId")
        expect_error(pub_param_input(param(1), ""), "non-empty string")
        expect_error(pub_param_input(param(1), NA_character_), "inputId")
        expect_error(
            pub_param_input(param(Sys.Date()), "d"),
            "type 'Date'.*ui_widget"
        )
        expect_error(
            pub_param_input(param("a", ui_widget = "spinner"), "a"),
            "Unknown widget 'spinner'"
        )
        expect_error(
            pub_param_input(param("a", ui_widget = 1), "a"),
            "widget name or function"
        )
        expect_error(
            pub_param_input(param(c("a", "b")), "a"),
            "'text' input for 'a' from a value of length 2"
        )
        expect_error(
            pub_param_input(param(c(TRUE, FALSE)), "a"),
            "'switch' input for 'a' from a value of length 2"
        )
        expect_error(
            pub_param_input(numeric_param(c(1, 2)), "a"),
            "'numeric' input for 'a' from a value of length 2"
        )
        expect_error(
            pub_param_input(
                numeric_param(1:3, min = 0, max = 5, ui_widget = "slider"),
                "a"
            ),
            "'slider' input for 'a' from a value of length 3"
        )
        expect_error(
            pub_param_input(numeric_param(1, ui_widget = "slider"), "a"),
            "finite attributes `min` and `max`"
        )
        expect_error(
            pub_param_input(param("a", ui_args = list(1)), "a"),
            "`ui_args` of 'a' must be a named list"
        )
        expect_error(
            pub_param_input(param("a", ui_args = "x"), "a"),
            "`ui_args` of 'a' must be a named list"
        )
    })
})

describe(".input_ids()", {
    it("gives the id of a single param and <id>_<child> for groups", {
        expect_equal(.input_ids(param(1), "x"), "x")
        expect_equal(
            .input_ids(demo_limits_param(), "l"),
            c(lower = "l_lower", upper = "l_upper")
        )
    })
})


# ======================================================================================
# Parameter table
# ======================================================================================

# -----
# Table
# -----

describe(".params_table()", {
    opts <- .module_options()
    ns <- shiny::NS("p")

    it("shows label and input per param with ids ns(name)", {
        params <- list(alpha = numeric_param(0.05, label = "Significance"))
        html <- html_of(.params_table(params, ns, opts))

        expect_match(
            html,
            paste0(
                '<label class="pubflow-param-label" for="p-alpha" ',
                'title="Significance">'
            )
        )
        expect_match(html, '<input id="p-alpha" type="number"')
        expect_match(html, 'style="width:15ch;"')
        expect_match(html, 'data-update-on="blur"')
        expect_match(html, 'class="[^"]*pubflow-tooltip"')

        opts$update_on <- "change"
        opts$tooltips <- FALSE
        opts$width <- NULL
        html <- html_of(.params_table(params, ns, opts))
        expect_match(html, 'data-update-on="change"')
        expect_no_match(html, "pubflow-tooltip|width:")
    })

    it("adds a heading per group if there is more than one group", {
        params <- list(
            a = param(1, area = "analysis"),
            b = param(2, area = "report"),
            c = param(3, area = "analysis"),
            d = param(4)
        )
        html <- html_of(.params_table(params, ns, opts))
        headings <- regmatches(
            html,
            gregexpr('pubflow-params-heading">[^<]*', html)
        )[[1]]
        expect_equal(
            sub(".*>", "", headings),
            c("analysis", "report", "Other")
        )
        expect_match(html, "p-a.*p-c.*p-b.*p-d")

        opts$group_labels <- c(analysis = "Analysis", report = "Report")
        html <- html_of(.params_table(params, ns, opts))
        expect_match(html, ">Analysis<.*>Report<.*>Other<")

        for (params in list(params[c("a", "c")], params)) {
            opts$group_by <- if (length(params) == 4L) NULL else "area"
            html <- html_of(.params_table(params, ns, opts))
            expect_no_match(html, "pubflow-params-heading|<fieldset")
        }
    })

    it("gives each group as a fieldset with its heading as legend", {
        params <- list(a = param(1, area = "x"), b = param(2, area = "y"))
        html <- html_of(.params_table(params, ns, opts))
        sections <- gregexpr(
            paste0(
                '<fieldset class="pubflow-params-section">\\s*',
                '<legend class="pubflow-params-heading">'
            ),
            html
        )
        expect_length(sections[[1]], 2L)
        expect_no_match(html, "<h[1-6]")
    })

    it("puts advanced params into a collapsed block per group", {
        params <- list(
            a = param(1, area = "x"),
            b = param(2, area = "x", advanced = TRUE),
            c = param(3, area = "y", advanced = TRUE)
        )
        html <- html_of(.params_table(params, ns, opts))

        blocks <- gregexpr('<details class="pubflow-params-advanced">', html)
        expect_length(blocks[[1]], 2L)
        expect_match(html, "p-a.*<details.*<summary>Advanced</summary>.*p-b")
        expect_match(html, ">y</legend>\\s*<details")
        expect_no_match(html, "<details open")
    })

    it("keeps the order of the params and gives an empty table for none", {
        params <- list(b = param(1), a = param(2))
        expect_match(html_of(.params_table(params, ns, opts)), "p-b.*p-a")

        html <- html_of(.params_table(list(), ns, opts))
        expect_equal(html, '<div class="pubflow-params-table"></div>')
    })

    it("puts params with a non-string group value under 'Other'", {
        params <- list(
            a = param(1, area = 1),
            b = param(2, area = c("x", "y")),
            c = param(3, area = "z")
        )
        html <- html_of(.params_table(params, ns, opts))
        expect_match(html, ">Other</legend>.*p-a.*p-b.*>z</legend>.*p-c")
    })

    it("gives only the advanced block if all params are advanced", {
        params <- list(a = param(1, advanced = TRUE))
        html <- html_of(.params_table(params, ns, opts))
        expect_match(
            html,
            '<div class="pubflow-params-table">\\s*<details'
        )
        expect_length(gregexpr("<table", html)[[1]], 1L)
    })

    it("adds the reset button if requested", {
        params <- list(a = param(1))
        expect_no_match(html_of(.params_table(params, ns, opts)), "reset")

        opts$reset <- TRUE
        expect_match(
            html_of(.params_table(params, ns, opts)),
            '<button class="btn [^"]*pubflow-params-reset" id="p-pubflow-reset"'
        )
    })

    it("styles inputs with the attribute ui_style", {
        params <- list(
            x.y = param(1, ui_style = "height: 30px;"),
            g = param_group(list(a = param("a", ui_style = "color: red;")))
        )
        html <- html_of(.params_table(params, ns, opts))

        expect_match(html, "<style>#p-x\\\\.y \\{height: 30px;\\}</style>")
        expect_match(html, "<style>#p-g_a \\{color: red;\\}</style>")

        # no style tag without (non-empty) ui_style
        params <- list(g = param_group(list(a = param(1, ui_style = ""))))
        expect_no_match(html_of(.params_table(params, ns, opts)), "<style>")
        expect_equal(.escape_css_id("a b:c-d_1"), "a\\ b\\:c-d_1")
    })

    it("names a group around inputs that the label can't point to", {
        params <- list(
            oo = choice_param(
                "on",
                c("on", "off"),
                label = "On/Off",
                ui_widget = "radio"
            ),
            g = param_group(list(b = param(TRUE), c = param("c")), label = "G")
        )
        html <- html_of(.params_table(params, ns, opts))
        for (name in c("oo", "g")) {
            id <- sprintf("p-%s-param-label", name)
            expect_match(
                html,
                sprintf('<label class="pubflow-param-label" id="%s" title=', id)
            )
            expect_match(
                html,
                sprintf('<div role="group" aria-labelledby="%s">', id)
            )
        }
        expect_no_match(html, 'class="pubflow-param-label" for=')
        # the group's own row has no second name
        expect_match(html, '<div class="pubflow-param-group"( style="[^"]*")?>')
    })

    it("marks the label of a locked param", {
        params <- list(a = param(1, label = "Alpha", locked = TRUE), b = param(2))
        html <- html_of(.params_table(params, ns, opts))

        expect_match(
            html,
            paste0(
                '<label class="pubflow-param-label pubflow-param-label-locked" ',
                'for="p-a" title="Alpha \\(locked\\)">Alpha</label>'
            )
        )
        expect_match(
            html,
            '<label class="pubflow-param-label" for="p-b" title="parameter">'
        )
    })
})


# ======================================================================================
# Scenarios
# ======================================================================================

# ------------
# UI snapshots
# ------------

describe("UI snapshots", {
    params <- unclass(ui_test_params())
    params$limits <- demo_limits_param()
    params$area <- param("a", label = "With area", area = "extra", advanced = TRUE)
    # without the reset button: shiny < 1.12 renders actionButton() labels differently
    opts <- .module_options()
    table <- .params_table(params, shiny::NS("params"), opts)

    for (bs in c("3", "5")) {
        it(sprintf("renders the parameter table with Bootstrap %s", bs), {
            skip_if_not_installed("bslib")
            rendered <- render_page(table, bootstrap = bs)

            expect_match(bootstrap_version(rendered), paste0("^", bs, "\\."))
            expect_snapshot(cat(as.character(rendered$html)))
        })
    }
})
