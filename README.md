# Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010-2025)

**Research Compendium** -- Environmental Epidemiology with DLNM and Hierarchical Bayesian Inference

---

## Abstract

This repository investigates non-linear and delayed associations between temperature, relative humidity, PM2.5 air pollution, and hospital admissions/deaths from cerebrovascular diseases (ICD-10 I60-I69) across the nine health macroregions of Rio de Janeiro state, Brazil, from 2010 to 2025.

**Study design:** Ecological daily time series
**Methods:** Distributed Lag Non-linear Models (DLNMs) with natural spline cross-bases, Quasi-Poisson/Negative Binomial regression, PM2.5 air pollution adjustment, hierarchical Bayesian stabilization, Newey-West HAC standard errors with delta-method propagation, and FDR-corrected prioritization
**Data:** DATASUS (SIH-RD, SIM-DO), INMET (BrazilMet), INEA/MonitorAr (PM2.5), SIDRA/IBGE population denominators

> Note: This is an ecological study. Associations are at the macroregional level. No individual-level inferences are made.

---

## Quick Start

> **Platform:** Developed on **Windows 11**. Fully tested and reproducible on **Linux** and **macOS**.
>  
> **R compatibility:** Developed and tested on R 4.6.0. Minimum required: **R ≥ 4.4.0** (required by `MASS 7.3-65`).  
> The pipeline is **fully functional on R 4.4.x, 4.5.x, and 4.6.x** — `renv::restore()` handles all version resolution.  
> For older R versions or any OS, use **Docker** (zero compatibility issues — Linux kernel, runs everywhere).

### Option 1: Docker (recommended — zero setup, any OS)

```bash
# IMPORTANT: This repository uses Git LFS for large data files.
# Clone with LFS enabled to get all data:
git lfs install
git clone https://github.com/santosry/exposome-cerebrovascular-rj.git
cd exposome-cerebrovascular-rj
git lfs pull               # Ensure all data files are downloaded
make docker-build           # Single command: R, Python, Playwright, all packages
make docker-run             # Runs full pipeline end-to-end
```

### Option 2: Local (R ≥ 4.4.0 + Python 3.9+)

```bash
git clone https://github.com/santosry/exposome-cerebrovascular-rj.git
cd exposome-cerebrovascular-rj
make setup           # renv::restore() + pip install + playwright install chromium
make all             # Full pipeline
```

### Option 3: Step-by-step

```bash
make download-pm25   # PM2.5 from INEA/MonitorAr (Playwright)
make download        # SIH + SIM (DATASUS) + INMET (API or local zip fallback)
make process         # Build analytic dataset
make models          # Fit DLNM models
make validate        # Bayesian hierarchical validation
make reports         # Figures, tables, manuscript
```

---

## How to Run — Full Guide

All data files (SIH, SIM, INMET, PM2.5) are already included in the repository via Git LFS.  
If the public APIs are unavailable, the pipeline falls back to the pre-downloaded files automatically.

### A) One-liner (Rscript)

```bash
Rscript run_pipeline.R
```

Runs the full pipeline end-to-end. Uses renv for package management and falls back to local data when APIs fail.

### B) Makefile (granular control)

| Command | What it does |
|---------|-------------|
| `make setup` | First-time: installs renv packages + Python deps + Playwright browser |
| `make download-pm25` | Extracts PM2.5 from INEA/MonitorAr Power BI dashboard (Python + Playwright) |
| `make download` | Downloads SIH-RD, SIM-DO, INMET (or uses local fallback) |
| `make process` | Builds analytic dataset (daily counts per macroregion × exposure) |
| `make models` | Fits all DLNM models (9 macroregions × 2 exposures × 2 outcomes × grid) |
| `make validate` | Bayesian hierarchical validation + prior sensitivity |
| `make reports` | Generates figures, tables, and renders manuscript |
| `make audit` | Runs benchmark validation and quality control |
| `make test` | Runs unit tests (testthat) |
| `make all` | Everything above, in order |
| `make clean` | Removes derived outputs (keeps raw data) |
| `make clean-all` | Removes everything including raw data |
| `make renv-snapshot` | Updates renv.lock with current package versions |
| `make renv-restore` | Restores exact package versions from renv.lock |
| `make help` | Shows this list |

