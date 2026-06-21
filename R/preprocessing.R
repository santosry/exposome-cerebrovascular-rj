# preprocessing.R — Data processing: SIH/SIM cleaning, INMET processing,
#                   population offset, analytic dataset assembly
# =============================================================================

#' Clean SIH-RD monthly file: extract dates, CID, municipality, outcomes
clean_sih_file <- function(path) {
  year <- stringr::str_extract(basename(path), "\\d{4}")
  df <- readRDS(path) |> janitor::clean_names()
  if (nrow(df) == 0) return(tibble::tibble())
  col_date  <- first_col(df, c("DT_INTER", "dt_inter"))
  col_cid   <- first_col(df, c("DIAG_PRINC", "diag_princ"))
  col_mun   <- first_col(df, c("MUNIC_RES", "MUN_RES", "munic_res", "mun_res"))
  col_morte <- first_col(df, c("MORTE", "morte"), required = FALSE)
  col_sexo  <- first_col(df, c("SEXO", "sexo"), required = FALSE)
  col_idade <- first_col(df, c("IDADE", "idade"), required = FALSE)

  out <- df |>
    dplyr::transmute(
      fonte = "SIH",
      data = parse_datasus_date(.data[[col_date]]),
      cid3 = clean_cid3(.data[[col_cid]]),
      ibge6 = stringr::str_pad(
        stringr::str_extract(as.character(.data[[col_mun]]), "\\d+"), 6, pad = "0"),
      obito_hospitalar = if (!is.na(col_morte))
        as.integer(as.character(.data[[col_morte]]) %in% c("1", "Sim", "sim"))
        else NA_integer_,
      sexo = if (!is.na(col_sexo)) as.character(.data[[col_sexo]]) else NA_character_,
      idade = if (!is.na(col_idade))
        suppressWarnings(as.numeric(as.character(.data[[col_idade]])))
        else NA_real_,
      ano_arquivo = as.integer(year)
    ) |>
    dplyr::filter(data >= DATE_START, data <= DATE_END,
                  cid3 %in% CID_CEREBRO,
                  stringr::str_starts(ibge6, "33"))
  out
}

#' Clean SIM-DO annual file
clean_sim_file <- function(path) {
  year <- stringr::str_extract(basename(path), "\\d{4}")
  df <- readRDS(path) |> janitor::clean_names()
  if (nrow(df) == 0) return(tibble::tibble())
  col_date <- first_col(df, c("DTOBITO", "dtobito", "DT_OBITO", "dt_obito"))
  col_cid  <- first_col(df, c("CAUSABAS", "causabas", "CAUSA_BAS", "causa_bas",
                               "LINHAA", "linhaa"))
  col_mun  <- first_col(df, c("CODMUNRES", "codmunres", "MUNRES", "munres",
                               "MUNIC_RES", "munic_res"))
  col_sexo <- first_col(df, c("SEXO", "sexo"), required = FALSE)
  col_idade <- first_col(df, c("IDADE", "idade"), required = FALSE)

  out <- df |>
    dplyr::transmute(
      fonte = "SIM",
      data = parse_datasus_date(.data[[col_date]]),
      cid3 = clean_cid3(.data[[col_cid]]),
      ibge6 = stringr::str_pad(
        stringr::str_extract(as.character(.data[[col_mun]]), "\\d+"), 6, pad = "0"),
      sexo = if (!is.na(col_sexo)) as.character(.data[[col_sexo]]) else NA_character_,
      idade = if (!is.na(col_idade))
        suppressWarnings(as.numeric(as.character(.data[[col_idade]])))
        else NA_real_,
      ano_arquivo = as.integer(year)
    ) |>
    dplyr::filter(data >= DATE_START, data <= DATE_END,
                  cid3 %in% CID_CEREBRO,
                  stringr::str_starts(ibge6, "33"))
  out
}

