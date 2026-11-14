#!/usr/bin/env Rscript
# =============================================================================
# Radar charts (cytokines / oxylipins) from a CSV file.
#
# Command line, from the labtools folder:
#   Rscript radar_plots/radar_cytokines.R                      # radar_plots/data/mes_donnees.csv
#   Rscript radar_plots/radar_cytokines.R <data.csv> [output_folder]
#
# In RStudio: open this file, then "Source".
# By default reads radar_plots/data/mes_donnees.csv and writes to
# radar_plots/output/. Start the CSV from radar_plots/radar_template.csv.
# =============================================================================

# ---- Settings (edit if needed) ----------------------------------------------
data_name     <- "mes_donnees.csv"  # file inside radar_plots/data/
normalisation <- "log2fc"   # "log2fc" (log2 fold change) or "fc" (fold change)
show_stars    <- TRUE       # FALSE = no significance stars
limits        <- NULL       # NULL = automatic; e.g. c(-3, 10) as in the Excel file
formats       <- c("png", "pdf")
# -----------------------------------------------------------------------------

# Folder of this script (radar_plots/), whether run with Rscript or sourced.
tool_dir <- tryCatch({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else dirname(normalizePath(sys.frame(1)$ofile))
}, error = function(e) "radar_plots")

data_file <- file.path(tool_dir, "data", data_name)
out_dir   <- file.path(tool_dir, "output")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) data_file <- args[1]
if (length(args) >= 2) out_dir   <- args[2]

# data/ is not versioned: create it on a fresh clone.
dir.create(file.path(tool_dir, "data"), showWarnings = FALSE)

if (!file.exists(data_file))
  stop("Data file not found: ", data_file,
       "\nCopy the template first, e.g.:\n  cp radar_plots/radar_template.csv radar_plots/data/",
       basename(data_file), call. = FALSE)

source(file.path(tool_dir, "radar_plot.R"))

radar_from_file(data_file, out_dir = out_dir, normalisation = normalisation,
                show_stars = show_stars, limits = limits, formats = formats)
