# Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010-2025)

**Research Compendium** -- Epidemiologia Ambiental com DLNM e Inferencia Bayesiana Hierarquica

---

## Abstract

This repository investigates non-linear and delayed associations between temperature, relative humidity, and hospital admissions/deaths from cerebrovascular diseases (ICD-10 I60-I69) across the nine health macroregions of Rio de Janeiro state, Brazil, from 2010 to 2025.

**Study design:** Ecological daily time series  
**Methods:** Distributed Lag Non-linear Models (DLNMs) with natural spline cross-bases, Quasi-Poisson/Negative Binomial regression, hierarchical Bayesian stabilization, and FDR-corrected prioritization  
**Data:** DATASUS (SIH-RD, SIM-DO), INMET (BrazilMet), SIDRA/IBGE population denominators  

> Note: This is an ecological study. No individual-level inferences are made.

---

## Quick Start

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

## Repository Structure

```
dlnm-cerebrovascular-rj/
├── README.md
├── LICENSE
├── CITATION.cff
├── COMPENDIUM_MANIFEST.yml
├── REPRODUCIBILITY_CHECKLIST.md
├── Makefile
├── run_pipeline.R
├── _targets.R
├── .gitignore
│
├── config/
│   └── config.R
│
├── R/
│   ├── utils.R
│   ├── download.R
│   ├── exposure_processing.R
│   ├── preprocessing.R
│   ├── dlnm_models.R
│   ├── bayesian_models.R
│   ├── visualization.R
│   └── reporting.R
│
├── data/
│   ├── raw/
│   ├── interim/
│   └── processed/
│
├── outputs/
│   ├── figures/
│   ├── tables/
│   └── logs/
│
├── reports/
│   ├── manuscript/
│   ├── presentations/
│   └── supplementary/
│
├── docs/
│   ├── formulas/
│   └── methodology/
│
├── audit/
├── metadata/
├── tests/testthat/
├── docker/
└── .github/workflows/
```

---

## Key Results

| Metric | Value |
|--------|-------|
| Macroregions covered | 9/9 |
| DLNM models fitted | 36+ (9 x 4 outcomes) |
| FDR-significant findings (p<0.05) | 8 robust + 3 with caution |
| Bayesian posterior probabilities computed | All models |
| Sensitivity analyses | Lag (7/14/21d), pandemic exclusion, spline df grid, prior sensitivity |

---

## Methods at a Glance

### DLNM Specification

- **Cross-basis:** Natural spline for exposure (df=4) x natural spline for lags (df=3, log-knots, max lag=14d)
- **Model family:** Quasi-Poisson with Negative Binomial fallback (dispersion > 3)
- **Time control:** Natural spline (7 df/year) + day-of-week + holidays + pandemic indicator
- **Confounder:** Complementary exposure variable (ns, df=3)
- **Offset:** log(population) from SIDRA/IBGE
- **Centering:** Minimum Morbidity/Mortality Temperature (MMT)
- **Standard errors:** Newey-West HAC (21 lags)

### Bayesian Stage

- **Model:** Normal-normal hierarchical (empirical Bayes)
- **Input:** Cumulative log(RR) +- SE from DLNM
- **Output:** Posterior RR, 95% credible interval, Pr(RR > 1.10)
- **Prior sensitivity:** Sceptical, Optimistic, Flat priors

### Prioritization Framework (5 levels)

1. **FDR** < 0.05 (Benjamini-Hochberg)
2. **IC95%** excludes 1.00
3. **RR** cumulative > 1.10
4. **AUC** of excess RR > 0
5. **Pr(RR > 1.10)** posterior > 0.80

---

## Reproducibility

This compendium follows the [Turing Way](https://the-turing-way.netlify.app/) and [FAIR Principles](https://www.go-fair.org/):

| Component | Status |
|-----------|--------|
| Computational environment | OK: Docker (rocker/geospatial:4.6.0) |
| Package versions | OK: renv.lock |
| Random seed | OK: set.seed(20260619) |
| Raw data versioning | OK: Pipeline regenerates from public APIs |
| Audit trail | OK: 30+ audit CSV files |
| Unit tests | OK: testthat |
| CI/CD | OK: GitHub Actions |
| FAIR metadata | OK: Data dictionary + lineage |

Reproducibility Score: 85/100 (was 42/100)

---

## Citation

```bibtex
@software{santos2026dlnm,
  title = {Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010-2025):
           A Reproducible DLNM-Bayesian Framework},
  author = {Santos, Ryan de Paulo and Nunes, Camila Henriques and
            Ribeiro, Karla Rangel and Medina-Acosta, Enrique},
  year = {2026},
  doi = {placeholder},
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
| **SIDRA/IBGE** | Population denominators | `sidrar` |
| **geobr** | Municipality geometries | `geobr` |

---

## Limitations

1. **SIM-DO 2025** unavailable -- filled with SIH hospital deaths (proxy, undercounts out-of-hospital deaths)
2. **Noroeste macroregion** has only 1 INMET station (no redundancy)
3. **Ecological design** -- no individual-level inference
4. **No air pollution adjustment** (feature flag exists but not yet implemented)
5. **Intercensal population estimates** for post-2022 years

---

## Development

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

## AI Usage Declaration

This project used AI technologies as technical assistants in compliance with **CNPq Portaria 2664/2026**.

| Technology | Purpose |
|------------|--------|
| **DeepSeek v4-pro** | Code refactoring, documentation, CI/CD pipelines, research compendium structure |
| **OpenAI Codex** | R function assistance, statistical debugging, FAIR metadata |
| **ChatGPT 5.5** | Technical audit, international benchmarking, compliance checklists |

All scientific decisions (model selection, parameters, result interpretation) were made exclusively by human researchers.

Full declaration: [docs/AI_DECLARATION.md](docs/AI_DECLARATION.md)

---

Status: Production-ready for journal submission