#' Process outcomes: build daily municipality-level count dataset
process_outcomes <- function() {
  lookup <- get_macro_lookup()
  sih_files <- list.files(file.path(PROJECT_ROOT, "data", "raw", "sih"),
                          "\\.rds$", full.names = TRUE)
  sim_files <- list.files(file.path(PROJECT_ROOT, "data", "raw", "sim"),
                          "^sim_do_rj_year_\\d{4}\\.rds$", full.names = TRUE)

  if (length(sih_files) == 0)
    stop("No SIH files found.", call. = FALSE)

  sih <- purrr::map_dfr(sih_files, clean_sih_file) |>
    dplyr::left_join(dplyr::select(lookup, ibge6, mun_nome, macro_regiao),
                     by = "ibge6")

  if (length(sim_files) == 0) {
    log_msg("WARN", "No SIM files found; using SIH hospital deaths as fallback")
    sim <- tibble::tibble(data = as.Date(character()),
                          cid3 = character(), ibge6 = character())
  } else {
    sim <- purrr::map_dfr(sim_files, clean_sim_file) |>
      dplyr::left_join(dplyr::select(lookup, ibge6, mun_nome, macro_regiao),
                       by = "ibge6")
  }

  write_audit(
    tibble::tibble(
      fonte = c("SIH", "SIM"),
      registros = c(nrow(sih), nrow(sim)),
      municipios = c(dplyr::n_distinct(sih$ibge6), dplyr::n_distinct(sim$ibge6))
    ),
    file.path(PROJECT_ROOT, "audit", "auditoria_desfechos_brutos.csv")
  )

  save_rds(sih, file.path(PROJECT_ROOT, "data", "interim",
                           "sih_cerebrovascular_individual.rds"))
  save_rds(sim, file.path(PROJECT_ROOT, "data", "interim",
                           "sim_cerebrovascular_individual.rds"))

  all_dates <- tibble::tibble(
    data = seq.Date(DATE_START, DATE_END, by = "day"))
  mun_grid <- lookup |> dplyr::select(ibge6, mun_nome, macro_regiao)

  # Primary outcomes
  sih_daily <- sih |>
    dplyr::count(data, ibge6, name = "internacoes_i60_i69") |>
    dplyr::right_join(tidyr::crossing(all_dates, mun_grid),
                      by = c("data", "ibge6")) |>
    dplyr::mutate(internacoes_i60_i69 =
                    tidyr::replace_na(internacoes_i60_i69, 0L))

  sih_sens <- sih |>
    dplyr::filter(cid3 %in% CID_SENS) |>
    dplyr::count(data, ibge6, name = "internacoes_i60_i64")

  sim_daily <- sim |>
    dplyr::count(data, ibge6, name = "obitos_i60_i69")

  sim_sens <- sim |>
    dplyr::filter(cid3 %in% CID_SENS) |>
    dplyr::count(data, ibge6, name = "obitos_i60_i64")

  sih_deaths_daily <- sih |>
    dplyr::filter(obito_hospitalar == 1) |>
    dplyr::count(data, ibge6, name = "obitos_sih_i60_i69")

  sih_deaths_sens <- sih |>
    dplyr::filter(obito_hospitalar == 1, cid3 %in% CID_SENS) |>
    dplyr::count(data, ibge6, name = "obitos_sih_i60_i64")

  # CID subtype counts
  sih_hemorr <- sih |> dplyr::filter(cid3 %in% CID_HEMORR) |>
    dplyr::count(data, ibge6, name = "internacoes_i60_i62")
  sim_hemorr <- sim |> dplyr::filter(cid3 %in% CID_HEMORR) |>
    dplyr::count(data, ibge6, name = "obitos_i60_i62")
  sih_isq <- sih |> dplyr::filter(cid3 == CID_ISQ) |>
    dplyr::count(data, ibge6, name = "internacoes_i63")
  sim_isq <- sim |> dplyr::filter(cid3 == CID_ISQ) |>
    dplyr::count(data, ibge6, name = "obitos_i63")

  # Influenza confounding
  sih_influenza <- sih |> dplyr::filter(cid3 %in% INFLUENZA_CIDS) |>
    dplyr::count(data, ibge6, name = "internacoes_influenza")
  sim_influenza <- sim |> dplyr::filter(cid3 %in% INFLUENZA_CIDS) |>
    dplyr::count(data, ibge6, name = "obitos_influenza")

  daily <- sih_daily |>
    dplyr::left_join(sih_sens, by = c("data", "ibge6")) |>
    dplyr::left_join(sim_daily, by = c("data", "ibge6")) |>
    dplyr::left_join(sim_sens, by = c("data", "ibge6")) |>
    dplyr::left_join(sih_deaths_daily, by = c("data", "ibge6")) |>
    dplyr::left_join(sih_deaths_sens, by = c("data", "ibge6")) |>
    dplyr::left_join(sih_hemorr, by = c("data", "ibge6")) |>
    dplyr::left_join(sim_hemorr, by = c("data", "ibge6")) |>
    dplyr::left_join(sih_isq, by = c("data", "ibge6")) |>
    dplyr::left_join(sim_isq, by = c("data", "ibge6")) |>
    dplyr::left_join(sih_influenza, by = c("data", "ibge6")) |>
    dplyr::left_join(sim_influenza, by = c("data", "ibge6")) |>
    dplyr::mutate(
      dplyr::across(c(internacoes_i60_i64, obitos_i60_i69, obitos_i60_i64,
                       obitos_sih_i60_i69, obitos_sih_i60_i64,
                       internacoes_i60_i62, obitos_i60_i62,
                       internacoes_i63, obitos_i63,
                       internacoes_influenza, obitos_influenza),
                    ~tidyr::replace_na(.x, 0L)),
      fonte_obitos = "SIM"
    )

  # Fallback: use SIH hospital deaths when SIM unavailable
  sim_audit_path <- file.path(PROJECT_ROOT, "audit", "auditoria_download_sim.csv")
  if (file.exists(sim_audit_path)) {
    sim_audit <- readr::read_csv(sim_audit_path, show_col_types = FALSE)
    anos_sim_ausentes <- sim_audit |>
      dplyr::filter(!status %in% c("baixado", "existente")) |>
      dplyr::pull(year)
  } else if (length(sim_files) == 0) {
    anos_sim_ausentes <- YEARS
  } else {
    anos_sim_ausentes <- setdiff(YEARS, unique(lubridate::year(sim$data)))
  }

  if (length(anos_sim_ausentes) > 0) {
    daily <- daily |>
      dplyr::mutate(
        obitos_i60_i69 = dplyr::if_else(
          lubridate::year(data) %in% anos_sim_ausentes,
          obitos_sih_i60_i69, obitos_i60_i69),
        obitos_i60_i64 = dplyr::if_else(
          lubridate::year(data) %in% anos_sim_ausentes,
          obitos_sih_i60_i64, obitos_i60_i64),
        fonte_obitos = dplyr::if_else(
          lubridate::year(data) %in% anos_sim_ausentes,
          "SIH_AIHS_MORTE", fonte_obitos)
      )
    write_audit(
      tibble::tibble(
        variavel = c("obitos_i60_i69", "obitos_i60_i64"),
        anos_substituidos = paste(anos_sim_ausentes, collapse = ", "),
        criterio = "MORTE == 1 in SIH-RD AIHs"
      ),
      file.path(PROJECT_ROOT, "audit", "auditoria_obitos_anos_ausentes.csv")
    )
  }

  save_rds(daily, file.path(PROJECT_ROOT, "data", "processed",
                             "desfechos_diarios_municipio.rds"))
  write_audit(
    daily |> dplyr::group_by(macro_regiao) |>
      dplyr::summarise(
        dias = dplyr::n_distinct(data),
        municipios = dplyr::n_distinct(ibge6),
        internacoes_i60_i69 = sum(internacoes_i60_i69, na.rm = TRUE),
        obitos_i60_i69 = sum(obitos_i60_i69, na.rm = TRUE),
        .groups = "drop"
      ),
    file.path(PROJECT_ROOT, "audit", "auditoria_desfechos_diarios.csv")
  )
  daily
}

