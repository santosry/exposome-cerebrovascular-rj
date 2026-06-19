# 🌡️ Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010–2025)

[![CI](https://github.com/santosry/exposome-cerebrovascular-rj/actions/workflows/ci.yml/badge.svg)](https://github.com/santosry/exposome-cerebrovascular-rj/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![FAIR](https://img.shields.io/badge/FAIR-Principles-green.svg)](https://www.go-fair.org/fair-principles/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)](docker/)

**Research Compendium** — Epidemiologia Ambiental com DLNM e Inferência Bayesiana Hierárquica

---

## 📋 Abstract

This repository investigates non-linear and delayed associations between temperature, relative humidity, and hospital admissions/deaths from cerebrovascular diseases (ICD-10 I60–I69) across the nine health macroregions of Rio de Janeiro state, Brazil, from 2010 to 2025.

**Study design:** Ecological daily time series  
**Methods:** Distributed Lag Non-linear Models (DLNMs) with natural spline cross-bases, Quasi-Poisson/Negative Binomial regression, hierarchical Bayesian stabilization, and FDR-corrected prioritization  
**Data:** DATASUS (SIH-RD, SIM-DO), INMET (BrazilMet), SIDRA/IBGE population denominators  

> ⚠️ This is an **ecological study**. No individual-level inferences are made.

---

## 🚀 Quick Start

### Option 1: Docker (recommended for reproducibility)

```bash
# Build and run the full pipeline
docker-compose -f docker/docker-compose.yml up dlnm-pipeline

# Or run interactively with RStudio Server
docker-compose -f docker/docker-compose.yml up dlnm-interactive
# Open http://localhost:8787 (username: rstudio, password: dlnm2026)
```

### Option 2: Local R

```bash
# Restore R package environment
Rscript -e 'renv::restore()'

# Run the full pipeline
Rscript run_pipeline.R

# Or use smart caching with targets
Rscript -e 'targets::tar_make()'

# Or use Make
make all
```

### Option 3: Make targets

```bash
make download    # Download raw data only
make process     # Build analytic dataset
make models      # Fit DLNM models
make validate    # Run Bayesian validation
make reports     # Generate figures and manuscript
make audit       # Benchmark and quality control
make all         # Everything
```

---

## 📂 Repository Structure

```
dlnm-cerebrovascular-rj/
├── README.md                          ← This file
├── LICENSE                            ← MIT License
├── CITATION.cff                       ← Citation metadata
├── COMPENDIUM_MANIFEST.yml            ← Research compendium manifest
├── REPRODUCIBILITY_CHECKLIST.md       ← Reproducibility documentation
├── Makefile                           ← Automated workflow
├── run_pipeline.R                     ← Master pipeline entry point
├── _targets.R                         ← targets pipeline with caching
├── .gitignore
│
├── config/
│   └── config.R                       ← All parameters and constants
│
├── R/                                 ← Modular source code
│   ├── utils.R                        ← Logging, encoding, safe eval
│   ├── download.R                     ← Data acquisition (DATASUS, INMET, SIDRA)
│   ├── exposure_processing.R          ← INMET processing, spatial mapping
│   ├── preprocessing.R                ← SIH/SIM cleaning, dataset assembly
│   ├── dlnm_models.R                  ← DLNM fitting, diagnostics, sensitivity
│   ├── bayesian_models.R              ← Hierarchical Bayesian stabilization
│   ├── visualization.R                ← Figures, plots, 3D surfaces
│   └── reporting.R                    ← Reports, benchmarks, rendering
│
├── data/
│   ├── raw/                           ← Downloaded raw data (not versioned)
│   ├── interim/                       ← Intermediate processed data
│   └── processed/                     ← Analytic datasets and model objects
│
├── outputs/
│   ├── figures/                       ← Static and interactive figures
│   ├── tables/                        ← CSV result tables
│   └── logs/                          ← Execution logs
│
├── reports/
│   ├── manuscript/                    ← Article PDF and Rmd
│   ├── presentations/                 ← Beamer slides
│   └── supplementary/                 ← Supplementary materials
│
├── docs/
│   ├── formulas/                      ← Model specification
│   └── methodology/                   ← Analytical framework overview
│
├── audit/                             ← Audit trail and quality control
├── metadata/                          ← FAIR data dictionary and lineage
├── tests/testthat/                    ← Unit tests
├── docker/                            ← Dockerfile and docker-compose
└── .github/workflows/                 ← CI/CD quality gates
```

---

## 📊 Key Results

| Metric | Value |
|--------|-------|
| Macroregions covered | 9/9 |
| DLNM models fitted | ≥36 (9 × 4 outcomes) |
| FDR-significant findings (p<0.05) | 8 robust + 3 with caution |
| Bayesian posterior probabilities computed | All models |
| Sensitivity analyses | Lag (7/14/21d), pandemic exclusion, spline df grid, prior sensitivity |

---

## 🔬 Methods at a Glance

### DLNM Specification

- **Cross-basis:** Natural spline for exposure (df=4) × natural spline for lags (df=3, log-knots, max lag=14d)
- **Model family:** Quasi-Poisson with Negative Binomial fallback (dispersion > 3)
- **Time control:** Natural spline (7 df/year) + day-of-week + holidays + pandemic indicator
- **Confounder:** Complementary exposure variable (ns, df=3)
- **Offset:** log(population) from SIDRA/IBGE
- **Centering:** Minimum Morbidity/Mortality Temperature (MMT)
- **Standard errors:** Newey-West HAC (21 lags)

### Bayesian Stage

- **Model:** Normal-normal hierarchical (empirical Bayes)
- **Input:** Cumulative log(RR) ± SE from DLNM
- **Output:** Posterior RR, 95% credible interval, Pr(RR > 1.10)
- **Prior sensitivity:** Sceptical, Optimistic, Flat priors

### Prioritization Framework (5 levels)

1. **FDR** < 0.05 (Benjamini-Hochberg)
2. **IC95%** excludes 1.00
3. **RR** cumulative > 1.10
4. **AUC** of excess RR > 0
5. **Pr(RR > 1.10)** posterior > 0.80

---

## 🐳 Reproducibility

This compendium follows the [Turing Way](https://the-turing-way.netlify.app/) and [FAIR Principles](https://www.go-fair.org/):

| Component | Status |
|-----------|--------|
| Computational environment | ✅ Docker (rocker/geospatial:4.6.0) |
| Package versions | ✅ renv.lock |
| Random seed | ✅ set.seed(20260619) |
| Raw data versioning | ✅ Pipeline regenerates from public APIs |
| Audit trail | ✅ 30+ audit CSV files |
| Unit tests | ✅ testthat |
| CI/CD | ✅ GitHub Actions |
| FAIR metadata | ✅ Data dictionary + lineage |

### Reproducibility Score: **85/100** ⬆ (was 42/100)

---

## 📝 Citation

```bibtex
@software{santos2026dlnm,
  title = {Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010–2025):
           A Reproducible DLNM-Bayesian Framework},
  author = {Santos, Ryan de Paulo and Nunes, Camila Henriques and
            Ribeiro, Karla Rangel and Medina-Acosta, Enrique},
  year = {2026},
  doi = {placeholder},
  url = {https://github.com/santosry/exposome-cerebrovascular-rj}
}
```

---

## 📚 Data Sources

| Source | Description | Access |
|--------|-------------|--------|
| **SIH-RD** | Hospital admissions (SUS) | `microdatasus` |
| **SIM-DO** | Mortality records | `microdatasus` |
| **INMET** | Weather stations (temp, humidity) | `BrazilMet` |
| **SIDRA/IBGE** | Population denominators | `sidrar` |
| **geobr** | Municipality geometries | `geobr` |

---

## ⚠️ Limitations

1. **SIM-DO 2025** unavailable — filled with SIH hospital deaths (proxy, undercounts out-of-hospital deaths)
2. **Noroeste macroregion** has only 1 INMET station (no redundancy)
3. **Ecological design** — no individual-level inference
4. **No air pollution adjustment** (feature flag exists but not yet implemented)
5. **Intercensal population estimates** for post-2022 years

---

## 🛠️ Development

```bash
# Run unit tests
make test

# Lint R code
make lint

# Build Docker image
make docker-build

# Generate renv.lock
make renv-snapshot
```

---

**Status:** 🟢 Production-ready for journal submission  
**Target journals:** *Environmental Health Perspectives*, *International Journal of Epidemiology*, *Lancet Planetary Health*
