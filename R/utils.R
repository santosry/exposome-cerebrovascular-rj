# utils.R — Core utility functions for the DLNM cerebrovascular research compendium
# =============================================================================
# Provides: logging, safe evaluation, encoding checks, audit writing,
#           string cleaning, package management, numeric parsing.

#' Log a timestamped message to console and file
#' @param level Severity level (INFO, WARN, ERROR)
#' @param ... Message components (concatenated)
log_msg <- function(level = "INFO", ...) {
  txt <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " [", level, "] ",
                paste(..., collapse = ""))
  cat(txt, "\n")
  if (exists("LOG_FILE", envir = .GlobalEnv)) {
    cat(txt, "\n", file = LOG_FILE, append = TRUE)
  }
}

#' Detect invalid encoding patterns in a string
BAD_ENCODING_PATTERNS <- c(
  intToUtf8(c(0x00EF, 0x00BF, 0x00BD)),
  intToUtf8(c(0x00C3, 0x00A7)),
  intToUtf8(c(0x00C3, 0x00A3)),
  intToUtf8(c(0x00C3, 0x00B3)),
  intToUtf8(c(0x00C3, 0x00A1)),
  intToUtf8(c(0x00C3, 0x00AA)),
  intToUtf8(c(0x00C3, 0x00A9)),
  intToUtf8(c(0x00C3, 0x00AD)),
  intToUtf8(c(0x00C3, 0x00B5)),
  intToUtf8(c(0x00C3, 0x00BA))
)

has_bad_encoding <- function(x) {
  if (is.null(x)) return(FALSE)
  txt <- as.character(unlist(x, use.names = FALSE))
  txt <- txt[!is.na(txt)]
  if (length(txt) == 0) return(FALSE)
  any(vapply(BAD_ENCODING_PATTERNS, function(p) any(grepl(p, txt, fixed = TRUE)), logical(1)))
}

assert_no_bad_encoding_object <- function(x, context) {
  if (!has_bad_encoding(x)) return(invisible(TRUE))
  audit_path <- file.path(PROJECT_ROOT, "audit", "encoding_invalid_object.csv")
  dir.create(dirname(audit_path), recursive = TRUE, showWarnings = FALSE)
  txt <- as.character(unlist(x, use.names = TRUE))
  enc_mat <- vapply(BAD_ENCODING_PATTERNS, function(p) grepl(p, txt, fixed = TRUE), logical(length(txt)))
  if (is.vector(enc_mat)) {
    bad <- txt[enc_mat]
  } else {
    bad <- txt[rowSums(enc_mat) > 0]
  }
  readr::write_csv(tibble::tibble(contexto = context, valor = bad), audit_path, na = "")
  stop("Invalid encoding characters detected in: ", context, call. = FALSE)
}

#' Write a data frame as CSV to audit trail
write_audit <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  assert_no_bad_encoding_object(x, path)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

#' Save an R object as RDS
save_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(x, path)
  invisible(path)
}

#' Create a safe file token from a string
safe_file_token <- function(x) {
  janitor::make_clean_names(as.character(x))[1]
}

#' Record parsing failures for audit trail
record_parse_failures <- function(raw, parsed, context, max_examples = 50) {
  raw_chr <- trimws(as.character(raw))
  failed <- !is.na(raw_chr) & raw_chr != "" & is.na(parsed)
  if (!any(failed)) return(invisible(FALSE))
  audit <- tibble::tibble(
    contexto = context,
    valor_original = raw_chr[failed]
  ) |>
    dplyr::count(.data$contexto, .data$valor_original, name = "n") |>
    dplyr::arrange(dplyr::desc(.data$n)) |>
    dplyr::slice_head(n = max_examples)
  write_audit(audit, file.path(PROJECT_ROOT, "audit",
    paste0("falhas_parsing_", safe_file_token(context), ".csv")))
  log_msg("WARN", context, ": ", sum(failed), " values could not be parsed")
  invisible(TRUE)
}