### C) Docker (isolated, portable)

```bash
# Build the image (R 4.6.0 + all packages + Python + Playwright)
make docker-build

# Run the full pipeline in a container
make docker-run

# Or use docker-compose for multi-service orchestration
docker-compose -f docker/docker-compose.yml up dlnm-pipeline     # Full pipeline
docker-compose -f docker/docker-compose.yml up dlnm-interactive  # RStudio Server on port 8787
docker-compose -f docker/docker-compose.yml up dlnm-benchmark    # Benchmark only
```

### D) targets pipeline (incremental, skips unchanged steps)

```r
library(targets)
tar_make()  # Runs only what's needed; caches intermediate results
```

The `_targets.R` file defines a `targets` workflow that skips already-computed steps — ideal for iterative development.

### E) Individual R scripts (manual exploration)

```r
source("config/config.R")
source("R/utils.R")
source("R/download.R")

# Download specific data
download_sih()       # 192 monthly SIH-RD files
download_sim()       # 15 annual SIM-DO files
download_inmet()     # Weather station data (API or local zip fallback)

# Or process specific components
source("R/exposure_processing.R")
meteo <- process_inmet()

source("R/preprocessing.R")
outcomes <- process_outcomes()
```

### What to do if downloads fail

The pipeline automatically falls back to pre-downloaded files stored in the repository (Git LFS):
- `data/raw/sih/` — 192 monthly hospital admission files
- `data/raw/sim/` — 15 annual mortality files
- `data/raw/inmet_zip/` — 16 yearly INMET zip archives
- `data/processed/pm25/` — Pre-computed PM2.5 tables

If Git LFS files weren't pulled during clone:
```bash
git lfs pull
```

---

## Repository Structure

    README.md
    LICENSE
    CITATION.cff
    COMPENDIUM_MANIFEST.yml
    REPRODUCIBILITY_CHECKLIST.md
    Makefile
    run_pipeline.R
    _targets.R
    renv.lock
    .gitignore
    config/
      config.R
    R/
      utils.R              # Logging, encoding, Brazilian holidays
      download.R           # Data acquisition (DATASUS, INMET, SIDRA)
      exposure_processing.R # INMET processing, spatial mapping
      preprocessing.R      # SIH/SIM cleaning, PM2.5 processing, dataset assembly
      dlnm_models.R        # DLNM fitting, HAC SE, diagnostics, sensitivity
      bayesian_models.R    # Hierarchical Bayesian stabilization
      visualization.R      # Figures, plots, 3D surfaces
      reporting.R          # Reports, benchmarks, rendering
    python/
      extrair_mp25_rj.py   # PM2.5 extraction from INEA/MonitorAr
      requirements.txt
    data/
    outputs/
    docs/
      formulas/
      methodology/
      AI_DECLARATION.md
    tests/testthat/
    docker/
    .github/workflows/

---

## What This Compendium Implements

### Air Pollution Control (PM2.5)
PM2.5 data from INEA/MonitorAr (VIGIAR program) is included as a linear covariate in all DLNM models. The extraction pipeline:

1. **Capture:** Python script (`python/extrair_mp25_rj.py`) uses Playwright to scrape the public Power BI dashboard
2. **Spatial assignment:** 74 monitored municipalities receive their measured mean; 18 unmonitored municipalities receive the value of the nearest monitored neighbor (Haversine distance)
3. **Macroregion mapping:** each municipality is assigned to its health macroregion (9 regions)
4. **Temporal downscaling:** annual values (2010-2025) are derived using the national VIGIAR series trend, assuming spatial homogeneity. 2025 is extrapolated
5. **Model integration:** annual macroregional mean PM2.5 is included as a linear term in all DLNM formulas

