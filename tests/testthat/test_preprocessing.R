# tests/testthat/test_preprocessing.R -- Preprocessing tests
# =============================================================================

test_that("clean_cid3 handles valid and invalid codes", {
  expect_equal(clean_cid3("I609"), "I60")
  expect_equal(clean_cid3("i61.0"), "I61")
  expect_equal(clean_cid3("I 63"), "I63")
  expect_equal(clean_cid3("J449"), "J44")
  expect_equal(clean_cid3(NA_character_), NA_character_)
  expect_equal(clean_cid3(""), "")
})

test_that("normalize_municipio_key removes accents", {
  expect_match(normalize_municipio_key("Sao Paulo"), "SAO PAULO")
  expect_match(normalize_municipio_key("Rio de Janeiro"), "RIO DE JANEIRO")
})

test_that("parse_datasus_date handles YMD and DMY formats", {
  expect_equal(parse_datasus_date("2020-01-15"), as.Date("2020-01-15"))
  expect_equal(parse_datasus_date("15/01/2020"), as.Date("2020-01-15"))
  expect_true(is.na(parse_datasus_date("invalid")))
})

test_that("clean_text removes whitespace", {
  expect_equal(clean_text("  hello  "), "hello")
  expect_equal(clean_text("test\n"), "test")
})

test_that("process_poluentes returns expected columns", {
  result <- process_poluentes()
  expect_s3_class(result, "data.frame")
  if (nrow(result) > 0) {
    expect_true("macro_regiao" %in% names(result))
    expect_true("ano" %in% names(result))
    expect_true("mes" %in% names(result))
    expect_true("pm25_mensal" %in% names(result))
  }
})

test_that("get_brazilian_holidays returns valid dates", {
  holidays <- get_brazilian_holidays(c(2020, 2021))
  expect_type(holidays, "double")
  expect_s3_class(holidays, "Date")
  expect_true(length(holidays) > 20)
  expect_true(as.Date("2020-01-01") %in% holidays)
  expect_true(as.Date("2020-12-25") %in% holidays)
})
