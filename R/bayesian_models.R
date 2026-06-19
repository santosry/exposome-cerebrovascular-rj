# bayesian_models.R — Hierarchical Bayesian stabilization and prior sensitivity
# =============================================================================
# Normal-normal hierarchical model for cumulative log(RR) estimates.
# Provides posterior probabilities, credible intervals, and prior sensitivity.

#' Normal-normal hierarchical Bayesian group model
#'
#' @param tbl data.frame with columns: macro_regiao, outcome, exposure,
#'            log_rr (point estimate), se_log_rr (standard error)
#' @param rr_threshold threshold for posterior probability (default 1.10)
#' @return data.frame with posterior summaries
bayes_normal_normal_group <- function(tbl, rr_threshold = 1.10) {
  required_cols <- c("macro_regiao", "outcome", "exposure", "log_rr", "se_log_rr")
  missing_cols <- setdiff(required_cols, names(tbl))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  purrr::map_dfr(
    dplyr::group_split(tbl, outcome, exposure),
    function(group) {
      y <- group$log_rr
      sigma <- group$se_log_rr

      # Remove non-finite values
      valid <- is.finite(y) & is.finite(sigma) & sigma > 0
      if (sum(valid) < 2) {
        group$posterior_mean <- y
        group$posterior_sd <- sigma
        group$prob_rr_gt_threshold <- ifelse(
          is.finite(y) & is.finite(sigma) & sigma > 0,
          stats::pnorm(y - log(rr_threshold), sd = sigma, lower.tail = FALSE),
          NA_real_
        )
        group$ci95_lower <- y - 1.96 * sigma
        group$ci95_upper <- y + 1.96 * sigma
        group$tau_hat <- NA_real_
        group$mu_hat <- NA_real_
        return(group)
      }

      y_v <- y[valid]
      sigma_v <- sigma[valid]
      n <- length(y_v)
      k <- length(y)

      # Grid-based empirical Bayes estimation of mu (group mean) and tau (heterogeneity)
      mu_grid <- seq(min(y_v) - 2 * max(sigma_v),
                     max(y_v) + 2 * max(sigma_v), length.out = 200)
      tau_grid <- seq(0.001, max(sigma_v) * 2, length.out = 200)

      best_mu <- mean(y_v); best_tau <- 0.1; best_loglik <- -Inf
      for (mu in mu_grid) {
        for (tau in tau_grid) {
          var_total <- sigma_v^2 + tau^2
          loglik <- sum(stats::dnorm(y_v, mean = mu, sd = sqrt(var_total), log = TRUE))
          if (loglik > best_loglik) {
            best_loglik <- loglik; best_mu <- mu; best_tau <- tau
          }
        }
      }

      # Posterior for each region (shrinkage)
      group$mu_hat <- best_mu
      group$tau_hat <- best_tau
      group$posterior_mean <- rep(NA_real_, k)
      group$posterior_sd <- rep(NA_real_, k)
      group$prob_rr_gt_threshold <- rep(NA_real_, k)
      group$ci95_lower <- rep(NA_real_, k)
      group$ci95_upper <- rep(NA_real_, k)

      for (i in seq_len(k)) {
        if (valid[i]) {
          prec_lik <- 1 / sigma[i]^2
          prec_prior <- 1 / best_tau^2
          post_var <- 1 / (prec_lik + prec_prior)
          post_mean <- post_var * (prec_lik * y[i] + prec_prior * best_mu)
          group$posterior_mean[i] <- post_mean
          group$posterior_sd[i] <- sqrt(post_var)
          group$prob_rr_gt_threshold[i] <- stats::pnorm(
            post_mean - log(rr_threshold), sd = sqrt(post_var), lower.tail = FALSE)
          group$ci95_lower[i] <- post_mean - 1.96 * sqrt(post_var)
          group$ci95_upper[i] <- post_mean + 1.96 * sqrt(post_var)
        } else {
          group$posterior_mean[i] <- best_mu
          group$posterior_sd[i] <- best_tau
          group$prob_rr_gt_threshold[i] <- stats::pnorm(
            best_mu - log(rr_threshold), sd = best_tau, lower.tail = FALSE)
          group$ci95_lower[i] <- best_mu - 1.96 * best_tau
          group$ci95_upper[i] <- best_mu + 1.96 * best_tau
        }
      }
      group
    }
  )
}

