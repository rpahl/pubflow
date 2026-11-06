# Tool discovery is tested with fake executables (shell scripts printing a version) and
# a controlled PATH, independent of the tools installed on the machine. The scripts need
# a POSIX shell.
skip_on_os("windows")

# Create an executable script `dir/name` that prints `output` and exits with `status`.
fake_tool <- function(dir, name, output = character(), status = 0L) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    path <- file.path(dir, name)
    script <- c(
        "#!/bin/sh",
        sprintf("echo '%s'", output),
        sprintf("exit %d", status)
    )
    writeLines(script, path)
    Sys.chmod(path, "755")
    path
}

# Unset all variables used for tool discovery and set the PATH to `path`. Variables
# given in `...` are set instead.
local_tool_env <- function(path = character(), ..., .env = parent.frame()) {
    vars <- list(
        PUBFLOW_PANDOC = NA,
        RSTUDIO_PANDOC = NA,
        PUBFLOW_TYPST = NA,
        QUARTO_PATH = NA,
        PATH = paste(path, collapse = .Platform$path.sep)
    )
    withr::local_envvar(utils::modifyList(vars, list(...)), .local_envir = .env)
}

# Fake Quarto installation in `root` with typst in `bin/tools/<tools_dir>`.
fake_quarto <- function(root, tools_dir = quarto_arch()) {
    quarto <- fake_tool(file.path(root, "bin"), "quarto", "1.8.25")
    typst <- fake_tool(
        file.path(root, "bin", "tools", tools_dir),
        "typst",
        "typst 0.13.1"
    )
    list(quarto = quarto, typst = typst)
}

quarto_arch <- function() {
    if (R.version$arch %in% c("aarch64", "arm64")) "aarch64" else "x86_64"
}


# ======================================================================================
# Tools
# ======================================================================================

# ------
# pandoc
# ------