Python dependencies: Playwright, Pandas, NumPy (`python/requirements.txt`). Full extraction audit log is generated by the script.

### Robust Standard Errors
Newey-West HAC standard errors (21 lags) are computed for all models and propagated to cumulative RR via the delta method. Both model-based and HAC-corrected confidence intervals are reported. The Bayesian stage uses the HAC-corrected standard error when available.

### Brazilian Holidays
The holiday indicator includes both fixed national holidays and movable dates (Carnival, Good Friday, Corpus Christi) computed via the Gauss algorithm for Easter. Rio de Janeiro state holidays (Sao Jorge, April 23; Consciencia Negra, November 20 until 2023) are also included.

### Sensitivity Analyses
- **Lag maximum:** 7, 14, and 21 days
- **Temporal df:** 4, 5, 6, and 7 df/year
- **Spline df:** 3x3 grid (df_exp: 3,4,5,6; df_lag: 3,4,5)
- **Pandemic exclusion:** models without 2020-2022
- **Seasonal:** separate DLNMs for summer (Dec-Feb) and winter (Jun-Aug)
- **Bayesian priors:** skeptical, optimistic, and flat specifications

---

## Methods at a Glance

### DLNM Specification

- **Cross-basis:** Natural spline for exposure (df=4) x natural spline for lags (df=3, log-knots, max lag=14d)
- **Model family:** Quasi-Poisson with Negative Binomial fallback (dispersion > 3)
- **Time control:** Natural spline (7 df/year) + day-of-week + Brazilian holidays + pandemic indicator
- **Confounders:** Complementary exposure (ns, df=3) + PM2.5 annual (linear) + influenza lag 7d
- **Offset:** log(population) from SIDRA/IBGE
- **Centering:** Minimum Morbidity/Mortality Temperature (MMT)
- **Standard errors:** Newey-West HAC (21 lags) propagated via delta method

### Bayesian Stage

- **Model:** Normal-normal hierarchical (empirical Bayes, grid search)
- **Input:** Cumulative log(RR) + HAC-corrected SE from DLNM
- **Output:** Posterior RR, 95% credible interval, Pr(RR > 1.10)
- **Note:** Two-stage approach; uncertainty from the first stage is not fully propagated (documented limitation)

### Prioritization Framework (5 levels)

1. **FDR** < 0.05 (Benjamini-Hochberg)
2. **IC95%** excludes 1.00
3. **RR** cumulative > 1.10
4. **AUC** of excess RR > 0
5. **Pr(RR > 1.10)** posterior > 0.80

---

## R Environment

R version 4.6.0 (2026-04-24). Full package inventory in `renv.lock` (151 packages).

| Package | Version | Purpose |
|---|---|---|
| dlnm | 2.4.10 | Distributed lag non-linear models |
| mgcv | 1.9.4 | GAM for time trend |
| MASS | 7.3-65 | Negative binomial GLM |
| sandwich | 3.1-1 | Newey-West HAC standard errors |
| microdatasus | 2.5.0 | DATASUS data acquisition |
| BrazilMet | 0.4.0 | INMET weather data |
| geobr | 1.9.1 | Municipality geometries |
| sf | 1.1-0 | Spatial operations |
| sidrar | 0.2.9 | SIDRA/IBGE population |
| tidyverse | 2.0.0 | Data manipulation and plotting |
| plotly | 4.12.0 | Interactive 3D surfaces |
| targets | 1.12.0 | Reproducible pipeline with caching |
| renv | 1.2.2 | Package version management |

---

## Reproducibility

| Component | Status |
|-----------|--------|
| Package versions | renv.lock (151 packages) |
| Computational environment | Docker (rocker/geospatial:latest) |
| Random seed | set.seed(20260619) |
| Raw data | Public APIs (DATASUS, INMET, SIDRA, INEA) |
| Audit trail | 30+ audit CSV files |
| Unit tests | testthat (utils, DLNM, Bayesian, preprocessing) |
| CI/CD | GitHub Actions (test, size-check, fair-check, modules) |
| FAIR metadata | Data dictionary + lineage + CITATION.cff |