#' Parse numeric values with locale-aware decimal handling
parse_numeric_audited <- function(x, context) {
  if (is.numeric(x)) return(as.numeric(x))
  raw <- trimws(as.character(x))
  out <- rep(NA_real_, length(raw))
  valid <- !is.na(raw) & raw != ""
  comma <- valid & stringr::str_detect(raw, ",")
  dot <- valid & !comma
  if (any(comma)) {
    out[comma] <- readr::parse_number(raw[comma],
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."))
  }
  if (any(dot)) {
    out[dot] <- readr::parse_number(raw[dot],
      locale = readr::locale(decimal_mark = ".", grouping_mark = ","))
  }
  record_parse_failures(raw, out, context)
  out
}

#' Check and install required packages
require_or_stop <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing packages: ", paste(missing, collapse = ", "),
         ". Install them before running the full pipeline.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Clean text: convert to UTF-8 and trim whitespace
clean_text <- function(x) {
  x <- as.character(x)
  x <- iconv(x, from = "", to = "UTF-8", sub = "")
  trimws(x)
}

#' Safely evaluate an expression with error handling
safe_fetch <- function(expr, context, critical = TRUE) {
  tryCatch(expr,
    error = function(e) {
      log_msg("ERROR", context, ": ", conditionMessage(e))
      if (critical) stop(e)
      NULL
    }
  )
}

#' Install packages from CRAN and Bioconductor if missing
ensure_packages <- function(cran = character(), bioc = character()) {
  installed <- rownames(installed.packages())
  missing_cran <- setdiff(cran, installed)
  if (length(missing_cran) > 0) {
    install.packages(missing_cran, dependencies = TRUE)
  }
  installed <- rownames(installed.packages())
  missing_bioc <- setdiff(bioc, installed)
  if (length(missing_bioc) > 0) {
    if (!requireNamespace("BiocManager", quietly = TRUE))
      install.packages("BiocManager")
    BiocManager::install(missing_bioc, ask = FALSE, update = FALSE)
  }
  invisible(TRUE)
}

#' Parse DATASUS date columns (try YMD then DMY)
parse_datasus_date <- function(x) {
  x <- as.character(x)
  out <- lubridate::ymd(x, quiet = TRUE)
  n_na_ymd <- sum(is.na(out) & !is.na(x))
  out[is.na(out)] <- lubridate::dmy(x[is.na(out)], quiet = TRUE)
  n_na_final <- sum(is.na(out) & !is.na(x))
  if (n_na_ymd > 0 || n_na_final > 0) {
    log_msg("WARN", "parse_datasus_date: ", n_na_ymd,
            " records re-parsed as DMY; ", n_na_final, " remained NA")
  }
  record_parse_failures(x, out, "datasus_datas")
  out
}

#' Clean CID-10 codes to 3-character format
clean_cid3 <- function(x) {
  n_input <- length(x)
  out <- x |>
    as.character() |>
    stringr::str_to_upper() |>
    stringr::str_replace_all("[^A-Z0-9]", "") |>
    stringr::str_sub(1, 3)
  n_na_output <- sum(is.na(out) | out == "")
  if (n_na_output > 0) {
    log_msg("WARN", "clean_cid3: ", n_na_output, " of ", n_input,
            " records produced empty CID")
  }
  out
}

#' Normalize municipality name for matching
normalize_municipio_key <- function(x) {
  x |>
    clean_text() |>
    stringi::stri_trans_general("Latin-ASCII") |>
    stringr::str_to_upper() |>
    stringr::str_replace_all("[^A-Z0-9 ]", " ") |>
    stringr::str_squish()
}

#' Find the first matching column name from candidates
first_col <- function(df, candidates, required = TRUE) {
  nms <- names(df)
  hit <- intersect(janitor::make_clean_names(candidates), nms)
  if (length(hit) == 0 && required)
    stop("Missing column: ", paste(candidates, collapse = "/"), call. = FALSE)
  if (length(hit) == 0) return(NA_character_)
  hit[1]
}

#' Haversine distance in km between two points on Earth
haversine_km <- function(lon1, lat1, lon2, lat2) {
  r <- 6371.0088
  rad <- pi / 180
  lon1 <- lon1 * rad; lat1 <- lat1 * rad
  lon2 <- lon2 * rad; lat2 <- lat2 * rad
  dlon <- lon2 - lon1; dlat <- lat2 - lat1
  a <- sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
  2 * r * asin(pmin(1, sqrt(a)))
}