describe(".find_pandoc()", {
    it("finds pandoc on the PATH", {
        dir <- withr::local_tempdir()
        pandoc <- fake_tool(dir, "pandoc", "pandoc 3.8.3")
        local_tool_env(dir)

        expect_equal(.find_pandoc(), pandoc)
    })

    it("prefers PUBFLOW_PANDOC over RSTUDIO_PANDOC and the PATH", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        rstudio <- fake_tool(file.path(tmp, "rs"), "pandoc", "pandoc 3.7")
        explicit <- fake_tool(file.path(tmp, "ex"), "pandoc", "pandoc 3.6.1")
        local_tool_env(
            dirname(onPath),
            RSTUDIO_PANDOC = dirname(rstudio),
            PUBFLOW_PANDOC = explicit
        )

        expect_equal(.find_pandoc(), explicit)
    })

    it("accepts the directory of pandoc in PUBFLOW_PANDOC", {
        dir <- withr::local_tempdir()
        explicit <- fake_tool(dir, "pandoc", "pandoc 3.8.3")
        local_tool_env(PUBFLOW_PANDOC = dir)

        expect_equal(.find_pandoc(), explicit)
    })

    it("makes a relative path in PUBFLOW_PANDOC absolute", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "bin"), "pandoc", "pandoc 3.8.3")
        withr::local_dir(tmp)
        local_tool_env(PUBFLOW_PANDOC = file.path("bin", "pandoc"))

        expect_equal(.find_pandoc(), file.path(getwd(), "bin", "pandoc"))
    })

    it("does not fall back if PUBFLOW_PANDOC is not an executable", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(tmp, "pandoc", "pandoc 3.8.3")
        notExecutable <- file.path(tmp, "pandoc.txt")
        writeLines("pandoc", notExecutable)

        local_tool_env(tmp, PUBFLOW_PANDOC = file.path(tmp, "missing"))
        expect_error(
            .find_pandoc(),
            "PUBFLOW_PANDOC does not point to pandoc",
            class = "pubflow_tool_missing"
        )

        local_tool_env(tmp, PUBFLOW_PANDOC = notExecutable)
        expect_error(.find_pandoc(), class = "pubflow_tool_missing")
    })

    it("does not fall back if the PUBFLOW_PANDOC directory has no pandoc", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        dir.create(file.path(tmp, "empty"))
        local_tool_env(file.path(tmp, "path"), PUBFLOW_PANDOC = file.path(tmp, "empty"))

        cnd <- expect_error(.find_pandoc(), class = "pubflow_tool_missing")
        expect_match(cnd$message, file.path(tmp, "empty"), fixed = TRUE)
    })

    it("treats empty PUBFLOW_PANDOC and RSTUDIO_PANDOC as unset", {
        dir <- withr::local_tempdir()
        pandoc <- fake_tool(dir, "pandoc", "pandoc 3.8.3")
        local_tool_env(dir, PUBFLOW_PANDOC = "", RSTUDIO_PANDOC = "")

        expect_equal(.find_pandoc(), pandoc)
    })

    it("does not fall back if PUBFLOW_PANDOC is outdated", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        old <- fake_tool(file.path(tmp, "old"), "pandoc", "pandoc 2.19.2")
        local_tool_env(file.path(tmp, "path"), PUBFLOW_PANDOC = old)

        cnd <- expect_error(.find_pandoc(), class = "pubflow_tool_missing")
        expect_equal(cnd$candidates, old)
        expect_equal(cnd$versions, "2.19.2")
        expect_match(cnd$message, "unset it", fixed = TRUE)
    })

    it("reports an explicit pandoc without version", {
        dir <- withr::local_tempdir()
        explicit <- fake_tool(dir, "pandoc", "pandoc 3.8.3", status = 1L)
        local_tool_env(PUBFLOW_PANDOC = explicit)

        cnd <- expect_error(.find_pandoc(), class = "pubflow_tool_missing")
        expect_equal(cnd$versions, NA_character_)
        expect_match(cnd$message, "did not report its version", fixed = TRUE)
        expect_match(cnd$message, "unset it", fixed = TRUE)
    })

    it("prefers RSTUDIO_PANDOC over the PATH", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        rstudio <- fake_tool(file.path(tmp, "rs"), "pandoc", "pandoc 3.7")
        local_tool_env(
            file.path(tmp, "path"),
            RSTUDIO_PANDOC = dirname(rstudio)
        )

        expect_equal(.find_pandoc(), rstudio)
    })

    it("skips an outdated pandoc in RSTUDIO_PANDOC", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        fake_tool(file.path(tmp, "rs"), "pandoc", "pandoc 2.19.2")
        local_tool_env(dirname(onPath), RSTUDIO_PANDOC = file.path(tmp, "rs"))

        expect_equal(.find_pandoc(), onPath)
    })

    it("ignores RSTUDIO_PANDOC without pandoc", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        local_tool_env(dirname(onPath), RSTUDIO_PANDOC = file.path(tmp, "no"))

        expect_equal(.find_pandoc(), onPath)
    })

    it("skips candidates that fail or report no version", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 3.8.3")
        fake_tool(file.path(tmp, "rs"), "pandoc", "pandoc 3.8.3", status = 1L)
        local_tool_env(dirname(onPath), RSTUDIO_PANDOC = file.path(tmp, "rs"))
        expect_equal(.find_pandoc(), onPath)

        fake_tool(file.path(tmp, "rs"), "pandoc", "no version here")
        expect_equal(.find_pandoc(), onPath)
    })

    it("checks a pandoc in both RSTUDIO_PANDOC and the PATH only once", {
        dir <- withr::local_tempdir()
        old <- fake_tool(dir, "pandoc", "pandoc 2.19.2")
        local_tool_env(dir, RSTUDIO_PANDOC = dir)

        cnd <- expect_error(.find_pandoc(), class = "pubflow_tool_missing")
        expect_equal(cnd$candidates, old)
        expect_equal(cnd$versions, "2.19.2")
    })

    it("requires min_version", {
        dir <- withr::local_tempdir()
        pandoc <- fake_tool(dir, "pandoc", "pandoc 3.6")
        local_tool_env(dir)

        expect_equal(.find_pandoc(), pandoc)
        expect_equal(.find_pandoc(min_version = "3.5.9"), pandoc)
        expect_error(
            .find_pandoc(min_version = "3.6.1"),
            "pandoc \\(>= 3.6.1\\) is required",
            class = "pubflow_tool_missing"
        )
    })

    it("lists the outdated candidates in the error", {
        tmp <- withr::local_tempdir()
        onPath <- fake_tool(file.path(tmp, "path"), "pandoc", "pandoc 2.9.2.1")
        rstudio <- fake_tool(file.path(tmp, "rs"), "pandoc", "x", status = 2L)
        local_tool_env(dirname(onPath), RSTUDIO_PANDOC = dirname(rstudio))

        cnd <- expect_error(.find_pandoc(), class = "pubflow_tool_missing")
        expect_equal(cnd$tool, "pandoc")
        expect_equal(cnd$required, "3.6")
        expect_equal(cnd$candidates, c(rstudio, onPath))
        expect_equal(cnd$versions, c(NA, "2.9.2.1"))
        expect_match(cnd$message, "no suitable pandoc was found:", fixed = TRUE)
        expect_no_match(cnd$message, "was not found", fixed = TRUE)
        expect_match(
            cnd$message,
            sprintf("'%s' has version 2.9.2.1.", onPath),
            fixed = TRUE
        )
        expect_match(
            cnd$message,
            sprintf("'%s' did not report its version.", rstudio),
            fixed = TRUE
        )
    })

    it("explains how to install pandoc if none is found", {
        local_tool_env(withr::local_tempdir())

        expect_snapshot(.find_pandoc(call = quote(pub_render())), error = TRUE)
    })

    it("reports the calling function", {
        local_tool_env(withr::local_tempdir())
        pub_render <- function() .find_pandoc()

        cnd <- expect_error(pub_render(), class = "pubflow_tool_missing")
        expect_equal(conditionCall(cnd), quote(pub_render()))
    })
})


