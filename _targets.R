# _targets.R — Modern reproducible pipeline with intelligent caching
# =============================================================================
# Uses the `targets` package for:
#   - Automatic dependency tracking
#   - Smart cache invalidation
#   - Parallel execution
#   - Progress monitoring
#
# Usage: targets::tar_make()

library(targets)
library(tarchetypes)

# Source configuration and all modules
tar_source("config/config.R")
tar_source("R/utils.R")
tar_source("R/download.R")
tar_source("R/exposure_processing.R")
tar_source("R/preprocessing.R")
tar_source("R/dlnm_models.R")
tar_source("R/bayesian_models.R")
tar_source("R/visualization.R")
tar_source("R/reporting.R")

# Package loading
tar_option_set(
  packages = c(
    "tidyverse", "lubridate", "janitor", "dlnm", "splines",
    "MASS", "mgcv", "lmtest", "ggplot2", "readr",
    "sandwich", "survival", "plotly", "htmlwidgets",
    "patchwork", "scales", "stringr", "stringi", "forcats",
    "sf", "geobr", "sidrar", "microdatasus", "BrazilMet"
  ),
  imports = c("dlnm", "MASS", "mgcv", "sandwich", "survival"),
  format = "rds",
  error = "continue"
)

# ═════════════════════════════════════════════════════════════════════════════
# PIPELINE TARGETS
# ═════════════════════════════════════════════════════════════════════════════

list(
  # ── Stage 1: Data Acquisition ──
  tar_target(
    sih_downloaded,
    download_sih(),
    cue = tar_cue("always")
  ),
  tar_target(
    sim_downloaded,
    download_sim(),
    cue = tar_cue("always")
  ),
  tar_target(
    inmet_downloaded,
    download_inmet(),
    cue = tar_cue("always")
  ),

  # ── Stage 2: Population and lookup ──
  tar_target(
    macro_lookup,
    get_macro_lookup()
  ),
  tar_target(
    population,
    download_population_sidra()
  ),

  # ── Stage 3: Data Processing ──
  tar_target(
    outcomes_daily,
    process_outcomes()
  ),
  tar_target(
    climate_macro,
    process_inmet()
  ),

  # ── Stage 4: Analytic Dataset ──
  tar_target(
    dataset_analytic,
    make_analytic_dataset(outcomes_daily, climate_macro, population)
  ),

  # ── Stage 5: DLNM Models ──
  tar_target(
    dlnm_results,
    run_dlnm(dataset_analytic)
  ),

  # ── Stage 6: Sensitivity Analyses ──
  tar_target(
    lag_sensitivity,
    run_lag_sensitivity(dataset_analytic)
  ),
  tar_target(
    pandemic_sensitivity,
    run_pandemic_exclusion_sensitivity(dataset_analytic)
  ),
  tar_target(
    spline_df_sensitivity,
    run_spline_df_sensitivity(dataset_analytic,
      readr::read_csv(
        file.path(PROJECT_ROOT, "outputs", "tables",
                  "tabela_auc_rr_dlnm_macrorregiao.csv"),
        show_col_types = FALSE))
  ),

  # ── Stage 7: Bayesian Validation ──
  tar_target(
    rr_table,
    readr::read_csv(
      file.path(PROJECT_ROOT, "outputs", "tables", "tabela_rr_dlnm_macrorregiao.csv"),
      show_col_types = FALSE)
  ),
  tar_target(
    auc_table,
    readr::read_csv(
      file.path(PROJECT_ROOT, "outputs", "tables", "tabela_auc_rr_dlnm_macrorregiao.csv"),
      show_col_types = FALSE)
  ),
  tar_target(
    residual_diagnostics,
    readr::read_csv(
      file.path(PROJECT_ROOT, "audit", "diagnosticos_autocorrelacao_dlnm.csv"),
      show_col_types = FALSE)
  ),
  tar_target(
    bayesian_results,
    run_bayesian_hierarchical_validation(rr_table, auc_table, residual_diagnostics)
  ),
  tar_target(
    prior_sensitivity_results,
    run_prior_sensitivity(rr_table, auc_table, residual_diagnostics)
  ),

  # ── Stage 8: Visualizations ──
  tar_target(
    fig_monthly_admissions,
    plot_monthly_admissions(dataset_analytic)
  ),
  tar_target(
    fig_climate_seasonality,
    plot_daily_climate_seasonality(dataset_analytic)
  ),
  tar_target(
    fig_cellpress,
    generate_cellpress_figures()
  ),

  # ── Stage 9: Reports ──
  tar_target(
    method_note,
    write_dlnm_method_note()
  ),
  tar_target(
    final_reports,
    write_final_reports_epidemiologicos(dataset_analytic, dlnm_results)
  ),
  tar_target(
    qc_check,
    final_quality_control_epidemiologicos(dataset_analytic, dlnm_results)
  ),
  tar_target(
    audit_centralized,
    centralize_audits()
  ),
  tar_target(
    benchmark_results,
    run_benchmark_validation()
  # [BSB-REMOVED] Manuscript rendering excluded from public compendium
  # tar_target(
  #   manuscript_rendered,
  #   render_bsb_outputs()
  # )
)
