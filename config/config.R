# config.R — Global configuration for the DLNM research compendium
# =============================================================================
# All tunable parameters are defined here. No hardcoded values in analysis code.

# ── Project paths ──
PROJECT_ROOT <- normalizePath(
  Sys.getenv("DLNM_PROJECT_ROOT", unset = getwd()),
  winslash = "/",
  mustWork = TRUE
)
setwd(PROJECT_ROOT)

# ── Reproducibility seed ──
SEED <- 20260619
set.seed(SEED)

# ── R options ──
options(
  repos = c(ropensci = "https://ropensci.r-universe.dev",
            CRAN = "https://cloud.r-project.org"),
  stringsAsFactors = FALSE,
  encoding = "UTF-8",
  warn = 1,
  timeout = 900,
  download.file.method = ifelse(.Platform$OS.type == "windows", "wininet", "libcurl")
)

# ── Temporal scope ──
DATE_START <- as.Date("2010-01-01")
DATE_END   <- as.Date("2025-12-31")
YEARS      <- 2010:2025
MONTHS     <- 1:12
PERIOD_LABEL <- paste0(min(YEARS), "-", max(YEARS))

# ── Run metadata ──
PIPELINE_STARTED_AT <- Sys.time()
PIPELINE_RUN_ID <- format(PIPELINE_STARTED_AT, "%Y%m%d_%H%M%S")

# ── Geography ──
UF_RJ <- "RJ"
MACRORREGIOES <- c(
  "Baia da Ilha Grande", "Baixada Litoranea", "Centro-Sul",
  "Medio Paraiba", "Metropolitana I", "Metropolitana II",
  "Noroeste", "Norte", "Serrana"
)

# ── Health outcomes (CID-10) ──
CID_CEREBRO  <- paste0("I", 60:69)   # All cerebrovascular
CID_SENS     <- paste0("I", 60:64)   # Sensitivity definition
CID_HEMORR   <- paste0("I", 60:62)   # Hemorrhagic stroke
CID_ISQ      <- "I63"               # Ischemic stroke
CID_NAO_ESPEC <- "I64"              # Unspecified stroke
CID_OUTRAS   <- paste0("I", 65:69)  # Other cerebrovascular

# ── Confounders ──
INFLUENZA_CIDS <- paste0("J", sprintf("%02d", 9:18))

# ── DLNM specification ──
DLNM_LAG_GRID <- c(7, 14, 21)
DLNM_FALLBACK <- list(df_exp = 4, df_lag = 3, lag_max = 14)
# [F-005] Grid estendido para incluir df=6 (recomendado por Gasparrini 2014)
DLNM_DF_EXP_GRID <- c(3, 4, 5, 6)
DLNM_DF_LAG_GRID <- c(3, 4, 5)
DLNM_MMT_ENABLE <- TRUE
DLNM_NW_HAC_ENABLE <- TRUE
DLNM_NW_LAGS <- 21

# ── Sensitivity analysis ──
DLNM_SEASONS <- list(
  summer = c(12, 1, 2),
  winter = c(6, 7, 8)
)

# ── Bayesian priors ──
PRIOR_SENS_GRID <- list(
  sceptical  = list(mu_mean = 0, mu_sd = 1, tau_scale = 0.5),
  optimistic = list(mu_mean = log(1.05), mu_sd = 0.3, tau_scale = 0.3),
  flat       = list(mu_mean = 0, mu_sd = 3, tau_scale = 1.5)
)

# ── Pandemic period ──
PANDEMIC_START <- as.Date("2020-03-01")
PANDEMIC_END   <- as.Date("2022-12-31")

# ── Feature flags ──
CASE_CROSSOVER_ENABLE <- FALSE
MORAN_ENABLE <- TRUE
# [F-005] Controle de poluicao do ar ATIVO por padrao.
# Dados: PM2.5 anual por macrorregiao (02_MP25_RJ_exposicao/data_processed/)
# Granularidade anual -- usado como termo linear (sem spline).
AIR_QUALITY_ENABLE <- tolower(
  Sys.getenv("DLNM_ENABLE_AIR_QUALITY", unset = "true")) %in%
  c("1", "true", "sim", "yes")
FORCE_RAW_DOWNLOAD <- tolower(
  Sys.getenv("DLNM_FORCE_RAW_DOWNLOAD", unset = "false")) %in%
  c("1", "true", "sim", "yes")

# ── Logging ──
LOG_FILE <- file.path(PROJECT_ROOT, "logs", "pipeline_integrado.log")
dir.create(dirname(LOG_FILE), recursive = TRUE, showWarnings = FALSE)

# ── Directory structure ──
DIRS <- list(
  data_raw      = file.path(PROJECT_ROOT, "data", "raw"),
  data_interim  = file.path(PROJECT_ROOT, "data", "interim"),
  data_processed = file.path(PROJECT_ROOT, "data", "processed"),
  outputs       = file.path(PROJECT_ROOT, "outputs"),
  figures       = file.path(PROJECT_ROOT, "outputs", "figures"),
  tables        = file.path(PROJECT_ROOT, "outputs", "tables"),
  audit         = file.path(PROJECT_ROOT, "audit"),
  logs          = file.path(PROJECT_ROOT, "logs"),
  reports       = file.path(PROJECT_ROOT, "reports"),
  docs          = file.path(PROJECT_ROOT, "docs")
)

for (d in unlist(DIRS)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ── Log startup ──
log_msg <- function(level = "INFO", ...) {
  txt <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " [", level, "] ",
                paste(..., collapse = ""))
  cat(txt, "\n")
  if (exists("LOG_FILE") && nzchar(LOG_FILE)) {
    cat(txt, "\n", file = LOG_FILE, append = TRUE)
  }
}

log_msg("INFO", "Configuration loaded — Project root: ", PROJECT_ROOT)
log_msg("INFO", "Run ID: ", PIPELINE_RUN_ID)
log_msg("INFO", "Period: ", PERIOD_LABEL, " | Seed: ", SEED)
log_msg("INFO", "FORCE_RAW_DOWNLOAD: ", FORCE_RAW_DOWNLOAD)