# -----
# typst
# -----

describe(".find_typst()", {
    it("finds typst on the PATH", {
        dir <- withr::local_tempdir()
        typst <- fake_tool(dir, "typst", "typst 0.15.1")
        local_tool_env(dir)

        expect_equal(.find_typst(), typst)
    })

    it("prefers PUBFLOW_TYPST over the PATH", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "path"), "typst", "typst 0.15.1")
        explicit <- fake_tool(file.path(tmp, "ex"), "typst", "typst 0.14.0")
        local_tool_env(file.path(tmp, "path"), PUBFLOW_TYPST = explicit)

        expect_equal(.find_typst(), explicit)
    })

    it("accepts the directory of typst in PUBFLOW_TYPST", {
        dir <- withr::local_tempdir()
        explicit <- fake_tool(dir, "typst", "typst 0.15.1")
        local_tool_env(PUBFLOW_TYPST = dir)

        expect_equal(.find_typst(), explicit)
    })

    it("does not fall back if PUBFLOW_TYPST is not an executable", {
        tmp <- withr::local_tempdir()
        fake_tool(tmp, "typst", "typst 0.15.1")
        local_tool_env(tmp, PUBFLOW_TYPST = file.path(tmp, "missing", "typst"))

        expect_error(
            .find_typst(),
            "PUBFLOW_TYPST does not point to typst",
            class = "pubflow_tool_missing"
        )
    })

    it("does not fall back if the PUBFLOW_TYPST directory has no typst", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "path"), "typst", "typst 0.15.1")
        dir.create(file.path(tmp, "empty"))
        local_tool_env(file.path(tmp, "path"), PUBFLOW_TYPST = file.path(tmp, "empty"))

        expect_error(.find_typst(), class = "pubflow_tool_missing")
    })

    it("treats empty PUBFLOW_TYPST and QUARTO_PATH as unset", {
        tmp <- withr::local_tempdir()
        quarto <- fake_quarto(file.path(tmp, "quarto"))
        local_tool_env(dirname(quarto$quarto), PUBFLOW_TYPST = "", QUARTO_PATH = "")

        expect_equal(.find_typst(), normalizePath(quarto$typst))
    })

    it("prefers QUARTO_PATH over quarto on the PATH", {
        tmp <- withr::local_tempdir()
        onPath <- fake_quarto(file.path(tmp, "a"))
        explicit <- fake_quarto(file.path(tmp, "b"))
        local_tool_env(dirname(onPath$quarto), QUARTO_PATH = explicit$quarto)

        expect_equal(.find_typst(), normalizePath(explicit$typst))
    })

    it("prefers typst on the PATH over the one bundled with Quarto", {
        tmp <- withr::local_tempdir()
        quarto <- fake_quarto(file.path(tmp, "quarto"))
        typst <- fake_tool(file.path(tmp, "path"), "typst", "typst 0.15.1")
        local_tool_env(c(dirname(typst), dirname(quarto$quarto)))

        expect_equal(.find_typst(), typst)
    })

    it("finds the typst bundled with Quarto on the PATH (symlinked)", {
        tmp <- withr::local_tempdir()
        quarto <- fake_quarto(file.path(tmp, "quarto"))
        dir.create(file.path(tmp, "path"))
        file.symlink(quarto$quarto, file.path(tmp, "path", "quarto"))
        local_tool_env(file.path(tmp, "path"))

        expect_equal(.find_typst(), normalizePath(quarto$typst))
    })

    it("finds the typst bundled with Quarto via QUARTO_PATH", {
        tmp <- withr::local_tempdir()
        quarto <- fake_quarto(file.path(tmp, "quarto"))
        local_tool_env(QUARTO_PATH = quarto$quarto)

        expect_equal(.find_typst(), normalizePath(quarto$typst))
    })

    it("finds typst directly in Quarto's tools directory", {
        tmp <- withr::local_tempdir()
        quarto <- fake_quarto(file.path(tmp, "quarto"), tools_dir = ".")
        local_tool_env(dirname(quarto$quarto))

        expect_equal(
            .find_typst(),
            file.path(normalizePath(dirname(quarto$quarto)), "tools", "typst")
        )
    })

    it("ignores a Quarto installation without typst", {
        tmp <- withr::local_tempdir()
        quarto <- fake_tool(file.path(tmp, "bin"), "quarto", "1.8.25")
        local_tool_env(dirname(quarto))
        expect_error(.find_typst(), class = "pubflow_tool_missing")

        local_tool_env(QUARTO_PATH = file.path(tmp, "missing"))
        expect_error(.find_typst(), class = "pubflow_tool_missing")
    })

    it("explains how to install typst if none is found", {
        local_tool_env(withr::local_tempdir())

        cnd <- expect_error(.find_typst(), class = "pubflow_tool_missing")
        expect_equal(cnd$tool, "typst")
        expect_snapshot(.find_typst(call = quote(pub_render())), error = TRUE)
    })
})


