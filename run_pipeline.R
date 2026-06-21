#!/usr/bin/env Rscript
# run_pipeline.R — Master entry point for the DLNM Research Compendium
# =============================================================================
# Usage: Rscript run_pipeline.R
# Or:    source("run_pipeline.R")
#
# This script orchestrates the full reproducible pipeline:
#   Download → Process → Model → Validate → Report → Benchmark

# ── Load configuration ──
source("config/config.R")

# ── Source all modules ──
source("R/utils.R")
source("R/download.R")
source("R/exposure_processing.R")
source("R/preprocessing.R")
source("R/dlnm_models.R")
source("R/bayesian_models.R")
source("R/visualization.R")
source("R/reporting.R")

# ── Install and load required packages ──
CRAN_PACKAGES <- c(
  "microdatasus", "BrazilMet", "tidyverse", "data.table", "lubridate", "janitor",
  "dlnm", "MASS", "mgcv", "lmtest", "ggplot2", "readr", "rmarkdown",
  "plotly", "htmlwidgets", "knitr", "httr",
  "ggrepel", "scales", "sidrar", "geobr", "sf",
  "sandwich", "spdep", "igraph", "zoo", "survival",
  "patchwork", "stringr", "stringi", "forcats", "purrr", "tibble", "tidyr",
  "dplyr", "jsonlite", "pheatmap"
)

ensure_packages(CRAN_PACKAGES)
require_or_stop(CRAN_PACKAGES)

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(janitor)
  library(dlnm)
  library(splines)
  library(MASS)
  library(mgcv)
  library(lmtest)
  library(stringi)
  library(sandwich)
  library(survival)
})

# ═════════════════════════════════════════════════════════════════════════════
# MAIN PIPELINE
# ═════════════════════════════════════════════════════════════════════════════

run_pipeline <- function() {
  log_msg("INFO", "═══ DLNM Research Compendium Pipeline ═══")
  log_msg("INFO", "Run ID: ", PIPELINE_RUN_ID)

  # ── Stage 1: Data Acquisition ──
  log_msg("INFO", "[1/8] Downloading SIH-RD hospital admissions")
  download_sih()

  log_msg("INFO", "[2/8] Downloading SIM-DO mortality records")
  download_sim()

  log_msg("INFO", "[3/8] Downloading INMET weather data")
  download_inmet()

  # ── Stage 2: Data Processing ──
  log_msg("INFO", "[4/8] Processing health outcomes")
  outcomes <- process_outcomes()

  log_msg("INFO", "[5/8] Processing climate exposures")
  meteo <- process_inmet()

  log_msg("INFO", "[6/8] Building population offset")
  population <- download_population_sidra()

  # ── Stage 3: Analytic Dataset ──
  log_msg("INFO", "[7/8] Assembling analytic dataset")
  dat_macro <- make_analytic_dataset(outcomes, meteo, population)
  audit_territorial_integrity_final(dat_macro, meteo)

  # ── Stage 4: DLNM Modeling ──
  log_msg("INFO", "[8/8] Running DLNM models")
  dlnm_results <- run_dlnm(dat_macro)

  # ── Stage 5: Sensitivity Analyses ──
  log_msg("INFO", "Running sensitivity analyses")
  lag_sens <- run_lag_sensitivity(dat_macro)
  pandemic_sens <- run_pandemic_exclusion_sensitivity(dat_macro)

  # ── Stage 6: Bayesian Validation ──
  log_msg("INFO", "Running Bayesian hierarchical validation")
  auc_tbl <- readr::read_csv(
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_auc_rr_dlnm_macrorregiao.csv"),
    show_col_types = FALSE)
  rr_tbl <- readr::read_csv(
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_rr_dlnm_macrorregiao.csv"),
    show_col_types = FALSE)
  resid_tbl <- readr::read_csv(
    file.path(PROJECT_ROOT, "audit", "diagnosticos_autocorrelacao_dlnm.csv"),
    show_col_types = FALSE)

  run_bayesian_hierarchical_validation(rr_tbl, auc_tbl, resid_tbl)
  run_prior_sensitivity(rr_tbl, auc_tbl, resid_tbl)
  run_spline_df_sensitivity(dat_macro, auc_tbl)

  # ── Stage 7: Visualizations ──
  log_msg("INFO", "Generating figures")
  plot_monthly_admissions(dat_macro)
  plot_daily_climate_seasonality(dat_macro)
  generate_cellpress_figures()

  # ── Stage 8: Reports and Validation ──
  log_msg("INFO", "Generating reports and running validation")
  write_dlnm_method_note()
  write_final_reports_epidemiologicos(dat_macro, dlnm_results)
  final_quality_control_epidemiologicos(dat_macro, dlnm_results)
  centralize_audits()
  run_benchmark_validation()

  # [S-015] Temporal holdout validation: train 2010-2022, test 2023-2025
  run_temporal_holdout_validation(dat_macro)

  # [BSB-REMOVED] Manuscript rendering is not part of the public compendium.
  # The BSB 2026 manuscript source is excluded from this repository.
  # render_bsb_outputs()

  log_msg("INFO", "═══ Pipeline Complete ═══")
  log_msg("INFO", length(dlnm_results), " DLNM models fitted across 9 macroregions")
  log_msg("INFO", "Output directory: ", file.path(PROJECT_ROOT, "outputs"))
  log_msg("INFO", "Audit trail: ", file.path(PROJECT_ROOT, "audit"))

  invisible(TRUE)
}

# ── Execute ──
if (tolower(Sys.getenv("RUN_PIPELINE_ON_SOURCE", unset = "true")) %in%
    c("1", "true", "sim", "yes")) {
  run_pipeline()
}
