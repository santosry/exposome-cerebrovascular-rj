# Final runner — PM2.5 enabled, saves incrementally with temp file to avoid corruption
Sys.setenv(DLNM_PROJECT_ROOT = getwd())
Sys.setenv(DLNM_FORCE_RAW_DOWNLOAD = 'false')
Sys.setenv(DLNM_ENABLE_AIR_QUALITY = 'true')
options(renv.config.autoloader.enabled = FALSE)

suppressPackageStartupMessages({
  library(dlnm); library(splines); library(MASS); library(sandwich)
  library(dplyr); library(tidyr); library(tibble); library(readr)
})

source('config/config.R', local=TRUE)
source('R/utils.R', local=TRUE)
source('R/dlnm_models.R', local=TRUE)
source('R/bayesian_models.R', local=TRUE)
source('R/reporting.R', local=TRUE)
source('R/preprocessing.R', local=TRUE)

cat('\n=== PM2.5 ENABLED ===\n')

dat_macro <- readRDS('data/processed/dataset_dlnm_macrorregiao.rds')
pm25 <- process_poluentes()
dat_macro$mes <- lubridate::month(dat_macro$data)
dat_macro$pm25_mensal <- NULL
dat_macro <- dplyr::left_join(dat_macro, pm25, by = c('macro_regiao', 'ano', 'mes'))
if(!'tempo' %in% names(dat_macro)) {
  dat_macro$tempo <- as.integer(dat_macro$data - min(dat_macro$data, na.rm=TRUE)) + 1L
}
cat(sprintf('Dataset: %d rows, PM2.5=%.1f ug/m3\n', nrow(dat_macro), mean(dat_macro$pm25_mensal, na.rm=TRUE)))

rfile <- 'data/processed/modelos_dlnm_pm25.rds'
results <- if(file.exists(rfile)) readRDS(rfile) else list()
cat(sprintf('Existing models: %d\n', length(results)))

outcomes <- c('internacoes_i60_i69','obitos_i60_i69','internacoes_i60_i64','obitos_i60_i64',
              'internacoes_i60_i62','obitos_i60_i62','internacoes_i63','obitos_i63')
exposures <- c('temp_med','ur_med')

for(region in sort(unique(dat_macro$macro_regiao))) {
  d <- dplyr::filter(dat_macro, macro_regiao == region)
  for(outcome in outcomes) {
    if(!outcome %in% names(d)) next
    for(exposure in exposures) {
      key <- janitor::make_clean_names(paste(region, outcome, exposure, sep='__'))
      if(key %in% names(results)) next
      cat(sprintf('%s...', key))
      obj <- safe_fetch(
        fit_one_dlnm(d, outcome, exposure, 
          DLNM_FALLBACK$df_exp, DLNM_FALLBACK$df_lag, DLNM_FALLBACK$lag_max),
        key, critical=FALSE)
      if(!is.null(obj)) {
        obj$macro_regiao <- region
        results[[key]] <- obj
        # Atomic save: write to temp, then rename
        tmp <- paste0(rfile, '.tmp')
        saveRDS(results, tmp)
        file.rename(tmp, rfile)
        cat(sprintf(' OK (%d)\n', length(results)))
      } else {
        cat(' FAIL\n')
      }
    }
  }
}

cat(sprintf('\nTotal: %d models\n', length(results)))

# Generate tables
summaries <- list(); aucs <- list(); diagnostics <- list()
for(k in names(results)) {
  obj <- results[[k]]
  summaries[[k]] <- summarise_pred(obj, obj$macro_regiao)
  aucs[[k]] <- summarise_auc(obj, obj$macro_regiao)
  diagnostics[[k]] <- diagnose_model(obj, obj$macro_regiao)
}

sum_tbl <- dplyr::bind_rows(summaries)
auc_tbl <- dplyr::bind_rows(aucs) |> add_fdr_and_evidence_flags()
diag_tbl <- dplyr::bind_rows(diagnostics)

write_audit(sum_tbl, 'outputs/tables/tabela_rr_dlnm_macrorregiao.csv')
write_audit(auc_tbl, 'outputs/tables/tabela_auc_rr_dlnm_macrorregiao.csv')
write_audit(diag_tbl, 'audit/diagnosticos_autocorrelacao_dlnm.csv')

bayes_results <- run_bayesian_hierarchical_validation(sum_tbl, auc_tbl)

sig <- auc_tbl[auc_tbl$classe_fdr == 'fdr_significativo', ]
cat(sprintf('FDR-sig: %d/%d\n', nrow(sig), nrow(auc_tbl)))
cat(sprintf('Bayes Pr>0.80: %d/%d\n',
  sum(bayes_results$prob_rr_gt_threshold>0.80, na.rm=TRUE), nrow(bayes_results)))

cat('DONE\n')
