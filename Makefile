# Makefile — Automated workflow orchestration for the DLNM compendium
# =============================================================================
# Usage:
#   make all          — Run the complete pipeline
#   make download     — Download all raw data
#   make process      — Process and build analytic dataset
#   make models       — Fit DLNM models
#   make validate     — Run Bayesian validation
#   make reports      — Generate figures, tables, and manuscript
#   make audit        — Run benchmark and quality control
#   make docker-build — Build Docker image
#   make docker-run   — Run pipeline in Docker
#   make clean        — Remove derived outputs
#   make clean-all    — Remove everything including raw data

.PHONY: all download process models validate reports audit clean clean-all \
        docker-build docker-run test lint

RSCRIPT = Rscript --vanilla

# ── Main targets ──
all: download process models validate reports audit

# ── Data acquisition ──
download:
	$(RSCRIPT) -e "source('config/config.R'); source('R/download.R'); download_sih(); download_sim(); download_inmet()"

# ── Data processing ──
process:
	$(RSCRIPT) -e "source('config/config.R'); source('R/utils.R'); source('R/download.R'); source('R/exposure_processing.R'); source('R/preprocessing.R'); outcomes <- process_outcomes(); meteo <- process_inmet(); population <- download_population_sidra(); dat_macro <- make_analytic_dataset(outcomes, meteo, population)"

# ── DLNM modeling ──
models:
	$(RSCRIPT) -e "source('config/config.R'); source('R/utils.R'); source('R/dlnm_models.R'); dat_macro <- readRDS('data/processed/dataset_dlnm_macrorregiao.rds'); run_dlnm(dat_macro)"

# ── Bayesian validation ──
validate:
	$(RSCRIPT) -e "source('config/config.R'); source('R/utils.R'); source('R/bayesian_models.R'); rr_tbl <- readr::read_csv('outputs/tables/tabela_rr_dlnm_macrorregiao.csv', show=F); auc_tbl <- readr::read_csv('outputs/tables/tabela_auc_rr_dlnm_macrorregiao.csv', show=F); run_bayesian_hierarchical_validation(rr_tbl, auc_tbl)"

# ── Reports and visualizations ──
reports:
	$(RSCRIPT) -e "source('config/config.R'); source('R/utils.R'); source('R/visualization.R'); source('R/reporting.R'); dat_macro <- readRDS('data/processed/dataset_dlnm_macrorregiao.rds'); dlnm_results <- readRDS('data/processed/modelos_dlnm_macrorregiao.rds'); plot_monthly_admissions(dat_macro); plot_daily_climate_seasonality(dat_macro); write_final_reports_epidemiologicos(dat_macro, dlnm_results); render_bsb_outputs()"

# ── Audit and benchmark ──
audit:
	$(RSCRIPT) -e "source('config/config.R'); source('R/utils.R'); source('R/reporting.R'); run_benchmark_validation(); centralize_audits()"

# ── Testing ──
test:
	$(RSCRIPT) -e "testthat::test_dir('tests/testthat')"

lint:
	$(RSCRIPT) -e "lintr::lint_dir('R/')"

# ── Docker ──
docker-build:
	docker build -t dlnm-cerebrovascular-rj -f docker/Dockerfile .

docker-run:
	docker run --rm \
		-v $(shell pwd)/outputs:/home/rstudio/dlnm-compendium/outputs \
		-v $(shell pwd)/data:/home/rstudio/dlnm-compendium/data \
		-v $(shell pwd)/audit:/home/rstudio/dlnm-compendium/audit \
		-v $(shell pwd)/logs:/home/rstudio/dlnm-compendium/logs \
		dlnm-cerebrovascular-rj

# ── Renv ──
renv-snapshot:
	$(RSCRIPT) -e "renv::snapshot()"

renv-restore:
	$(RSCRIPT) -e "renv::restore()"

# ── Cleaning ──
clean:
	rm -rf outputs/figures/* outputs/tables/* logs/*.log
	rm -rf data/interim/* data/processed/*

clean-all: clean
	rm -rf data/raw/*

# ── Help ──
help:
	@echo "DLNM Cerebrovascular RJ (2010–2025) — Research Compendium"
	@echo ""
	@echo "Targets:"
	@echo "  all           Run complete pipeline"
	@echo "  download      Download raw data (SIH, SIM, INMET)"
	@echo "  process       Build analytic dataset"
	@echo "  models        Fit DLNM models"
	@echo "  validate      Run Bayesian validation"
	@echo "  reports       Generate figures, tables, manuscript"
	@echo "  audit         Benchmark and quality control"
	@echo "  test          Run unit tests"
	@echo "  lint          Lint R code"
	@echo "  docker-build  Build Docker image"
	@echo "  docker-run    Run pipeline in Docker"
	@echo "  clean         Remove derived outputs"
	@echo "  clean-all     Remove all data and outputs"
