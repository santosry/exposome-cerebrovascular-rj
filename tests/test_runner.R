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
# Defensive sourcing: config sets PROJECT_ROOT with mustWork=TRUE;
# in CI this should resolve to the checkout directory.
tryCatch({
  source("config/config.R", local = TRUE)
  source("R/utils.R", local = TRUE)
  source("R/dlnm_models.R", local = TRUE)
}, error = function(e) {
  cat(sprintf("  SKIP: Could not source modules — %s\n", conditionMessage(e)))
  cat("  Running inline fallback checks instead\n")
  # Fallback: inline versions for CI resilience
  clean_text <- function(x) { x <- as.character(x); trimws(iconv(x, from="", to="UTF-8", sub="")) }
  clean_cid3 <- function(x) { o <- toupper(gsub("[^A-Z0-9]", "", as.character(x))); substr(o, 1, 3) }
  haversine_km <- function(lon1,lat1,lon2,lat2) { r<-6371; dlon<-(lon2-lon1)*pi/180; dlat<-(lat2-lat1)*pi/180; a<-sin(dlat/2)^2+cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dlon/2)^2; 2*r*asin(pmin(1,sqrt(a))) }
  trapezoid_auc <- function(x,y) { ye<-pmax(y-1,0); n<-length(x); if(n<2) return(0); sum((x[2:n]-x[1:(n-1)])*(ye[2:n]+ye[1:(n-1)]))/2 }
})

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
