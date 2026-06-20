# tests/testthat/test_utils.R -- Unit tests for utility functions
# =============================================================================

test_that("clean_text handles basic cases", {
  expect_equal(clean_text("  Rio de Janeiro  "), "Rio de Janeiro")
  expect_equal(clean_text("Sao Paulo"), "Sao Paulo")
  expect_equal(clean_text(NA_character_), NA_character_)
})

test_that("normalize_municipio_key produces consistent output", {
  expect_equal(
    normalize_municipio_key("Rio de Janeiro"),
    "RIO DE JANEIRO"
  )
  expect_equal(
    normalize_municipio_key("Angra dos Reis"),
    "ANGRA DOS REIS"
  )
})

test_that("clean_cid3 formats ICD codes correctly", {
  expect_equal(clean_cid3("I609"), "I60")
  expect_equal(clean_cid3("i61.0"), "I61")
  expect_equal(clean_cid3("I 63"), "I63")
  expect_equal(clean_cid3(NA_character_), NA_character_)
})

test_that("haversine_km computes correct distances", {
  d <- haversine_km(-43.20, -22.91, -46.63, -23.55)
  expect_gt(d, 300)
  expect_lt(d, 450)
  expect_equal(haversine_km(-44.30, -22.98, -44.30, -22.98), 0)
})

test_that("trapezoid_auc computes correctly", {
  expect_equal(trapezoid_auc(c(0, 1), c(2, 2)), 1)
  expect_equal(trapezoid_auc(c(0, 1), c(1, 3)), 1)
  expect_equal(trapezoid_auc(c(0, 1, 2), c(0.5, 1.0, 0.8)), 0)
})

test_that("first_col finds matching columns", {
  df <- data.frame(DT_INTER = 1, dt_inter = 2, DIAG_PRINC = 3)
  expect_equal(first_col(df, c("dt_inter", "data")), "dt_inter")
  expect_equal(first_col(df, c("DIAG_PRINC", "diag_princ")), "DIAG_PRINC")
  expect_error(first_col(df, c("nonexistent"), required = TRUE))
  expect_equal(first_col(df, c("nonexistent"), required = FALSE), NA_character_)
})

test_that("safe_fetch handles errors gracefully", {
  expect_null(safe_fetch(stop("test error"), "test_context", critical = FALSE))
  expect_error(safe_fetch(stop("test error"), "test_context", critical = TRUE))
  expect_equal(safe_fetch(42, "returns_42"), 42)
})

test_that("parse_numeric_audited handles basic cases", {
  expect_equal(parse_numeric_audited(c(1, 2, 3), "test"), c(1, 2, 3))
  expect_true(is.na(parse_numeric_audited("N/A", "test")[1]))
})
