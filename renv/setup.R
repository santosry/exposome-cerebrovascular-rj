# ── renv bootstrap script ──
# This file activates renv for reproducible R package management.
# Run renv::init() to create the lockfile, then renv::snapshot() to save state.

# Load renv
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}
library(renv)

# Initialize renv (only needed once)
# renv::init()

# After installing all packages used in the project:
# renv::snapshot()

# To restore on another machine:
# renv::restore()

# ── Package manifest ──
# The following packages are used in this project:

project_packages <- c(
  # Data acquisition
  "microdatasus", "BrazilMet", "sidrar", "geobr", "sf",
  # Core
  "tidyverse", "data.table", "lubridate", "janitor", "dplyr", "tidyr",
  "readr", "tibble", "purrr", "forcats", "stringr", "stringi",
  # DLNM
  "dlnm", "splines", "MASS", "mgcv", "lmtest",
  # Robust SE
  "sandwich",
  # Survival
  "survival",
  # Spatial
  "spdep", "igraph",
  # Time series
  "zoo",
  # Bayesian
  # (no extra packages needed — base R stats used for normal-normal)
  # Visualization
  "ggplot2", "plotly", "htmlwidgets", "patchwork",
  "ggrepel", "scales", "pheatmap",
  # Reporting
  "rmarkdown", "knitr", "DT", "kableExtra",
  # Utilities
  "httr", "jsonlite",
  # Pipeline tools
  "targets", "tarchetypes",
  # Testing
  "testthat", "lintr", "styler"
)

# Install missing
installed <- rownames(installed.packages())
missing <- setdiff(project_packages, installed)
if (length(missing) > 0) {
  cat("Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing)
}

cat("All packages installed. Run renv::snapshot() to lock versions.\n")