#' Run full Bayesian hierarchical validation pipeline
run_bayesian_hierarchical_validation <- function(rr_tbl, auc_tbl,
                                                  residual_tbl = NULL,
                                                  rr_threshold = 1.10) {
  log_msg("INFO", "Starting Bayesian hierarchical validation")

  # Prepare input: compute log(RR) and approximate SE from CI
  bayes_input <- rr_tbl |>
    dplyr::mutate(
      log_rr = log(rr_cumulativo),
      # Approximate SE from 95% CI width
      se_log_rr = (log(rr_cumulativo_high) - log(rr_cumulativo_low)) / (2 * 1.96)
    ) |>
    dplyr::filter(is.finite(log_rr), is.finite(se_log_rr), se_log_rr > 0)

  # Run hierarchical model
  bayes_results <- bayes_normal_normal_group(bayes_input, rr_threshold)

  # Merge with AUC and diagnostic info
  if (!is.null(auc_tbl)) {
    bayes_results <- bayes_results |>
      dplyr::left_join(
        auc_tbl |> dplyr::select(macro_regiao, outcome, exposure,
                                  auc_excesso_rr, p_fdr, fdr_significant),
        by = c("macro_regiao", "outcome", "exposure")
      )
  }

  # Write outputs
  write_audit(bayes_results,
    file.path(PROJECT_ROOT, "outputs", "tables",
              "ranking_modelos_rr_ic95_auc_residuos_bayes.csv"))

  # Run prior sensitivity
  prior_sens <- run_prior_sensitivity(rr_tbl, auc_tbl, residual_tbl)

  log_msg("INFO", "Bayesian validation complete: ", nrow(bayes_results), " rows")
  invisible(bayes_results)
}

#' Run prior sensitivity analysis with sceptical, optimistic, and flat priors
run_prior_sensitivity <- function(rr_tbl, auc_tbl, residual_tbl = NULL) {
  bayes_input <- rr_tbl |>
    dplyr::mutate(
      log_rr = log(rr_cumulativo),
      se_log_rr = (log(rr_cumulativo_high) - log(rr_cumulativo_low)) / (2 * 1.96)
    ) |>
    dplyr::filter(is.finite(log_rr), is.finite(se_log_rr), se_log_rr > 0)

  all_priors <- list()
  for (prior_name in names(PRIOR_SENS_GRID)) {
    prior <- PRIOR_SENS_GRID[[prior_name]]
    prior_results <- bayes_with_prior(bayes_input, prior)
    prior_results$prior_label <- prior_name
    all_priors[[prior_name]] <- prior_results
  }

  prior_tbl <- dplyr::bind_rows(all_priors)
  write_audit(prior_tbl,
    file.path(PROJECT_ROOT, "outputs", "tables",
              "sensibilidade_priors_bayesianos.csv"))
  invisible(prior_tbl)
}

#' Bayesian model with explicit prior specification
bayes_with_prior <- function(tbl, prior, rr_threshold = 1.10) {
  purrr::map_dfr(
    dplyr::group_split(tbl, outcome, exposure),
    function(group) {
      y <- group$log_rr; sigma <- group$se_log_rr
      valid <- is.finite(y) & is.finite(sigma) & sigma > 0
      k <- length(y)

      group$posterior_mean <- rep(NA_real_, k)
      group$posterior_sd <- rep(NA_real_, k)
      group$prob_rr_gt_threshold <- rep(NA_real_, k)

      for (i in seq_len(k)) {
        if (valid[i]) {
          prec_lik <- 1 / sigma[i]^2
          prec_prior <- 1 / prior$mu_sd^2
          post_var <- 1 / (prec_lik + prec_prior)
          post_mean <- post_var * (prec_lik * y[i] + prec_prior * prior$mu_mean)
          group$posterior_mean[i] <- post_mean
          group$posterior_sd[i] <- sqrt(post_var)
          group$prob_rr_gt_threshold[i] <- stats::pnorm(
            post_mean - log(rr_threshold), sd = sqrt(post_var), lower.tail = FALSE)
        } else {
          group$posterior_mean[i] <- prior$mu_mean
          group$posterior_sd[i] <- prior$mu_sd
          group$prob_rr_gt_threshold[i] <- stats::pnorm(
            prior$mu_mean - log(rr_threshold), sd = prior$mu_sd, lower.tail = FALSE)
        }
      }
      group
    }
  )
}
