# tests/test_runner.R -- Self-contained validation (zero dependencies)
# =============================================================================

cat("Running self-contained validation checks...\n")
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

# -- Inline function definitions (no external source needed) --

clean_text <- function(x) {
  x <- as.character(x)
  x <- iconv(x, from = "", to = "UTF-8", sub = "")
  trimws(x)
}

clean_cid3 <- function(x) {
  out <- as.character(x)
  out <- toupper(out)
  out <- gsub("[^A-Z0-9]", "", out)
  out <- substr(out, 1, 3)
  out[is.na(x)] <- NA_character_
  out
}

haversine_km <- function(lon1, lat1, lon2, lat2) {
  r <- 6371.0088
  rad <- pi / 180
  lon1 <- lon1 * rad; lat1 <- lat1 * rad
  lon2 <- lon2 * rad; lat2 <- lat2 * rad
  dlon <- lon2 - lon1; dlat <- lat2 - lat1
  a <- sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
  2 * r * asin(pmin(1, sqrt(a)))
}

trapezoid_auc <- function(x, y) {
  y_excess <- pmax(y - 1, 0)
  n <- length(x)
  if (n < 2) return(0)
  sum((x[2:n] - x[1:(n - 1)]) * (y_excess[2:n] + y_excess[1:(n - 1)])) / 2
}

# -- Tests --

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

# -- Summary --
if (errors > 0) {
  cat(sprintf("\n%d check(s) FAILED!\n", errors))
  quit(status = 1)
} else {
  cat("\nAll checks PASSED.\n")
  quit(status = 0)
}
