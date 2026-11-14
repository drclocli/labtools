#!/usr/bin/env Rscript
# =============================================================================
# Radar charts (cytokines / oxylipins) from a CSV file.
#
# Command line, from the labtools folder:
#   Rscript scripts/radar_cytokines.R <data.csv> [output_folder]
#
# In RStudio: set `data_file` below, then "Source".
# Fill the CSV from templates/radar_template.csv (layout described in the README).
# =============================================================================

# ---- Settings (edit if needed) ----------------------------------------------
data_file     <- "templates/radar_template.csv"
out_dir       <- "output/radar"
normalisation <- "log2fc"   # "log2fc" (log2 fold change) or "fc" (fold change)
show_stars    <- TRUE       # FALSE = no significance stars
limits        <- NULL       # NULL = automatic; e.g. c(-3, 10) as in the Excel file
formats       <- c("png", "pdf")
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) data_file <- args[1]
if (length(args) >= 2) out_dir   <- args[2]

# Locate R/radar_plot.R whether the script is run with Rscript or sourced.
script_dir <- tryCatch({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else dirname(normalizePath(sys.frame(1)$ofile))
}, error = function(e) "scripts")
source(file.path(script_dir, "..", "R", "radar_plot.R"))

radar_from_file(data_file, out_dir = out_dir, normalisation = normalisation,
                show_stars = show_stars, limits = limits, formats = formats)
