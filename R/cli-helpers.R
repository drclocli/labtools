# Internal helpers shared by all tools and their command line apps
# (exec/<tool>.R). A tool function validates its inputs with
# check_input_file() / check_formats(), writes into resolve_out_dir(out_dir)
# and returns the absolute paths it created. A CLI script wraps its body in
# cli_main() and finishes with cli_emit_files().

# Check that an input file exists and has an accepted extension; returns its
# absolute path. Relative paths are resolved against the working directory.
check_input_file <- function(path, ext = NULL, arg = "path") {
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path))
    cli::cli_abort("{.arg {arg}} must be a single file path.")
  path <- path.expand(path)
  if (!file.exists(path))
    cli::cli_abort("Input file not found: {.path {path}}.")
  if (dir.exists(path))
    cli::cli_abort("{.path {path}} is a folder, not a file.")
  if (!is.null(ext)) {
    file_ext <- tolower(tools::file_ext(path))
    if (!file_ext %in% ext)
      cli::cli_abort(c("Unsupported input format {.val {file_ext}} for {.path {basename(path)}}.",
                       "i" = "Expected: {.or {.val {ext}}}."))
  }
  normalizePath(path)
}

# Resolve the output folder (NULL, "" or "." = current working directory),
# create it if needed and return its absolute path.
resolve_out_dir <- function(out_dir = NULL) {
  if (is.null(out_dir) || !nzchar(out_dir)) out_dir <- "."
  out_dir <- path.expand(out_dir)
  if (file.exists(out_dir) && !dir.exists(out_dir))
    cli::cli_abort("Output path {.path {out_dir}} exists and is not a folder.")
  if (!dir.exists(out_dir) && !dir.create(out_dir, recursive = TRUE, showWarnings = FALSE))
    cli::cli_abort("Cannot create output folder {.path {out_dir}}.")
  normalizePath(out_dir)
}

# Lower-case, de-duplicate and validate requested output formats.
check_formats <- function(formats, allowed) {
  formats <- unique(tolower(trimws(unlist(strsplit(as.character(formats), ",")))))
  formats <- formats[nzchar(formats)]
  if (!length(formats))
    cli::cli_abort("At least one output format is needed ({.or {.val {allowed}}}).")
  bad <- setdiff(formats, allowed)
  if (length(bad))
    cli::cli_abort(c("Unsupported output format{?s}: {.val {bad}}.",
                     "i" = "Supported: {.val {allowed}}."))
  formats
}

# Parse "min,max" (CLI string) into numeric limits; "" = NULL (automatic).
parse_limits <- function(x) {
  if (is.null(x) || !nzchar(trimws(x))) return(NULL)
  v <- suppressWarnings(as.numeric(trimws(strsplit(x, ",", fixed = TRUE)[[1]])))
  if (length(v) != 2 || anyNA(v) || v[1] >= v[2])
    cli::cli_abort("Invalid limits {.val {x}}: expected two increasing numbers, e.g. {.val -3,10}.")
  v
}

#' Helpers for the command line apps
#'
#' Used by the scripts in `exec/`; not meant to be called directly.
#' `cli_main()` evaluates `expr`, prints errors and warnings to stderr with
#' cli, and exits with status 1 on error (outside interactive sessions).
#' `cli_emit_files()` prints `{"files": [...]}` on stdout when `json` is
#' `TRUE`, otherwise the list of files on stderr.
#'
#' @param expr Code to run.
#' @param files Absolute paths of the files created.
#' @param json Print JSON on stdout.
#' @return `cli_main()`: the value of `expr`, invisibly. `cli_emit_files()`:
#'   `files`, invisibly.
#' @keywords internal
#' @export
cli_main <- function(expr) {
  withCallingHandlers(
    tryCatch(expr, error = function(e) {
      msg <- conditionMessage(e)
      cli::cat_line(cli::col_red(paste0(cli::symbol$cross, " Error: ")), msg, file = stderr())
      if (!interactive()) quit(save = "no", status = 1)
      invisible(NULL)
    }),
    warning = function(w) {
      cli::cat_line(cli::col_yellow(paste0("! ", conditionMessage(w))), file = stderr())
      invokeRestart("muffleWarning")
    }
  )
}

#' @rdname cli_main
#' @export
cli_emit_files <- function(files, json = FALSE) {
  files <- as.character(files)
  if (isTRUE(json)) {
    cat(jsonlite::toJSON(list(files = files), auto_unbox = FALSE), "\n", sep = "")
  } else {
    cli::cli_inform(c("i" = "{length(files)} file{?s} created:"))
    for (f in files) cli::cat_line("  ", f, file = stderr())
  }
  invisible(files)
}
