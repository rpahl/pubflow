# -------------
# Cache objects
# -------------

describe("pub_cache()", {
    it("creates an empty cache with a directory", {
        dir <- withr::local_tempdir()
        cache <- pub_cache(file.path(dir, "figures"), max_entries = 3)

        expect_s3_class(cache, "pub_cache")
        expect_true(dir.exists(file.path(dir, "figures")))
        expect_identical(cache$max_entries, 3L)
        expect_output(print(cache), "<pubflow render cache> 0 of at most 3")
        expect_true(dir.exists(pub_cache()$dir))
    })

    it("validates its arguments", {
        expect_error(pub_cache(dir = 1), "`dir` must be a single string")
        expect_error(pub_cache(max_entries = 0), "positive whole number")
        expect_error(pub_cache(max_entries = 1.5), "positive whole number")
        expect_error(pub_cache(dir = NA_character_), "`dir` must be a single string")
        expect_error(pub_cache(dir = c("a", "b")), "`dir` must be a single string")
        expect_error(pub_cache(max_entries = NA), "positive whole number")
        expect_error(pub_cache(max_entries = -1), "positive whole number")
        expect_error(pub_cache(max_entries = 1:2), "positive whole number")
        expect_error(pub_cache(max_entries = "3"), "positive whole number")
    })

    it("reuses an existing directory and keeps its files", {
        dir <- withr::local_tempdir()
        file <- file.path(dir, "old.png")
        writeBin(as.raw(1), file)

        cache <- pub_cache(dir)

        expect_identical(cache$dir, normalizePath(dir, winslash = "/"))
        expect_true(file.exists(file))
        expect_identical(length(cache$entries), 0L)
    })

    it("fails if the directory can't be created", {
        file <- withr::local_tempfile()
        writeLines("", file)

        expect_no_warning(
            err <- expect_error(
                pub_cache(file.path(file, "figures")),
                "Can't create the cache directory"
            )
        )
        # base R's reason
        expect_match(conditionMessage(err), "reason '", fixed = TRUE)
    })

    it("prints the number of entries", {
        cache <- pub_cache(max_entries = 5)
        .cache_set(cache, "t", "<table></table>", is_file = FALSE)

        expect_output(res <- withVisible(print(cache)), "1 of at most 5 entries")
        expect_false(res$visible)
        expect_identical(res$value, cache)
    })
})

describe(".check_cache()", {
    it("accepts a cache or NULL", {
        cache <- pub_cache()

        expect_identical(.check_cache(cache), cache)
        expect_null(.check_cache(NULL))
    })

    it("reports the error for the caller", {
        f <- function(cache) .check_cache(cache)

        err <- expect_error(f(list()), "`cache` must be made by `pub_cache\\(\\)`")
        expect_identical(err$call, quote(f(list())))
    })
})


# ----
# Keys
# ----

describe(".cache_key()", {
    stamped <- function(call = 1L) {
        stamp <- list(pipeline = "p", step = "plot", time = as.POSIXct(0), call = call)
        pub_set_meta(recorded_plot(), stamp = stamp)
    }
    device <- list(device = "png", res = 150, width = 8, height = 6)

    it("has keys for stamped figures only", {
        expect_null(.cache_key(recorded_plot(), device))
        expect_null(.cache_key(pub_set_meta(recorded_plot(), caption = "C"), device))
        key <- .cache_key(stamped(), device)

        expect_true(rlang::is_string(key))
        expect_identical(.cache_key(stamped(), device), key)
    })

    it("changes with the stamp, the device and the metadata", {
        key <- .cache_key(stamped(), device)

        expect_false(identical(.cache_key(stamped(call = 2L), device), key))
        device$res <- 72
        expect_false(identical(.cache_key(stamped(), device), key))
        fig <- pub_set_meta(stamped(), caption = "Other")
        expect_false(identical(.cache_key(fig, list()), .cache_key(stamped(), list())))
    })

    it("works for ggplots", {
        skip_if_not_installed("ggplot2")
        stamp <- list(pipeline = "p", step = "plot", time = as.POSIXct(0), call = 1L)
        gg <- ggplot2::ggplot(data.frame(x = 1:3), ggplot2::aes(x, x))

        key <- .cache_key(pub_set_meta(gg, stamp = stamp), device)

        expect_true(rlang::is_string(key))
        expect_null(.cache_key(gg, device))
    })
})