### Platform Compatibility

| Platform | Status | Notes |
|----------|--------|-------|
| **Windows 11** | ✅ Development platform | Full pipeline executed natively |
| **Linux** (Ubuntu/Debian) | ✅ Fully compatible | R, Python, Playwright all native; Docker tested |
| **macOS** (Intel + Apple Silicon) | ✅ Fully compatible | `renv::restore()` resolves all binary packages; Docker provides Linux runtime if needed |
| **Any OS via Docker** | ✅ Recommended | Single `make docker-build && make docker-run` — zero platform issues |

> **Cross-platform guarantee:** All R packages in `renv.lock` are CRAN-hosted (no platform-specific binaries).  
> The single OS-dependent line (`download.file.method`) auto-detects Windows vs Unix in `config/config.R`.  
> Python dependencies (`playwright`, `pandas`, `numpy`) are pure Python — identical behavior on all platforms.  
> Git LFS is used for large data files (INMET zips, SIH/SIM RDS) — works identically on Windows, Linux, and macOS.

---

## Citation

```bibtex
@software{santos2026dlnm,
  title = {Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010-2025):
           A Reproducible DLNM-Bayesian Framework},
  author = {Santos, Ryan de Paulo and Nunes, Camila Henriques and
            Ribeiro, Karla Rangel and Medina-Acosta, Enrique},
  year = {2026},
  url = {https://github.com/santosry/exposome-cerebrovascular-rj}
}
```

---

## Data Sources

| Source | Description | Access |
|--------|-------------|--------|
| **SIH-RD** | Hospital admissions (SUS) | `microdatasus` |
| **SIM-DO** | Mortality records | `microdatasus` |
| **INMET** | Weather stations (temp, humidity) | `BrazilMet` |
| **INEA/MonitorAr** | PM2.5 air pollution | Python/Playwright extraction from public Power BI dashboard |

To reproduce the PM2.5 extraction:
```bash
cd python
pip install -r requirements.txt
playwright install chromium
python extrair_mp25_rj.py
```
| **SIDRA/IBGE** | Population denominators | `sidrar` |
| **geobr** | Municipality geometries | `geobr` |

---

## Limitations

1. **Ecological design** — associations at macroregional level; no individual-level inference
2. **PM2.5 granularity** — annual by macroregion; intra-annual variation not captured; 2025 extrapolated via linear regression from 2020–2024
3. **SIM-DO 2025 unavailable** — mortality for 2025 uses SIH in-hospital deaths as proxy, which **undercounts out-of-hospital cerebrovascular fatalities** (common in stroke). This affects ~1/16 of the time series. A sensitivity analysis excluding 2025 is recommended for confirmation
4. **SIM-DO 2014–2016 partial** — some monthly SIM files were unavailable; filled with SIH deaths where gaps exist
5. **Noroeste macroregion** has only 1 INMET station (no spatial redundancy for imputation)
6. **Climate aggregation** — simple mean across stations, not population-weighted or distance-weighted
7. **Two-stage Bayesian** — uncertainty from DLNM stage not fully propagated to posterior intervals (when using plug-in RR point estimates)
8. **Intercensal population estimates** for 2023–2025 based on post-Census 2022 projections (IBGE/SIDRA table 6579)
9. **Multiple comparisons** — FDR correction applied; prioritization examines multiple dimensions (exploratory nature documented)

---

## AI Usage Declaration

This project used AI technologies as technical assistants.

| Technology | Purpose |
|------------|--------|
| **DeepSeek v4-pro** | Code refactoring, documentation, CI/CD pipelines, research compendium structure |
| **OpenAI Codex** | R function assistance, statistical debugging, FAIR metadata |
| **ChatGPT 5.5** | Technical audit, international benchmarking, compliance checklists |

All scientific decisions (model selection, parameters, result interpretation) were made exclusively by human researchers.

Full declaration: [docs/AI_DECLARATION.md](docs/AI_DECLARATION.md)

---

Languages: R, Python, HTML
