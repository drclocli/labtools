#' @keywords internal
"_PACKAGE"

# Columns used in ggplot2::aes() inside plot_radar().
utils::globalVariables(c("x", "y", "xend", "yend", "ring", "serie", "lab", "hjust", "vjust"))

# Rapp runs the scripts in exec/; imported so that installing labtools
# always brings it along.
#' @importFrom Rapp run
NULL
