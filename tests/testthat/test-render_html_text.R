describe(".markdown_html()", {
    html <- function(text) .markdown_html(text)$html

    it("converts CommonMark", {
        expect_identical(
            html("Some **bold** and *italic* text.\n\n- a\n- b"),
            paste0(
                "<p>Some <strong>bold</strong> and <em>italic</em> ",
                "text.</p>\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n"
            )
        )
    })

    it("restores inline and display math for MathJax", {
        res <- .markdown_html("Model $y = a + b \\cdot t$.\n\n$$\nx < 1\n$$")

        expect_true(res$math)
        expect_match(
            res$html,
            paste0(
                "<p>Model <span class=\"pubflow-math\">",
                "\\(y = a + b \\cdot t\\)</span>.</p>"
            ),
            fixed = TRUE
        )
        expect_match(
            res$html,
            paste0(
                "<span class=\"pubflow-math pubflow-math-display\">",
                "\\[x &lt; 1\\]</span>"
            ),
            fixed = TRUE
        )
    })

    it("follows Pandoc's rules for inline math", {
        res <- .markdown_html("costs $5 and $10, \\$x\\$ and $ y $.")

        expect_false(res$math)
        expect_identical(res$html, "<p>costs $5 and $10, $x$ and $ y $.</p>\n")
    })

    it("converts placeholder spans, escaping their text", {
        expect_identical(
            html("See [<insert link>]{.placeholder}."),
            paste0(
                "<p>See <span class=\"pubflow-placeholder\">",
                "&lt;insert link&gt;</span>.</p>\n"
            )
        )
    })

    it("escapes raw HTML", {
        out <- html("a <b>x</b> <script>alert(1)</script>")

        expect_false(grepl("<script>", out, fixed = TRUE))
        expect_false(grepl("<b>", out, fixed = TRUE))
        expect_match(out, "&lt;script&gt;alert(1)&lt;/script&gt;", fixed = TRUE)
    })

    it("escapes raw HTML as CommonMark parses it", {
        # not a fence: the info string of a backtick fence has no backticks
        expect_identical(
            html("```foo`\n<script>alert(1)</script>"),
            "<p>```foo`\n&lt;script&gt;alert(1)&lt;/script&gt;</p>\n"
        )
        # HTML inside an attribute, an HTML block, text before (UTF-8)
        nested <- html("\u00fc <a title=\"<b>x</b>\">link</a>")
        expect_false(grepl("<a|<b", nested))
        expect_identical(
            html("<div>\nblock\n</div>"),
            "<p>&lt;div&gt;\nblock\n&lt;/div&gt;</p>\n"
        )
    })

    it("leaves code in list items and indented code alone", {
        out <- html(paste(
            "- item",
            "",
            "    ```",
            "    x < y",
            "    ```",
            "",
            "        code < indented",
            sep = "\n"
        ))

        expect_match(out, "<pre><code>x &lt; y\n</code></pre>", fixed = TRUE)
        expect_match(out, "<code>  code &lt; indented\n", fixed = TRUE)
    })

    it("leaves code spans and fenced code blocks as they are", {
        out <- html(paste(
            "Code `a $b$ <c>` and ``x ` y``.",
            "",
            "```r",
            "x <- '$a$'",
            "```",
            "",
            "~~~",
            "[y]{.placeholder}",
            "~~~",
            sep = "\n"
        ))

        expect_match(out, "<code>a $b$ &lt;c&gt;</code>", fixed = TRUE)
        expect_match(out, "<code>x ` y</code>", fixed = TRUE)
        expect_match(out, "x &lt;- '$a$'", fixed = TRUE)
        expect_match(out, "[y]{.placeholder}", fixed = TRUE)
        expect_false(grepl("\\(", out, fixed = TRUE))
    })

    it("starts no code span at an escaped backtick", {
        out <- html("a \\` $x$ b \\` and \\\\`$y$` and `c\\` $z$")

        expect_match(
            out,
            "a ` <span class=\"pubflow-math\">\\(x\\)</span> b `",
            fixed = TRUE
        )
        expect_match(out, "\\<code>$y$</code>", fixed = TRUE)
        expect_match(
            out,
            "<code>c\\</code> <span class=\"pubflow-math\">",
            fixed = TRUE
        )
    })

    it("handles an unclosed code fence and text without lines", {
        expect_match(html("```\n$a$"), "<code>$a$\n</code>", fixed = TRUE)
        expect_identical(html(""), "")
        expect_identical(html("text\n"), "<p>text</p>\n")
    })

    it("keeps backslashes in math and placeholders", {
        # the replacements are inserted literally, not as regex replacements
        expect_identical(
            html("$a \\\\ b$ [c\\\\d]{.placeholder}"),
            paste0(
                "<p><span class=\"pubflow-math\">\\(a \\\\ b\\)</span> ",
                "<span class=\"pubflow-placeholder\">c\\\\d</span></p>\n"
            )
        )
    })

    it("leaves unclosed and adjacent dollars as text", {
        for (text in c("$$ unclosed", "$x unclosed", "$x$$y$")) {
            res <- .markdown_html(text)
            expect_false(res$math)
            expect_identical(res$html, paste0("<p>", text, "</p>\n"))
        }
    })

    it("converts empty and repeated placeholders, which are not math", {
        res <- .markdown_html("[]{.placeholder}, [a]{.placeholder} [a]{.placeholder}")

        expect_false(res$math)
        expect_identical(
            res$html,
            paste0(
                "<p><span class=\"pubflow-placeholder\"></span>, ",
                "<span class=\"pubflow-placeholder\">a</span> ",
                "<span class=\"pubflow-placeholder\">a</span></p>\n"
            )
        )
    })

    it("keeps parts nested in placeholders and math literal, escaped", {
        expect_identical(
            html(
                "[$x$]{.placeholder} [`<script>`]{.placeholder} [`a]b`]{.placeholder}"
            ),
            paste0(
                "<p><span class=\"pubflow-placeholder\">$x$</span> ",
                "<span class=\"pubflow-placeholder\">`&lt;script&gt;`</span> ",
                "<span class=\"pubflow-placeholder\">`a]b`</span></p>\n"
            )
        )
        expect_identical(
            html("$a `<b>` c$"),
            "<p><span class=\"pubflow-math\">\\(a `&lt;b&gt;` c\\)</span></p>\n"
        )
    })

    it("escapes HTML comments, processing instructions and CDATA", {
        expect_identical(
            html("<!-- c --> <?php x ?> <![CDATA[x]]>"),
            "<p>&lt;!-- c --&gt; &lt;?php x ?&gt; &lt;![CDATA[x]]&gt;</p>\n"
        )
    })

    it("keeps autolinks, entities and a lone `<`", {
        expect_identical(
            html("<http://a.b> a &lt; b <"),
            "<p><a href=\"http://a.b\">http://a.b</a> a &lt; b &lt;</p>\n"
        )
    })
})

