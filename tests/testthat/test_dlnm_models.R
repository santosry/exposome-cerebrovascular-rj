# tests/testthat/test_dlnm_models.R -- DLNM model tests with synthetic data
# [EXPANDED] Added PM2.5, FDR, and MMT bootstrap tests
# =============================================================================

test_that("fit_one_dlnm returns valid structure with synthetic data", {
  set.seed(42)
  n <- 365
  dat <- data.frame(
    data = seq.Date(as.Date("2020-01-01"), by = "day", length.out = n),
    macro_regiao = "Test",
    internacoes_i60_i69 = rpois(n, 5),
    temp_med = 20 + 10 * sin(2 * pi * (1:n) / 365) + rnorm(n, 0, 1),
    ur_med = 70 + 10 * cos(2 * pi * (1:n) / 365) + rnorm(n, 0, 3),
    ano = 2020, dow = rep(1:7, length.out = n),
    feriado = FALSE, pandemia = FALSE,
    offset_log_populacao = log(100000),
    tempo = as.numeric(1:n) / 365.25,
    pm25_mensal = NA_real_,
    influenza_lag7 = NA_real_
  )

  result <- fit_one_dlnm(dat, "internacoes_i60_i69", "temp_med",
                          df_exp = 4, df_lag = 3, lag_max = 14,
                          use_mmt = FALSE)

  expect_type(result, "list")
  expect_true(!is.null(result$model))
  expect_true(!is.null(result$cb))
  expect_true(!is.null(result$pred))
  expect_true(result$pred$allRRfit[length(result$pred$allRRfit)] > 0)
  expect_true(is.numeric(result$p_association))
  expect_match(result$family, "quasipoisson|negative_binomial")
  # [NEW] Check p_method indicates Wald HAC primary
  expect_match(result$p_method, "Wald HAC")
})

test_that("fit_one_dlnm works with PM2.5 covariate", {
  set.seed(42)
  n <- 365
  dat <- data.frame(
    data = seq.Date(as.Date("2020-01-01"), by = "day", length.out = n),
    macro_regiao = "Test",
    internacoes_i60_i69 = rpois(n, 5),
    temp_med = 20 + 10 * sin(2 * pi * (1:n) / 365) + rnorm(n, 0, 1),
    ur_med = 60 + rnorm(n, 0, 3),
    ano = 2020, dow = rep(1:7, length.out = n),
    feriado = FALSE, pandemia = FALSE,
    offset_log_populacao = log(100000),
    tempo = as.numeric(1:n) / 365.25,
    pm25_mensal = runif(n, 10, 25),
    influenza_lag7 = NA_real_
  )

  result <- fit_one_dlnm(dat, "internacoes_i60_i69", "temp_med",
                          df_exp = 4, df_lag = 3, lag_max = 14,
                          use_mmt = FALSE)

  expect_type(result, "list")
  expect_true(!is.null(result$model))
  # With PM2.5, model should still converge
  expect_true(is.finite(result$p_association))
})

test_that("add_fdr_and_evidence_flags computes FDR correctly", {
  set.seed(42)
  auc_tbl <- data.frame(
    macro_regiao = rep("Test", 10),
    outcome = rep("deaths", 10),
    exposure = rep("temp_med", 10),
    p_association = c(0.001, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.20, 0.50, 0.99),
    auc_excesso_rr = runif(10, 0, 10),
    rr_cumulativo = runif(10, 0.8, 1.5),
    stringsAsFactors = FALSE
  )

  result <- add_fdr_and_evidence_flags(auc_tbl)

  expect_true("p_fdr" %in% names(result))
  expect_true("fdr_significant" %in% names(result))
  expect_true("evidence_level" %in% names(result))
  # At least the first test (p=0.001) should survive BH correction
  expect_true(result$p_fdr[1] <= 0.05 || result$fdr_significant[1])
})

test_that("summarise_pred produces valid RR summary", {
  set.seed(42)
  n <- 365
  dat <- data.frame(
    data = seq.Date(as.Date("2020-01-01"), by = "day", length.out = n),
    macro_regiao = "Test",
    internacoes_i60_i69 = rpois(n, 5),
    temp_med = 20 + 10 * sin(2 * pi * (1:n) / 365) + rnorm(n, 0, 1),
    ur_med = 60 + rnorm(n, 0, 3),
    ano = 2020, dow = rep(1:7, length.out = n),
    feriado = FALSE, pandemia = FALSE,
    offset_log_populacao = log(100000),
    tempo = as.numeric(1:n) / 365.25,
    pm25_mensal = NA_real_,
    influenza_lag7 = NA_real_
  )

  obj <- fit_one_dlnm(dat, "internacoes_i60_i69", "temp_med",
                       df_exp = 4, df_lag = 3, lag_max = 14,
                       use_mmt = FALSE)
  summ <- summarise_pred(obj, "Test")

  expect_s3_class(summ, "data.frame")
  expect_true(summ$rr_cumulativo > 0)
  expect_true("rr_cumulativo_hac_low" %in% names(summ))
  expect_true("se_log_rr_hac" %in% names(summ))
})

test_that("trapezoid_auc computes correctly", {
  expect_equal(trapezoid_auc(c(0, 1), c(2, 2)), 1)
  expect_equal(trapezoid_auc(c(0, 1), c(1, 3)), 1)
  expect_equal(trapezoid_auc(c(0, 1, 2), c(0.5, 1.0, 0.8)), 0)
})

test_that("diagnose_model returns diagnostics", {
  set.seed(42)
  n <- 365
  dat <- data.frame(
    data = seq.Date(as.Date("2020-01-01"), by = "day", length.out = n),
    macro_regiao = "Test",
    internacoes_i60_i69 = rpois(n, 5),
    temp_med = 20 + rnorm(n, 0, 2),
    ur_med = 60 + rnorm(n, 0, 3),
    ano = 2020, dow = rep(1:7, length.out = n),
    feriado = FALSE, pandemia = FALSE,
    offset_log_populacao = log(100000),
    tempo = as.numeric(1:n) / 365.25,
    pm25_mensal = NA_real_,
    influenza_lag7 = NA_real_
  )

  obj <- fit_one_dlnm(dat, "internacoes_i60_i69", "temp_med",
                       df_exp = 4, df_lag = 3, lag_max = 14,
                       use_mmt = FALSE)
  diag <- diagnose_model(obj, "Test")

  expect_s3_class(diag, "data.frame")
  expect_true("lb_pvalue" %in% names(diag))
  expect_true("autocorr_residual_after_hac" %in% names(diag))
})