#' Process INMET station data into macroregion daily climate series
process_inmet <- function() {
  files <- list.files(file.path(PROJECT_ROOT, "data", "raw", "inmet"),
                      "\\.rds$", full.names = TRUE)
  if (length(files) == 0)
    stop("No INMET files found.", call. = FALSE)

  dat <- purrr::map_dfr(files, \(x) standardize_inmet(readRDS(x)))
  station_map <- map_inmet_stations_to_macro()
  dat <- dat |> dplyr::left_join(station_map, by = "station_code")

  audit <- dat |>
    dplyr::summarise(
      linhas = dplyr::n(),
      dias = dplyr::n_distinct(data),
      estacoes = dplyr::n_distinct(station_code, na.rm = TRUE),
      temp_na = mean(is.na(temp_med)),
      ur_na = mean(is.na(ur_med)),
      temp_outliers = sum(flag_temp, na.rm = TRUE),
      ur_outliers = sum(flag_ur, na.rm = TRUE)
    )
  write_audit(audit, file.path(PROJECT_ROOT, "audit", "auditoria_inmet_qc.csv"))

  station_daily <- dat |>
    dplyr::filter(!is.na(macro_regiao)) |>
    dplyr::select(data, station_code, macro_regiao, latitude_degrees,
                  longitude_degrees, temp_med, temp_min, temp_max, ur_med)

  lookup_macro <- get_macro_lookup()
  macro_centroids <- get_macro_centroids_for_climate(station_map, lookup_macro)

  # Build macroregion daily means
  own_macro <- station_daily |>
    dplyr::group_by(data, macro_regiao) |>
    dplyr::summarise(
      temp_med = mean(temp_med, na.rm = TRUE),
      temp_min = mean(temp_min, na.rm = TRUE),
      temp_max = mean(temp_max, na.rm = TRUE),
      ur_med = mean(ur_med, na.rm = TRUE),
      n_estacoes = dplyr::n(),
      .groups = "drop"
    )

  climate_grid <- tidyr::crossing(
    data = seq.Date(DATE_START, DATE_END, by = "day"),
    macro_regiao = unique(lookup_macro$macro_regiao)
  )

  climate_macro <- climate_grid |>
    dplyr::left_join(own_macro, by = c("data", "macro_regiao")) |>
    dplyr::mutate(n_estacoes = tidyr::replace_na(n_estacoes, 0L))

  # Fill gaps with nearest macroregion
  climate_macro <- fill_missing_macro_climate(
    climate_macro, station_daily, macro_centroids)

  save_rds(station_daily,
    file.path(PROJECT_ROOT, "data", "interim", "inmet_diario_estacoes.rds"))
  save_rds(climate_macro,
    file.path(PROJECT_ROOT, "data", "processed", "inmet_diario_macrorregiao.rds"))
  write_audit(climate_macro,
    file.path(PROJECT_ROOT, "data", "processed", "inmet_diario_macrorregiao.csv"))

  audit_macro_climate(climate_macro, station_daily, station_map)
  climate_macro
}

