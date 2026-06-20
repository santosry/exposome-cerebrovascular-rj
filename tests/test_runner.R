# tests/test_runner.R -- Simple validation script (no testthat dependency)
# =============================================================================
# This script validates core utility functions.
# Exits with code 1 if any check fails.

cat("Running validation checks...\n")
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

eq <- function(a, b) identical(a, b)

# -- clean_text --
check("clean_text strips whitespace",
  eq(clean_text("  Rio de Janeiro  "), "Rio de Janeiro"))
check("clean_text handles NA",
  is.na(clean_text(NA_character_)))

# -- clean_cid3 --
check("clean_cid3 I609 -> I60",
  eq(clean_cid3("I609"), "I60"))
check("clean_cid3 i61.0 -> I61",
  eq(clean_cid3("i61.0"), "I61"))
check("clean_cid3 removes spaces",
  eq(clean_cid3("I 63"), "I63"))
check("clean_cid3 NA stays NA",
  is.na(clean_cid3(NA_character_)))

# -- haversine_km --
d <- haversine_km(-43.20, -22.91, -46.63, -23.55)
check("haversine Rio-SP distance > 300km", d > 300)
check("haversine Rio-SP distance < 450km", d < 450)
check("haversine same point = 0",
  eq(haversine_km(-44.30, -22.98, -44.30, -22.98), 0))

# -- trapezoid_auc --
check("trapezoid_auc rectangle",
  eq(trapezoid_auc(c(0, 1), c(2, 2)), 1))
check("trapezoid_auc triangle",
  eq(trapezoid_auc(c(0, 1), c(1, 3)), 1))
check("trapezoid_auc no excess",
  eq(trapezoid_auc(c(0, 1, 2), c(0.5, 1.0, 0.8)), 0))

# -- safe_fetch --
check("safe_fetch returns NULL on error (non-critical)",
  is.null(safe_fetch(stop("boom"), "test", critical = FALSE)))
check("safe_fetch errors on critical failure", {
  tryCatch({ safe_fetch(stop("boom"), "test", critical = TRUE); FALSE },
           error = function(e) TRUE)
})
check("safe_fetch returns value on success",
  eq(safe_fetch(42, "test"), 42))

# -- Summary --
if (errors > 0) {
  cat(sprintf("\n%d check(s) FAILED!\n", errors))
  quit(status = 1)
} else {
  cat("\nAll checks PASSED.\n")
  quit(status = 0)
}
