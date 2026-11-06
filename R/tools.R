# Discovery of external tools: pandoc renders DOCX, PDF and Markdown, typst is the
# optional PDF engine. Tools are looked up on every call (no cache), so changed
# environment variables take effect at once.

# ======================================================================================
# Tools
# ======================================================================================

# ------
# pandoc
# ------
.pandoc_min_version <- "3.6"

#' Locate pandoc
#'
#' Candidates in this order:
#' 1. environment variable `PUBFLOW_PANDOC` (the pandoc executable or the directory
#'    containing it); if set, it is the only candidate;
#' 2. `pandoc` in the directory given by `RSTUDIO_PANDOC` (set by RStudio and Posit
#'    Connect);
#' 3. `pandoc` on the PATH.
#'
#' The first candidate with version >= `min_version` wins, so an outdated pandoc bundled
#' with RStudio does not hide a recent one on the PATH.
#'
#' @param min_version minimum required pandoc version.
#' @param call see `.pubflow_error()`.
#' @return `character(1)` absolute path of the pandoc executable. Signals a
#'   `pubflow_tool_missing` error if no suitable pandoc is found.
#' @noRd
.find_pandoc <- function(
    min_version = .pandoc_min_version,
    call = rlang::caller_env()
) {
    explicit <- Sys.getenv("PUBFLOW_PANDOC")
    candidates <- if (nzchar(explicit)) {
        .explicit_tool("pandoc", "PUBFLOW_PANDOC", explicit, call = call)
    } else {
        .existing_tools(c(
            .tool_in_dir(Sys.getenv("RSTUDIO_PANDOC"), "pandoc"),
            .which("pandoc")
        ))
    }
    versions <- rep(NA_character_, length(candidates))
    for (i in seq_along(candidates)) {
        version <- .tool_version(candidates[[i]])
        if (!is.null(version) && version >= min_version) {
            return(candidates[[i]])
        }
        versions[[i]] <- if (is.null(version)) NA else format(version)
    }
    rlang::cnd_signal(.pandoc_missing_error(
        candidates,
        versions,
        min_version,
        explicit = nzchar(explicit),
        call = call
    ))
}

#' Error for a missing or outdated pandoc
#'
#' @param candidates `character` paths of the pandoc executables checked.
#' @param versions `character` their versions (`NA`: unknown).
#' @param min_version minimum required version.
#' @param explicit `TRUE` if the candidate came from `PUBFLOW_PANDOC`.
#' @param call see `.pubflow_error()`.
#' @return a `pubflow_tool_missing` condition.
#' @noRd
.pandoc_missing_error <- function(
    candidates,
    versions,
    min_version,
    explicit,
    call = NULL
) {
    found <- ifelse(
        is.na(versions),
        sprintf("'%s' did not report its version.", candidates),
        sprintf("'%s' has version %s.", candidates, versions)
    )
    names(found) <- rep("x", length(found))
    hint <- if (explicit) {
        paste0(
            "Set the environment variable PUBFLOW_PANDOC to a pandoc >= ",
            min_version,
            " executable, or unset it to search ",
            "RSTUDIO_PANDOC and the PATH."
        )
    } else {
        paste0(
            "Install pandoc >= ",
            min_version,
            " (https://pandoc.org/installing.html) and add it to the PATH, ",
            "or set the environment variable PUBFLOW_PANDOC to the pandoc ",
            "executable."
        )
    }
    headline <- if (length(candidates) == 0L) {
        "pandoc (>= %s) is required but was not found."
    } else {
        "pandoc (>= %s) is required, but no suitable pandoc was found:"
    }
    .tool_missing_error(
        "pandoc",
        c(sprintf(headline, min_version), found, i = hint),
        required = min_version,
        candidates = candidates,
        versions = versions,
        call = call
    )
}


# -----
# typst
# -----
#' Locate typst
#'
#' Candidates in this order:
#' 1. environment variable `PUBFLOW_TYPST` (the typst executable or the directory
#'    containing it); if set, it is the only candidate;
#' 2. `typst` on the PATH;
#' 3. the typst bundled with Quarto (see `.quarto_typst()`).
#'
#' The executable is not run (no version check).
#'
#' @param call see `.pubflow_error()`.
#' @return `character(1)` absolute path of the typst executable. Signals a
#'   `pubflow_tool_missing` error if typst is not found.
#' @noRd
.find_typst <- function(call = rlang::caller_env()) {
    explicit <- Sys.getenv("PUBFLOW_TYPST")
    if (nzchar(explicit)) {
        return(.explicit_tool("typst", "PUBFLOW_TYPST", explicit, call = call))
    }
    candidates <- .existing_tools(c(.which("typst"), .quarto_typst()))
    if (length(candidates) > 0L) {
        return(candidates[[1L]])
    }
    rlang::cnd_signal(.tool_missing_error(
        "typst",
        c(
            "typst is required for PDF output via Typst but was not found.",
            i = paste0(
                "Install typst (https://github.com/typst/typst/releases) or ",
                "Quarto (https://quarto.org, bundles typst), or set the ",
                "environment variable PUBFLOW_TYPST to the typst executable."
            )
        ),
        call = call
    ))
}

