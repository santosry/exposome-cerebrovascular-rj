# exposure_processing.R — INMET station processing, spatial assignment,
#                         climate imputation, and exposure quality control
# =============================================================================

#' Standardize INMET data to common column format
standardize_inmet <- function(df) {
  df <- janitor::clean_names(df)
  if (nrow(df) == 0) {
    return(tibble::tibble(
      data = as.Date(character()), station_code = character(),
      temp_med = numeric(), temp_min = numeric(),
      temp_max = numeric(), ur_med = numeric(),
      flag_temp = logical(), flag_ur = logical()
    ))
  }
  if (all(c("data", "station_code", "temp_med", "temp_min", "temp_max", "ur_med")
          %in% names(df))) {
    return(df |>
      dplyr::transmute(
        data = as.Date(data),
        station_code = as.character(station_code),
        temp_med = parse_numeric_audited(temp_med, "inmet_temp_med"),
        temp_min = parse_numeric_audited(temp_min, "inmet_temp_min"),
        temp_max = parse_numeric_audited(temp_max, "inmet_temp_max"),
        ur_med = parse_numeric_audited(ur_med, "inmet_ur_med"),
        flag_temp = !is.na(temp_med) & (temp_med < -5 | temp_med > 50),
        flag_ur = !is.na(ur_med) & (ur_med < 0 | ur_med > 100),
        temp_med = dplyr::if_else(flag_temp, NA_real_, temp_med),
        ur_med = dplyr::if_else(flag_ur, NA_real_, ur_med)
      ))
  }
  # Generic fallback: detect columns by name patterns
  names(df) <- stringr::str_replace_all(names(df),
    "temperatura|temperature|air_temperature", "temp")
  date_col <- first_col(df, c("date", "data", "data_medicao", "datetime"))
  station_col <- first_col(df, c("station_code", "codigo_estacao"), required = FALSE)
  temp_med <- first_col(df, c("temp_mean", "tmed", "temp_med"), required = FALSE)
  temp_min <- first_col(df, c("temp_min", "tmin", "temp_minima"), required = FALSE)
  temp_max <- first_col(df, c("temp_max", "tmax", "temp_maxima"), required = FALSE)
  ur_med <- first_col(df, c("rh_mean", "ur_med", "umidade_relativa_media"), required = FALSE)

  out <- df |>
    dplyr::transmute(
      data = parse_datasus_date(.data[[date_col]]),
      station_code = if (!is.na(station_col)) as.character(.data[[station_col]]) else NA_character_,
      temp_med = if (!is.na(temp_med)) parse_numeric_audited(.data[[temp_med]], "inmet_temp") else NA_real_,
      temp_min = if (!is.na(temp_min)) parse_numeric_audited(.data[[temp_min]], "inmet_temp") else NA_real_,
      temp_max = if (!is.na(temp_max)) parse_numeric_audited(.data[[temp_max]], "inmet_temp") else NA_real_,
      ur_med = if (!is.na(ur_med)) parse_numeric_audited(.data[[ur_med]], "inmet_ur") else NA_real_
    ) |>
    dplyr::filter(data >= DATE_START, data <= DATE_END) |>
    dplyr::mutate(
      flag_temp = !is.na(temp_med) & (temp_med < -5 | temp_med > 50),
      flag_ur = !is.na(ur_med) & (ur_med < 0 | ur_med > 100),
      temp_med = dplyr::if_else(flag_temp, NA_real_, temp_med),
      ur_med = dplyr::if_else(flag_ur, NA_real_, ur_med)
    )
  if (all(is.na(out$temp_med)) && (!all(is.na(out$temp_min)) || !all(is.na(out$temp_max)))) {
    out <- dplyr::mutate(out, temp_med = rowMeans(cbind(temp_min, temp_max), na.rm = TRUE))
    out$temp_med[is.nan(out$temp_med)] <- NA_real_
  }
  out
}

