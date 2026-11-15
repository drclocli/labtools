test_that("cli_emit_files() prints only JSON on stdout in json mode", {
  files <- c("/tmp/a.png", "/tmp/b.pdf")
  out <- capture.output(cli_emit_files(files, json = TRUE), type = "output")
  expect_length(out, 1)
  expect_identical(jsonlite::fromJSON(out)$files, files)
})

test_that("cli_emit_files() keeps an array for a single file", {
  out <- capture.output(cli_emit_files("/tmp/a.png", json = TRUE))
  expect_identical(out, '{"files":["/tmp/a.png"]}')
})

test_that("resolve_out_dir() treats empty as the working directory", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  expect_identical(resolve_out_dir(""), normalizePath(dir))
  expect_identical(resolve_out_dir(NULL), normalizePath(dir))
  expect_identical(resolve_out_dir("sub"), normalizePath(file.path(dir, "sub")))
})

test_that("parse_limits() and check_formats()", {
  expect_null(parse_limits(""))
  expect_identical(parse_limits("-3, 10"), c(-3, 10))
  expect_identical(check_formats(c("PNG", "pdf,png"), c("png", "pdf")), c("png", "pdf"))
})
