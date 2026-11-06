# ------------
# Pandoc input
# ------------

describe(".markdown_pandoc()", {
    docx <- function(text) .markdown_pandoc(text, "docx")
    pandoc_native <- function(text) {
        pandoc <- skip_if_no_pandoc()
        input <- withr::local_tempfile(fileext = ".md")
        writeLines(enc2utf8(text), input, useBytes = TRUE)
        out <- system2(
            pandoc,
            c("-f", .pandoc_reader(), "-t", "native", shQuote(input)),
            stdout = TRUE
        )
        paste(out, collapse = "\n")
    }
    hostile <- c(
        "<b>bold</b> and <script>alert(1)</script>",
        "`x`{=latex} and ``y ` z``{=openxml} and `q`{.cls}",
        "```{=latex}\n\\input{/etc/passwd}\n```",
        "~~~ {=openxml}\n<w:p/>\n~~~",
        "- item `x`{=html}\n\n> quote `y`{=latex}",
        "[text]{.class} and [x]{custom-style=\"Title\"}",
        "::: {custom-style=\"Error\"}\nboxed\n:::",
        "  ::: warning\n  text\n  :::",
        "![img](x.png){width=10%} and [a](b){=latex}",
        "\\input{x} and \\textbf{y}",
        "a \\{b} and `x`\\{=latex} and `y`\\\\{=latex} and `z\\`{=latex}"
    )

    it("escapes raw HTML", {
        expect_identical(docx("a <b>x</b>"), "a &lt;b>x&lt;/b>")
    })

    it("escapes raw attributes, spans and divs in text", {
        expect_identical(
            docx("`x`{=latex} and ``y``{=openxml}"),
            "`x`\\{=latex} and ``y``\\{=openxml}"
        )
        expect_identical(docx("[x]{.foo}"), "[x]\\{.foo}")
        # parts nested in placeholders and math stay literal
        expect_identical(
            docx("[$x$]{.placeholder} $a `b` c$"),
            "[\\$x\\$]{custom-style=\"Placeholder\"} $a `b` c$"
        )
        expect_identical(
            .markdown_pandoc("[`x`]{.placeholder}", "latex"),
            paste0(
                "`\\textcolor[HTML]{0083C0}{`{=latex}\\`x\\``}`{=latex}"
            )
        )
        expect_identical(docx("::: {.note}\nx\n:::"), "\\::: \\{.note}\nx\n\\:::")
        expect_identical(docx("- a {b}\n\n> :::"), "- a \\{b}\n\n> \\:::")
    })

    it("escapes a brace only once", {
        expect_identical(docx("a \\{b}"), "a \\{b}")
        expect_identical(docx("a \\\\{b}"), "a \\\\\\{b}")
        expect_identical(docx("`x\\`{=latex}"), "`x\\`\\{=latex}")
    })

    it("escapes only what commonmark parses as text", {
        expect_identical(docx("`{x}`"), "`{x}`")
        expect_identical(docx("    {code}"), "    {code}")
        expect_identical(docx("a ::: b"), "a ::: b")
        expect_identical(docx("*{x}* [{y}](u)"), "*\\{x}* [\\{y}](u)")
        expect_identical(
            docx("| a {b} |\n|---|\n| {c} |"),
            "| a \\{b} |\n|---|\n| \\{c} |"
        )
    })

    it("counts columns in bytes and keeps the encoding", {
        out <- docx("\u00e4 {x} \u00f6 {y}")
        expect_identical(out, "\u00e4 \\{x} \u00f6 \\{y}")
        expect_identical(Encoding(out), "UTF-8")
    })

    it("returns text without extension syntax as it is", {
        expect_identical(docx(""), "")
        expect_identical(docx("plain *text*"), "plain *text*")
    })

    it("keeps only the language of fenced code blocks", {
        expect_identical(docx("```{=latex}\n\\input{x}\n```"), "```\n\\input{x}\n```")
        expect_identical(docx("~~~ r {.cls}\nx <- 1\n~~~"), "~~~r\nx <- 1\n~~~")
        expect_identical(
            docx("   ````r{=latex} x\n{y}\n   ````"),
            "   ````r\n{y}\n   ````"
        )
        expect_identical(
            docx("```\n[x]{.placeholder}\n```"),
            "```\n[x]{.placeholder}\n```"
        )
    })

    it("leaves code, math and autolinks alone", {
        text <- paste(
            "`{=latex}` and `<b>`, $\\frac{a}{b}$, $a<b>c$,",
            "<https://example.org/{a}>\n\n$$\n\\left\\{x\\right\\}\n$$"
        )
        expect_identical(docx(text), text)
    })

    it("writes placeholders in the target's form", {
        expect_identical(
            docx("See [<insert *link*>]{.placeholder}."),
            "See [\\<insert \\*link\\*\\>]{custom-style=\"Placeholder\"}."
        )
        expect_identical(
            .markdown_pandoc("[todo]{.placeholder}", "md"),
            "[todo]{.placeholder}"
        )
        expect_identical(
            .markdown_pandoc("[a_b]{.placeholder}", "latex", "0083c0"),
            "`\\textcolor[HTML]{0083C0}{`{=latex}a\\_b`}`{=latex}"
        )
        expect_identical(
            .markdown_pandoc("[a]{.placeholder}", "typst", "0083C0"),
            "`#text(fill: rgb(\"#0083c0\"))[`{=typst}a`]`{=typst}"
        )
        expect_identical(
            .markdown_pandoc("$x$ [a&b <c>]{.placeholder}", "typst", "FF0000"),
            "$x$ `#text(fill: rgb(\"#ff0000\"))[`{=typst}a\\&b \\<c\\>`]`{=typst}"
        )
        expect_identical(
            .markdown_pandoc("<b>[a]{.placeholder}</b>", "docx", "FF0000"),
            "&lt;b>[a]{custom-style=\"Placeholder\"}&lt;/b>"
        )
    })

    it("reads captioned images as figures for LaTeX and Typst only", {
        expect_false(grepl("implicit_figures", .pandoc_reader("docx")))
        expect_match(.pandoc_reader("latex"), "\\+implicit_figures$")
        expect_match(.pandoc_reader("typst"), "\\+implicit_figures$")
    })

    it("doesn't change what CommonMark shows (but the code language)", {
        for (text in hostile) {
            expected <- commonmark::markdown_html(.escape_raw_html(text))
            expect_identical(
                commonmark::markdown_html(.markdown_pandoc(text, "md")),
                gsub(" class=\"language-\\{[^\"]*\"", "", expected),
                info = text
            )
        }
    })

    it("leaves pandoc no raw content, spans or divs", {
        for (text in hostile) {
            native <- pandoc_native(docx(text))
            expect_false(grepl("Raw|Span|Div|\"width\"", native), info = text)
        }
        native <- pandoc_native(docx("A [todo]{.placeholder}."))
        expect_match(native, "( \"custom-style\" , \"Placeholder\" )", fixed = TRUE)
    })
})