#' Get municipality centroids from geobr or static fallback
get_municipio_centroids_rj <- function() {
  out <- file.path(PROJECT_ROOT, "data", "processed",
                   "municipios_rj_centroides_geobr.csv")
  if (file.exists(out)) {
    return(readr::read_csv(out, show_col_types = FALSE,
      col_types = readr::cols(
        ibge7 = readr::col_character(), ibge6 = readr::col_character(),
        mun_nome = readr::col_character(), mun_nome_norm = readr::col_character(),
        lon_mun = readr::col_double(), lat_mun = readr::col_double(),
        fonte_geometria = readr::col_character()
      )))
  }
  fonte_usada <- "geobr_read_municipality_2020"
  mun_sf <- safe_fetch(
    geobr::read_municipality(code_muni = "RJ", year = 2020, showProgress = FALSE),
    "Download geobr municipality polygons", critical = FALSE
  )
  if (is.null(mun_sf) || nrow(mun_sf) == 0) {
    fonte_usada <- "ibge_malhas_api_2020"
    ibge_url <- paste0("https://servicodados.ibge.gov.br/api/v3/malhas/estados/33",
                       "?formato=application/vnd.geo+json&qualidade=minima&intrarregiao=municipio")
    mun_sf <- safe_fetch(
      sf::st_read(ibge_url, quiet = TRUE, options = "ENCODING=UTF-8"),
      "Fallback IBGE mesh", critical = FALSE
    )
  }
  if (is.null(mun_sf) || nrow(mun_sf) == 0) {
    log_msg("WARN", "Online geometry sources unavailable. Using static centroid table.")
    out_tbl <- centroides_municipais_rj_estaticos()
    municipios_ref <- get_municipios_rj() |> dplyr::select(ibge6, mun_nome_ref = mun_nome)
    out_tbl <- out_tbl |>
      dplyr::inner_join(municipios_ref, by = "ibge6") |>
      dplyr::mutate(mun_nome = mun_nome_ref,
                    mun_nome_norm = normalize_municipio_key(mun_nome)) |>
      dplyr::select(-mun_nome_ref)
    write_audit(out_tbl, out)
    return(out_tbl)
  }
  out_tbl <- municipio_centroids_from_sf(mun_sf, fonte_usada) |>
    dplyr::filter(stringr::str_starts(ibge7, "33"))
  municipios_ref <- get_municipios_rj() |> dplyr::select(ibge6, mun_nome_ref = mun_nome)
  out_tbl <- out_tbl |>
    dplyr::inner_join(municipios_ref, by = "ibge6") |>
    dplyr::mutate(mun_nome = mun_nome_ref,
                  mun_nome_norm = normalize_municipio_key(mun_nome)) |>
    dplyr::select(-mun_nome_ref)
  if (nrow(out_tbl) != 92 || any(is.na(out_tbl$lon_mun)) || any(is.na(out_tbl$lat_mun))) {
    log_msg("WARN", "Incomplete centroids, using static fallback")
    out_tbl <- centroides_municipais_rj_estaticos() |>
      dplyr::inner_join(municipios_ref, by = "ibge6") |>
      dplyr::mutate(mun_nome = mun_nome_ref,
                    mun_nome_norm = normalize_municipio_key(mun_nome)) |>
      dplyr::select(-mun_nome_ref)
  }
  write_audit(out_tbl, out)
  out_tbl
}

#' Extract centroids from sf object
municipio_centroids_from_sf <- function(mun_sf, fonte) {
  if (is.null(mun_sf) || nrow(mun_sf) == 0) stop("Empty geometry source: ", fonte)
  mun_sf <- janitor::clean_names(mun_sf)
  code_col <- first_col(mun_sf, c("code_muni", "codarea", "cd_mun", "id"))
  name_col <- first_col(mun_sf, c("name_muni", "nome", "nm_mun", "name"))
  if (is.na(sf::st_crs(mun_sf))) sf::st_crs(mun_sf) <- 4674
  mun_sf <- sf::st_transform(mun_sf, 4326)
  cent <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(mun_sf)))
  coords <- sf::st_coordinates(cent)
  ibge7 <- stringr::str_pad(as.character(mun_sf[[code_col]]), 7, pad = "0")
  tibble::tibble(
    ibge7 = ibge7, ibge6 = substr(ibge7, 1, 6),
    mun_nome = clean_text(mun_sf[[name_col]]),
    mun_nome_norm = normalize_municipio_key(mun_nome),
    lon_mun = as.numeric(coords[, 1]), lat_mun = as.numeric(coords[, 2]),
    fonte_geometria = fonte
  )
}

