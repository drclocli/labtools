# =============================================================================
# radar_plot.R — Radar charts of mediators (cytokines, oxylipins, ...) per
# condition, normalised against a reference condition (e.g. "Non traité").
#
# R port of the Excel template "Modele_radar_ATB_cytokines_oxylipines":
#   - one radar per group (column "Groupe"), conditions drawn in table order;
#   - values = log2 fold change (or fold change) vs the reference row;
#   - grey dashed polygon = reference (0 in log2 FC, 1 in FC);
#   - branch labels coloured by category (anti- vs pro-inflammatory);
#   - significance stars: next to the branch name when the radar has a single
#     condition, otherwise in the legend, e.g. "Ciprofloxacin (IL-6 **, ...)".
#
# Dependency: ggplot2.
#
# Quick use:
#   source("radar_plots/radar_plot.R")
#   plots <- radar_from_file("radar_plots/data/mes_donnees.csv", out_dir = "radar_plots/output")
# =============================================================================

# ---- Default settings -------------------------------------------------------

# Colours / markers of the conditions, in order (Okabe-Ito, colour-blind safe).
# The first 4 are those of the Excel template.
RADAR_SERIES_COLOURS <- c("#0072B2", "#D55E00", "#CC79A7", "#E69F00",
                          "#009E73", "#56B4E9", "#000000", "#F0E442")
RADAR_SERIES_SHAPES  <- c(16, 15, 17, 18, 1, 0, 2, 5)  # circle, square, triangle, diamond, ...

# Branch label colour per category (keys are matched case-insensitively on
# their beginning: "anti", "anti-inflammatoire", "pro", "pro-inflammatoire"...).
RADAR_CATEGORY_COLOURS <- c(anti = "#1A7F3C", pro = "#C00000")

# Reserved values of the "Groupe" column.
RADAR_REFERENCE_GROUP <- c("reference", "référence")
RADAR_HIDDEN_GROUP    <- c("ne pas afficher", "hide")

# ---- Reading ----------------------------------------------------------------

#' Read the input table (CSV, comma or semicolon separated).
#'
#' Expected layout (one row per condition; see radar_plots/radar_template.csv):
#'   Condition | Groupe | <branch 1> | ... | <branch n> | <branch 1>_sig | ... | <branch n>_sig
#' - exactly one row whose Groupe is "Référence": the reference condition;
#' - optional row whose Condition is "Catégorie": "anti" / "pro" per branch
#'   (colours the branch labels);
#' - "<branch>_sig" columns (optional): *, **, *** or **** ; empty if ns.
#' Branch order on the radar = column order.
read_radar_data <- function(path) {
  first <- readLines(path, n = 1, warn = FALSE, encoding = "UTF-8")
  semicolon <- lengths(regmatches(first, gregexpr(";", first))) >
               lengths(regmatches(first, gregexpr(",", first)))
  raw <- utils::read.table(
    path, header = TRUE, sep = if (semicolon) ";" else ",",
    dec = if (semicolon) "," else ".", quote = "\"",
    check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character",
    na.strings = c("", "NA"), fileEncoding = "UTF-8-BOM", comment.char = "",
    strip.white = TRUE, blank.lines.skip = TRUE
  )
  parse_radar_table(raw, decimal_comma = semicolon)
}

