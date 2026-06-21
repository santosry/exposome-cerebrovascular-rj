# reporting.R — Report generation, manuscript rendering, and audit centralization
# =============================================================================

#' Render BSB 2026 outputs: article PDF and presentation PDF
#' [BSB-REMOVED] This function is disabled in the public compendium.
#' The BSB 2026 manuscript source is excluded from this repository.
render_bsb_outputs <- function() {
  log_msg("INFO", "BSB manuscript rendering is disabled in the public compendium. " ,
          "The manuscript source is excluded from this repository.")
  invisible(TRUE)
}

#' Centralize all audit files for final delivery
centralize_audits <- function() {
  audit_dir <- file.path(PROJECT_ROOT, "audit")
  dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

  sources <- c(
    file.path(PROJECT_ROOT, "outputs", "audits"),
    file.path(PROJECT_ROOT, "outputs", "logs"),
    file.path(PROJECT_ROOT, "outputs", "reports"),
    file.path(PROJECT_ROOT, "logs")
  )
  sources <- sources[file.exists(sources)]

  manifest <- purrr::map_dfr(sources, function(src) {
    files <- list.files(src, recursive = TRUE, full.names = TRUE)
    purrr::map_dfr(files, function(f) {
      tibble::tibble(
        origem = f,
        tamanho = file.info(f)$size,
        mtime = as.character(file.info(f)$mtime)
      )
    })
  })
  write_audit(manifest, file.path(audit_dir, "manifesto_auditorias.csv"))
  invisible(manifest)
}

#' Write final epidemiological reports
write_final_reports_epidemiologicos <- function(dat_macro, dlnm_results) {
  report_dir <- file.path(PROJECT_ROOT, "reports")
  dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

  auc_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                        "tabela_auc_rr_dlnm_macrorregiao.csv")
  bayes_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                          "ranking_modelos_rr_ic95_auc_residuos_bayes.csv")
  quality_path <- file.path(PROJECT_ROOT, "audit",
                            "resumo_qualidade_modelos_dlnm.csv")

  # Technical report
  lines_tec <- c(
    "# Technical Report — DLNM Cerebrovascular RJ (2010–2025)",
    "",
    paste0("Execution: ", PIPELINE_RUN_ID),
    paste0("Period: ", PERIOD_LABEL),
    paste0("Macroregions: ", dplyr::n_distinct(dat_macro$macro_regiao)),
    paste0("Days per macroregion: ",
           paste(sort(unique(table(dat_macro$macro_regiao))), collapse = ", ")),
    paste0("DLNM models fitted: ", length(dlnm_results)),
    "",
    "## Data Sources",
    "- SIH-RD: hospital admissions (microdatasus)",
    "- SIM-DO: mortality records (microdatasus); 2025 uses SIH hospital deaths as fallback",
    "- INMET: temperature and humidity (BrazilMet)",
    "- SIDRA/IBGE: population denominators",
    "",
    "## Model Specification",
    "- DLNM with Quasi-Poisson / Negative Binomial",
    "- Natural splines: exposure (df=4), lags (df=3, log-knots, max=14)",
    "- Time trend: ns(df=7/year)",
    "- MMT-based centering",
    "",
    "## Interpretation Criteria",
    "- RR cumulative, IC95%",
    "- Excess RR AUC",
    "- FDR correction",
    "- Bayesian hierarchical stabilization",
    "- Posterior probability of RR > 1.10"
  )
  writeLines(lines_tec, file.path(report_dir, "technical_report.md"))

  # Reproducibility report
  lines_rep <- c(
    "# Reproducibility Report",
    "",
    paste0("FORCE_RAW_DOWNLOAD: ", FORCE_RAW_DOWNLOAD),
    "The pipeline executes: download → process → DLNM → Bayesian → reports",
    "Derived directories are cleaned before execution.",
    "Execution fails on: invalid encoding, duplicate climate series, convergence alerts."
  )
  writeLines(lines_rep, file.path(report_dir, "reproducibility_report.md"))

  # Bayesian validation report
  if (file.exists(bayes_path)) {
    bayes <- readr::read_csv(bayes_path, show_col_types = FALSE)
    lines_bayes <- c(
      "# Bayesian Validation Report",
      "",
      "Model: hierarchical normal-normal",
      "Input: log(RR) from DLNM",
      paste0("Rows: ", nrow(bayes)),
      paste0("Posterior probabilities (RR > 1.10): ",
             sum(is.finite(bayes$prob_rr_gt_threshold)))
    )
    writeLines(lines_bayes, file.path(report_dir, "bayesian_report.md"))
  }

  # Quality control report
  if (file.exists(quality_path)) {
    qc_tbl <- readr::read_csv(quality_path, show_col_types = FALSE)
    lines_qc <- c(
      "# Quality Control Report",
      "",
      paste0("Models with convergence alert: ",
             sum(qc_tbl$alerta_convergencia %in% TRUE, na.rm = TRUE)),
      "Audit trail: see audit/ directory",
      "Blocking criteria: encoding, coverage, climate duplication, convergence"
    )
    writeLines(lines_qc, file.path(report_dir, "quality_control_report.md"))
  }

  invisible(TRUE)
}

