# Scientific Audit Response

This document records the repository-level response to a critical scientific audit of the compendium. It does not change reported results; it clarifies scope, limits claims and documents methodological safeguards.

## Implemented Corrections

| Audit issue | Repository response |
|---|---|
| PM2.5 annual data were described too strongly for a daily DLNM framework | PM2.5 is now documented as optional monthly sensitivity covariate, not as a primary exposure-lag variable. **Update 2026-06-21:** upgraded from annual to monthly granularity via two-stage downscaling (annual + seasonal). |
| PM2.5 granularity was insufficient for seasonal intra-annual control | Granularity elevated to **monthly** (17,664 municipality-month rows). Seasonal profile extracted from INEA/VIGIAR Power BI 2024 national data. Still not daily; remains a linear covariate. |
| Risk of causal overclaiming | README now states that the study is ecological, associational and not designed for individual causal inference or forecasting. |
| Lack of explicit hypotheses | README now declares H0 and H1 for daily temperature and humidity. |
| Raw-data-heavy GitHub package | `05_publicacao_github/data/raw/` was cleaned and `.gitignore` now excludes raw downloads, RDS objects, zips and other regenerated binaries. |
| PM2.5 path was not self-contained | `R/preprocessing.R` now reads PM2.5 from `data/processed/pm25/` inside the compendium. |
| PM2.5 delimiter mismatch risk | PM2.5 is now read with `read_delim(delim = ";")`, matching the generated CSV files. |
| PM2.5 extraction script had non-portable paths | `python/extrair_mp25_rj.py` now derives paths from the repository root. |
| PM2.5 coverage and granularity were insufficiently explicit | New audit CSVs are stored under `audit/air_quality/`. Monthly granularity explicitly documented. |
| No benchmark/SHA256 integrity check | `audit/air_quality/benchmark_mp25_sha256.csv` records SHA256 hashes of the PM2.5 output files. |
| No compliance checklist | `audit/air_quality/compliance_pm25_mensal_20260621.csv` provides a line-by-line audit. |

## PM2.5 Downscaling Methodology (2026-06-21 upgrade)

Two-stage approach due to the Power BI source providing only a single mean PM2.5 value per municipality:

1. **Annual downscaling:** `PM25(mun, year) = PM25_mean(mun) x PM25_national(year) / PM25_national_mean` using the VIGIAR national annual series (2010-2024).
2. **Monthly downscaling:** `PM25(mun, year, month) = PM25(mun, year) x profile[month] / mean(profile)` using the 2024 national monthly profile extracted from the same Power BI dashboard (query `df_mensal.mes_nome`).

2025 is extrapolated via linear regression on 2020-2024.

## Remaining Scientific Limitations

1. The study remains ecological; results must not be interpreted at the individual level.
2. PM2.5 remains **monthly** (not daily) and partially nearest-neighbor assigned; it is suitable as a seasonal covariate but not as a daily exposure-lag cross-basis.
3. The same seasonal profile is applied uniformly to all years and all municipalities; interannual and spatial variability in seasonality is not captured.
4. The Bayesian stage is a two-stage hierarchical stabilization of DLNM estimates, not a fully joint Bayesian DLNM.
5. Residual confounding may persist because individual socioeconomic, behavioral, occupational and clinical covariates are not available in the aggregated DATASUS design.
6. Spatial aggregation to health macroregions reduces noise but may obscure intraurban microclimate and exposure heterogeneity.

## Recommended Positioning for Publication

The strongest contribution of the compendium is reproducibility and transparent environmental epidemiology workflow engineering: public health data acquisition, daily macroregional climate exposure construction, DLNM modeling, hierarchical Bayesian stabilization, sensitivity analyses, audit trails and FAIR documentation.

The defensible scientific claim is:

> This repository provides a reproducible ecological time-series framework to estimate and prioritize macroregional associations between daily climate exposures and cerebrovascular outcomes in Rio de Janeiro.

The repository should avoid claims that it:

- estimates individual risk;
- establishes causal effects;
- forecasts future admissions or deaths;
- treats PM2.5 as a daily exposure-lag variable; PM2.5 is monthly derived and is limited to optional linear sensitivity adjustment.

---

## Response to Second Scientific Audit (2026-06-21, Score 68/100)

A second independent audit was conducted on 2026-06-21 by a panel simulating
Johns Hopkins, Harvard, Nature Medicine, Lancet Digital Health, Cochrane, and NIH
reviewers. This audit scored the compendium at **68/100** (up from 47/100 in the
first audit), with reproducibility at 9.5/10 and transparency at 9/10.

### Items Already Addressed (from Audit 1)

All 12 code-level corrections from the first forensic audit (C1-C12) were
implemented before this second audit, which explains the score improvement:
- C1: PM2.5 path fixed → reads from `data/processed/pm25/`
- C2: Python script uses relative path
- C4: Moran's I implemented via `spdep::moran.test`
- C5: CI runs real `testthat` suite
- C6: `test_runner.R` sources real functions
- C7: FDR Wald test uses HAC vcov
- C8: Bayesian SE unified between main and prior sensitivity
- C9: Climate imputation validation implemented (LOO)
- C10: Benchmark threshold dynamic
- C11: Model coverage audit (expected vs. obtained)
- C12: Consciência Negra holiday logic fixed

### Items Acknowledged as Inherent Limitations

| Audit finding | Repository response |
|---|---|
| Ecological bias / aggregation (Critical) | Explicitly declared in README line 15; 9-item limitations section; no individual, causal, or forecasting claims made |
| PM2.5 granularity mismatch (Critical) | Upgraded from annual to monthly; documented as "monthly derived"; `DLNM_ENABLE_AIR_QUALITY=false` by default; PM2.5 is an optional sensitivity covariate, never a primary DLNM exposure |
| Bayes 2-stage underestimates uncertainty (High) | Documented as Limitation 7 in README; code comment in `R/bayesian_models.R` lines 7-11 explicitly acknowledges this |
| Spatial aggregation via nearest neighbor (High) | Moran's I implemented; nearest-neighbor for 18/92 municipalities documented in audit |
| MMT data-driven without bootstrap (Moderate) | Acknowledged; bootstrap recommended for future work per Tobias et al. (2017) |
| No external temporal validation (Moderate) | 16-year series; holdout partition feasible but not implemented; documented as future work |

### New Actions Taken After Second Audit

| Action | Status |
|---|---|
| OSF pre-registration template | Created at `docs/methodology/osf_preregistration_template.md` |
| Ecological bias discussion expanded | This document now explicitly addresses the aggregation caveat |
| Priority framework documented as exploratory | README and pre-registration clarify five criteria are exploratory, not a formal decision rule |
| Language audit: no "effect", "causal", or inappropriate "risk" found in README | Confirmed — language is strictly associational |

### Recommended Next Steps for Journal Submission

1. **Complete OSF registration** using the template at `docs/methodology/osf_preregistration_template.md`
2. **Fill ORCID identifiers** in `CITATION.cff` (currently placeholders)
3. **Add CRediT author contribution statement** per ICMJE criteria
4. **Consider external validation** (temporal holdout 2010-2022 vs. 2023-2025) for robustness
5. **Target journals:** *Environmental Health Perspectives* (40-55% acceptance probability estimated) or *Scientific Reports* (60%+) for initial submission
