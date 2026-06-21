# dlnm_models.R - Distributed Lag Non-linear Models
# =============================================================================
# Core DLNM fitting, cross-prediction, AUC computation, sensitivity analyses,
# model diagnostics, and prioritization framework.

#' Fit one DLNM for a single macroregion-outcome-exposure combination
fit_one_dlnm <- function(dat, outcome, exposure, df_exp, df_lag, lag_max,
                          use_mmt = TRUE) {
  # [S-006] Defensive: create 'tempo' if missing (e.g., stratified datasets built on-the-fly)
  if (!"tempo" %in% names(dat)) {
    dat$tempo <- as.integer(dat$data - min(dat$data, na.rm = TRUE)) + 1L
  }
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
  covars <- paste0("splines::ns(tempo, df = ", 7 * length(unique(dat$ano)),
    ") + dow + feriado + pandemia + splines::ns(", complementary, ", df = 3)")
  if (!is.null(dat$influenza_lag7) && all(is.finite(dat$influenza_lag7))) {
    covars <- paste0(covars, " + splines::ns(influenza_lag7, df = 2)")
  }
  # [F-005] Optional PM2.5 control (monthly derived, linear sensitivity term -- no spline/cross-basis)
  if (!is.null(dat$pm25_mensal) && any(is.finite(dat$pm25_mensal))) {
    covars <- paste0(covars, " + pm25_mensal")
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

  # [FIX C7] Compute HAC vcov BEFORE association test
  nw_cov_early <- NULL
  if (DLNM_NW_HAC_ENABLE && requireNamespace("sandwich", quietly = TRUE)) {
    nw_cov_early <- tryCatch(
      sandwich::NeweyWest(model, lag = DLNM_NW_LAGS, prewhite = FALSE),
      error = function(e) NULL
    )
  }

  # [AUDIT-FIX] Use Wald HAC as PRIMARY test; ANOVA/LRT only as fallback
  p_association <- NA_real_
  p_method <- "Wald HAC (primary)"

  # Primary: Wald test with HAC vcov on crossbasis coefficients
  p_association <- tryCatch({
    idx <- grep("^cb", names(stats::coef(model)))
    beta <- stats::coef(model)[idx]
    if (!is.null(nw_cov_early) && all(idx %in% seq_len(nrow(nw_cov_early)))) {
      vc <- nw_cov_early[idx, idx, drop = FALSE]
    } else {
      vc <- stats::vcov(model)[idx, idx, drop = FALSE]
      p_method <- paste0(p_method, " (model vcov, HAC unavailable)")
    }
    stat <- drop(t(beta) %*% solve(vc) %*% beta)
    stats::pchisq(stat, df = length(idx), lower.tail = FALSE)
  }, error = function(e) NA_real_)

  # Fallback: ANOVA/LRT if Wald fails
  if (!is.finite(p_association)) {
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
        p_method <- paste0("ANOVA/LRT (fallback, HAC Wald failed)")
        as.numeric(tail(tab[[grep("^Pr", names(tab), value = TRUE)[1]]], 1))
      }, error = function(e) NA_real_)
    }
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
    # [FIX C7] Reuse early HAC if already computed; otherwise compute now
    nw_cov <- if (!is.null(nw_cov_early)) nw_cov_early else tryCatch(
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

  # [FIX C4 + C11] Moran's I spatial test and model coverage audit
  run_moran_spatial_test(results)
  audit_model_coverage(dat_macro, results)

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

# [NW-SENS] Newey-West HAC lag sensitivity: tests 14, 21, 28, 35 lags
# to verify that the chosen truncation (21) is sufficient.
#' Run Newey-West lag sensitivity analysis
run_nw_lag_sensitivity <- function(dlnm_results, auc_tbl, nw_lags = c(14, 21, 28, 35)) {
  if (!requireNamespace("sandwich", quietly = TRUE)) {
    log_msg("WARN", "sandwich not available; skipping NW lag sensitivity")
    return(invisible(NULL))
  }

  log_msg("INFO", "Running Newey-West lag sensitivity: ",
          paste(nw_lags, collapse = ", "))

  # Focus on FDR-significant models
  if (!is.null(auc_tbl) && "fdr_significant" %in% names(auc_tbl)) {
    target_models <- auc_tbl |>
      dplyr::filter(fdr_significant) |>
      dplyr::select(macro_regiao, outcome = desfecho, exposure = exposicao)
  } else {
    # Fallback: test all models
    target_models <- NULL
  }

  all_results <- list()

  for (key in names(dlnm_results)) {
    obj <- dlnm_results[[key]]
    if (is.null(obj) || is.null(obj$model)) next

    # Filter to target models if specified
    if (!is.null(target_models)) {
      match <- target_models |>
        dplyr::filter(macro_regiao == obj$macro_regiao,
                       outcome == obj$outcome,
                       exposure == obj$exposure)
      if (nrow(match) == 0) next
    }

    for (nw_lag in nw_lags) {
      nw <- tryCatch(
        sandwich::NeweyWest(obj$model, lag = nw_lag, prewhite = FALSE),
        error = function(e) NULL
      )
      if (is.null(nw)) next

      idx <- grep("^cb", names(stats::coef(obj$model)))
      if (length(idx) == 0) next

      beta <- stats::coef(obj$model)[idx]
      vc <- nw[idx, idx, drop = FALSE]

      # Wald test with this NW lag
      wald_stat <- tryCatch(
        drop(t(beta) %*% solve(vc) %*% beta),
        error = function(e) NA_real_
      )
      wald_p <- if (is.finite(wald_stat)) {
        stats::pchisq(wald_stat, df = length(idx), lower.tail = FALSE)
      } else NA_real_

      # SE of cumulative log(RR) with this NW lag
      se_hac <- tryCatch(sqrt(t(rep(1/length(idx), length(idx))) %*%
                               vc %*% rep(1/length(idx), length(idx))),
                         error = function(e) NA_real_)

      all_results[[paste(key, nw_lag, sep = "__")]] <- tibble::tibble(
        macro_regiao = obj$macro_regiao,
        outcome = obj$outcome,
        exposure = obj$exposure,
        nw_lag = nw_lag,
        wald_statistic = as.numeric(wald_stat),
        wald_p_value = wald_p,
        se_log_rr_hac = as.numeric(se_hac)
      )
    }
  }

  nw_tbl <- dplyr::bind_rows(all_results)

  if (nrow(nw_tbl) > 0) {
    # Stability assessment
    stability <- nw_tbl |>
      dplyr::group_by(macro_regiao, outcome, exposure) |>
      dplyr::summarise(
        n_lags_tested = dplyr::n(),
        se_min = min(se_log_rr_hac, na.rm = TRUE),
        se_max = max(se_log_rr_hac, na.rm = TRUE),
        se_range = se_max - se_min,
        se_cv = sd(se_log_rr_hac, na.rm = TRUE) / mean(se_log_rr_hac, na.rm = TRUE),
        p_min = min(wald_p_value, na.rm = TRUE),
        p_max = max(wald_p_value, na.rm = TRUE),
        stable_p = dplyr::if_else(
          (p_min < 0.05 & p_max < 0.05) | (p_min >= 0.05 & p_max >= 0.05),
          TRUE, FALSE
        ),
        .groups = "drop"
      )

    write_audit(nw_tbl,
      file.path(PROJECT_ROOT, "outputs", "tables",
                "sensibilidade_newey_west_lags.csv"))
    write_audit(stability,
      file.path(PROJECT_ROOT, "outputs", "tables",
                "estabilidade_newey_west_lags.csv"))

    n_stable <- sum(stability$stable_p, na.rm = TRUE)
    log_msg("INFO", "NW lag sensitivity complete: ",
            n_stable, "/", nrow(stability),
            " models stable across lag choices")
  }

  invisible(nw_tbl)
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

#' [FIX C4] Moran's I spatial autocorrelation test for DLNM residuals
#' Tests whether residuals from models in neighboring macroregions are correlated.
#' Builds a queen-contiguity spatial weights matrix from the 9 macroregions.
run_moran_spatial_test <- function(dlnm_results) {
  if (!requireNamespace("spdep", quietly = TRUE)) {
    log_msg("WARN", "spdep not installed; skipping Moran's I spatial test")
    return(invisible(NULL))
  }

  log_msg("INFO", "Running Moran's I spatial autocorrelation test on DLNM residuals")

  # 1. Build adjacency matrix for the 9 health macroregions of RJ
  macro_names <- c(
    "Baía da Ilha Grande", "Baixada Litorânea", "Centro-Sul",
    "Médio Paraíba", "Metropolitana I", "Metropolitana II",
    "Noroeste", "Norte", "Serrana"
  )

  # Adjacency list: each macroregion's neighbors by geographic contiguity
  adjacency <- list(
    "Baía da Ilha Grande" = c("Metropolitana I", "Médio Paraíba"),
    "Baixada Litorânea" = c("Metropolitana II", "Norte", "Serrana"),
    "Centro-Sul" = c("Metropolitana I", "Médio Paraíba", "Serrana"),
    "Médio Paraíba" = c("Baía da Ilha Grande", "Centro-Sul", "Metropolitana I", "Serrana"),
    "Metropolitana I" = c("Baía da Ilha Grande", "Centro-Sul", "Médio Paraíba",
                           "Metropolitana II", "Serrana"),
    "Metropolitana II" = c("Baixada Litorânea", "Metropolitana I", "Norte", "Serrana"),
    "Noroeste" = c("Norte", "Serrana"),
    "Norte" = c("Baixada Litorânea", "Metropolitana II", "Noroeste", "Serrana"),
    "Serrana" = c("Baixada Litorânea", "Centro-Sul", "Médio Paraíba",
                   "Metropolitana I", "Metropolitana II", "Noroeste", "Norte")
  )

  n <- length(macro_names)
  W <- matrix(0, n, n, dimnames = list(macro_names, macro_names))
  for (i in seq_along(macro_names)) {
    neighbors <- adjacency[[macro_names[i]]]
    if (length(neighbors) > 0) {
      W[i, neighbors] <- 1 / length(neighbors)
    }
  }
  lw <- spdep::mat2listw(W, style = "W", zero.policy = TRUE)

  # 2. For each outcome×exposure, compute Moran's I on mean deviance residuals
  residual_summary <- dplyr::bind_rows(
    purrr::map(names(dlnm_results), function(key) {
      obj <- dlnm_results[[key]]
      if (is.null(obj) || is.null(obj$model)) return(NULL)
      res <- residuals(obj$model, type = "deviance")
      tibble::tibble(
        modelo_id = key,
        macro_regiao = obj$macro_regiao,
        outcome = obj$outcome,
        exposure = obj$exposure,
        residuo_medio = mean(res, na.rm = TRUE),
        residuo_sd = sd(res, na.rm = TRUE),
        n_obs = length(res)
      )
    })
  )

  if (nrow(residual_summary) == 0) {
    log_msg("WARN", "Moran's I: no residuals available")
    return(invisible(NULL))
  }

  # 3. Run Moran's I for each outcome×exposure pair with >=4 macroregions
  moran_results <- purrr::map_dfr(
    dplyr::group_split(residual_summary, outcome, exposure),
    function(group) {
      if (nrow(group) < 4) return(NULL)
      res_vec <- rep(NA_real_, n)
      names(res_vec) <- macro_names
      for (i in seq_len(nrow(group))) {
        if (group$macro_regiao[i] %in% macro_names) {
          res_vec[group$macro_regiao[i]] <- group$residuo_medio[i]
        }
      }
      valid_idx <- !is.na(res_vec)
      if (sum(valid_idx) < 4) return(NULL)

      # Subset weights matrix to valid regions
      W_sub <- W[valid_idx, valid_idx, drop = FALSE]
      lw_sub <- spdep::mat2listw(W_sub, style = "W", zero.policy = TRUE)

      mi <- tryCatch(
        spdep::moran.test(res_vec[valid_idx], lw_sub,
                          zero.policy = TRUE, alternative = "two.sided"),
        error = function(e) {
          log_msg("WARN", "Moran's I failed: ", conditionMessage(e))
          list(estimate = c("Moran I statistic" = NA_real_), p.value = NA_real_)
        }
      )

      tibble::tibble(
        outcome = group$outcome[1],
        exposure = group$exposure[1],
        n_macroregioes = sum(valid_idx),
        moran_i = as.numeric(mi$estimate["Moran I statistic"]),
        moran_i_expectation = -1 / (sum(valid_idx) - 1),
        moran_p = as.numeric(mi$p.value),
        interpretacao = dplyr::case_when(
          is.na(moran_p) ~ "teste_nao_convergiu",
          moran_p < 0.01 ~ "autocorrelacao_espacial_significativa",
          moran_p < 0.05 ~ "autocorrelacao_espacial_moderada",
          moran_p < 0.10 ~ "evidencia_fraca_autocorrelacao",
          TRUE ~ "sem_evidencia_autocorrelacao_espacial"
        )
      )
    }
  )

  if (nrow(moran_results) > 0) {
    write_audit(moran_results,
      file.path(PROJECT_ROOT, "audit", "diagnosticos_moran_espacial_dlnm.csv"))
    n_sig <- sum(moran_results$moran_p < 0.05, na.rm = TRUE)
    log_msg("INFO", "Moran's I complete: ", nrow(moran_results), " tests; ",
            n_sig, " significant at p<0.05")
  } else {
    write_audit(
      tibble::tibble(outcome=character(), exposure=character(),
        n_macroregioes=integer(), moran_i=numeric(),
        moran_i_expectation=numeric(), moran_p=numeric(),
        interpretacao=character()),
      file.path(PROJECT_ROOT, "audit", "diagnosticos_moran_espacial_dlnm.csv"))
    log_msg("WARN", "Moran's I: no tests could be computed")
  }

  invisible(moran_results)
}

#' [FIX C11] Audit expected vs. obtained model combinations
audit_model_coverage <- function(dat_macro, dlnm_results) {
  log_msg("INFO", "Auditing model coverage: expected vs. obtained")

  base_outcomes <- c("internacoes_i60_i69", "obitos_i60_i69",
                     "internacoes_i60_i64", "obitos_i60_i64")
  cid_outcomes <- c("internacoes_i60_i62", "obitos_i60_i62",
                    "internacoes_i63", "obitos_i63")
  available_cols <- names(dat_macro)
  cid_outcomes <- intersect(cid_outcomes, available_cols)
  outcomes <- c(base_outcomes, cid_outcomes)
  exposures <- c("temp_med", "ur_med")

  expected <- tidyr::crossing(
    macro_regiao = sort(unique(dat_macro$macro_regiao)),
    outcome = outcomes,
    exposure = exposures
  ) |>
    dplyr::mutate(combinacao_id = paste(macro_regiao, outcome, exposure, sep = "__") |>
                    janitor::make_clean_names())

  obtained_keys <- names(dlnm_results)

  coverage <- expected |>
    dplyr::mutate(
      modelo_ajustado = combinacao_id %in% obtained_keys,
      status = dplyr::if_else(modelo_ajustado, "obtido", "ausente")
    )

  # Add event counts for diagnosing why models are missing
  obs_counts <- dat_macro |>
    dplyr::group_by(macro_regiao) |>
    dplyr::summarise(
      dias = dplyr::n(),
      dplyr::across(dplyr::any_of(intersect(outcomes, names(dat_macro))),
                    ~sum(.x, na.rm = TRUE), .names = "total_{.col}"),
      .groups = "drop"
    )

  coverage <- coverage |>
    dplyr::left_join(obs_counts, by = "macro_regiao")

  write_audit(coverage,
    file.path(PROJECT_ROOT, "audit", "auditoria_cobertura_modelos_esperado_vs_obtido.csv"))

  n_ausentes <- sum(!coverage$modelo_ajustado)
  n_total <- nrow(coverage)
  log_msg("INFO", "Model coverage: ", n_total - n_ausentes, "/", n_total,
          " (", round(100 * (n_total - n_ausentes) / n_total, 1), "%); ",
          n_ausentes, " absent")

  invisible(coverage)
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
            covars <- paste0("splines::ns(tempo, df = ", df_year * length(unique(d$ano)),
              ") + dow + feriado + pandemia + splines::ns(", complementary, ", df = 3)")
            if (!is.null(d$pm25_mensal) && any(is.finite(d$pm25_mensal)))
              covars <- paste0(covars, " + pm25_mensal")
            if (!is.null(d$influenza_lag7) && all(is.finite(d$influenza_lag7)))
              covars <- paste0(covars, " + splines::ns(influenza_lag7, df = 2)")
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

# [S-015] Temporal holdout validation: train 2010-2022, test 2023-2025.
# Fits DLNM on training period, predicts on held-out test period,
# and computes calibration metrics (RMSE, MAE, correlation, coverage).
#' Run temporal holdout validation
run_temporal_holdout_validation <- function(dat_macro) {
  log_msg("INFO", "Starting temporal holdout validation: 2010-2022 vs 2023-2025")

  train_start <- as.Date("2010-01-01")
  train_end <- as.Date("2022-12-31")
  test_start <- as.Date("2023-01-01")
  test_end <- as.Date("2025-12-31")

  dat_train <- dat_macro |> dplyr::filter(data >= train_start, data <= train_end)
  dat_test <- dat_macro |> dplyr::filter(data >= test_start, data <= test_end)

  log_msg("INFO", "Training period: ", nrow(dat_train), " rows (",
          train_start, " to ", train_end, ")")
  log_msg("INFO", "Test period: ", nrow(dat_test), " rows (",
          test_start, " to ", test_end, ")")

  outcomes <- c("internacoes_i60_i69", "obitos_i60_i69")
  exposures <- c("temp_med", "ur_med")

  all_metrics <- list()

  for (region in sort(unique(dat_macro$macro_regiao))) {
    d_train <- dplyr::filter(dat_train, macro_regiao == region)
    d_test <- dplyr::filter(dat_test, macro_regiao == region)

    if (nrow(d_train) < 365 || nrow(d_test) < 90) next

    for (outcome in outcomes) {
      for (exposure in exposures) {
        key <- paste(region, outcome, exposure, sep = "__")
        log_msg("INFO", "Holdout: ", key)

        obj <- safe_fetch({
          # Build crossbasis on FULL training data to get basis functions
          cb_train <- dlnm::crossbasis(
            d_train[[exposure]], lag = DLNM_FALLBACK$lag_max,
            argvar = list(fun = "ns", df = DLNM_FALLBACK$df_exp),
            arglag = list(fun = "ns",
              knots = dlnm::logknots(DLNM_FALLBACK$lag_max, df = DLNM_FALLBACK$df_lag))
          )

          # Fit model on training data
          complementary <- if (exposure == "temp_med") "ur_med" else "temp_med"
          covars <- paste0("splines::ns(tempo, df = ", 7 * length(unique(d_train$ano)),
            ") + dow + feriado + pandemia + splines::ns(", complementary, ", df = 3)")
          if (!is.null(d_train$influenza_lag7) && all(is.finite(d_train$influenza_lag7))) {
            covars <- paste0(covars, " + splines::ns(influenza_lag7, df = 2)")
          }
          if (!is.null(d_train$pm25_mensal) && any(is.finite(d_train$pm25_mensal))) {
            covars <- paste0(covars, " + pm25_mensal")
          }
          form <- stats::as.formula(
            paste(outcome, "~ cb_train +", covars, "+ offset(offset_log_populacao)"))

          m <- glm(form, family = quasipoisson(link = "log"),
                   data = d_train, na.action = na.exclude)

          # Predict on test data using crossbasis reconstructed with same basis
          cb_test <- dlnm::crossbasis(
            d_test[[exposure]], lag = DLNM_FALLBACK$lag_max,
            argvar = list(fun = "ns", df = DLNM_FALLBACK$df_exp),
            arglag = list(fun = "ns",
              knots = dlnm::logknots(DLNM_FALLBACK$lag_max, df = DLNM_FALLBACK$df_lag))
          )

          pred_counts <- predict(m, newdata = d_test, type = "response")
          obs_counts <- d_test[[outcome]]

          list(
            region = region, outcome = outcome, exposure = exposure,
            pred = pred_counts, obs = obs_counts,
            n_train = nrow(d_train), n_test = nrow(d_test)
          )
        }, paste("HOLDOUT", key), critical = FALSE)

        if (is.null(obj)) next

        # Compute metrics
        valid_idx <- !is.na(obj$pred) & !is.na(obj$obs) & is.finite(obj$pred) & is.finite(obj$obs)
        pred_v <- obj$pred[valid_idx]
        obs_v <- obj$obs[valid_idx]

        if (length(pred_v) < 30) next

        rmse <- sqrt(mean((pred_v - obs_v)^2))
        mae <- mean(abs(pred_v - obs_v))
        spearman_cor <- tryCatch(
          stats::cor(pred_v, obs_v, method = "spearman"),
          error = function(e) NA_real_
        )
        pearson_cor <- tryCatch(
          stats::cor(pred_v, obs_v, method = "pearson"),
          error = function(e) NA_real_
        )

        # Prediction interval coverage (approximate, Poisson-based)
        se_pred <- sqrt(pred_v)  # Poisson SE approximation
        ci_lower <- pmax(0, pred_v - 1.96 * se_pred)
        ci_upper <- pred_v + 1.96 * se_pred
        coverage_95 <- mean(obs_v >= ci_lower & obs_v <= ci_upper, na.rm = TRUE)

        # Relative metrics
        mean_obs <- mean(obs_v)
        cv_rmse <- if (mean_obs > 0) rmse / mean_obs else NA_real_

        all_metrics[[key]] <- tibble::tibble(
          macro_regiao = region,
          outcome = outcome,
          exposure = exposure,
          train_start = train_start,
          train_end = train_end,
          test_start = test_start,
          test_end = test_end,
          n_train_days = obj$n_train,
          n_test_days = obj$n_test,
          n_valid_pairs = length(pred_v),
          mean_obs = round(mean_obs, 4),
          mean_pred = round(mean(pred_v), 4),
          rmse = round(rmse, 4),
          mae = round(mae, 4),
          cv_rmse = round(cv_rmse, 4),
          spearman_cor = round(spearman_cor, 4),
          pearson_cor = round(pearson_cor, 4),
          coverage_95 = round(coverage_95, 4),
          total_obs_events = sum(obs_v),
          total_pred_events = round(sum(pred_v), 1)
        )
      }
    }
  }

  results <- dplyr::bind_rows(all_metrics)

  if (nrow(results) > 0) {
    # Add summary row
    summary <- tibble::tibble(
      macro_regiao = "RESUMO_GERAL",
      outcome = "TODOS",
      exposure = "TODAS",
      train_start = train_start, train_end = train_end,
      test_start = test_start, test_end = test_end,
      n_train_days = NA_integer_, n_test_days = NA_integer_,
      n_valid_pairs = sum(results$n_valid_pairs),
      mean_obs = NA_real_, mean_pred = NA_real_,
      rmse = round(mean(results$rmse, na.rm = TRUE), 4),
      mae = round(mean(results$mae, na.rm = TRUE), 4),
      cv_rmse = round(mean(results$cv_rmse, na.rm = TRUE), 4),
      spearman_cor = round(mean(results$spearman_cor, na.rm = TRUE), 4),
      pearson_cor = round(mean(results$pearson_cor, na.rm = TRUE), 4),
      coverage_95 = round(mean(results$coverage_95, na.rm = TRUE), 4),
      total_obs_events = sum(results$total_obs_events),
      total_pred_events = sum(results$total_pred_events)
    )
    results <- dplyr::bind_rows(results, summary)

    write_audit(results,
      file.path(PROJECT_ROOT, "audit", "validacao_temporal_holdout_2010_2022_vs_2023_2025.csv"))

    log_msg("INFO", "Temporal holdout complete: ",
            nrow(results) - 1, " model combinations tested")
    log_msg("INFO", "  Mean RMSE: ", round(summary$rmse, 3),
            ", Mean Spearman rho: ", round(summary$spearman_cor, 3),
            ", Mean coverage 95%: ", round(summary$coverage_95 * 100, 1), "%")
  } else {
    write_audit(
      tibble::tibble(
        macro_regiao = character(), outcome = character(), exposure = character(),
        rmse = numeric(), mae = numeric(), spearman_cor = numeric()
      ),
      file.path(PROJECT_ROOT, "audit", "validacao_temporal_holdout_2010_2022_vs_2023_2025.csv")
    )
    log_msg("WARN", "Temporal holdout: no models could be validated")
  }

  invisible(results)
}