#' Candidate paths of the typst bundled with Quarto
#'
#' Quarto is found via the environment variable `QUARTO_PATH` (path of the quarto
#' executable, as used by the quarto R package) or on the PATH. Symbolic links are
#' resolved to find the installation directory; typst is located in `bin/tools/<arch>/`
#' (or `bin/tools/`) next to `bin/quarto`.
#'
#' @return `character` candidate paths (possibly not existing), or `character(0)` if
#'   Quarto is not found.
#' @noRd
.quarto_typst <- function() {
    quarto <- Sys.getenv("QUARTO_PATH")
    if (!nzchar(quarto)) {
        quarto <- .which("quarto")
    }
    if (length(quarto) == 0L || !file.exists(quarto)) {
        return(character())
    }
    bin <- dirname(normalizePath(quarto, winslash = "/"))
    exe <- .exe_name("typst")
    arch <- if (.platform()$arch %in% c("aarch64", "arm64")) {
        "aarch64"
    } else {
        "x86_64"
    }
    c(file.path(bin, "tools", arch, exe), file.path(bin, "tools", exe))
}


# ======================================================================================
# Lookup
# ======================================================================================

# ----------
# Candidates
# ----------
#' Check a tool path given by an environment variable
#'
#' @param tool `character(1)` tool name.
#' @param envvar `character(1)` name of the environment variable.
#' @param value `character(1)` its value: the executable or the directory containing it.
#' @param call see `.pubflow_error()`.
#' @return `character(1)` absolute path of the executable. Signals a
#'   `pubflow_tool_missing` error if it is not an executable file.
#' @noRd
.explicit_tool <- function(tool, envvar, value, call = NULL) {
    path <- .absolute_path(value)
    if (dir.exists(path)) {
        path <- file.path(path, .exe_name(tool))
    }
    if (!.is_executable(path)) {
        rlang::cnd_signal(.tool_missing_error(
            tool,
            c(
                sprintf(
                    "The environment variable %s does not point to %s.",
                    envvar,
                    tool
                ),
                x = sprintf("%s is set to '%s'.", envvar, value),
                i = sprintf(
                    paste0(
                        "Set it to the %s executable (or the directory ",
                        "containing it), or unset it."
                    ),
                    tool
                )
            ),
            call = call
        ))
    }
    path
}

#' Version of a command line tool
#'
#' Runs `<path> --version` and parses the first version number in the first line of the
#' output (e.g. `"pandoc 3.8.3"`).
#'
#' @param path `character(1)` path of the executable (`system2()` quotes it).
#' @return `numeric_version` or `NULL` if the tool fails or reports no version.
#' @noRd
.tool_version <- function(path) {
    out <- tryCatch(
        suppressWarnings(system2(
            path,
            "--version",
            stdout = TRUE,
            stderr = TRUE,
            timeout = 10
        )),
        error = function(e) character()
    )
    status <- attr(out, "status")
    if (length(out) == 0L || (!is.null(status) && status != 0L)) {
        return(NULL)
    }
    version <- regmatches(out[[1L]], regexpr("[0-9]+(\\.[0-9]+)+", out[[1L]]))
    if (length(version) == 0L) NULL else numeric_version(version)
}

#' Find executables on the PATH
#'
#' @param name `character(1)` program name.
#' @return `character` absolute path, or `character(0)` if not found.
#' @noRd
.which <- function(name) {
    path <- unname(Sys.which(name))
    path[!is.na(path) & nzchar(path)]
}

#' Path of a tool inside a directory
#'
#' @param dir `character(1)` directory (`""`: none).
#' @param tool `character(1)` tool name.
#' @return `character` path (possibly not existing), or `character(0)` if `dir` is
#'   empty.
#' @noRd
.tool_in_dir <- function(dir, tool) {
    if (!nzchar(dir)) {
        return(character())
    }
    file.path(dir, .exe_name(tool))
}

#' Keep executable candidates
#'
#' @param paths `character` candidate paths.
#' @return `character` absolute paths of the executable candidates, without duplicates,
#'   in the given order.
#' @noRd
.existing_tools <- function(paths) {
    paths <- vapply(paths, .absolute_path, character(1), USE.NAMES = FALSE)
    unique(paths[.is_executable(paths)])
}


# -----
# Files
# -----
#' Is a path an executable file?
#'
#' @param path `character` paths.
#' @return `logical` of the same length.
#' @noRd
.is_executable <- function(path) {
    vapply(
        path,
        \(p) {
            nzchar(p) && file.exists(p) && !dir.exists(p) && file.access(p, 1L) == 0L
        },
        logical(1),
        USE.NAMES = FALSE
    )
}

#' Make a path absolute
#'
#' Unlike `normalizePath()`, symbolic links are kept: some executables (e.g. snap
#' packages) depend on the name they are called by.
#'
#' @param path `character(1)` path.
#' @return `character(1)` absolute path.
#' @noRd
.absolute_path <- function(path) {
    path <- path.expand(path)
    if (grepl("^(/|[A-Za-z]:[/\\\\]|\\\\\\\\)", path)) {
        return(path)
    }
    file.path(getwd(), path)
}

#' File name of an executable on the current platform
#'
#' @param tool `character(1)` tool name.
#' @return `character(1)`, with `.exe` appended on Windows.
#' @noRd
.exe_name <- function(tool) {
    if (.platform()$os == "windows") paste0(tool, ".exe") else tool
}

#' Operating system type and architecture of R (a binding that tests can mock)
#' @return `list(os, arch)`: `.Platform$OS.type` and `R.version$arch`.
#' @noRd
.platform <- function() {
    list(os = .Platform$OS.type, arch = R.version$arch)
}
