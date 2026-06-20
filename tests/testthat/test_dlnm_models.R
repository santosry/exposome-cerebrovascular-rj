# tests/testthat/test_dlnm_models.R -- DLNM model tests with synthetic data
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
    pm25_anual = NA_real_,
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
    pm25_anual = NA_real_,
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
    pm25_anual = NA_real_,
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