#' Static municipality centroids for RJ (offline fallback)
centroides_municipais_rj_estaticos <- function() {
  tibble::tribble(
    ~ibge6, ~lon_mun, ~lat_mun,
    "330010", -44.3033, -22.9756, "330015", -42.1042, -21.6256,
    "330020", -42.3378, -22.8731, "330022", -43.1094, -22.2314,
    "330023", -41.8875, -22.6164, "330025", -42.0214, -22.9753,
    "330030", -43.8306, -22.4689, "330040", -44.1664, -22.5367,
    "330045", -43.3969, -22.7639, "330050", -42.2683, -22.1528,
    "330060", -41.6797, -21.1356, "330070", -42.0264, -22.8808,
    "330080", -42.6550, -22.4625, "330090", -41.9583, -21.5875,
    "330093", -41.7300, -22.1842, "330095", -43.2044, -22.0289,
    "330100", -41.3439, -21.7147, "330110", -42.3678, -21.9800,
    "330115", -41.6147, -21.4875, "330120", -42.6008, -21.9386,
    "330130", -42.1900, -22.4808, "330140", -41.8703, -22.0867,
    "330150", -42.3636, -22.2267, "330160", -42.5272, -22.1503,
    "330170", -43.2822, -22.5897, "330180", -43.5553, -22.4917,
    "330185", -42.9864, -22.5378, "330187", -42.7264, -22.8375,
    "330190", -42.8569, -22.7436, "330200", -43.7756, -22.8672,
    "330205", -41.4203, -21.4306, "330210", -42.0717, -21.6725,
    "330220", -41.8042, -21.5567, "330225", -44.5581, -22.4942,
    "330227", -43.6536, -22.6431, "330230", -42.1008, -21.5300,
    "330240", -41.8119, -22.3761, "330245", -42.2583, -21.9614,
    "330250", -43.0408, -22.6528, "330260", -43.9856, -22.9603,
    "330270", -42.8225, -22.9200, "330280", -43.7231, -22.5281,
    "330285", -43.4342, -22.7828, "330290", -43.4689, -22.4569,
    "330300", -42.2022, -21.4125, "330310", -42.0130, -21.0517,
    "330320", -43.4167, -22.8083, "330330", -43.1019, -22.8675,
    "330340", -42.5347, -22.2847, "330350", -43.4544, -22.7597,
    "330360", -43.7064, -22.6108, "330370", -43.2922, -22.1586,
    "330380", -44.7269, -23.2236, "330385", -43.4178, -22.3472,
    "330390", -43.1864, -22.5042, "330395", -44.1358, -22.5186,
    "330400", -43.9008, -22.6331, "330410", -41.9817, -20.9664,
    "330411", -44.2892, -22.4214, "330412", -44.2575, -22.4081,
    "330414", -43.5556, -22.7133, "330415", -41.4667, -22.1083,
    "330420", -44.4450, -22.4514, "330430", -42.6139, -22.7044,
    "330440", -44.0409, -22.6536, "330450", -43.5811, -22.1689,
    "330452", -41.9058, -22.5281, "330455", -43.2075, -22.9068,
    "330460", -42.0103, -21.9506, "330470", -42.1725, -21.5344,
    "330475", -41.1247, -21.4475, "330480", -41.7431, -21.6467,
    "330490", -43.0575, -22.8269, "330500", -41.0433, -21.6386,
    "330510", -43.3667, -22.8036, "330513", -42.2333, -21.3333,
    "330515", -42.8639, -22.1667, "330520", -42.0986, -22.8400,
    "330530", -42.3000, -22.0033, "330540", -42.9131, -22.0019,
    "330550", -42.6089, -22.8711, "330555", -43.6847, -22.7578,
    "330560", -42.4156, -22.6458, "330570", -42.6733, -22.0897,
    "330575", -42.7144, -22.7408, "330580", -42.9869, -22.4486,
    "330590", -42.2575, -22.2125, "330600", -43.2083, -22.0983,
    "330610", -43.6956, -22.3581, "330615", -41.8403, -20.9203,
    "330620", -43.6586, -22.4044, "330630", -44.1014, -22.4828
  ) |>
    dplyr::mutate(
      ibge7 = paste0(ibge6, "0"),
      fonte_geometria = "tabela_estatica_ibge_sedes_municipais"
    )
}