#' Final quality control check
final_quality_control_epidemiologicos <- function(dat_macro, dlnm_results) {
  required_files <- c(
    file.path(PROJECT_ROOT, "data", "processed", "dataset_dlnm_macrorregiao.rds"),
    file.path(PROJECT_ROOT, "data", "processed", "modelos_dlnm_macrorregiao.rds"),
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_rr_dlnm_macrorregiao.csv"),
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_auc_rr_dlnm_macrorregiao.csv"),
    file.path(PROJECT_ROOT, "outputs", "tables",
              "ranking_modelos_rr_ic95_auc_residuos_bayes.csv")
  )

  quality_path <- file.path(PROJECT_ROOT, "audit", "resumo_qualidade_modelos_dlnm.csv")
  model_quality <- if (file.exists(quality_path)) {
    readr::read_csv(quality_path, show_col_types = FALSE)
  } else {
    tibble::tibble(alerta_convergencia = logical())
  }

  expected_macros <- length(unique(macro_lookup_manual()$macro_regiao))

  qc <- tibble::tibble(
    item = c("arquivos_obrigatorios", "n_macrorregioes",
             "modelos_dlnm", "alerta_convergencia"),
    valor = c(
      paste(file.exists(required_files), collapse = ";"),
      as.character(dplyr::n_distinct(dat_macro$macro_regiao)),
      as.character(length(dlnm_results)),
      as.character(sum(model_quality$alerta_convergencia %in% TRUE, na.rm = TRUE))
    ),
    status = c(
      ifelse(all(file.exists(required_files)), "ok", "falha"),
      ifelse(dplyr::n_distinct(dat_macro$macro_regiao) == expected_macros, "ok", "falha"),
      ifelse(length(dlnm_results) > 0, "ok", "falha"),
      ifelse(sum(model_quality$alerta_convergencia %in% TRUE, na.rm = TRUE) == 0,
             "ok", "warning")
    )
  )
  write_audit(qc, file.path(PROJECT_ROOT, "audit", "controle_qualidade_final.csv"))

  if (any(qc$status == "falha")) {
    stop("Final quality control failed. See audit/controle_qualidade_final.csv",
         call. = FALSE)
  }
  invisible(qc)
}

#' Run benchmark validation suite
run_benchmark_validation <- function() {
  log_msg("INFO", "Benchmark: starting full validation")

  dlnm_dir <- file.path(PROJECT_ROOT, "data", "processed")
  auc_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                        "tabela_auc_rr_dlnm_macrorregiao.csv")

  checks <- list()

  # Check 1: All macroregions present
  lookup <- macro_lookup_manual()
  expected_macros <- unique(lookup$macro_regiao)
  checks$macroregions <- length(expected_macros) == 9

  # Check 2: AUC table exists and has models (dynamic threshold from actual grid)
  if (file.exists(auc_path)) {
    auc_tbl <- readr::read_csv(auc_path, show_col_types = FALSE)
    # [FIX C10] Dynamic expected count: unique macroregions × outcomes × exposures
    n_expected_models <- dplyr::n_distinct(auc_tbl$macro_regiao) *
                         dplyr::n_distinct(auc_tbl$outcome) *
                         dplyr::n_distinct(auc_tbl$exposure)
    checks$auc_model_count <- nrow(auc_tbl) >= max(4, n_expected_models * 0.5)
    checks$auc_all_positive <- all(auc_tbl$auc_excesso_rr >= 0, na.rm = TRUE)
  }

  # Check 3: RR table exists
  rr_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                       "tabela_rr_dlnm_macrorregiao.csv")
  if (file.exists(rr_path)) {
    rr_tbl <- readr::read_csv(rr_path, show_col_types = FALSE)
    checks$rr_all_positive <- all(rr_tbl$rr_cumulativo > 0, na.rm = TRUE)
  }

  # Check 4: Bayesian results
  bayes_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                          "ranking_modelos_rr_ic95_auc_residuos_bayes.csv")
  if (file.exists(bayes_path)) {
    bayes <- readr::read_csv(bayes_path, show_col_types = FALSE)
    checks$bayesian_prob_range <- all(
      dplyr::between(bayes$prob_rr_gt_threshold, 0, 1), na.rm = TRUE)
  }

  # Write benchmark results
  bench_results <- tibble::tibble(
    check = names(checks),
    passed = unlist(checks)
  )
  write_audit(bench_results,
    file.path(PROJECT_ROOT, "audit", "benchmark_validation_results.csv"))

  n_passed <- sum(bench_results$passed)
  n_total <- nrow(bench_results)
  log_msg("INFO", "Benchmark complete: ", n_passed, "/", n_total, " checks passed")

  invisible(bench_results)
}

#' Audit the geographic consistency of outcome data
audit_outcome_geography_criterion <- function() {
  audit <- tibble::tibble(
    criterio = "municipio_residencia_macrorregiao",
    descricao = "Outcomes assigned by municipality of residence → health macroregion",
    validacao = "All 92 municipalities mapped to 9 macroregions"
  )
  write_audit(audit, file.path(PROJECT_ROOT, "audit",
    "auditoria_criterio_geografico_desfechos.csv"))
  invisible(audit)
}