# ======================================================================================
# Lookup
# ======================================================================================

# ----------
# Candidates
# ----------

describe(".quarto_typst()", {
    it("looks in the tools directory of the architecture, then in tools", {
        bin <- file.path(withr::local_tempdir(), "bin")
        dir.create(bin)
        quarto <- file.path(bin, "quarto")
        file.create(quarto)
        withr::local_envvar(QUARTO_PATH = quarto)
        bin <- dirname(normalizePath(quarto, winslash = "/"))
        dirs <- c(aarch64 = "aarch64", arm64 = "aarch64", x86_64 = "x86_64")
        for (arch in names(dirs)) {
            local_mocked_bindings(.platform = \() list(os = "unix", arch = arch))
            expect_identical(
                .quarto_typst(),
                c(
                    file.path(bin, "tools", dirs[[arch]], "typst"),
                    file.path(bin, "tools", "typst")
                )
            )
        }
        local_mocked_bindings(.platform = \() list(os = "windows", arch = "x86_64"))
        expect_identical(basename(.quarto_typst()), rep("typst.exe", 2L))
    })
})

describe(".tool_version()", {
    it("parses the version from the first line of the output", {
        dir <- withr::local_tempdir()
        pandoc <- fake_tool(
            dir,
            "pandoc",
            c("pandoc 3.8.3", "Features: +server +lua")
        )
        windows <- fake_tool(dir, "pandoc-win", "pandoc.exe 3.1.1")
        typst <- fake_tool(dir, "typst", "typst 0.15.1 (8ac2b0d5)")

        expect_equal(.tool_version(pandoc), numeric_version("3.8.3"))
        expect_equal(.tool_version(windows), numeric_version("3.1.1"))
        expect_equal(.tool_version(typst), numeric_version("0.15.1"))
    })

    it("returns NULL if the tool fails or reports no version", {
        dir <- withr::local_tempdir()

        expect_null(.tool_version(fake_tool(dir, "a", "a 1.0", status = 1L)))
        expect_null(.tool_version(fake_tool(dir, "b", "no version")))
        expect_null(.tool_version(fake_tool(dir, "c")))
        expect_null(.tool_version(file.path(dir, "missing")))
    })

    it("ignores a version after the first line", {
        dir <- withr::local_tempdir()
        tool <- fake_tool(dir, "tool", c("tool", "version 1.2.3"))

        expect_null(.tool_version(tool))
    })

    it("handles paths with spaces", {
        dir <- file.path(withr::local_tempdir(), "with space")
        tool <- fake_tool(dir, "pandoc", "pandoc 3.8.3")

        expect_equal(.tool_version(tool), numeric_version("3.8.3"))
    })
})