#' Split a raw data frame (all character columns) into its components.
parse_radar_table <- function(raw, decimal_comma = FALSE) {
  names(raw) <- trimws(names(raw))
  low <- tolower(names(raw))
  cond_col  <- match("condition", low)
  group_col <- match("groupe", low)
  if (is.na(group_col)) group_col <- match("group", low)
  if (is.na(cond_col) || is.na(group_col))
    stop("The table must contain the columns 'Condition' and 'Groupe'.")

  other  <- setdiff(seq_along(raw), c(cond_col, group_col))
  is_sig <- grepl("_sig$", names(raw)[other])
  branches <- names(raw)[other][!is_sig]
  if (length(branches) < 3) stop("At least 3 branches (value columns) are needed for a radar.")

  raw <- raw[!(is.na(raw[[cond_col]]) & is.na(raw[[group_col]])), , drop = FALSE]
  cond  <- trimws(ifelse(is.na(raw[[cond_col]]), "", raw[[cond_col]]))
  group <- trimws(ifelse(is.na(raw[[group_col]]), "", raw[[group_col]]))

  # Optional "Catégorie" row
  cat_row <- which(tolower(cond) %in% c("catégorie", "categorie", "category"))
  categories <- setNames(rep(NA_character_, length(branches)), branches)
  if (length(cat_row)) {
    categories[] <- trimws(unlist(raw[cat_row[1], branches]))
  }

  ref_row <- which(tolower(group) %in% RADAR_REFERENCE_GROUP)
  if (length(ref_row) != 1)
    stop("Exactly one row must have Groupe = 'Référence' (found ", length(ref_row), ").")

  to_num <- function(x) {
    x <- gsub("[[:space:] ]", "", x)
    if (decimal_comma) x <- sub(",", ".", x, fixed = TRUE)
    suppressWarnings(as.numeric(x))
  }
  values <- as.data.frame(lapply(raw[, branches, drop = FALSE], to_num),
                          check.names = FALSE)

  stars <- matrix("", nrow(raw), length(branches), dimnames = list(NULL, branches))
  for (b in branches) {
    sc <- paste0(b, "_sig")
    if (sc %in% names(raw)) {
      s <- trimws(ifelse(is.na(raw[[sc]]), "", raw[[sc]]))
      bad <- s != "" & !grepl("^\\*{1,4}$", s)
      if (any(bad)) stop("Invalid star value in column '", sc, "': ",
                         paste(unique(s[bad]), collapse = ", "),
                         " (expected *, **, *** or ****).")
      stars[, b] <- s
    }
  }

  keep <- setdiff(seq_len(nrow(raw)), c(cat_row, ref_row))
  keep <- keep[cond[keep] != "" & group[keep] != "" &
               !(tolower(group[keep]) %in% RADAR_HIDDEN_GROUP)]

  ref_values <- unlist(values[ref_row, ])
  if (any(is.na(ref_values) | ref_values <= 0))
    stop("The reference row must contain a positive value for every branch: ",
         paste(branches[is.na(ref_values) | ref_values <= 0], collapse = ", "))

  list(
    branches   = branches,
    categories = categories,
    reference  = list(name = cond[ref_row], values = ref_values),
    conditions = data.frame(condition = cond[keep], group = group[keep],
                            stringsAsFactors = FALSE),
    values     = as.matrix(values[keep, , drop = FALSE]),
    stars      = stars[keep, , drop = FALSE]
  )
}

# ---- Normalisation ----------------------------------------------------------

#' Fold change (or log2 fold change) of each condition vs the reference.
normalise_radar <- function(dat, normalisation = c("log2fc", "fc")) {
  normalisation <- match.arg(normalisation)
  ratio <- sweep(dat$values, 2, dat$reference$values, "/")
  out <- if (normalisation == "fc") ratio else log2(ratio)
  out[!is.finite(out)] <- NA
  rownames(out) <- dat$conditions$condition
  out
}

# ---- Plot -------------------------------------------------------------------

# "IL-6 **, IL-1β ***" for one condition (NULL-safe).
stars_text <- function(stars_row) {
  s <- stars_row[stars_row != ""]
  if (!length(s)) return("")
  paste(paste(names(s), s), collapse = ", ")
}

# Wrap a legend label at ", " only, so a star never leaves its mediator name.
wrap_legend <- function(s, width = 45) {
  parts <- strsplit(s, ", ", fixed = TRUE)[[1]]
  lines <- parts[1]
  for (p in parts[-1]) {
    last <- length(lines)
    if (nchar(lines[last]) + nchar(p) + 2 <= width) {
      lines[last] <- paste0(lines[last], ", ", p)
    } else {
      lines[last] <- paste0(lines[last], ",")
      lines <- c(lines, paste0("  ", p))
    }
  }
  paste(lines, collapse = "\n")
}

