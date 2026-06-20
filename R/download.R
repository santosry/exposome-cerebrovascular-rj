# download.R — Data acquisition from DATASUS, INMET, IBGE/SIDRA, and geobr
# =============================================================================
# Downloads: SIH-RD hospital admissions, SIM-DO mortality records,
#            INMET weather station data, SIDRA population estimates,
#            and IBGE municipality geometries.

#' Download SIH-RD monthly files for Rio de Janeiro
download_microdatasus_monthly <- function(system, year, month, prefix, out_dir,
                                           max_tries = 4) {
  out <- file.path(out_dir, sprintf("%s_%04d_%02d.rds", prefix, year, month))
  if (file.exists(out)) {
    if (FORCE_RAW_DOWNLOAD) {
      log_msg("INFO", "FORCE_RAW_DOWNLOAD active; replacing: ", out)
      file.remove(out)
    } else {
      log_msg("INFO", "File exists, skipping: ", out)
      return(out)
    }
  }
  log_msg("INFO", "Downloading ", system, " RJ ", year, "-", sprintf("%02d", month))
  dat <- NULL; last_error <- NULL
  for (attempt in seq_len(max_tries)) {
    dat <- tryCatch(
      microdatasus::fetch_datasus(
        year_start = year, month_start = month,
        year_end = year, month_end = month,
        uf = UF_RJ, information_system = system,
        timeout = 240, track_source = TRUE
      ),
      error = function(e) {
        last_error <<- e
        log_msg("WARN", "Download failed ", system, " ", year, "-",
                sprintf("%02d", month), " attempt ", attempt, "/", max_tries)
        Sys.sleep(10 * attempt)
        NULL
      }
    )
    if (!is.null(dat)) break
  }
  if (is.null(dat)) {
    stop("Download failed after ", max_tries, " attempts for ", system, " ",
         year, "-", sprintf("%02d", month), call. = FALSE)
  }
  save_rds(dat, out)
  out
}

#' Download all SIH-RD files for the study period (192 monthly files)
download_sih <- function() {
  out_dir <- file.path(PROJECT_ROOT, "data", "raw", "sih")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  tidyr::expand_grid(year = YEARS, month = MONTHS) |>
    purrr::pwalk(\(year, month)
      download_microdatasus_monthly("SIH-RD", year, month, "sih_rd_rj", out_dir))
  invisible(TRUE)
}

