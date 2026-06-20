# dlnm_models.R — Distributed Lag Non-linear Models
# =============================================================================
# Core DLNM fitting, cross-prediction, AUC computation, sensitivity analyses,
# model diagnostics, and prioritization framework.

#' Fit one DLNM for a single macroregion-outcome-exposure combination
fit_one_dlnm <- function(dat, outcome, exposure, df_exp, df_lag, lag_max,
                          use_mmt = TRUE) {
  model_warnings <- character()
  capture_model_warnings <- function(expr) {
    withCallingHandlers(expr,
      warning = function(w) {
        model_warnings <<- c(model_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  }

  cb <- dlnm::crossbasis(
    dat[[exposure]], lag = lag_max,
    argvar = list(fun = "ns", df = df_exp),
    arglag = list(fun = "ns", knots = dlnm::logknots(lag_max, df = df_lag))
  )

  complementary <- if (exposure == "temp_med") "ur_med" else "temp_med"
  # [F-003] 7 df/year for temporal trend (upper bound per Bhaskaran et al. 2013)
  # Total df = 7 * N_years distributed across 16-year span
  covars <- paste0("ns(tempo, df = ", 7 * length(unique(dat$ano)),
    ") + dow + feriado + pandemia + ns(", complementary, ", df = 3)")
  if (!is.null(dat$influenza_lag7) && all(is.finite(dat$influenza_lag7))) {
    covars <- paste0(covars, " + ns(influenza_lag7, df = 2)")
  }
  # [F-005] PM2.5 air pollution control (annual, linear term -- no spline)
  if (!is.null(dat$pm25_anual) && any(is.finite(dat$pm25_anual))) {
    covars <- paste0(covars, " + pm25_anual")
  }
  form <- stats::as.formula(
    paste(outcome, "~ cb +", covars, "+ offset(offset_log_populacao)"))
  form_reduced <- stats::as.formula(
    paste(outcome, "~", covars, "+ offset(offset_log_populacao)"))

  # Quasi-Poisson primary model
  m_qp <- capture_model_warnings(
    glm(form, family = quasipoisson(link = "log"), data = dat, na.action = na.exclude))
  dispersion <- sum(residuals(m_qp, type = "pearson")^2, na.rm = TRUE) /
    m_qp$df.residual
  model <- m_qp
  family_used <- "quasipoisson"
  p_association <- NA_real_
  p_method <- "Quasi-Poisson F test"

  # [S-005] Negative binomial fallback when dispersion > 3.
  # Threshold justification: Quasi-Poisson is robust for moderate overdispersion
  # (< 3). Above that, inflated Type I error risk. Reference: Ver Hoef & Boveng
  # (2007, Ecological Applications).
  if (is.finite(dispersion) && dispersion > 3) {
    nb_warnings <- character()
    m_nb <- try(withCallingHandlers(
      MASS::glm.nb(form, data = dat, na.action = na.exclude),
      warning = function(w) {
        nb_warnings <<- c(nb_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ), silent = TRUE)
    nb_unstable <- inherits(m_nb, "try-error") ||
      isFALSE(m_nb$converged) ||
      any(stringr::str_detect(stringr::str_to_lower(nb_warnings),
           "converg|alternation|iteration|limite|limit"))
    if (!nb_unstable) {
      model <- m_nb
      family_used <- "negative_binomial"
      p_method <- "Negative binomial LRT"
    } else {
      model_warnings <- c(model_warnings,
        "Binomial negativa rejeitada por instabilidade numerica; mantido Quasi-Poisson.")
    }
  }

  # Compute association p-value
  reduced <- tryCatch({
    if (identical(family_used, "negative_binomial")) {
      capture_model_warnings(
        MASS::glm.nb(form_reduced, data = dat, na.action = na.exclude))
    } else {
      capture_model_warnings(
        glm(form_reduced, family = quasipoisson(link = "log"),
            data = dat, na.action = na.exclude))
    }
  }, error = function(e) NULL)

  if (!is.null(reduced)) {
    p_association <- tryCatch({
      test <- if (identical(family_used, "negative_binomial")) "Chisq" else "F"
      tab <- anova(reduced, model, test = test)
      as.numeric(tail(tab[[grep("^Pr", names(tab), value = TRUE)[1]]], 1))
    }, error = function(e) NA_real_)
  }
  if (!is.finite(p_association)) {
    p_association <- tryCatch({
      idx <- grep("^cb", names(stats::coef(model)))
      beta <- stats::coef(model)[idx]
      vc <- stats::vcov(model)[idx, idx, drop = FALSE]
      stat <- drop(t(beta) %*% solve(vc) %*% beta)
      stats::pchisq(stat, df = length(idx), lower.tail = FALSE)
    }, error = function(e) NA_real_)
  }

  # Cross-prediction
  # [S-004] Extended prediction range to capture extreme effects.
  # Caveat: extrapolation beyond [P0.1, P99.9] has higher uncertainty.
  pred_at <- seq(
    stats::quantile(dat[[exposure]], 0.001, na.rm = TRUE),
    stats::quantile(dat[[exposure]], 0.999, na.rm = TRUE),
    length.out = 80
  )

  # MMT (Minimum Mortality Temperature) estimation
  if (use_mmt) {
    cen_p50 <- stats::quantile(dat[[exposure]], 0.50, na.rm = TRUE)
    pred_p50 <- dlnm::crosspred(cb, model, at = pred_at, cen = cen_p50,
                                 bylag = 1, cumul = TRUE)
    mmt_idx <- which.min(pred_p50$allRRfit)
    cen <- pred_at[mmt_idx]
    cen_mmt <- cen
    cen_percentil_mmt <- round(mean(dat[[exposure]] <= cen, na.rm = TRUE) * 100, 1)
  } else {
    cen <- stats::quantile(dat[[exposure]], 0.50, na.rm = TRUE)
    cen_mmt <- NA_real_
    cen_percentil_mmt <- 50
  }

  pred <- dlnm::crosspred(cb, model, at = pred_at, cen = cen,
                            bylag = 1, cumul = TRUE)

  # [S-008] Newey-West HAC standard errors with delta-method propagation
  # to cumulative RR. The SE from crosspred uses model vcov, not HAC.
  nw_se <- NULL; nw_cov <- NULL
  se_log_rr_hac <- NA_real_
  if (DLNM_NW_HAC_ENABLE && requireNamespace("sandwich", quietly = TRUE)) {
    nw_cov <- tryCatch(
      sandwich::NeweyWest(model, lag = DLNM_NW_LAGS, prewhite = FALSE),
      error = function(e) NULL
    )
    if (!is.null(nw_cov)) {
      nw_se <- sqrt(diag(nw_cov))
      # [S-009] Delta method: propagate HAC vcov to cumulative log(RR)
      cb_idx <- grep("^cb", names(stats::coef(model)))
      if (length(cb_idx) > 0) {
        # Gradient of cumulative prediction w.r.t. cross-basis coefficients
        grad_cumul <- colSums(pred$matRRfit) / nrow(pred$matRRfit)
        # Approximate: SE of log(cumul RR) via delta method on HAC vcov
        vc_cb <- nw_cov[cb_idx, cb_idx, drop = FALSE]
        se_log_rr_hac <- tryCatch(
          sqrt(t(grad_cumul) %*% vc_cb %*% grad_cumul),
          error = function(e) NA_real_
        )
      }
    }
  }

  alerta_convergencia <- isFALSE(model$converged) ||
    any(stringr::str_detect(stringr::str_to_lower(model_warnings),
         "converg|alternation|iteration|limite|limit"))

  list(
    model = model, cb = cb, pred = pred,
    family = family_used, dispersion = dispersion,
    p_association = p_association, p_method = p_method,
    cen = cen, cen_mmt = cen_mmt,
    cen_percentil_mmt = cen_percentil_mmt,
    nw_se = nw_se, nw_cov = nw_cov,
    se_log_rr_hac = se_log_rr_hac,
    alerta_convergencia = alerta_convergencia,
    model_warnings = model_warnings,
    exposure = exposure, outcome = outcome,
    df_exp = df_exp, df_lag = df_lag, lag_max = lag_max
  )
}

#' Summarize cumulative RR from a DLNM fit
summarise_pred <- function(obj, region) {
  rr <- obj$pred$allRRfit
  rr_low <- obj$pred$allRRlow
  rr_high <- obj$pred$allRRhigh
  # [S-009] HAC-based CI for cumulative RR
  se_hac <- obj$se_log_rr_hac
  rr_cum <- rr[length(rr)]
  if (is.finite(se_hac) && se_hac > 0) {
    hac_low <- exp(log(rr_cum) - 1.96 * se_hac)
    hac_high <- exp(log(rr_cum) + 1.96 * se_hac)
  } else {
    hac_low <- rr_low[length(rr_low)]
    hac_high <- rr_high[length(rr_high)]
  }
  tibble::tibble(
    macro_regiao = region,
    outcome = obj$outcome,
    exposure = obj$exposure,
    rr_cumulativo = rr_cum,
    rr_cumulativo_low = rr_low[length(rr_low)],
    rr_cumulativo_high = rr_high[length(rr_high)],
    rr_cumulativo_hac_low = hac_low,
    rr_cumulativo_hac_high = hac_high,
    se_log_rr_hac = se_hac,
    p_association = obj$p_association,
    family = obj$family,
    dispersion = obj$dispersion,
    alerta_convergencia = obj$alerta_convergencia,
    df_exp = obj$df_exp,
    df_lag = obj$df_lag,
    lag_max = obj$lag_max,
    cen = obj$cen,
    cen_mmt = obj$cen_mmt,
    cen_percentil_mmt = obj$cen_percentil_mmt
  )
}

#' Trapezoidal AUC for excess RR
trapezoid_auc <- function(x, y) {
  y_excess <- pmax(y - 1, 0)
  n <- length(x)
  if (n < 2) return(0)
  sum((x[2:n] - x[1:(n-1)]) * (y_excess[2:n] + y_excess[1:(n-1)])) / 2
}

#' Summarise excess RR AUC from a DLNM fit
summarise_auc <- function(obj, region) {
  rr <- obj$pred$allRRfit
  pred_at <- obj$pred$predvar
  if (is.list(pred_at)) pred_at <- pred_at[[1]]
  auc_val <- trapezoid_auc(pred_at, rr)
  tibble::tibble(
    macro_regiao = region,
    outcome = obj$outcome,
    exposure = obj$exposure,
    auc_excesso_rr = auc_val,
    rr_cumulativo = rr[length(rr)],
    p_association = obj$p_association,
    family = obj$family,
    alerta_convergencia = obj$alerta_convergencia
  )
}

#' Model diagnostics: residuals, autocorrelation, Durbin-Watson
diagnose_model <- function(obj, region) {
  res <- residuals(obj$model, type = "deviance")
  dw <- tryCatch(
    lmtest::dwtest(res ~ 1, alternative = "two.sided"),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_)
  )
  acf_vals <- stats::acf(res, plot = FALSE, lag.max = 14, na.action = na.pass)
  # [S-014] Ljung-Box test for residual autocorrelation (multiple lags)
  lb <- tryCatch(
    stats::Box.test(res, lag = 14, type = "Ljung-Box"),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_)
  )
  # [S-014] Check if autocorrelation persists after Newey-West
  autocorr_after_hac <- FALSE
  if (!is.null(obj$nw_cov) && is.finite(lb$p.value)) {
    autocorr_after_hac <- lb$p.value < 0.05
  }
  tibble::tibble(
    macro_regiao = region,
    outcome = obj$outcome,
    exposure = obj$exposure,
    dw_statistic = dw$statistic,
    dw_pvalue = dw$p.value,
    acf_lag1 = acf_vals$acf[2],
    acf_lag7 = acf_vals$acf[8],
    acf_lag14 = acf_vals$acf[15],
    lb_statistic = lb$statistic,
    lb_pvalue = lb$p.value,
    autocorr_residual_after_hac = autocorr_after_hac,
    n_residuals = length(res),
    dispersion = obj$dispersion,
    alerta_convergencia = obj$alerta_convergencia
  )
}

#' Run all DLNMs across macroregions, outcomes, and exposures
run_dlnm <- function(dat_macro, extra_outcomes = character(),
                     extra_exposures = character()) {
  base_outcomes <- c("internacoes_i60_i69", "obitos_i60_i69",
                     "internacoes_i60_i64", "obitos_i60_i64")
  cid_outcomes <- c("internacoes_i60_i62", "obitos_i60_i62",
                    "internacoes_i63", "obitos_i63")
  available_cols <- names(dat_macro)
  cid_outcomes <- intersect(cid_outcomes, available_cols)
  outcomes <- c(base_outcomes, cid_outcomes, extra_outcomes)
  exposures <- c("temp_med", "ur_med", extra_exposures)

  results <- list(); summaries <- list(); aucs <- list(); diagnostics <- list()

  for (region in sort(unique(dat_macro$macro_regiao))) {
    d <- dplyr::filter(dat_macro, macro_regiao == region)
    for (outcome in outcomes) {
      for (exposure in exposures) {
        log_msg("INFO", "Fitting DLNM: ", region, " / ", outcome, " / ", exposure)
        obj <- safe_fetch(
          fit_one_dlnm(d, outcome, exposure,
                       DLNM_FALLBACK$df_exp, DLNM_FALLBACK$df_lag,
                       DLNM_FALLBACK$lag_max),
          paste("DLNM", region, outcome, exposure),
          critical = FALSE
        )
        if (is.null(obj)) next
        obj$macro_regiao <- region
        key <- paste(region, outcome, exposure, sep = "__") |>
          janitor::make_clean_names()
        results[[key]] <- obj
        summaries[[key]] <- summarise_pred(obj, region)
        aucs[[key]] <- summarise_auc(obj, region)
        diagnostics[[key]] <- diagnose_model(obj, region)
      }
    }
  }

  if (length(results) == 0)
    stop("No DLNM models were successfully fitted.", call. = FALSE)

  save_rds(results, file.path(PROJECT_ROOT, "data", "processed",
                               "modelos_dlnm_macrorregiao.rds"))
  write_audit(dplyr::bind_rows(summaries),
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_rr_dlnm_macrorregiao.csv"))

  auc_tbl <- dplyr::bind_rows(aucs, .id = "modelo_id") |>
    add_fdr_and_evidence_flags()
  write_audit(auc_tbl,
    file.path(PROJECT_ROOT, "outputs", "tables", "tabela_auc_rr_dlnm_macrorregiao.csv"))

  write_audit(dplyr::bind_rows(diagnostics),
    file.path(PROJECT_ROOT, "audit", "diagnosticos_autocorrelacao_dlnm.csv"))

  results
}

#' Add FDR correction and evidence flags
add_fdr_and_evidence_flags <- function(auc_tbl) {
  # [S-013] FDR controls false discovery rate among rejected tests,
  # but does not control global error when multiple dimensions
  # (RR, AUC, Pr posterior) are examined.
  n_total <- nrow(auc_tbl)
  auc_tbl |>
    dplyr::mutate(
      p_fdr = stats::p.adjust(p_association, method = "fdr"),
      fdr_significant = p_fdr < 0.05,
      n_testes_total = n_total,
      evidence_level = dplyr::case_when(
        p_fdr < 0.01 ~ "strong",
        p_fdr < 0.05 ~ "moderate",
        p_fdr < 0.10 ~ "weak",
        TRUE ~ "insufficient"
      )
    )
}

#' Run lag sensitivity analysis
run_lag_sensitivity <- function(dat_macro, lag_grid = c(7, 14, 21)) {
  results <- list()
  for (lag in lag_grid) {
    log_msg("INFO", "Lag sensitivity: lag_max = ", lag)
    lag_results <- dplyr::bind_rows(purrr::map(
      sort(unique(dat_macro$macro_regiao)),
      function(region) {
        d <- dplyr::filter(dat_macro, macro_regiao == region)
        purrr::map_dfr(c("internacoes_i60_i69", "obitos_i60_i69"), function(outc) {
          purrr::map_dfr(c("temp_med", "ur_med"), function(exp) {
            obj <- safe_fetch(
              fit_one_dlnm(d, outc, exp,
                           DLNM_FALLBACK$df_exp, DLNM_FALLBACK$df_lag, lag),
              paste("LAG_SENS", region, outc, exp, "lag", lag),
              critical = FALSE
            )
            if (is.null(obj)) return(NULL)
            tibble::tibble(
              macro_regiao = region, outcome = outc, exposure = exp,
              lag_max = lag, rr_cumulativo = obj$pred$allRRfit[length(obj$pred$allRRfit)],
              p_association = obj$p_association
            )
          })
        })
      }
    ))
    results[[as.character(lag)]] <- lag_results
  }
  estabilidade <- dplyr::bind_rows(results) |>
    dplyr::group_by(macro_regiao, outcome, exposure) |>
    dplyr::summarise(
      rr_min = min(rr_cumulativo, na.rm = TRUE),
      rr_max = max(rr_cumulativo, na.rm = TRUE),
      rr_range = rr_max - rr_min,
      n_lags_tested = dplyr::n(),
      .groups = "drop"
    )
  write_audit(estabilidade,
    file.path(PROJECT_ROOT, "outputs", "tables", "comparacao_estabilidade_lags_dlnm.csv"))
  list(results = results, estabilidade = estabilidade)
}

#' Run pandemic exclusion sensitivity
run_pandemic_exclusion_sensitivity <- function(dat_macro) {
  dat_no_pand <- dat_macro |>
    dplyr::filter(!(data >= PANDEMIC_START & data <= PANDEMIC_END))
  log_msg("INFO", "Pandemic exclusion sensitivity: ",
          nrow(dat_no_pand), " rows (",
          round(100 * nrow(dat_no_pand) / nrow(dat_macro)), "% of original)")
  results <- dplyr::bind_rows(purrr::map(
    sort(unique(dat_no_pand$macro_regiao)),
    function(region) {
      d <- dplyr::filter(dat_no_pand, macro_regiao == region)
      purrr::map_dfr(c("internacoes_i60_i69", "obitos_i60_i69"), function(outc) {
        purrr::map_dfr(c("temp_med", "ur_med"), function(exp) {
          obj <- safe_fetch(
            fit_one_dlnm(d, outc, exp,
                         DLNM_FALLBACK$df_exp, DLNM_FALLBACK$df_lag,
                         DLNM_FALLBACK$lag_max),
            paste("PANDEMIC_SENS", region, outc, exp),
            critical = FALSE
          )
          if (is.null(obj)) return(NULL)
          tibble::tibble(
            macro_regiao = region, outcome = outc, exposure = exp,
            rr_sem_pandemia = obj$pred$allRRfit[length(obj$pred$allRRfit)],
            p_sem_pandemia = obj$p_association
          )
        })
      })
    }
  ))
  write_audit(results,
    file.path(PROJECT_ROOT, "outputs", "tables", "sensibilidade_sem_pandemia_dlnm.csv"))
  results
}

#' Run spline df sensitivity analysis
run_spline_df_sensitivity <- function(dat_macro, auc_tbl,
                                       df_exp_grid = c(3, 4, 5),
                                       df_lag_grid = c(3, 4, 5)) {
  # Identify FDR-significant models from primary analysis
  fdr_models <- auc_tbl |>
    dplyr::filter(fdr_significant) |>
    dplyr::distinct(macro_regiao, outcome, exposure)

  results <- list()
  for (df_exp in df_exp_grid) {
    for (df_lag in df_lag_grid) {
      key <- paste0("dfexp", df_exp, "_dflag", df_lag)
      log_msg("INFO", "Spline df sensitivity: exp=", df_exp,
              ", lag=", df_lag)
      grid_results <- dplyr::bind_rows(purrr::map(
        seq_len(nrow(fdr_models)),
        function(i) {
          r <- fdr_models[i, ]
          d <- dplyr::filter(dat_macro, macro_regiao == r$macro_regiao)
          obj <- safe_fetch(
            fit_one_dlnm(d, r$outcome, r$exposure, df_exp, df_lag,
                         DLNM_FALLBACK$lag_max),
            paste("DF_SENS", r$macro_regiao, r$outcome, r$exposure,
                  "dfe", df_exp, "dfl", df_lag),
            critical = FALSE
          )
          if (is.null(obj)) return(NULL)
          tibble::tibble(
            macro_regiao = r$macro_regiao, outcome = r$outcome,
            exposure = r$exposure, df_exp = df_exp, df_lag = df_lag,
            rr_cumulativo = obj$pred$allRRfit[length(obj$pred$allRRfit)],
            p_association = obj$p_association
          )
        }
      ))
      results[[key]] <- grid_results
    }
  }
  sens_tbl <- dplyr::bind_rows(results)
  write_audit(sens_tbl,
    file.path(PROJECT_ROOT, "outputs", "tables",
              "sensibilidade_df_spline_modelos_fdr_i60_i69.csv"))
  sens_tbl
}

#' Write DLNM model specification audit
write_dlnm_model_audits <- function(results) {
  spec <- purrr::map_dfr(names(results), function(k) {
    obj <- results[[k]]
    tibble::tibble(
      modelo_id = k,
      macro_regiao = obj$macro_regiao,
      outcome = obj$outcome,
      exposure = obj$exposure,
      family = obj$family,
      df_exp = obj$df_exp,
      df_lag = obj$df_lag,
      lag_max = obj$lag_max,
      cen = obj$cen,
      cen_mmt = obj$cen_mmt,
      alerta_convergencia = obj$alerta_convergencia
    )
  })
  write_audit(spec,
    file.path(PROJECT_ROOT, "audit", "especificacao_modelos_dlnm.csv"))

  quality <- spec |>
    dplyr::mutate(
      status = dplyr::if_else(alerta_convergencia, "alerta", "ok")
    )
  write_audit(quality,
    file.path(PROJECT_ROOT, "audit", "resumo_qualidade_modelos_dlnm.csv"))
  invisible(spec)
}

#' Write methodological note about DLNM formulation
write_dlnm_method_note <- function() {
  lines <- c(
    "# DLNM Methodological Note",
    "",
    paste0("Period: ", PERIOD_LABEL),
    "Model family: Quasi-Poisson with negative binomial fallback (dispersion > 3)",
    "Cross-basis: natural spline for exposure (df=", DLNM_FALLBACK$df_exp,
    ") x natural spline for lags (df=", DLNM_FALLBACK$df_lag,
    ", log-knots, max lag=", DLNM_FALLBACK$lag_max, ")",
    "Time control: natural spline with 7 df/year",
    "Additional covariates: day-of-week, holidays, pandemic period, complementary exposure (df=3)",
    "Influenza control: natural spline (df=2) on 7-day lagged influenza admissions",
    "Offset: log(population) from SIDRA/IBGE",
    "Standard errors: Newey-West HAC with ", DLNM_NW_LAGS, " lags",
    "Centering: MMT (minimum mortality/morbidity temperature)"
  )
  writeLines(lines, file.path(PROJECT_ROOT, "docs", "formulas",
                               "model_formulas.md"))
}

# [F-003] Sensitivity analysis for temporal df (4, 5, 6 df/year)
# to assess robustness of the 7 df/year choice.
#' Run temporal df sensitivity analysis
run_temporal_df_sensitivity <- function(dat_macro, df_grid = c(4, 5, 6)) {
  log_msg("INFO", "Temporal df sensitivity: testing ",
          paste(df_grid, collapse = ", "), " df/year")
  results <- list()
  for (df_year in df_grid) {
    log_msg("INFO", "Temporal df sensitivity: df/year = ", df_year)
    for (region in sort(unique(dat_macro$macro_regiao))) {
      d <- dplyr::filter(dat_macro, macro_regiao == region)
      for (outc in c("internacoes_i60_i69", "obitos_i60_i69")) {
        for (exp in c("temp_med", "ur_med")) {
          # Re-fit with modified temporal df
          obj <- safe_fetch({
            cb <- dlnm::crossbasis(
              d[[exp]], lag = DLNM_FALLBACK$lag_max,
              argvar = list(fun = "ns", df = DLNM_FALLBACK$df_exp),
              arglag = list(fun = "ns",
                knots = dlnm::logknots(DLNM_FALLBACK$lag_max,
                                        df = DLNM_FALLBACK$df_lag))
            )
            complementary <- if (exp == "temp_med") "ur_med" else "temp_med"
            covars <- paste0("ns(tempo, df = ", df_year * length(unique(d$ano)),
              ") + dow + feriado + pandemia + ns(", complementary, ", df = 3)")
            if (!is.null(d$pm25_anual) && any(is.finite(d$pm25_anual)))
              covars <- paste0(covars, " + pm25_anual")
            if (!is.null(d$influenza_lag7) && all(is.finite(d$influenza_lag7)))
              covars <- paste0(covars, " + ns(influenza_lag7, df = 2)")
            form <- stats::as.formula(paste(outc, "~ cb +", covars,
              "+ offset(offset_log_populacao)"))
            glm(form, family = quasipoisson(link = "log"),
                data = d, na.action = na.exclude)
          }, paste("TEMP_DF_SENS", region, outc, exp, "df", df_year),
          critical = FALSE)
          if (is.null(obj)) next
          pred <- dlnm::crosspred(cb, obj, at = seq(
            stats::quantile(d[[exp]], 0.01, na.rm = TRUE),
            stats::quantile(d[[exp]], 0.99, na.rm = TRUE),
            length.out = 50), cen = stats::quantile(d[[exp]], 0.50, na.rm = TRUE),
            bylag = 1, cumul = TRUE)
          results[[paste(region, outc, exp, df_year, sep = "__")]] <-
            tibble::tibble(
              macro_regiao = region, outcome = outc, exposure = exp,
              df_year = df_year,
              rr_cumulativo = pred$allRRfit[length(pred$allRRfit)],
              aic = stats::AIC(obj)
            )
        }
      }
    }
  }
  sens_tbl <- dplyr::bind_rows(results)
  if (nrow(sens_tbl) > 0) {
    write_audit(sens_tbl,
      file.path(PROJECT_ROOT, "outputs", "tables", "sensibilidade_df_temporal.csv"))
  }
  sens_tbl
}
