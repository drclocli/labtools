example_csv <- function() {
  system.file("extdata", "radar_example.csv", package = "labtools")
}

expected_files <- function(formats, normalisation = "log2fc") {
  c(as.vector(t(outer(c("radar_01_ATB_paroi_membrane", "radar_02_ATB_autre"),
                      formats, paste, sep = "."))),
    paste0("valeurs_normalisees_", normalisation, ".csv"))
}

test_that("radar_plots() writes PNG, PDF and the normalised CSV by default", {
  out <- withr::local_tempdir()
  files <- suppressMessages(radar_plots(example_csv(), out_dir = out))
  expect_setequal(basename(files), expected_files(c("png", "pdf")))
  expect_true(all(file.exists(files)))
  expect_true(all(startsWith(files, normalizePath(out))))
  expect_true(all(file.size(files) > 0))
  png <- files[endsWith(files, ".png")][1]
  expect_identical(readBin(png, "raw", 4), as.raw(c(0x89, 0x50, 0x4e, 0x47)))
  pdf <- files[endsWith(files, ".pdf")][1]
  expect_identical(readChar(pdf, 4), "%PDF")
})

test_that("the normalised CSV holds log2 fold changes vs the reference", {
  out <- withr::local_tempdir()
  files <- suppressMessages(radar_plots(example_csv(), out_dir = out, formats = "png"))
  tab <- utils::read.csv(files[endsWith(files, ".csv")], check.names = FALSE,
                         encoding = "UTF-8")
  expect_equal(tab$Condition, paste("Traitement", c("A", "B", "C", "D")))
  expect_equal(tab[["IL-10"]][1], round(log2(14500 / 70.8), 4))
})

test_that("fc normalisation and other formats are honoured", {
  out <- withr::local_tempdir()
  files <- suppressMessages(radar_plots(example_csv(), out_dir = out,
                                        normalisation = "fc", formats = c("tiff", "PNG")))
  expect_setequal(basename(files), expected_files(c("tiff", "png"), "fc"))
})

test_that("the output folder is created, and defaults to the working directory", {
  base <- withr::local_tempdir()
  nested <- file.path(base, "a", "b")
  files <- suppressMessages(radar_plots(example_csv(), out_dir = nested, formats = "png"))
  expect_true(dir.exists(nested))
  expect_true(all(dirname(files) == normalizePath(nested)))

  withr::local_dir(base)
  files <- suppressMessages(radar_plots(example_csv(), formats = "png"))
  expect_true(all(dirname(files) == normalizePath(base)))
})

test_that("semicolon / decimal comma files are read", {
  out <- withr::local_tempdir()
  lines <- readLines(example_csv(), encoding = "UTF-8")
  csv2 <- file.path(out, "fr.csv")
  writeLines(gsub(".", ",", gsub(",", ";", lines, fixed = TRUE), fixed = TRUE), csv2, useBytes = TRUE)
  plots <- radar_build(csv2)
  expect_named(plots, c("ATB paroi/membrane", "ATB autre"))
  expect_s3_class(plots[[1]], "ggplot")
})

test_that("explicit errors on bad inputs", {
  out <- withr::local_tempdir()
  expect_error(radar_plots(file.path(out, "nope.csv"), out_dir = out), "not found")
  expect_error(radar_plots(example_csv(), out_dir = out, formats = "bmp"),
               "Unsupported output format")
  bad <- file.path(out, "bad.csv")
  writeLines(c("Sample,Group,A,B,C", "x,Référence,1,2,3"), bad)
  expect_error(radar_plots(bad, out_dir = out), "Missing required column")
  txt <- file.path(out, "data.xlsx")
  file.create(txt)
  expect_error(radar_plots(txt, out_dir = out), "Unsupported input format")
  expect_error(radar_plots(example_csv(), out_dir = out, limits = "10,-3"), "Invalid limits")
})
