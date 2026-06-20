# tests/testthat/test_bayesian.R -- Bayesian model tests
# =============================================================================

test_that("bayes_normal_normal_group returns valid output", {
  set.seed(42)
  n_regions <- 9
  tbl <- data.frame(
    macro_regiao = paste0("Region_", 1:n_regions),
    outcome = rep("deaths", n_regions),
    exposure = rep("temp_med", n_regions),
    log_rr = log(1.2) + rnorm(n_regions, 0, 0.1),
    se_log_rr = rep(0.05, n_regions),
    stringsAsFactors = FALSE
  )

  result <- bayes_normal_normal_group(tbl, rr_threshold = 1.10)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), n_regions)
  expect_true(all(result$prob_rr_gt_threshold >= 0, na.rm = TRUE))
  expect_true(all(result$prob_rr_gt_threshold <= 1, na.rm = TRUE))
  expect_true(all(!is.na(result$posterior_mean)))
})

test_that("bayes_normal_normal_group handles 1 region", {
  tbl <- data.frame(
    macro_regiao = "Single",
    outcome = "deaths",
    exposure = "temp_med",
    log_rr = log(1.2),
    se_log_rr = 0.05,
    stringsAsFactors = FALSE
  )

  result <- bayes_normal_normal_group(tbl, rr_threshold = 1.10)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
})

test_that("bayes_normal_normal_group handles NAs", {
  tbl <- data.frame(
    macro_regiao = c("R1", "R2", "R3"),
    outcome = rep("deaths", 3),
    exposure = rep("temp_med", 3),
    log_rr = c(log(1.2), NA, log(1.1)),
    se_log_rr = c(0.05, 0.05, NA),
    stringsAsFactors = FALSE
  )

  result <- bayes_normal_normal_group(tbl, rr_threshold = 1.10)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
})

test_that("bayes_normal_normal_group produces shrinkage", {
  set.seed(42)
  n_regions <- 9
  log_rr_obs <- log(1.0) + c(rep(0.3, 3), rep(-0.2, 3), rep(0.1, 3)) + rnorm(9, 0, 0.05)
  tbl <- data.frame(
    macro_regiao = paste0("Region_", 1:n_regions),
    outcome = rep("deaths", n_regions),
    exposure = rep("temp_med", n_regions),
    log_rr = log_rr_obs,
    se_log_rr = rep(0.05, n_regions),
    stringsAsFactors = FALSE
  )

  result <- bayes_normal_normal_group(tbl, rr_threshold = 1.10)

  var_obs <- var(log_rr_obs)
  var_post <- var(result$posterior_mean, na.rm = TRUE)
  expect_lt(var_post, var_obs)
})