describe(".which()", {
    it("returns the path of a program on the PATH", {
        dir <- withr::local_tempdir()
        tool <- fake_tool(dir, "tool")
        local_tool_env(dir)

        expect_equal(.which("tool"), tool)
    })

    it("returns character(0) if the program is not found", {
        local_tool_env(withr::local_tempdir())

        expect_equal(.which("tool"), character())
    })
})

describe(".tool_in_dir()", {
    it("returns the path of the tool in the directory", {
        expect_equal(.tool_in_dir("/opt/pandoc", "pandoc"), "/opt/pandoc/pandoc")
    })

    it("returns character(0) for an empty directory name", {
        expect_equal(.tool_in_dir("", "pandoc"), character())
    })
})

describe(".existing_tools()", {
    it("keeps executables in order, made absolute and without duplicates", {
        tmp <- withr::local_tempdir()
        fake_tool(file.path(tmp, "a"), "tool")
        b <- fake_tool(file.path(tmp, "b"), "tool")
        withr::local_dir(tmp)

        expect_equal(
            .existing_tools(c(b, file.path(tmp, "missing"), file.path("a", "tool"), b)),
            c(b, file.path(getwd(), "a", "tool"))
        )
        expect_equal(.existing_tools(character()), character())
    })
})


# -----
# Files
# -----

describe(".is_executable()", {
    it("is TRUE only for executable files", {
        dir <- withr::local_tempdir()
        tool <- fake_tool(dir, "tool")
        plain <- file.path(dir, "plain")
        writeLines("x", plain)

        expect_equal(
            .is_executable(c(tool, plain, dir, file.path(dir, "missing"), "")),
            c(TRUE, FALSE, FALSE, FALSE, FALSE)
        )
        expect_equal(.is_executable(character()), logical())
    })
})

describe(".absolute_path()", {
    it("keeps absolute paths", {
        expect_equal(.absolute_path("/usr/bin/pandoc"), "/usr/bin/pandoc")
        expect_equal(
            .absolute_path("C:/pandoc/pandoc.exe"),
            "C:/pandoc/pandoc.exe"
        )
        expect_equal(.absolute_path("C:\\pandoc"), "C:\\pandoc")
    })

    it("prepends the working directory to relative paths", {
        dir <- withr::local_tempdir()
        withr::local_dir(dir)

        expect_equal(
            .absolute_path("bin/pandoc"),
            file.path(getwd(), "bin/pandoc")
        )
    })

    it("expands the home directory", {
        expect_equal(.absolute_path("~/x"), path.expand("~/x"))
    })

    it("does not resolve symbolic links", {
        dir <- withr::local_tempdir()
        tool <- fake_tool(dir, "tool")
        link <- file.path(dir, "link")
        file.symlink(tool, link)

        expect_equal(.absolute_path(link), link)
    })
})