# --------
# Escaping
# --------

describe(".escape_extensions()", {
    it("keeps trailing newlines", {
        expect_identical(.escape_extensions("a {b}\n"), "a \\{b}\n")
        expect_identical(.escape_extensions("a {b}\n\n"), "a \\{b}\n\n")
        expect_identical(.escape_extensions("a {b}"), "a \\{b}")
    })
})

describe(".escape_literal()", {
    pandoc_plain <- function(text) {
        pandoc <- skip_if_no_pandoc()
        input <- withr::local_tempfile(fileext = ".md")
        writeLines(enc2utf8(text), input, useBytes = TRUE)
        out <- system2(
            pandoc,
            c("-f", .pandoc_reader(), "-t", "plain", "--wrap=none", shQuote(input)),
            stdout = TRUE
        )
        paste(out, collapse = "\n")
    }

    it("puts a string on one line", {
        expect_identical(.escape_literal(" a\n b\t c "), "a b c")
    })

    it("is vectorised and keeps empty strings and NA", {
        expect_identical(.escape_literal(character()), character())
        expect_identical(
            .escape_literal(c("", NA, "10. x", "+1", "3")),
            c("", NA, "10\\. x", "\\+1", "3")
        )
    })

    it("makes pandoc read the string as it is", {
        strings <- c(
            "# Heading",
            "- item",
            "+ item",
            "1. one",
            "2) two",
            "> quote",
            "::: div",
            "= setext",
            "A {#id .cls}",
            "$x$ and $$y$$",
            "<b>bold</b>",
            "*em* _u_ `code` ~~s~~",
            "[link](url)",
            "![img](x.png)",
            "a\\b",
            "x^2^ and H~2~O",
            "@cite",
            "end \\",
            "&amp; entity",
            "|pipe|",
            "Table: caption",
            "100% <1e-04"
        )
        for (s in strings) {
            expect_identical(pandoc_plain(.escape_literal(s)), s, info = s)
        }
    })
})
