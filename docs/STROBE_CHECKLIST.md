# STROBE Statement — Checklist for Observational Studies

**Study:** Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010–2025)
**Design:** Ecological daily time-series study
**STROBE version:** STROBE 2007 (v4) — adapted for ecological time-series

---

## Title and Abstract

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1a | Indicate study design in title/abstract | ✅ | "Ecological daily time series" stated in abstract |
| 1b | Structured abstract | ✅ | Study design, methods, data sources, note on ecological inference |

## Introduction

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2 | Background/rationale | ✅ | README Abstract section |
| 3 | Objectives | ✅ | Explicit: investigate non-linear delayed associations of temperature, humidity, PM2.5 with cerebrovascular outcomes |

## Methods

| # | Item | Status | Notes |
|---|------|--------|-------|
| 4 | Study design | ✅ | Ecological daily time-series, 9 macroregions |
| 5 | Setting | ✅ | Rio de Janeiro state, Brazil, 2010–2025 |
| 6a | Participants | — | Ecological — no individual participants. 92 municipalities aggregated to 9 health macroregions |
| 6b | Eligibility | ✅ | All SIH-RD admissions and SIM-DO deaths with CID-10 I60–I69 |
| 7 | Variables | ✅ | Exposures: temp_med, ur_med, PM2.5. Outcomes: internacoes_i60_i69, obitos_i60_i69. Confounders: time, DOW, holidays, pandemic, influenza |
| 8 | Data sources | ✅ | DATASUS, INMET, INEA/MonitorAr, SIDRA/IBGE — all public |
| 9 | Bias | ✅ | Limitations documented in README (9 items) |
| 10 | Study size | ✅ | 5,844 days × 9 macroregions = 52,596 obs; 192 SIH monthly files; 15 SIM annual files |
| 11 | Quantitative variables | ✅ | DLNM crossbasis, spline df grid (3-6), lag grid (7,14,21 days) |
| 12a | Statistical methods | ✅ | DLNM + Quasi-Poisson/NegBin GLM + Bayesian hierarchical validation |
| 12b | Subgroups | ✅ | Sensitivity: sex-stratified, age-stratified, seasonal (summer/winter) |
| 12c | Missing data | ✅ | Climate imputation (nearest station), SIM gaps filled with SIH deaths |
| 12d | Sensitivity | ✅ | Lag sensitivity, pandemic exclusion, prior sensitivity, spline df sensitivity, temporal holdout (2010-2022 vs 2023-2025), delta-method SE inflation sensitivity |
| 12e | Software | ✅ | R 4.6.0, renv.lock (151 pkgs), Python 3 (Playwright), Docker |

## Results

| # | Item | Status | Notes |
|---|------|--------|-------|
| 13a | Participants | ✅ | 92 municipalities → 9 macroregions |
| 13b | Descriptive data | ✅ | Monthly admissions plots, daily climate seasonality |
| 13c | Outcome data | ✅ | Counts per macroregion × day |
| 14a | Main results | ✅ | Fig01–07 CellPress figures in `figures/`; tables in `outputs/tables/` |
| 14b | Other analyses | ✅ | Bayesian validation, sensitivity: `validacao_bayesiana_hierarquica_dlnm.csv`, `sensibilidade_*.csv` |
| 15 | Supplementary | ✅ | FigS1, S3 in `figures/`; diagnostic residuals in `outputs/figures/diagnosticos_residuos/` |

## Discussion

| # | Item | Status | Notes |
|---|------|--------|-------|
| 16 | Key results | ✅ | Manuscript §Resultados e discussão; 2 robust associations, 8 with caution; temperature predominates |
| 17 | Limitations | ✅ | 9 limitations documented in README + §Limitações section in manuscript |
| 18 | Interpretation | ✅ | Caution about ecological fallacy stated in abstract, §Limitações, and §Conclusão |
| 19 | Generalisability | ✅ | Rio de Janeiro state only; tropical climate context discussed in §Introdução and §Limitações |

## Other Information

| # | Item | Status | Notes |
|---|------|--------|-------|
| 20 | Funding | N/A | No funding declared at this stage |
| 21 | Reproducibility | ✅ | Full compendium: Docker, renv, Makefile, audit trail, CI/CD (4 jobs passing) |
| 22 | Data availability | ✅ | Raw data in `data/raw/` as fallback; public APIs; selected outputs versioned |

---

**Status:** ✅ ALL ITEMS VERIFIED — 21 June 2026
**Last audit:** Independent forensic audit completed (score 68/100). All critical code-level corrections (C1-C12) implemented.
**New since last review:** Moran's I spatial test, temporal holdout validation (2010-2022 vs 2023-2025), delta-method sensitivity in Bayesian stage, PM2.5 monthly granularity upgrade.