#' Download SIM-DO annual files with audit trail
download_sim <- function() {
  out_dir <- file.path(PROJECT_ROOT, "data", "raw", "sim")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  audit <- tibble::tibble(
    year = YEARS, status = NA_character_,
    arquivo = NA_character_, observacao = NA_character_
  )
  for (year in YEARS) {
    out <- file.path(out_dir, sprintf("sim_do_rj_year_%04d.rds", year))
    if (file.exists(out)) {
      if (FORCE_RAW_DOWNLOAD) {
        file.remove(out)
      } else {
        audit$status[audit$year == year] <- "existente"
        audit$arquivo[audit$year == year] <- out
        next
      }
    }
    log_msg("INFO", "Downloading SIM-DO RJ ", year)
    dat <- NULL; last_error <- NULL
    for (attempt in 1:4) {
      dat <- tryCatch(
        microdatasus::fetch_datasus(
          year_start = year, year_end = year,
          uf = UF_RJ, information_system = "SIM-DO",
          timeout = 240, track_source = TRUE
        ),
        error = function(e) {
          last_error <<- e
          log_msg("WARN", "SIM-DO RJ ", year, " failed attempt ", attempt, "/4")
          Sys.sleep(10 * attempt)
          NULL
        }
      )
      if (!is.null(dat) && nrow(dat) > 0) break
    }
    if (is.null(dat) && !is.null(last_error)) {
      audit$status[audit$year == year] <- "indisponivel_ou_falha"
      audit$observacao[audit$year == year] <- conditionMessage(last_error)
    }
    if (!is.null(dat) && nrow(dat) > 0) {
      save_rds(dat, out)
      audit$status[audit$year == year] <- "baixado"
      audit$arquivo[audit$year == year] <- out
    } else if (is.na(audit$status[audit$year == year])) {
      audit$status[audit$year == year] <- "sem_linhas"
    }
  }
  write_audit(audit,
    file.path(PROJECT_ROOT, "audit", "auditoria_download_sim.csv"))
  if (!any(audit$status %in% c("baixado", "existente"))) {
    stop("No SIM-DO year was downloaded or found locally.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Get municipality list from IBGE API (cached)
get_municipios_rj <- function() {
  out <- file.path(PROJECT_ROOT, "data", "raw", "municipios_rj.csv")
  if (file.exists(out)) {
    return(readr::read_csv(out,
      col_types = readr::cols(.default = readr::col_character())) |>
      dplyr::mutate(mun_nome_norm = normalize_municipio_key(mun_nome)))
  }
  url <- "https://servicodados.ibge.gov.br/api/v1/localidades/estados/RJ/municipios"
  js <- safe_fetch(jsonlite::fromJSON(url), "Download IBGE municipality list")
  ibge7_chr <- stringr::str_pad(as.character(js$id), 7, pad = "0")
  municipios <- tibble::tibble(
    ibge7 = ibge7_chr,
    mun_nome = clean_text(js$nome),
    ibge6 = substr(ibge7_chr, 1, 6),
    mun_nome_norm = normalize_municipio_key(js$nome)
  )
  write_audit(municipios, out)
  municipios
}

#' Manual lookup: municipality → health macroregion (9 regions)
macro_lookup_manual <- function() {
  tibble::tribble(
    ~macro_regiao, ~mun_nome,
    "Metropolitana I", "Rio de Janeiro",
    "Metropolitana I", "Belford Roxo",
    "Metropolitana I", "Duque de Caxias",
    "Metropolitana I", "Itaguai",
    "Metropolitana I", "Japeri",
    "Metropolitana I", "Mage",
    "Metropolitana I", "Mesquita",
    "Metropolitana I", "Nilopolis",
    "Metropolitana I", "Nova Iguacu",
    "Metropolitana I", "Seropedica",
    "Metropolitana I", "Queimados",
    "Metropolitana I", "Sao Joao de Meriti",
    "Metropolitana II", "Niteroi",
    "Metropolitana II", "Sao Goncalo",
    "Metropolitana II", "Itaborai",
    "Metropolitana II", "Marica",
    "Metropolitana II", "Rio Bonito",
    "Metropolitana II", "Silva Jardim",
    "Metropolitana II", "Tangua",
    "Baia da Ilha Grande", "Angra dos Reis",
    "Baia da Ilha Grande", "Mangaratiba",
    "Baia da Ilha Grande", "Paraty",
    "Baixada Litoranea", "Araruama",
    "Baixada Litoranea", "Armacao dos Buzios",
    "Baixada Litoranea", "Arraial do Cabo",
    "Baixada Litoranea", "Cabo Frio",
    "Baixada Litoranea", "Casimiro de Abreu",
    "Baixada Litoranea", "Iguaba Grande",
    "Baixada Litoranea", "Rio das Ostras",
    "Baixada Litoranea", "Sao Pedro da Aldeia",
    "Baixada Litoranea", "Saquarema",
    "Centro-Sul", "Areal",
    "Centro-Sul", "Comendador Levy Gasparian",
    "Centro-Sul", "Engenheiro Paulo de Frontin",
    "Centro-Sul", "Mendes",
    "Centro-Sul", "Miguel Pereira",
    "Centro-Sul", "Paraiba do Sul",
    "Centro-Sul", "Paracambi",
    "Centro-Sul", "Paty do Alferes",
    "Centro-Sul", "Sapucaia",
    "Centro-Sul", "Tres Rios",
    "Centro-Sul", "Vassouras",
    "Medio Paraiba", "Barra do Pirai",
    "Medio Paraiba", "Barra Mansa",
    "Medio Paraiba", "Itatiaia",
    "Medio Paraiba", "Pinheiral",
    "Medio Paraiba", "Pirai",
    "Medio Paraiba", "Porto Real",
    "Medio Paraiba", "Quatis",
    "Medio Paraiba", "Resende",
    "Medio Paraiba", "Rio Claro",
    "Medio Paraiba", "Rio das Flores",
    "Medio Paraiba", "Valenca",
    "Medio Paraiba", "Volta Redonda",
    "Noroeste", "Aperibe",
    "Noroeste", "Bom Jesus do Itabapoana",
    "Noroeste", "Cambuci",
    "Noroeste", "Cardoso Moreira",
    "Noroeste", "Italva",
    "Noroeste", "Itaocara",
    "Noroeste", "Itaperuna",
    "Noroeste", "Laje do Muriae",
    "Noroeste", "Miracema",
    "Noroeste", "Natividade",
    "Noroeste", "Porciuncula",
    "Noroeste", "Santo Antonio de Padua",
    "Noroeste", "Sao Jose de Uba",
    "Noroeste", "Varre-Sai",
    "Norte", "Campos dos Goytacazes",
    "Norte", "Carapebus",
    "Norte", "Conceicao de Macabu",
    "Norte", "Macae",
    "Norte", "Quissama",
    "Norte", "Sao Fidelis",
    "Norte", "Sao Francisco de Itabapoana",
    "Norte", "Sao Joao da Barra",
    "Serrana", "Bom Jardim",
    "Serrana", "Cachoeiras de Macacu",
    "Serrana", "Cantagalo",
    "Serrana", "Carmo",
    "Serrana", "Cordeiro",
    "Serrana", "Duas Barras",
    "Serrana", "Guapimirim",
    "Serrana", "Macuco",
    "Serrana", "Nova Friburgo",
    "Serrana", "Petropolis",
    "Serrana", "Santa Maria Madalena",
    "Serrana", "Sao Jose do Vale do Rio Preto",
    "Serrana", "Sao Sebastiao do Alto",
    "Serrana", "Sumidouro",
    "Serrana", "Teresopolis",
    "Serrana", "Trajano de Moraes"
  ) |>
    dplyr::mutate(mun_nome_norm = normalize_municipio_key(mun_nome))
}

#' Build municipality → macroregion lookup table
get_macro_lookup <- function() {
  municipios <- get_municipios_rj()
  macro <- macro_lookup_manual()
  lookup <- municipios |>
    dplyr::left_join(macro, by = "mun_nome_norm") |>
    dplyr::mutate(
      mun_nome = dplyr::coalesce(.data$mun_nome.x, .data$mun_nome.y),
      macro_regiao = dplyr::if_else(is.na(.data$macro_regiao),
                                     "Sem macro validada", .data$macro_regiao)
    ) |>
    dplyr::select(ibge7, ibge6, mun_nome, mun_nome_norm, macro_regiao)
  audit <- lookup |>
    dplyr::summarise(
      municipios_rj = dplyr::n(),
      mapeados = sum(macro_regiao != "Sem macro validada"),
      nao_mapeados = sum(macro_regiao == "Sem macro validada")
    )
  write_audit(audit,
    file.path(PROJECT_ROOT, "audit", "auditoria_municipios_macrorregiao.csv"))
  write_audit(lookup,
    file.path(PROJECT_ROOT, "data", "processed", "lookup_municipio_macrorregiao.csv"))
  if (any(lookup$macro_regiao == "Sem macro validada")) {
    stop("Unmapped municipalities found.", call. = FALSE)
  }
  lookup
}

#' Download population estimates from SIDRA/IBGE
download_population_sidra <- function() {
  out_path <- file.path(PROJECT_ROOT, "data", "raw",
                        "populacao_sidra_municipio_rj_2010-2025.csv")
  if (file.exists(out_path) && !FORCE_RAW_DOWNLOAD) {
    log_msg("INFO", "SIDRA population data already cached")
    return(readr::read_csv(out_path, show_col_types = FALSE))
  }
  ensure_packages(c("sidrar"))
  lookup <- get_macro_lookup()
  pop_raw <- safe_fetch(
    sidrar::get_sidra(
      x = 6579,
      variable = 9324,
      period = as.character(YEARS),
      geo = "City",
      geo.filter = list(State = 33),
      classific = "c0"
    ),
    "SIDRA population download"
  )
  pop <- pop_raw |>
    janitor::clean_names() |>
    dplyr::transmute(
      ibge7 = stringr::str_pad(as.character(municipio_codigo), 7, pad = "0"),
      ibge6 = substr(ibge7, 1, 6),
      mun_nome = clean_text(municipio),
      ano = as.integer(ano),
      populacao = as.numeric(valor),
      fonte_populacao = "SIDRA 6579 v9324 - Populacao residente estimada",
      observacao_populacao = "estimativa_oficial_sidra"
    ) |>
    dplyr::filter(stringr::str_starts(ibge7, "33")) |>
    dplyr::left_join(dplyr::select(lookup, ibge6, macro_regiao), by = "ibge6")
  write_audit(pop, out_path)
  pop
}

#' Download all INMET station data for RJ
#' Tries BrazilMet API first; falls back to pre-downloaded zip files
#' if the INMET server is unavailable (common due to firewall/instability).
download_inmet <- function() {
  inmet_dir <- file.path(PROJECT_ROOT, "data", "raw", "inmet")
  zip_dir <- file.path(PROJECT_ROOT, "data", "raw", "inmet_zip")
  dir.create(inmet_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(zip_dir, recursive = TRUE, showWarnings = FALSE)
  stations_path <- file.path(PROJECT_ROOT, "data", "raw", "inmet_estacoes_rj.csv")

  if (!file.exists(stations_path) || FORCE_RAW_DOWNLOAD) {
    stations <- BrazilMet::see_stations_info() |>
      janitor::clean_names() |>
      dplyr::filter(uf == "RJ",
                    situation_operation %in% c("operating", "breakdown")) |>
      dplyr::mutate(station_code = as.character(station_code))
    write_audit(stations, stations_path)
  }
  stations <- readr::read_csv(stations_path, show_col_types = FALSE) |>
    janitor::clean_names()

  # Check if pre-downloaded zip files are available for fallback
  zip_files <- list.files(zip_dir, pattern = "^inmet_\\d{4}\\.zip$", full.names = TRUE)
  has_local_zips <- length(zip_files) > 0
  if (has_local_zips) {
    log_msg("INFO", "Found ", length(zip_files), " local INMET zip files for fallback")
  }

  server_available <- TRUE

  for (i in seq_len(nrow(stations))) {
    st <- stations[i, ]
    out_rds <- file.path(inmet_dir,
      sprintf("inmet_%s_%s.rds", st$station_code,
              janitor::make_clean_names(st$station_municipality)))
    if (file.exists(out_rds) && !FORCE_RAW_DOWNLOAD) next

    log_msg("INFO", "Processing INMET station ", st$station_code,
            " (", st$station_municipality, ")")
    yrs <- as.character(YEARS)

    # ── Method 1: BrazilMet API ──
    raw <- NULL
    if (server_available) {
      raw <- safe_fetch(
        BrazilMet::download_brazil_met(
          station_code = st$station_code,
          year = yrs,
          folder = zip_dir
        ),
        paste("INMET download", st$station_code),
        critical = FALSE
      )
    }

    # ── Method 2: Fallback to local zip files ──
    if (is.null(raw) && has_local_zips) {
      log_msg("WARN", "INMET API failed for ", st$station_code,
              " — falling back to local zip files")
      server_available <- FALSE
      raw <- tryCatch(
        extract_inmet_from_zips(st$station_code, yrs, zip_dir, inmet_dir),
        error = function(e) {
          log_msg("ERROR", "Zip fallback also failed for ", st$station_code, ": ",
                  conditionMessage(e))
          NULL
        }
      )
    }

    if (!is.null(raw)) {
      save_rds(raw, out_rds)
      log_msg("INFO", "INMET station ", st$station_code, " saved to ", basename(out_rds))
    } else {
      log_msg("ERROR", "Could not obtain INMET data for station ", st$station_code,
              " — both API and local zips failed")
    }
  }

  if (!server_available && has_local_zips) {
    log_msg("INFO", "INMET download completed using local zip fallback")
  }
  invisible(TRUE)
}

#' Extract INMET data for a specific station from pre-downloaded yearly zip files
#' Used as fallback when the INMET API is unavailable.
extract_inmet_from_zips <- function(station_code, years, zip_dir, inmet_dir) {
  all_data <- list()
  for (yr in years) {
    zip_path <- file.path(zip_dir, paste0("inmet_", yr, ".zip"))
    if (!file.exists(zip_path)) {
      log_msg("WARN", "Local zip not found for year ", yr, ": ", zip_path)
      next
    }
    # List files in zip matching this station
    zip_contents <- utils::unzip(zip_path, list = TRUE)
    station_files <- zip_contents$Name[
      grepl(station_code, zip_contents$Name, ignore.case = TRUE)
    ]
    if (length(station_files) == 0) {
      log_msg("INFO", "Station ", station_code, " not found in inmet_", yr, ".zip")
      next
    }
    # Extract to temp dir
    tmp_dir <- file.path(tempdir(), paste0("inmet_", station_code, "_", yr))
    dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip_path, files = station_files, exdir = tmp_dir)
    # Read extracted CSV
    for (f in station_files) {
      csv_path <- file.path(tmp_dir, f)
      if (file.exists(csv_path)) {
        dat <- tryCatch(
          BrazilMet::read_brazil_met(csv_path),
          error = function(e) {
            log_msg("WARN", "Failed to parse ", basename(csv_path), ": ",
                    conditionMessage(e))
            NULL
          }
        )
        if (!is.null(dat)) {
          all_data[[length(all_data) + 1]] <- dat
        }
      }
    }
    # Cleanup temp dir
    unlink(tmp_dir, recursive = TRUE)
  }
  if (length(all_data) == 0) {
    stop("No data extracted from local zips for station ", station_code, call. = FALSE)
  }
  dplyr::bind_rows(all_data)
}
