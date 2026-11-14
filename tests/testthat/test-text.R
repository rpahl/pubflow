describe("pub_text()", {
    it("joins lines and sets the title", {
        x <- pub_text(c("First line", "second line"), title = "Note")

        expect_identical(as.vector(x), "First line\nsecond line")
        expect_identical(pub_meta(x), list(title = "Note"))
        expect_identical(pub_type(x), "text")
    })

    it("keeps metadata of the input", {
        x <- pub_set_meta(c("a", "b"), title = "Old", id = "t1")

        expect_identical(pub_meta(pub_text(x)), list(title = "Old", id = "t1"))
        expect_identical(pub_meta(pub_text(x, title = "New"))$title, "New")
        expect_null(attributes(pub_text("plain")))
    })

    it("accepts every element of the supported Markdown subset", {
        elements <- list(
            paragraphs = c("First paragraph.", "", "Second paragraph."),
            italic = "Some *italic* text",
            bold = "Some **bold** text",
            code = "Call `pub_text()`",
            link = "See [pubflow](https://github.com/rpahl/pubflow)",
            bullets = c("- one", "- two"),
            ordered = c("1. one", "2. two"),
            line_break = c("first\\", "second"),
            inline_math = "The slope $\\beta_1 < 0$",
            display_math = c("Model:", "", "$$", "y = a + b x", "$$"),
            placeholder = "See [<insert link>]{.placeholder}.",
            code_block = c("```", "# a comment, not a heading", "x <- 1", "```"),
            hash_tag = "#hashtag and C# are no headings"
        )
        for (name in names(elements)) {
            expect_identical(
                as.vector(pub_text(elements[[name]])),
                paste(elements[[name]], collapse = "\n"),
                label = name
            )
        }
    })

    it("signals an error for headings", {
        for (level in 1:6) {
            heading <- paste(strrep("#", level), "Results")
            expect_error(
                pub_text(c("Intro", "", heading)),
                sprintf("line 3: \"%s\"", heading)
            )
        }
        expect_error(pub_text(c("Results", "=======")), "must not contain headings")
        expect_error(pub_text(c("", "Results", "---")), "line 2: \"Results\"")
        expect_error(pub_text("- # in a list"), "must not contain headings")
    })

    it("lists all headings in the message", {
        err <- expect_error(pub_text(c("# A", "text", "", "## B")))

        expect_match(conditionMessage(err), "line 1: \"# A\"")
        expect_match(conditionMessage(err), "line 4: \"## B\"")
    })

    it("validates its input", {
        expect_error(pub_text(1), "character vector")
        expect_error(pub_text(c("a", NA)), "without `NA`")
        expect_error(pub_text("a", title = 1), "`title` must be")
        expect_error(pub_text(factor("a")), "character vector")
        expect_error(pub_text("a", title = NA_character_), "`title` must be")
        expect_error(pub_text("a", title = c("a", "b")), "`title` must be")
    })

    it("counts lines with embedded line breaks in the message", {
        expect_error(pub_text(c("a\nb", "# C")), "line 3: \"# C\"")
    })

    it("finds headings in block quotes", {
        expect_error(pub_text("> # Quoted"), "line 1: \"> # Quoted\"")
    })

    it("quotes the line without the carriage return of Windows line endings", {
        err <- expect_error(pub_text("a\r\n# B\r\nc"), "line 2")
        expect_match(conditionMessage(err), "line 2: \"# B\"$")
        expect_error(pub_text("a\r# B"), "line 2: \"# B\"")
    })

    it("reports the error from pub_text()", {
        err <- expect_error(pub_text("# A"))

        expect_identical(err$call, quote(pub_text("# A")))
    })
})

describe(".check_markdown()", {
    it("returns the text invisibly if there are no headings", {
        expect_invisible(res <- .check_markdown("plain"))
        expect_identical(res, "plain")
        expect_identical(.check_markdown(""), "")
    })

    it("names the text and the caller in the error", {
        err <- expect_error(
            .check_markdown("# A", what = "Section text", call = quote(f())),
            "^Section text must not contain headings"
        )

        expect_identical(err$call, quote(f()))
    })
})

describe("pub_md_escape()", {
    it("escapes inline syntax and block starts", {
        expect_identical(
            pub_md_escape(c("*A* $5 @fig:x {.c}", "1. one", "- item", "> q")),
            c("\\*A\\* \\$5 \\@fig:x \\{.c\\}", "1\\. one", "\\- item", "\\> q")
        )
    })

    it("puts the text on one line but keeps single outer spaces", {
        expect_identical(pub_md_escape(" a\n\n b\t c  "), " a b c ")
        expect_identical(pub_md_escape("\n- x"), " \\- x")
        expect_identical(pub_md_escape("  12) x"), " 12\\) x")
    })

    it("leaves numbers alone", {
        expect_identical(
            pub_md_escape(c("-1.5", "+2", "0.95", "1.")),
            c("-1.5", "+2", "0.95", "1\\.")
        )
    })

    it("is vectorised and keeps empty strings and NA", {
        expect_identical(pub_md_escape(character()), character())
        expect_identical(pub_md_escape(c("", NA, "3")), c("", NA, "3"))
    })

    it("shows the text as it is in a document", {
        strings <- c(
            "Mean *Ozone* (Month #5_a)",
            "1. Main Street",
            "<b>B</b> & $5 and $6",
            "x^2^ H~2~O @fig:x [l](u) {.c} `c` a\\b"
        )
        md <- c(
            paste0("Before ", pub_md_escape(strings), " after."),
            pub_md_escape(strings)
        )
        html <- pub_html(pub_doc(pub_text(paste(md, collapse = "\n\n"))))
        paras <- xml2::xml_text(xml2::xml_find_all(xml2::read_html(html), "//p"))

        expect_identical(
            paras,
            c(paste0("Before ", strings, " after."), strings)
        )
    })

    it("takes factors", {
        expect_identical(pub_md_escape(factor(c("*a*", NA))), c("\\*a\\*", NA))
    })

    it("rejects input that isn't character", {
        expect_error(pub_md_escape(1), "must be a character vector")
        expect_error(pub_md_escape(NULL), "must be a character vector")
    })
})
