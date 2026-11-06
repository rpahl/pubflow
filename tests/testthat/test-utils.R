describe("%||%", {
    it("returns y only if x is NULL", {
        expect_identical(NULL %||% 2, 2)
        expect_identical(FALSE %||% 1, FALSE)
        expect_identical(NA %||% 1, NA)
        expect_identical(list() %||% 1, list())
        expect_null(NULL %||% NULL)
    })

    it("evaluates y only if it is needed", {
        expect_identical(1 %||% stop("evaluated"), 1)
    })
})

describe(".file_op()", {
    it("returns success and the last warning as reason, without warning", {
        expect_identical(.file_op(TRUE), list(ok = TRUE, reason = NULL))
        expect_identical(.file_op(c(TRUE, TRUE))$ok, TRUE)
        expect_no_warning(
            res <- .file_op({
                warning("first")
                warning("second")
                c(TRUE, FALSE)
            })
        )
        expect_identical(res, list(ok = FALSE, reason = "second"))
    })
})

describe(".is_positive_number()", {
    it("is TRUE for one number greater than zero", {
        expect_true(.is_positive_number(0.5))
        expect_true(.is_positive_number(3L))
        expect_false(.is_positive_number(0))
        expect_false(.is_positive_number(-1))
        expect_false(.is_positive_number(NA_real_))
        expect_false(.is_positive_number(c(1, 2)))
        expect_false(.is_positive_number("1"))
    })

    it("is FALSE for NULL, empty, NaN and logical values", {
        expect_false(.is_positive_number(NULL))
        expect_false(.is_positive_number(numeric()))
        expect_false(.is_positive_number(NaN))
        expect_false(.is_positive_number(NA_integer_))
        expect_false(.is_positive_number(TRUE))
    })

    it("is FALSE for Inf", {
        expect_false(.is_positive_number(Inf))
        expect_false(.is_positive_number(-Inf))
    })
})

describe(".join_lines()", {
    it("joins the lines with LF and turns CRLF and CR into LF", {
        expect_identical(.join_lines(c("a\r\nb", "c\rd", "e\n")), "a\nb\nc\nd\ne\n")
        expect_identical(.join_lines(character()), "")
    })
})

describe(".cnd_message()", {
    it("drops the ANSI colours of rlang's bullets", {
        withr::local_options(cli.num_colors = 256L)
        e <- tryCatch(
            rlang::abort(c("Can't do it:", x = "bad", i = "info")),
            error = identity
        )
        expect_match(conditionMessage(e), "\033[", fixed = TRUE)
        text <- .cnd_message(e)
        expect_no_match(text, "\033", fixed = TRUE)
        expect_match(text, "^Can't do it:\n.* bad\n.* info$")
        expect_identical(.cnd_message(simpleError("plain")), "plain")
    })

    it("drops hyperlinks (OSC 8)", {
        link <- "\033]8;;https://x.org\ahere\033]8;;\a"
        e <- simpleError(paste("\033[1mUse\033[22m", link))
        expect_identical(.cnd_message(e), "Use here")
    })
})

describe(".unlist1()", {
    it("removes one level of nesting only", {
        x <- list(list(1, list(2)), NULL, list(a = 3))

        expect_identical(.unlist1(x), list(1, list(2), a = 3))
        expect_identical(.unlist1(x, use.names = FALSE), list(1, list(2), 3))
        expect_null(.unlist1(list()))
    })
})

describe(".first_line()", {
    it("keeps lines up to `width` and shortens longer ones", {
        expect_identical(.first_line(strrep("a", 10L), 10L), strrep("a", 10L))
        expect_identical(
            .first_line(strrep("a", 11L), 10L),
            paste0(strrep("a", 7L), "...")
        )
    })

    it("takes the first line of the joined text", {
        expect_identical(.first_line(c("one", "two"), 10L), "one")
        expect_identical(.first_line("one\ntwo", 10L), "one")
        expect_identical(.first_line(character(), 10L), "")
        expect_identical(.first_line("", 10L), "")
        expect_identical(.first_line("\n  \nabc", 10L), "abc")
        expect_identical(.first_line(c("", "x"), 10L), "x")
    })
})
