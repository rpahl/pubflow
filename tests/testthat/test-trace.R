describe("pub_trace_stamp()", {
    noon <- as.POSIXct("2026-10-07 12:00:05", tz = "UTC")
    meta <- list(author = "Jane Doe", time = noon, app = "myapp", version = "1.2.0")

    it("names the author, the time in UTC and the application", {
        expect_identical(
            pub_trace_stamp(meta),
            "Jane Doe at 07-Oct-2026 12:00:05 UTC (myapp v1.2.0)"
        )
        local <- as.POSIXct("2026-10-07 14:00:05", tz = "Europe/Berlin")
        expect_identical(
            pub_trace_stamp(utils::modifyList(meta, list(time = local))),
            pub_trace_stamp(meta)
        )
        expect_identical(pub_trace_stamp(pub_doc(meta = meta)), pub_trace_stamp(meta))
    })

    it("leaves out the application or its version if missing", {
        expect_identical(
            pub_trace_stamp(meta[c("author", "time", "app")]),
            "Jane Doe at 07-Oct-2026 12:00:05 UTC (myapp)"
        )
        expect_identical(
            pub_trace_stamp(meta[c("author", "time", "version")]),
            "Jane Doe at 07-Oct-2026 12:00:05 UTC"
        )
    })

    it("treats blank strings as missing", {
        expect_identical(
            pub_trace_stamp(utils::modifyList(meta, list(app = "", version = " "))),
            "Jane Doe at 07-Oct-2026 12:00:05 UTC"
        )
        expect_identical(
            pub_trace_stamp(utils::modifyList(meta, list(version = ""))),
            "Jane Doe at 07-Oct-2026 12:00:05 UTC (myapp)"
        )
        expect_error(
            pub_trace_stamp(utils::modifyList(meta, list(author = ""))),
            "needs the metadata `author`"
        )
    })

    it("uses English month names", {
        months <- vapply(
            1:12,
            \(m) {
                time <- as.POSIXct(sprintf("2026-%02d-01 00:00:00", m), tz = "UTC")
                pub_trace_stamp(list(author = "A", time = time))
            },
            character(1)
        )

        expect_identical(substr(months, 9L, 11L), month.abb)
    })

    it("doesn't depend on the locale", {
        expected <- pub_trace_stamp(meta)
        german <- suppressWarnings(withr::with_locale(
            c(LC_TIME = "de_DE.UTF-8"),
            format(noon, "%b")
        ))
        skip_if_not(identical(german, "Okt"), "no German locale")
        withr::local_locale(c(LC_TIME = "de_DE.UTF-8"))

        expect_identical(pub_trace_stamp(meta), expected)
    })

    it("truncates the seconds instead of rounding them", {
        time <- as.POSIXct("2026-12-31 23:59:59.999", tz = "UTC")

        expect_identical(
            pub_trace_stamp(list(author = "A", time = time)),
            "A at 31-Dec-2026 23:59:59 UTC"
        )
    })

    it("keeps special characters of the metadata as they are", {
        stamp <- pub_trace_stamp(list(
            author = "A\\1 %s $1",
            time = noon,
            app = "a%d",
            version = "\\0"
        ))

        expect_identical(stamp, "A\\1 %s $1 at 07-Oct-2026 12:00:05 UTC (a%d v\\0)")
    })

    it("uses the time now without a time", {
        stamp <- pub_trace_stamp(list(author = "A"))

        expect_match(stamp, "^A at [0-9]{2}-[A-Z][a-z]{2}-[0-9]{4} [0-9:]{8} UTC$")
    })

    it("needs an author", {
        expect_error(
            pub_trace_stamp(meta[c("time", "app")]),
            "needs the metadata `author`"
        )
        expect_error(pub_trace_stamp("Jane"), "`meta` must be a list")
        expect_error(pub_trace_stamp(NULL), "`meta` must be a list")
        expect_error(
            pub_trace_stamp(list(author = NA_character_)),
            "`author` must be a single string"
        )
        expect_error(
            pub_trace_stamp(list(author = "A", app = c("x", "y"))),
            "`app` must be a single string"
        )
        expect_error(
            pub_trace_stamp(list(author = "A", time = "now")),
            "single date-time"
        )
    })
})

describe(".expand_trace()", {
    meta <- list(author = "A", time = as.POSIXct("2026-10-07", tz = "UTC"))

    it("replaces {trace} in header and footer lines", {
        expect_identical(
            .expand_trace(
                c(left = "{trace}", right = "x {trace} y"),
                meta,
                format = "pdf"
            ),
            c(
                left = "A at 07-Oct-2026 00:00:00 UTC",
                right = "x A at 07-Oct-2026 00:00:00 UTC y"
            )
        )
        expect_null(.expand_trace(NULL, list(), format = "pdf"))
    })

    it("replaces every token and leaves other lines as they are", {
        stamp <- "A at 07-Oct-2026 00:00:00 UTC"

        expect_identical(
            .expand_trace(
                c(left = "{trace}|{trace}", center = "x", right = NA),
                meta,
                format = "pdf"
            ),
            c(left = paste0(stamp, "|", stamp), center = "x", right = NA)
        )
        author <- list(author = "A\\1", time = meta$time)
        expect_identical(
            .expand_trace(c(left = "{trace}"), author, format = "pdf"),
            c(left = "A\\1 at 07-Oct-2026 00:00:00 UTC")
        )
    })

    it("makes no stamp without the token", {
        expect_identical(
            .expand_trace(c(left = "x"), list(), format = "pdf"),
            c(left = "x")
        )
        expect_identical(
            .expand_trace(character(0), list(), format = "pdf"),
            character(0)
        )
    })

    it("signals a render error without an author", {
        err <- expect_error(
            .expand_trace(c(left = "{trace}"), list(), format = "docx"),
            "Can't expand `{trace}`",
            fixed = TRUE,
            class = "pubflow_render_error"
        )
        expect_identical(err$format, "docx")
    })
})
