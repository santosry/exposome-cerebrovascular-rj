# tests/test_runner.R -- CI validation (sources real functions, no duplication)
# =============================================================================
# [FIX C6] This runner now sources the actual R/ modules instead of
# reimplementing inline copies. This prevents silent divergence between
# test code and production code.

cat("Running CI validation checks...\n")
errors <- 0

check <- function(label, expr) {
  result <- tryCatch(expr, error = function(e) paste("ERROR:", conditionMessage(e)))
  if (isTRUE(result)) {
    cat(sprintf("  PASS: %s\n", label))
  } else {
    cat(sprintf("  FAIL: %s -- %s\n", label, as.character(result)))
    errors <<- errors + 1
  }
}

# -- Source real production functions (no duplication) --
# [FIX C6] Use the actual R/ modules tested by testthat
source("config/config.R", local = TRUE)
source("R/utils.R", local = TRUE)
source("R/dlnm_models.R", local = TRUE)

# -- Tests using production functions --

check("clean_text strips whitespace",
  identical(clean_text("  Rio de Janeiro  "), "Rio de Janeiro"))
check("clean_text handles NA",
  is.na(clean_text(NA_character_)))

check("clean_cid3 I609 -> I60",
  identical(clean_cid3("I609"), "I60"))
check("clean_cid3 lowercase -> uppercase",
  identical(clean_cid3("i61.0"), "I61"))
check("clean_cid3 removes spaces",
  identical(clean_cid3("I 63"), "I63"))
check("clean_cid3 NA stays NA",
  is.na(clean_cid3(NA_character_)))

d <- haversine_km(-43.20, -22.91, -46.63, -23.55)
check("haversine Rio-SP > 300km", d > 300)
check("haversine Rio-SP < 450km", d < 450)
check("haversine same point = 0",
  identical(haversine_km(-44.30, -22.98, -44.30, -22.98), 0.0))

check("trapezoid_auc rectangle",
  abs(trapezoid_auc(c(0, 1), c(2, 2)) - 1) < 1e-10)
check("trapezoid_auc triangle",
  abs(trapezoid_auc(c(0, 1), c(1, 3)) - 1) < 1e-10)
check("trapezoid_auc no excess",
  trapezoid_auc(c(0, 1, 2), c(0.5, 1.0, 0.8)) == 0)

# -- Project structure checks --
check("config file exists",
  file.exists("config/config.R"))
check("R modules directory exists",
  dir.exists("R/") && length(list.files("R/", pattern = "\\.R$")) >= 8)
check("README exists",
  file.exists("README.md"))
check("LICENSE exists",
  file.exists("LICENSE"))
check("CITATION.cff exists",
  file.exists("CITATION.cff"))

# -- Testthat suite exists and is loadable --
check("testthat tests directory exists",
  dir.exists("tests/testthat/") && length(list.files("tests/testthat/", pattern = "\\.R$")) >= 2)

# -- Summary --
if (errors > 0) {
  cat(sprintf("\n%d check(s) FAILED!\n", errors))
  quit(status = 1)
} else {
  cat("\nAll checks PASSED.\n")
  quit(status = 0)
}