describe(".split_fenced_code()", {
    it("splits text and fenced code blocks, fences included", {
        chunks <- .split_fenced_code("a\n```r\nx\n```\nb")

        expect_identical(unlist(chunks), c("a", "```r\nx\n```", "b"))
        expect_identical(
            vapply(chunks, attr, logical(1), "code"),
            c(FALSE, TRUE, FALSE)
        )
    })

    it("closes a fence only with at least as many of its characters", {
        chunks <- .split_fenced_code("````\n```\n~~~~\n`````\nb")

        expect_identical(unlist(chunks), c("````\n```\n~~~~\n`````", "b"))
        expect_identical(
            unlist(.split_fenced_code("~~~\n```\n~~~ \nb")),
            c("~~~\n```\n~~~ ", "b")
        )
    })

    it("returns no chunks for empty text", {
        expect_identical(.split_fenced_code(""), list())
    })
})

describe(".escape_starts()", {
    it("escapes the first `<` at or after each start, from the right", {
        starts <- data.frame(line = c(1L, 1L, 2L), col = c(1L, 4L, 1L))

        expect_identical(
            .escape_starts("<a <b <c\nx <y", starts),
            "&lt;a &lt;b <c\nx &lt;y"
        )
    })

    it("leaves a line without `<` after the start as it is", {
        starts <- data.frame(line = 1L, col = 4L)

        expect_identical(.escape_starts("a < b", starts), "a < b")
    })
})