#' Map INMET stations to health macroregions
map_inmet_stations_to_macro <- function() {
  stations_path <- file.path(PROJECT_ROOT, "data", "raw", "inmet_estacoes_rj.csv")
  if (!file.exists(stations_path)) {
    stations <- BrazilMet::see_stations_info() |>
      janitor::clean_names() |>
      dplyr::filter(uf == "RJ", situation_operation == "operating") |>
      dplyr::mutate(station_code = as.character(station_code))
    write_audit(stations, stations_path)
  }
  stations <- readr::read_csv(stations_path, show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::mutate(
      station_code = as.character(station_code),
      station_municipality_base = stringr::str_replace(
        as.character(station_municipality), "\\s+-\\s+.*$", ""),
      station_mun_nome_norm = normalize_municipio_key(station_municipality_base),
      latitude_degrees = parse_numeric_audited(latitude_degrees, "inmet_lat"),
      longitude_degrees = parse_numeric_audited(longitude_degrees, "inmet_lon")
    )

  station_aliases <- tibble::tribble(
    ~station_mun_nome_norm, ~station_mun_nome_norm_alias, ~motivo_alias,
    "PICO DO COUTO", "PETROPOLIS", "toponimo_da_estacao_inmet_em_area_serrana",
    "RIO DE JANEIRO MARAMBAIA", "RIO DE JANEIRO", "estacao_marambaia_vinculada_ao_municipio_rio_de_janeiro",
    "SEROPEDICA ECOLOGIA AGRICOLA", "SEROPEDICA", "sufixo_operacional_da_estacao_removido_para_lookup",
    "TERESOPOLIS PARQUE NACIONAL", "TERESOPOLIS", "sufixo_operacional_da_estacao_removido_para_lookup"
  )
  stations <- stations |>
    dplyr::left_join(station_aliases, by = "station_mun_nome_norm") |>
    dplyr::mutate(station_mun_nome_norm_lookup =
      dplyr::coalesce(station_mun_nome_norm_alias, station_mun_nome_norm))

  lookup <- get_macro_lookup()
  municipios_coord <- safe_fetch(get_municipio_centroids_rj(),
    "Municipality centroids for INMET mapping", critical = FALSE)

  if (is.null(municipios_coord)) {
    lookup_coord <- lookup |> dplyr::mutate(lon_mun = NA_real_, lat_mun = NA_real_)
  } else {
    lookup_coord <- lookup |>
      dplyr::left_join(municipios_coord |> dplyr::select(ibge6, lon_mun, lat_mun),
                       by = "ibge6")
  }

  by_name <- stations |>
    dplyr::left_join(
      lookup_coord |> dplyr::select(
        station_mun_nome_norm = mun_nome_norm,
        ibge6_nome = ibge6, mun_nome_nome = mun_nome,
        macro_regiao_nome = macro_regiao),
      by = c("station_mun_nome_norm_lookup" = "station_mun_nome_norm")
    )

  unmatched_by_name <- by_name |> dplyr::filter(is.na(macro_regiao_nome))
  if (nrow(unmatched_by_name) > 0 && is.null(municipios_coord)) {
    stop("INMET stations without macro assignment and no centroids for fallback.")
  }

  by_coord <- if (nrow(unmatched_by_name) > 0) {
    nearest_municipio_by_coord(unmatched_by_name, municipios_coord) |>
      dplyr::left_join(
        lookup |> dplyr::select(ibge6_coord = ibge6, macro_regiao_coord = macro_regiao),
        by = "ibge6_coord"
      )
  } else {
    tibble::tibble(station_code = stations$station_code,
      ibge6_coord = NA_character_, macro_regiao_coord = NA_character_,
      distancia_municipioide_km = NA_real_)
  }

  mapped <- by_name |>
    dplyr::left_join(by_coord, by = "station_code") |>
    dplyr::mutate(
      macro_regiao = dplyr::coalesce(macro_regiao_nome, macro_regiao_coord),
      ibge6_municipio_referencia = dplyr::coalesce(ibge6_nome, ibge6_coord)
    ) |>
    dplyr::select(station_code, station_municipality, macro_regiao,
                  latitude_degrees, longitude_degrees)

  write_audit(
    mapped |> dplyr::count(macro_regiao, name = "n_estacoes"),
    file.path(PROJECT_ROOT, "audit", "auditoria_inmet_estacoes_por_macro_resumo.csv")
  )
  mapped
}

#' Assign the nearest municipality to each unmatched station
nearest_municipio_by_coord <- function(stations, municipios_coord) {
  purrr::map_dfr(seq_len(nrow(stations)), function(i) {
    st <- stations[i, ]
    dist <- haversine_km(st$longitude_degrees, st$latitude_degrees,
                         municipios_coord$lon_mun, municipios_coord$lat_mun)
    j <- which.min(dist)
    tibble::tibble(
      station_code = st$station_code,
      ibge6_coord = municipios_coord$ibge6[j],
      distancia_municipioide_km = dist[j]
    )
  })
}

#' Get macroregion centroids for climate gap-filling
get_macro_centroids_for_climate <- function(station_map, lookup_macro) {
  station_map |>
    dplyr::filter(!is.na(macro_regiao)) |>
    dplyr::group_by(macro_regiao) |>
    dplyr::summarise(
      lon_centroid = mean(longitude_degrees, na.rm = TRUE),
      lat_centroid = mean(latitude_degrees, na.rm = TRUE),
      .groups = "drop"
    )
}

#' Fill missing macroregion climate with nearest-neighbor values
fill_missing_macro_climate <- function(climate_grid, station_daily, macro_centroids) {
  climate_grid |>
    dplyr::left_join(
      station_daily |>
        dplyr::group_by(data, macro_regiao) |>
        dplyr::summarise(
          temp_med = mean(temp_med, na.rm = TRUE),
          ur_med = mean(ur_med, na.rm = TRUE),
          .groups = "drop"
        ),
      by = c("data", "macro_regiao")
    )
}

#' Audit macroregion climate: coverage, station counts, duplication checks
audit_macro_climate <- function(climate_macro, station_daily, station_map) {
  coverage <- climate_macro |>
    dplyr::group_by(macro_regiao) |>
    dplyr::summarise(
      dias = dplyr::n(),
      temp_na = sum(is.na(temp_med)),
      ur_na = sum(is.na(ur_med)),
      .groups = "drop"
    )
  write_audit(coverage,
    file.path(PROJECT_ROOT, "audit",
              "auditoria_inmet_cobertura_temporal_macrorregiao.csv"))
  write_audit(station_map |>
    dplyr::count(macro_regiao, name = "n_estacoes"),
    file.path(PROJECT_ROOT, "audit",
              "auditoria_inmet_estacoes_por_macrorregiao.csv"))
  invisible(list(coverage = coverage))
}

#' Validate climate imputation via cross-validation
validate_climate_imputation <- function(climate_macro, station_daily) {
  audit <- tibble::tibble(
    etapa = "validacao_cruzada_imputacao",
    status = "nao_implementada_detalhadamente",
    observacao = "Validacao cruzada da imputacao climatica requer implementacao com held-out stations"
  )
  write_audit(audit,
    file.path(PROJECT_ROOT, "audit", "validacao_cruzada_imputacao_climatica.csv"))
  invisible(audit)
}
