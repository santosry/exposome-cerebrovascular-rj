# OSF Pre-Registration Template
# =============================================================================
# Study: Climate Exposure and Cerebrovascular Outcomes in Rio de Janeiro (2010-2025)
# Design: Ecological daily time-series with DLNM + Bayesian hierarchical stabilization
# OSF: To be registered at https://osf.io/ before submission
# =============================================================================

## 1. Study Information

**Title:** Non-linear and delayed associations of daily temperature and relative humidity
with cerebrovascular hospitalizations and deaths across nine health macroregions of
Rio de Janeiro, Brazil (2010-2025): a reproducible DLNM-Bayesian ecological time-series
analysis.

**Authors:** Ryan de Paulo Santos, Camila Henriques Nunes, Karla Rangel Ribeiro,
Enrique Medina-Acosta

**Registration date:** [to be filled upon OSF registration]

## 2. Hypotheses

**H0:** Daily temperature and relative humidity are not associated with short-term
variation in cerebrovascular admissions or deaths after adjustment for seasonality,
long-term trend, calendar structure, population offset and complementary climate exposure.

**H1:** Daily temperature and/or relative humidity show non-linear and delayed
associations with cerebrovascular admissions or deaths, with heterogeneous magnitude
across the nine health macroregions.

**Sensitivity hypothesis (exploratory):** Monthly PM2.5 (INEA/MonitorAr, derived via
two-stage downscaling) is associated with residual variation in cerebrovascular outcomes
after climate adjustment. Note: PM2.5 is monthly, not daily, and serves only as
contextual sensitivity adjustment.

## 3. Study Design

- **Type:** Ecological daily time-series (observational, associational)
- **Unit of analysis:** macroregion-day (9 macroregions × ~5,844 days = 52,596 observations)
- **Period:** January 1, 2010 to December 31, 2025
- **Location:** Rio de Janeiro state, Brazil (92 municipalities → 9 health macroregions)
- **Data sources:** DATASUS (SIH-RD, SIM-DO), INMET, INEA/MonitorAr (VIGIAR), SIDRA/IBGE

## 4. Variables

### Outcomes (daily counts per macroregion)
- `internacoes_i60_i69` — Hospital admissions for I60-I69 (all cerebrovascular)
- `obitos_i60_i69` — Deaths from I60-I69
- `internacoes_i60_i64` — Admissions for I60-I64 (sensitivity definition)
- `obitos_i60_i64` — Deaths from I60-I64
- `internacoes_i60_i62` — Admissions for I60-I62 (hemorrhagic subtype)
- `obitos_i60_i62` — Deaths from I60-I62
- `internacoes_i63` — Admissions for I63 (ischemic subtype)
- `obitos_i63` — Deaths from I63

### Exposures (daily per macroregion)
- `temp_med` — Mean daily temperature (°C), INMET station mean per macroregion
- `ur_med` — Mean daily relative humidity (%), INMET station mean per macroregion
- `pm25_mensal` — Monthly PM2.5 (µg/m³), optional sensitivity covariate, disabled by default

### Covariates
- `ns(tempo, df = 7*years)` — Natural spline for long-term trend and seasonality
- `dow` — Day of week (factor)
- `feriado` — Brazilian national and state holidays (logical)
- `pandemia` — COVID-19 pandemic indicator (2020-03-01 to 2022-12-31)
- `ns(complementary_exposure, df = 3)` — Complementary climate exposure
- `ns(influenza_lag7, df = 2)` — 7-day lagged influenza admissions
- `offset(log_populacao)` — Population offset from SIDRA/IBGE

## 5. Statistical Models

### Primary: Distributed Lag Non-linear Model (DLNM)
- **Cross-basis:** natural spline exposure (df=4) × natural spline lags (df=3, log-knots, max lag=14)
- **Family:** Quasi-Poisson primary; Negative Binomial fallback if dispersion > 3
- **Standard errors:** Newey-West HAC (21 lags) with delta-method propagation to cumulative RR
- **Centering:** Minimum Mortality/Morbidity Temperature (MMT), estimated from data
- **Grid:** 9 macroregions × up to 8 outcomes × 2 exposures = up to 144 models

### Secondary: Bayesian Hierarchical Stabilization
- **Model:** Normal-Normal empirical Bayes on log(RR) estimates
- **Grouping:** by outcome × exposure (9 macroregions per group)
- **Outputs:** posterior mean, posterior SD, Pr(RR > 1.10), 95% credible intervals

## 6. Multiple Comparisons and Prioritization

- **FDR:** Benjamini-Hochberg correction on association p-values
- **Prioritization framework:** 5 criteria (exploratory, not a formal decision rule):
  1. FDR < 0.05
  2. 95% CI excludes 1.00
  3. Cumulative RR > 1.10
  4. AUC of excess RR > 0
  5. Posterior probability Pr(RR > 1.10) > 0.80

## 7. Sensitivity Analyses

1. **Lag sensitivity:** lag_max ∈ {7, 14, 21} days
2. **Temporal df sensitivity:** df/year ∈ {4, 5, 6}
3. **Spline df sensitivity:** df_exp ∈ {3, 4, 5} × df_lag ∈ {3, 4, 5}
4. **Pandemic exclusion:** excluding 2020-03-01 to 2022-12-31
5. **Seasonal stratification:** summer (DJF) vs. winter (JJA)
6. **Bayesian prior sensitivity:** sceptical, optimistic, flat priors

## 8. Known Limitations (pre-registered)

1. Ecological design — no individual-level inference
2. PM2.5 monthly, not daily — serves as sensitivity covariate only
3. SIM-DO 2025 and partial 2014-2016 — mortality proxy via SIH hospital deaths
4. Climate aggregation — simple station mean per macroregion
5. Two-stage Bayesian — DLNM uncertainty not fully propagated
6. Spatial independence assumed — Moran's I tested but spatial models not fitted
7. No external validation / temporal holdout
8. Multiple comparisons — prioritization is exploratory

## 9. Deviations from Protocol

[To be filled if any deviations occur during analysis]

## 10. Data and Code Availability

- **Repository:** https://github.com/santosry/exposome-cerebrovascular-rj
- **License:** MIT
- **Raw data:** included as pipeline fallback in `data/raw/`
- **Environment:** renv.lock (151 packages), Docker, Makefile, targets
- **FAIR:** data dictionary, lineage, outputs manifest provided
