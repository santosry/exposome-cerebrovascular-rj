# Model Formulas -- DLNM Cerebrovascular RJ (2010-2025)

## Core DLNM Equation

For macroregion $r$, day $t$, and outcome $o$ (admissions or deaths from ICD-10 I60-I69):

```text
log(E[Y_{r,t,o}]) =
    alpha
  + log(Pop_{r,y})                                    -- Population offset (SIDRA/IBGE)
  + cb(X_{r,t,e}, lag)                                -- Cross-basis: exposure x lag
  + ns(time, 7 * n_years)                             -- Temporal trend (7 df/year)
  + dow_{t}                                           -- Day of week (1-7)
  + holiday_{t}                                       -- Brazilian holidays (fixed + movable)
  + pandemic_{t}                                      -- COVID-19 indicator (2020-03 to 2022-12)
  + ns(Z_{r,t,e}, df=3)                               -- Complementary climate exposure
  + pm25_{r,m}                                        -- Optional monthly PM2.5 contextual covariate
  + ns(influenza_{t-7}, df=2)                          -- Influenza control (7-day lag)
```

Where:
- $Y_{r,t,o}$: observed count of admissions or deaths
- $Pop_{r,y}$: population of macroregion $r$ in year $y$
- $X_{r,t,e}$: climate exposure $e$ (temp_med or ur_med) in macroregion $r$ on day $t$
- $Z_{r,t,e}$: complementary exposure (ur_med when X is temp_med, and vice-versa)
- $cb(X, lag)$: cross-basis function combining exposure-response and lag-response
- $pm25_{r,m}$: optional monthly derived PM2.5 covariate for macroregion $r$ and month $m$; it is linear and is not part of the DLNM cross-basis

## Cross-Basis Specification

```text
cb(X, lag) = sum_{i=1}^{df_exp} sum_{j=1}^{df_lag} eta_{ij} * ns_i(X) * ns_j(lag)
```

- Exposure dimension: natural spline, df = 4 (sensitivity grid: 3, 4, 5, 6)
- Lag dimension: natural spline, df = 3, log-knots, max lag = 14 (sensitivity: 7, 14, 21)
- $\eta_{ij}$: cross-basis coefficients estimated from data

## Model Family

- **Primary:** Quasi-Poisson with log link
- **Fallback:** Negative Binomial when dispersion > 3
- **Standard errors:** Newey-West HAC (21 lags) with delta-method propagation to cumulative RR

## MMT Centering

```text
MMT = argmin_{X} RR_{cumul}(X)
```

The Minimum Mortality/Morbidity Temperature is estimated from the data. Cumulative RR is centered at the MMT, meaning RR(MMT) = 1.

## Cumulative Relative Risk

```text
RR_{cumul}(X) = exp(sum_{lag=0}^{L} log(RR(X, lag)))
```

Computed across exposure percentiles P0.1 to P99.9 with MMT as reference.

## Excess RR AUC

```text
AUC = integral_{X_min}^{X_max} max(RR_{cumul}(X) - 1, 0) dX
```

Approximated via trapezoidal integration over 80 exposure points.

## Hierarchical Bayesian Model (Two-Stage)

**Stage 1 (DLNM):** Produces cumulative log(RR) estimate $\hat{\theta}_r$ and HAC-corrected standard error $SE_r$ for each macroregion $r$.

**Stage 2 (Bayesian):**

```text
theta_hat_r ~ Normal(theta_r, SE_r^2)     -- Likelihood (observed estimate)
theta_r     ~ Normal(mu, tau^2)           -- Hierarchical prior
```

Where:
- $\mu$: overall mean effect across macroregions (estimated via grid search)
- $\tau$: between-macroregion heterogeneity (estimated via grid search)
- Grid: 200 x 200 points over $\mu$ and $\tau$

**Posterior (shrinkage):**

```text
theta_r | theta_hat_r, mu, tau ~ Normal(
    (theta_hat_r / SE_r^2 + mu / tau^2) / (1 / SE_r^2 + 1 / tau^2),
    1 / (1 / SE_r^2 + 1 / tau^2)
)
```

**Output:** Posterior RR = exp($\theta_r$), 95% credible interval, Pr(RR > 1.10).

**Prior sensitivity:** Three specifications tested:
- Skeptical: $\mu \sim N(0, 1^2)$, $\tau = 0.5$
- Optimistic: $\mu \sim N(\log(1.05), 0.3^2)$, $\tau = 0.3$
- Flat: $\mu \sim N(0, 3^2)$, $\tau = 1.5$

**Known limitation:** Two-stage approach does not propagate first-stage uncertainty to posterior intervals, which may be moderately narrow.

## FDR Correction

Benjamini-Hochberg procedure applied across all exposure-outcome-macroregion tests:

```text
p_{FDR} = p.adjust(p_{association}, method = "fdr")
```

Significance threshold: FDR < 0.05.

## Prioritization Framework

Models are prioritized using five sequential criteria:

1. **FDR < 0.05** -- statistical credibility
2. **IC95% excludes 1.00** -- effect precision
3. **RR > 1.10** -- effect magnitude
4. **AUC > 0** -- excess risk persistence
5. **Pr(RR > 1.10) > 0.80** -- posterior evidence (Bayesian)

## Sensitivity Analyses Implemented

| Analysis | Description |
|----------|-------------|
| Lag maximum | 7, 14, 21 days |
| Temporal df | 4, 5, 6, 7 df/year |
| Spline df | Grid: df_exp (3,4,5,6) x df_lag (3,4,5) |
| Pandemic exclusion | Models without 2020-03 to 2022-12 |
| Seasonal | Separate DLNMs for summer (Dec-Feb) and winter (Jun-Aug) |
| Bayesian priors | Skeptical, optimistic, flat |
