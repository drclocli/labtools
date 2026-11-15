#!/bin/sh
# Install (or update) the labtools R package and its command line apps.
#
#   ./install.sh                         # from anywhere: path/to/labtools/install.sh
#   RAPP_BIN_DIR=/some/bin ./install.sh  # install the launchers elsewhere
#
# Safe to run again: packages already present are kept, the package and the
# launchers are reinstalled from the current sources.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export LABTOOLS_REPO_DIR="$REPO_DIR"
export LABTOOLS_SHELL_PATH="$PATH"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Error: Rscript not found. Install R first (macOS: brew install r)." >&2
  exit 1
fi

Rscript --vanilla - <<'EOF'
repo <- Sys.getenv("LABTOOLS_REPO_DIR")
options(repos = c(CRAN = "https://cloud.r-project.org"))
lib <- .libPaths()[1]

step <- function(...) cat("\n==>", ..., "\n")

# 1. pak and Rapp
for (p in c("pak", "Rapp")) {
  if (requireNamespace(p, quietly = TRUE)) {
    cat(sprintf("%s %s already installed\n", p, utils::packageVersion(p)))
  } else {
    step("Installing", p)
    utils::install.packages(p, lib = lib)
    if (!requireNamespace(p, quietly = TRUE))
      stop("Could not install ", p, ". Rapp needs the Rust compiler when built ",
           "from source (macOS: brew install rust).", call. = FALSE)
  }
}

# 2. The package and its dependencies
step("Installing labtools from", repo)
pak::local_install(repo, upgrade = FALSE, ask = FALSE)

# 3. Launchers (only files previously written by Rapp are replaced)
step("Installing command line launchers")
launchers <- Rapp::install_pkg_cli_apps("labtools")

# 4. Summary
bin_dir <- if (length(launchers)) dirname(launchers[1]) else NA
apps <- list.files(system.file("exec", package = "labtools"), pattern = "\\.[Rr]$")
step("Installed commands")
for (a in sub("\\.[Rr]$", "", apps)) {
  path <- file.path(bin_dir, a)
  cat(sprintf("  %-14s %s%s\n", a, path, if (file.exists(path)) "" else "  (MISSING)"))
}
on_path <- !is.na(bin_dir) &&
  normalizePath(bin_dir) %in% normalizePath(strsplit(Sys.getenv("LABTOOLS_SHELL_PATH"), ":")[[1]], mustWork = FALSE)
if (!on_path)
  cat("\nNote:", bin_dir, "is not on the PATH of this shell yet.",
      "Open a new terminal (Rapp adds it to ~/.zprofile on macOS),",
      "or call the commands with their absolute path.\n")
EOF