# [F-005] Process PM2.5 air pollution data for confounding control.
# Data source: INEA/MonitorAr via Power BI dashboard, extracted to CSV.
# Granularity: ANNUAL by macroregion (not daily).
# Downscaling: national VIGIAR trend applied to municipal means.
# 2025 is extrapolated. These limitations are documented in the article.
#' Process PM2.5 pollution data
process_poluentes <- function() {
  pm25_path <- file.path(PROJECT_ROOT, "data", "processed", "pm25",
                         "mp25_rj_anual_2010_2025.csv")
  if (!file.exists(pm25_path)) {
    log_msg("WARN", "PM2.5 data not found at ", pm25_path,
            "; air quality control disabled.")
    return(tibble::tibble(macro_regiao = character(), ano = integer(),
                          pm25_anual = numeric()))
  }
  pm25_raw <- readr::read_delim(pm25_path, delim = ";",
                                show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::mutate(
      pm25 = as.numeric(pm25),
      ano = as.integer(ano)
    )

  pm25 <- pm25_raw |>
    dplyr::group_by(macroregiao, ano) |>
    dplyr::summarise(pm25_anual = mean(pm25, na.rm = TRUE), .groups = "drop") |>
    dplyr::rename(macro_regiao = macroregiao)

  write_audit(tibble::tibble(
    exposicao = "PM2.5",
    fonte = "INEA/MonitorAr-VIGIAR via Power BI",
    unidade_espacial_origem = "municipio",
    unidade_espacial_modelo = "macrorregiao",
    granularidade_temporal = "anual",
    n_municipios = dplyr::n_distinct(pm25_raw$municipio),
    n_macrorregioes = dplyr::n_distinct(pm25$macro_regiao),
    ano_min = min(pm25$ano, na.rm = TRUE),
    ano_max = max(pm25$ano, na.rm = TRUE),
    uso_no_dlnm = "covariavel linear anual; nao entra como cross-basis diario",
    limitacao = "granularidade temporal inferior a temperatura e umidade"
  ), file.path(PROJECT_ROOT, "audit", "air_quality",
               "auditoria_granularidade_pm25.csv"))

  log_msg("INFO", "PM2.5 loaded: ", nrow(pm25), " rows, ",
          sprintf("%.1f", mean(pm25$pm25_anual, na.rm = TRUE)),
          " ug/m3 mean")
  pm25
}

#' Build analytic dataset: merge outcomes, climate, and population offset
make_analytic_dataset <- function(outcomes, meteo, population = NULL) {
  if (is.null(population)) {
    population <- download_population_sidra()
  }

  pop_macro <- population |>
    dplyr::group_by(macro_regiao, ano) |>
    dplyr::summarise(populacao = sum(populacao, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(offset_log_populacao = log(populacao))

  # Aggregate outcomes to macroregion
  outcomes_macro <- outcomes |>
    dplyr::group_by(data, macro_regiao) |>
    dplyr::summarise(
      dplyr::across(dplyr::starts_with("internacoes_") |
                    dplyr::starts_with("obitos_"),
                    ~sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )

  dat <- outcomes_macro |>
    dplyr::left_join(
      meteo |> dplyr::select(data, macro_regiao,
                             temp_med, temp_min, temp_max, ur_med, n_estacoes),
      by = c("data", "macro_regiao")
    ) |>
    dplyr::mutate(
      ano = lubridate::year(data),
      mes = lubridate::month(data),
      dow = lubridate::wday(data, week_start = 1),
      feriado = FALSE,
      pandemia = data >= PANDEMIC_START & data <= PANDEMIC_END
    ) |>
    dplyr::left_join(pop_macro, by = c("macro_regiao", "ano")) |>
    dplyr::mutate(
      tempo = as.numeric(data - DATE_START) / 365.25,
      influenza_lag7 = dplyr::lag(internacoes_influenza, 7)
    )

  # [F-004] Brazilian holidays including movable dates (Carnival, Easter, Corpus Christi)
  holidays <- get_brazilian_holidays(YEARS)
  dat$feriado[dat$data %in% holidays] <- TRUE

  # [F-005] Join PM2.5 air pollution data (annual by macroregion) when enabled
  if (AIR_QUALITY_ENABLE) {
    pm25 <- process_poluentes()
    dat <- dat |> dplyr::left_join(pm25, by = c("macro_regiao", "ano"))
  } else {
    dat$pm25_anual <- NA_real_
  }

  save_rds(dat, file.path(PROJECT_ROOT, "data", "processed",
                           "dataset_dlnm_macrorregiao.rds"))
  audit_missing_values_final(list(
    clima_macrorregional = meteo,
    populacao_sidra = population,
    base_analitica_macrorregional = dat
  ))
  dat
}

#' Audit missing values in final datasets
audit_missing_values_final <- function(named_data) {
  audit_rows <- purrr::map_dfr(names(named_data), function(nm) {
    df <- named_data[[nm]]
    purrr::map_dfr(names(df), function(vn) {
      n_na <- sum(is.na(df[[vn]]))
      tibble::tibble(
        base = nm,
        variavel = vn,
        n_linhas = nrow(df),
        n_na = n_na,
        pct_na = round(100 * n_na / nrow(df), 2),
        metodo = "sem imputacao manual",
        justificativa = "auditoria de completude e impacto",
        impacto = if (n_na > 0) "verificar" else "sem NA"
      )
    })
  })
  write_audit(audit_rows, file.path(PROJECT_ROOT, "audit",
                                     "auditoria_na_variaveis.csv"))
  invisible(audit_rows)
}

#' Audit territorial integrity
audit_territorial_integrity_final <- function(dat_macro, meteo) {
  lookup <- get_macro_lookup()
  coverage <- meteo |>
    dplyr::group_by(macro_regiao) |>
    dplyr::summarise(
      dias = dplyr::n_distinct(data),
      anos = paste(sort(unique(lubridate::year(data))), collapse = ", "),
      municipios = dplyr::n_distinct(dat_macro$macro_regiao),
      n_estacoes_media = mean(n_estacoes, na.rm = TRUE),
      .groups = "drop"
    )
  write_audit(coverage, file.path(PROJECT_ROOT, "audit",
                                   "auditoria_cobertura_territorial_final.csv"))
  invisible(coverage)
}
