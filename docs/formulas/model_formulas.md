# Model Formulas

## DLNM

The epidemiological model uses a count outcome with log link, population offset, cross-basis exposure-lag term, temporal control and calendar covariates.

```text
log(E[Y_{r,t,o}]) =
  alpha + log(Pop_{r,t}) + cb(X_{r,t,e}, lag)
  + ns(time, 7 * years) + dow + holiday + pandemic
  + ns(Z_{r,t,e}, 3)
```

## Bayesian Hierarchical Stabilization

DLNM cumulative log-relative risks are treated as observed estimates with uncertainty:

```text
theta_hat_r ~ Normal(theta_r, SE_r^2)
theta_r ~ Normal(mu, tau^2)
```

The output is posterior RR, 95% credible interval and posterior probability that RR exceeds 1.10.