category_colour <- function(cat) {
  out <- rep("black", length(cat))
  for (k in names(RADAR_CATEGORY_COLOURS)) {
    hit <- !is.na(cat) & startsWith(tolower(cat), k)
    out[hit] <- RADAR_CATEGORY_COLOURS[[k]]
  }
  out
}

#' Draw one radar.
#'
#' @param norm     matrix (conditions x branches) of normalised values.
#' @param stars    matrix of stars, same shape as `norm`.
#' @param branches branch names (column order = order around the radar).
#' @param categories category of each branch ("anti"/"pro"/NA).
#' @param ref_name name of the reference condition (legend).
#' @param ref_value 0 (log2 FC) or 1 (FC).
#' @param limits   c(min, max) of the radial scale.
#' @param step     spacing of the grid rings.
#' @param show_stars TRUE to show significance stars.
#' @param clockwise FALSE (default, as in the Excel file): branches go
#'                 counter-clockwise from the top.
#' @param title    plot title (NULL for none).
#' @param legend_width wrap width (characters) of legend labels.
plot_radar <- function(norm, stars, branches, categories, ref_name,
                       ref_value = 0, limits = c(-3, 10), step = 2,
                       show_stars = TRUE, clockwise = FALSE, title = NULL,
                       legend_width = 45, base_size = 11) {
  if (!requireNamespace("ggplot2", quietly = TRUE))
    stop("Package 'ggplot2' is required: install.packages('ggplot2')")

  n_b <- length(branches)
  n_c <- nrow(norm)
  if (n_c > length(RADAR_SERIES_COLOURS))
    stop("At most ", length(RADAR_SERIES_COLOURS), " conditions per radar.")
  lo <- limits[1]; hi <- limits[2]

  # Geometry: first branch at the top, then counter-clockwise (or clockwise).
  dir   <- if (clockwise) -1 else 1
  theta <- pi / 2 + dir * 2 * pi * (seq_len(n_b) - 1) / n_b
  rad   <- function(v) (pmin(pmax(v, lo), hi) - lo) / (hi - lo)
  xy    <- function(v, i) data.frame(x = rad(v) * cos(theta[i]), y = rad(v) * sin(theta[i]))

  # Grid rings (polygons, like Excel) and spokes
  breaks <- unique(c(seq(lo, hi, by = step), hi))
  rings <- do.call(rbind, lapply(breaks, function(b) {
    i <- c(seq_len(n_b), 1)
    cbind(xy(rep(b, length(i)), i), ring = b)
  }))
  spokes <- data.frame(x = 0, y = 0, xend = cos(theta), yend = sin(theta))
  tick_lab <- data.frame(
    x = rad(breaks) * cos(theta[1]), y = rad(breaks) * sin(theta[1]),
    lab = ifelse(breaks > 0, paste0("+", format(breaks, trim = TRUE)),
                 format(breaks, trim = TRUE))
  )

  # Series names (stars in the legend when several conditions)
  cond_names <- rownames(norm)
  legend_names <- cond_names
  if (show_stars && n_c > 1) {
    st <- vapply(seq_len(n_c), function(k) stars_text(stars[k, ]), "")
    legend_names <- ifelse(st == "", cond_names, paste0(cond_names, " (", st, ")"))
  }
  legend_names <- unname(vapply(legend_names, wrap_legend, "", width = legend_width))
  ref_label <- paste0(ref_name, " (référence)")
  series_levels <- c(legend_names, ref_label)

  # Data of the curves (closed polygon; NA = gap in the line)
  curve <- function(v, name) {
    i <- c(seq_len(n_b), 1)
    d <- xy(v[i], i)
    d$y[is.na(v[i])] <- NA
    d$serie <- name
    d
  }
  lines <- do.call(rbind, c(
    lapply(seq_len(n_c), function(k) curve(norm[k, ], legend_names[k])),
    list(curve(rep(ref_value, n_b), ref_label))
  ))
  lines$serie <- factor(lines$serie, levels = series_levels)
  points <- lines[lines$serie != ref_label & !is.na(lines$y), ]
  points <- points[!duplicated(points[c("x", "y", "serie")]), ]

  # Branch labels (stars next to the name when a single condition)
  lab_txt <- branches
  if (show_stars && n_c == 1) {
    s <- stars[1, ]
    lab_txt <- ifelse(s == "", branches, paste(branches, s))
  }
  lab_r <- 1.08
  labels <- data.frame(
    x = lab_r * cos(theta), y = lab_r * sin(theta), lab = lab_txt,
    col = category_colour(categories),
    hjust = ifelse(abs(cos(theta)) < 0.15, 0.5, ifelse(cos(theta) > 0, 0, 1)),
    vjust = ifelse(abs(sin(theta)) < 0.15, 0.5, ifelse(sin(theta) > 0, 0, 1))
  )

  cols   <- setNames(c(RADAR_SERIES_COLOURS[seq_len(n_c)], "#7F7F7F"), series_levels)
  shapes <- setNames(c(RADAR_SERIES_SHAPES[seq_len(n_c)], NA), series_levels)
  ltys   <- setNames(c(rep("solid", n_c), "dashed"), series_levels)
  lwds   <- setNames(c(rep(0.9, n_c), 0.8), series_levels)

  ggplot2::ggplot() +
    ggplot2::geom_path(data = rings, ggplot2::aes(x, y, group = ring),
                       colour = "#D9D9D9", linewidth = 0.35) +
    ggplot2::geom_segment(data = spokes, ggplot2::aes(x, y, xend = xend, yend = yend),
                          colour = "#D9D9D9", linewidth = 0.35) +
    ggplot2::geom_path(data = lines,
                       ggplot2::aes(x, y, colour = serie, linetype = serie,
                                    linewidth = serie, group = serie),
                       na.rm = TRUE) +
    ggplot2::geom_point(data = points, ggplot2::aes(x, y, colour = serie, shape = serie),
                        size = 2.6) +
    ggplot2::geom_label(data = tick_lab, ggplot2::aes(x, y, label = lab),
                        colour = "#808080", fill = "white", alpha = 0.8,
                        linewidth = 0, label.padding = grid::unit(0.08, "lines"),
                        size = (base_size - 2) / ggplot2::.pt,
                        hjust = 1, nudge_x = -0.025, vjust = 0.5) +
    ggplot2::geom_text(data = labels,
                       ggplot2::aes(x, y, label = lab, hjust = hjust, vjust = vjust),
                       colour = labels$col, fontface = "bold",
                       size = (base_size - 0.5) / ggplot2::.pt) +
    ggplot2::scale_colour_manual(values = cols, breaks = series_levels, name = NULL, drop = FALSE) +
    ggplot2::scale_shape_manual(values = shapes, breaks = series_levels, name = NULL, drop = FALSE) +
    ggplot2::scale_linetype_manual(values = ltys, breaks = series_levels, name = NULL, drop = FALSE) +
    ggplot2::scale_linewidth_manual(values = lwds, breaks = series_levels, name = NULL, drop = FALSE) +
    ggplot2::coord_equal(xlim = c(-1.45, 1.45), ylim = c(-1.2, 1.2), clip = "off") +
    ggplot2::labs(title = title) +
    ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(
      legend.position = "right",
      legend.key.width = grid::unit(1.6, "lines"),
      legend.key.spacing.y = grid::unit(0.5, "lines"),
      legend.text = ggplot2::element_text(size = base_size - 1),
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5,
                                         margin = ggplot2::margin(b = 8)),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
}