describe(".cache_table_key()", {
    it("keys tables by their content and settings", {
        ht <- pub_table(data.frame(a = 1:2))

        key <- .cache_table_key(ht, NULL)

        expect_identical(.cache_table_key(pub_table(data.frame(a = 1:2)), NULL), key)
        expect_false(identical(.cache_table_key(ht, 8), key))
        ht2 <- huxtable::set_bold(ht, 2, 1)
        expect_false(identical(.cache_table_key(ht2, NULL), key))
        ht3 <- pub_table(data.frame(a = c(1L, 3L)))
        expect_false(identical(.cache_table_key(ht3, NULL), key))
    })
})


# -------
# Entries
# -------

describe("cache entries", {
    write_file <- function(cache, key) {
        file <- .cache_path(cache, key, "png")
        writeBin(as.raw(1), file)
        file
    }

    it("puts files into the cache directory", {
        cache <- pub_cache()

        file <- .cache_path(cache, "abc", "svg")

        expect_identical(dirname(file), cache$dir)
        expect_identical(basename(file), "abc.svg")
    })

    it("stores files and HTML, and forgets missing files", {
        cache <- pub_cache()
        file <- write_file(cache, "a")

        expect_identical(.cache_set(cache, "a", file), file)
        .cache_set(cache, "t", "<table></table>", is_file = FALSE)

        expect_identical(.cache_get(cache, "a"), file)
        expect_identical(.cache_get(cache, "t"), "<table></table>")
        expect_null(.cache_get(cache, "unknown"))
        unlink(file)
        expect_null(.cache_get(cache, "a"))
        # the stale entry is gone and no longer counts
        expect_identical(names(cache$entries), "t")
        expect_identical(names(cache$used), "t")
    })

    it("replaces the value of a key without removing other entries", {
        cache <- pub_cache(max_entries = 2)
        .cache_set(cache, "a", "<a>", is_file = FALSE)
        .cache_set(cache, "b", "<b>", is_file = FALSE)

        .cache_set(cache, "a", "<new>", is_file = FALSE)

        expect_setequal(names(cache$entries), c("a", "b"))
        expect_identical(.cache_get(cache, "a"), "<new>")
        # "a" is now the most recently used entry
        .cache_set(cache, "c", "<c>", is_file = FALSE)
        expect_setequal(names(cache$entries), c("a", "c"))
    })

    it("removes the least recently used entries and their files", {
        cache <- pub_cache(max_entries = 2)
        files <- vapply(c("a", "b", "c"), \(key) write_file(cache, key), character(1))

        .cache_set(cache, "a", files[["a"]])
        .cache_set(cache, "b", files[["b"]])
        .cache_get(cache, "a")
        .cache_set(cache, "c", files[["c"]])

        expect_setequal(names(cache$entries), c("a", "c"))
        expect_setequal(names(cache$used), c("a", "c"))
        expect_false(file.exists(files[["b"]]))
        expect_true(all(file.exists(files[c("a", "c")])))
        .cache_set(cache, "t", "<table></table>", is_file = FALSE)
        expect_setequal(names(cache$entries), c("c", "t"))
        expect_false(file.exists(files[["a"]]))
    })

    it("keeps only the newest entry with max_entries = 1", {
        cache <- pub_cache(max_entries = 1)
        file <- write_file(cache, "a")
        .cache_set(cache, "a", file)

        .cache_set(cache, "t", "<table></table>", is_file = FALSE)

        expect_identical(names(cache$entries), "t")
        expect_false(file.exists(file))
    })

    it("removes an entry whose file is already gone", {
        cache <- pub_cache(max_entries = 1)
        file <- write_file(cache, "a")
        .cache_set(cache, "a", file)
        unlink(file)

        expect_no_condition(.cache_set(cache, "b", "<b>", is_file = FALSE))
        expect_identical(names(cache$entries), "b")
    })

    it("never deletes files for HTML entries", {
        cache <- pub_cache(max_entries = 1)
        # HTML that happens to be the path of an existing file
        file <- write_file(cache, "x")
        .cache_set(cache, "t", file, is_file = FALSE)

        .cache_set(cache, "u", "<table></table>", is_file = FALSE)

        expect_identical(names(cache$entries), "u")
        expect_true(file.exists(file))
    })
})
