#!/usr/bin/env Rapp
#| name: radar-plot
#| title: Radar charts of mediators vs a reference
#| description: |
#|   Draw one radar per group of conditions from a CSV file (cytokines,
#|   oxylipins...), as log2 fold change (or fold change) vs the reference row.
#|   Writes radar_NN_<group>.<format> per group and format, plus
#|   valeurs_normalisees_<normalisation>.csv. Files go to the current folder
#|   unless --out is given.
#| examples:
#|   - radar-plot data.csv
#|   - radar-plot data.csv --out figures --format png --format svg
#|   - radar-plot data.csv --limits=-3,10 --json
#| launcher:
#|   default-packages: [base, methods, utils, grDevices, graphics, stats, labtools]

#| description: Input CSV file (columns Condition, Groupe, one per mediator, optional <mediator>_sig).
input <- NULL

#| description: Output folder, created if needed. Default is the current folder.
#| short: o
out <- ""

#| description: "Figure format: png, pdf, svg or tiff. Repeat for several. Default: png and pdf."
#| short: f
format <- c()

#| description: "Normalisation: log2fc (log2 fold change) or fc (fold change)."
normalisation <- "log2fc"

#| description: Scale as min,max, e.g. --limits=-3,10 (use = with negative values). Default is automatic and shared by all radars.
limits <- ""

#| description: Spacing between grid rings. 0 means automatic (2 in log2fc).
step <- 0

#| description: Hide the significance stars (shown by default).
stars <- TRUE

#| description: Do not use the group name as title.
title <- TRUE

#| description: Draw branches clockwise (default is counter-clockwise from the top).
clockwise <- FALSE

#| description: Figure width in inches.
width <- 9

#| description: Figure height in inches.
height <- 6

#| description: Resolution of raster formats (png, tiff).
dpi <- 300L

#| description: Print only {"files":[absolute paths]} on stdout.
json <- FALSE

labtools::cli_main({
  files <- labtools::radar_plots(
    path          = input,
    out_dir       = out,
    normalisation = normalisation,
    show_stars    = stars,
    limits        = limits,
    step          = if (step > 0) step else NULL,
    formats       = if (length(format)) format else c("png", "pdf"),
    width         = width,
    height        = height,
    dpi           = dpi,
    title         = title,
    clockwise     = clockwise
  )
  labtools::cli_emit_files(files, json = json)
})