# Pick "nice" radial limits that contain all the values and the reference.
auto_limits <- function(norm, ref_value, step) {
  v <- c(norm[is.finite(norm)], ref_value)
  if (ref_value == 0) {
    lo <- min(-3, floor(min(v)))
    hi <- max(3, ceiling(max(v)))
  } else {
    lo <- 0
    hi <- max(2, max(v))
  }
  # Rings start at `lo` every `step` (as in Excel: -3, -1, +1, ...)
  c(lo, lo + step * ceiling((hi - lo) / step))
}

# ---- Main entry point -------------------------------------------------------

#' Read a data file and produce one radar per group.
#'
#' @param path          CSV file (see read_radar_data()).
#' @param out_dir       folder for the figures (NULL = do not save).
#' @param normalisation "log2fc" (default) or "fc".
#' @param show_stars    TRUE / FALSE.
#' @param limits        c(min, max) of the scale; NULL = automatic, shared by
#'                      all radars. The Excel template used c(-3, 10).
#' @param step          spacing between grid rings; NULL = 2 in log2 FC,
#'                      automatic in FC.
#' @param formats       file formats to write ("png", "pdf", "svg", "tiff").
#' @param width,height  figure size in inches.
#' @param title         TRUE = group name as title, FALSE = no title.
#' @return a named list of ggplot objects (one per group), invisibly.
radar_from_file <- function(path, out_dir = "radar_plots/output",
                            normalisation = c("log2fc", "fc"),
                            show_stars = TRUE, limits = NULL, step = NULL,
                            formats = c("png", "pdf"), width = 9, height = 6,
                            dpi = 300, title = TRUE, clockwise = FALSE) {
  normalisation <- match.arg(normalisation)
  dat  <- read_radar_data(path)
  norm <- normalise_radar(dat, normalisation)
  ref_value <- if (normalisation == "fc") 1 else 0
  if (is.null(step)) {
    # log2 FC: rings every 2 units (as in Excel); FC: about 5 rings.
    step <- if (normalisation == "fc") diff(pretty(c(0, max(norm, 2, na.rm = TRUE)), n = 5))[1] else 2
  }
  if (is.null(limits)) limits <- auto_limits(norm, ref_value, step)

  outside <- norm < limits[1] | norm > limits[2]
  if (any(outside, na.rm = TRUE))
    warning("Some values fall outside the scale ", limits[1], " to ", limits[2],
            " and are drawn at its edge.")

  groups <- unique(dat$conditions$group)
  plots <- list()
  for (g in groups) {
    rows <- which(dat$conditions$group == g)
    plots[[g]] <- plot_radar(
      norm = norm[rows, , drop = FALSE], stars = dat$stars[rows, , drop = FALSE],
      branches = dat$branches, categories = dat$categories,
      ref_name = dat$reference$name, ref_value = ref_value,
      limits = limits, step = step, show_stars = show_stars,
      clockwise = clockwise, title = if (isTRUE(title)) g else NULL
    )
  }

  if (!is.null(out_dir)) {
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    for (i in seq_along(plots)) {
      slug <- gsub("[^A-Za-z0-9]+", "_", iconv(names(plots)[i], to = "ASCII//TRANSLIT"))
      slug <- gsub("^_|_$", "", slug)
      base <- file.path(out_dir, sprintf("radar_%02d_%s", i, slug))
      for (f in formats) {
        # cairo_pdf renders Greek letters (TNFα, IL-1β); the base pdf device does not.
        dev <- if (f == "pdf" && capabilities("cairo")) grDevices::cairo_pdf else NULL
        ggplot2::ggsave(paste0(base, ".", f), plots[[i]], device = dev,
                        width = width, height = height, dpi = dpi, bg = "white")
      }
    }
    # Normalised table (equivalent of the "2_Normalisé" sheet), for traceability
    tab <- data.frame(Condition = dat$conditions$condition,
                      Groupe = dat$conditions$group, round(norm, 4),
                      check.names = FALSE, row.names = NULL)
    utils::write.csv(tab, file.path(out_dir, paste0("valeurs_normalisees_", normalisation, ".csv")),
                     row.names = FALSE, fileEncoding = "UTF-8")
    message("Radars written to ", normalizePath(out_dir), " (scale ",
            limits[1], " to ", limits[2], ").")
  }
  invisible(plots)
}
