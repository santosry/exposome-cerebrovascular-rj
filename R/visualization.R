# visualization.R — Figures, plots, and interactive 3D surface generation
# =============================================================================
# Generates: exposure-response curves, lag-response curves, AUC rankings,
#            seasonal plots, residual diagnostics, 3D heatmap surfaces.

#' Plot exposure-response curve with confidence bands (HAC-corrected when available)
plot_exposure_response <- function(obj, region, fdr_value = NA_real_,
                                    percentile_values = NULL) {
  pred <- obj$pred
  pred_var <- pred$predvar
  if (is.list(pred_var)) pred_var <- pred_var[[1]]
  rr <- pred$allRRfit
  rr_low <- pred$allRRlow
  rr_high <- pred$allRRhigh

  df_plot <- tibble::tibble(
    exposure = pred_var,
    rr = rr, rr_low = rr_low, rr_high = rr_high
  )

  subtitle <- if (!is.na(fdr_value)) {
    paste0("FDR = ", format(fdr_value, digits = 3))
  } else {
    paste0(region, " — ", obj$outcome, " ~ ", obj$exposure)
  }

  p <- ggplot2::ggplot(df_plot, ggplot2::aes(x = exposure, y = rr)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = rr_low, ymax = rr_high),
                         fill = "#174BFF", alpha = 0.15) +
    ggplot2::geom_line(color = "#174BFF", linewidth = 1) +
    ggplot2::geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
    ggplot2::scale_y_continuous(
      trans = "log",
      labels = scales::number_format(accuracy = 0.01, decimal.mark = ",")) +
    ggplot2::labs(
      title = paste("Exposure-Response:", region),
      subtitle = subtitle,
      x = if (obj$exposure == "temp_med") "Temperature (°C)" else "Relative Humidity (%)",
      y = "Relative Risk (RR)"
    ) +
    ggplot2::theme_minimal(base_size = 12)

  if (!is.null(percentile_values)) {
    p <- p +
      ggplot2::geom_vline(xintercept = percentile_values$p10, linetype = "dotted",
                          color = "gray60") +
      ggplot2::geom_vline(xintercept = percentile_values$p90, linetype = "dotted",
                          color = "gray60")
  }
  p
}

#' Compute exposure percentiles for annotation
exposure_percentiles <- function(dat, exposure) {
  list(
    p10 = stats::quantile(dat[[exposure]], 0.10, na.rm = TRUE),
    p50 = stats::quantile(dat[[exposure]], 0.50, na.rm = TRUE),
    p90 = stats::quantile(dat[[exposure]], 0.90, na.rm = TRUE)
  )
}

#' Plot lag-response curve at a specific exposure percentile
plot_lag_response <- function(obj, region, fdr_value = NA_real_) {
  pred <- obj$pred
  lags <- 0:obj$lag_max
  # Extract lag-specific RR at 90th percentile of exposure
  pred_var <- pred$predvar
  if (is.list(pred_var)) pred_var <- pred_var[[1]]
  idx_high <- which(pred_var >= quantile(pred_var, 0.90))[1]
  rr_lag <- pred$matRRfit[idx_high, ]
  rr_lag_low <- pred$matRRlow[idx_high, ]
  rr_lag_high <- pred$matRRhigh[idx_high, ]

  df_plot <- tibble::tibble(
    lag = lags, rr = rr_lag, rr_low = rr_lag_low, rr_high = rr_lag_high
  )

  ggplot2::ggplot(df_plot, ggplot2::aes(x = lag, y = rr)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = rr_low, ymax = rr_high),
                         fill = "#A12CFF", alpha = 0.15) +
    ggplot2::geom_line(color = "#A12CFF", linewidth = 1) +
    ggplot2::geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
    ggplot2::labs(
      title = paste("Lag-Response:", region),
      subtitle = "At P90 exposure",
      x = "Lag (days)", y = "Relative Risk (RR)"
    ) +
    ggplot2::theme_minimal(base_size = 12)
}

#' Plot monthly admission seasonality
plot_monthly_admissions <- function(dat_macro) {
  monthly <- dat_macro |>
    dplyr::mutate(mes = lubridate::month(data)) |>
    dplyr::group_by(macro_regiao, mes) |>
    dplyr::summarise(
      internacoes = sum(internacoes_i60_i69, na.rm = TRUE),
      obitos = sum(obitos_i60_i69, na.rm = TRUE),
      .groups = "drop"
    )

  p <- ggplot2::ggplot(monthly,
    ggplot2::aes(x = mes, y = internacoes, color = macro_regiao, group = macro_regiao)) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::scale_x_continuous(breaks = 1:12,
      labels = c("J","F","M","A","M","J","J","A","S","O","N","D")) +
    ggplot2::labs(
      title = "Monthly Hospital Admissions (I60–I69)",
      x = "Month", y = "Admissions",
      color = "Macroregion"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggsave(file.path(PROJECT_ROOT, "outputs", "figures",
                   "sazonalidade_mensal_taxa_admissao.png"),
         p, width = 12, height = 7, dpi = 150, bg = "white")
  invisible(p)
}

#' Plot daily climate seasonality
plot_daily_climate_seasonality <- function(dat_macro) {
  daily_climate <- dat_macro |>
    dplyr::group_by(macro_regiao) |>
    dplyr::summarise(
      temp_media = mean(temp_med, na.rm = TRUE),
      ur_media = mean(ur_med, na.rm = TRUE),
      .groups = "drop"
    )

  p1 <- ggplot2::ggplot(dat_macro |>
    dplyr::mutate(dia_ano = lubridate::yday(data)),
    ggplot2::aes(x = dia_ano, y = temp_med, color = macro_regiao)) +
    ggplot2::geom_smooth(se = FALSE, linewidth = 0.5) +
    ggplot2::labs(title = "Daily Temperature Seasonality",
                  x = "Day of Year", y = "Temperature (°C)") +
    ggplot2::theme_minimal(base_size = 10)

  p2 <- ggplot2::ggplot(dat_macro |>
    dplyr::mutate(dia_ano = lubridate::yday(data)),
    ggplot2::aes(x = dia_ano, y = ur_med, color = macro_regiao)) +
    ggplot2::geom_smooth(se = FALSE, linewidth = 0.5) +
    ggplot2::labs(title = "Daily Humidity Seasonality",
                  x = "Day of Year", y = "Relative Humidity (%)") +
    ggplot2::theme_minimal(base_size = 10)

  p <- patchwork::wrap_plots(p1, p2, ncol = 1) +
    patchwork::plot_annotation(title = "Climate Seasonality by Macroregion")

  ggsave(file.path(PROJECT_ROOT, "outputs", "figures",
                   "sazonalidade_diaria_temperatura.png"),
         p1, width = 10, height = 5, dpi = 150, bg = "white")
  ggsave(file.path(PROJECT_ROOT, "outputs", "figures",
                   "sazonalidade_diaria_umidade.png"),
         p2, width = 10, height = 5, dpi = 150, bg = "white")
  invisible(list(temp = p1, ur = p2))
}

#' Plot AUC-based model ranking
plot_top_auc <- function(auc_tbl) {
  top_models <- auc_tbl |>
    dplyr::filter(fdr_significant) |>
    dplyr::arrange(dplyr::desc(auc_excesso_rr)) |>
    dplyr::slice_head(n = 15) |>
    dplyr::mutate(
      label = paste(macro_regiao, outcome, exposure, sep = " | "),
      label = forcats::fct_reorder(label, auc_excesso_rr)
    )

  p <- ggplot2::ggplot(top_models,
    ggplot2::aes(x = auc_excesso_rr, y = label, fill = exposure)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::scale_fill_manual(values = c(temp_med = "#E63946", ur_med = "#457B9D")) +
    ggplot2::labs(
      title = "Top DLNM Models by Excess RR AUC",
      subtitle = "FDR < 0.05",
      x = "Excess RR AUC", y = NULL, fill = "Exposure"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggsave(file.path(PROJECT_ROOT, "outputs", "figures", "Fig03_auc_ranking.png"),
         p, width = 12, height = 7, dpi = 150, bg = "white")
  invisible(p)
}

#' Generate 3D RR surface as interactive HTML
save_rr_surface_3d <- function(obj, region, model_key,
                                p_bruto = NA_real_, p_fdr = NA_real_) {
  pred <- obj$pred
  rr_mat <- pred$matRRfit
  pred_var <- pred$predvar
  if (is.list(pred_var)) pred_var <- pred_var[[1]]
  lags <- 0:(ncol(rr_mat) - 1)

  subtitle <- sprintf("%s | %s ~ %s", region, obj$outcome, obj$exposure)
  if (is.finite(p_fdr)) {
    subtitle <- paste0(subtitle, sprintf(" | FDR = %.4f", p_fdr))
  }

  p <- plotly::plot_ly(
    x = pred_var, y = lags, z = t(rr_mat),
    type = "surface",
    colorscale = list(
      c(0, "#457B9D"), c(0.5, "#F1FAEE"), c(1, "#E63946")),
    contours = list(z = list(show = TRUE, project = list(z = TRUE)))
  ) |>
    plotly::layout(
      title = paste("3D RR Surface:", subtitle),
      scene = list(
        xaxis = list(title = if (obj$exposure == "temp_med")
          "Temperature (°C)" else "Relative Humidity (%)"),
        yaxis = list(title = "Lag (days)"),
        zaxis = list(title = "RR")
      )
    )

  outdir <- file.path(PROJECT_ROOT, "outputs", "figures", "interactive")
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  html_path <- file.path(outdir,
    paste0("rr_surface_3d_", model_key, ".html"))

  htmlwidgets::saveWidget(p, html_path, selfcontained = FALSE,
    libdir = paste0(basename(tools::file_path_sans_ext(html_path)), "_files"))
  log_msg("INFO", "3D surface saved: ", html_path)
  invisible(html_path)
}

#' Generate CellPress-quality manuscript figures
generate_cellpress_figures <- function() {
  log_msg("INFO", "Generating CellPress-quality figures")

  # Load required data
  dlnm_dir <- file.path(PROJECT_ROOT, "data", "processed")
  models_path <- file.path(dlnm_dir, "modelos_dlnm_macrorregiao.rds")
  dat_path <- file.path(dlnm_dir, "dataset_dlnm_macrorregiao.rds")
  auc_path <- file.path(PROJECT_ROOT, "outputs", "tables",
                        "tabela_auc_rr_dlnm_macrorregiao.csv")

  if (!all(file.exists(models_path, dat_path, auc_path))) {
    log_msg("WARN", "CellPress figures: required files not found, skipping")
    return(invisible(NULL))
  }

  results <- readRDS(models_path)
  dat_macro <- readRDS(dat_path)
  auc_tbl <- readr::read_csv(auc_path, show_col_types = FALSE)

  fig_dir <- file.path(PROJECT_ROOT, "outputs", "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  # Fig01: Daily climate
  cp_fig_daily_timeseries(dat_macro)

  # Fig02: Exposure-lag heatmap (static version)
  # Select top FDR-significant model
  top <- auc_tbl |>
    dplyr::filter(fdr_significant) |>
    dplyr::arrange(dplyr::desc(auc_excesso_rr)) |>
    dplyr::slice_head(n = 1)

  if (nrow(top) > 0) {
    key <- paste(top$macro_regiao, top$outcome, top$exposure, sep = "__") |>
      janitor::make_clean_names()
    if (key %in% names(results)) {
      obj <- results[[key]]
      p <- ggplot2::ggplot(
        tidyr::expand_grid(
          exposure = obj$pred$predvar[[1]],
          lag = 0:(ncol(obj$pred$matRRfit) - 1)
        ) |>
          dplyr::mutate(
            rr = as.vector(t(obj$pred$matRRfit))
          ),
        ggplot2::aes(x = exposure, y = lag, fill = rr)
      ) +
        ggplot2::geom_tile() +
        ggplot2::scale_fill_gradient2(
          low = "#457B9D", mid = "#F1FAEE", high = "#E63946",
          midpoint = 1, trans = "log",
          labels = scales::number_format(accuracy = 0.01, decimal.mark = ",")
        ) +
        ggplot2::labs(
          title = paste("Exposure-Lag-RR:", top$macro_regiao),
          subtitle = paste(top$outcome, "~", top$exposure),
          x = if (top$exposure == "temp_med") "Temperature (°C)" else "Relative Humidity (%)",
          y = "Lag (days)", fill = "RR"
        ) +
        ggplot2::theme_minimal(base_size = 12)

      ggsave(file.path(fig_dir, "Fig02_exposure_lag.png"),
             p, width = 10, height = 7, dpi = 150, bg = "white")
    }
  }

  log_msg("INFO", "CellPress figures complete")
  invisible(TRUE)
}

# [DIAG-PLOTS] Extended diagnostic residual plots for top FDR-significant models.
# Generates ACF, PACF, QQ-normal, and residual-vs-fitted plots.
#' Generate extended diagnostic residual plots
plot_extended_diagnostics <- function(dlnm_results, auc_tbl, max_models = 12) {
  if (!requireNamespace("ggplot2", quietly = TRUE) ||
      !requireNamespace("patchwork", quietly = TRUE)) {
    log_msg("WARN", "ggplot2/patchwork not available; skipping extended diagnostics")
    return(invisible(NULL))
  }

  log_msg("INFO", "Generating extended diagnostic residual plots")

  diag_dir <- file.path(PROJECT_ROOT, "outputs", "figures", "diagnosticos_residuos")
  dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

  # Select top models: FDR-significant prioritized by RR magnitude
  if (!is.null(auc_tbl) && "fdr_significant" %in% names(auc_tbl)) {
    top_models <- auc_tbl |>
      dplyr::filter(fdr_significant) |>
      dplyr::arrange(dplyr::desc(rr_cumulativo_max)) |>
      utils::head(max_models)
  } else {
    # Fallback: take first N models with valid residuals
    top_models <- NULL
  }

  plotted <- 0

  for (key in names(dlnm_results)) {
    obj <- dlnm_results[[key]]
    if (is.null(obj) || is.null(obj$model)) next

    # Filter to top FDR models if available
    if (!is.null(top_models)) {
      model_match <- top_models |>
        dplyr::filter(
          macro_regiao == obj$macro_regiao,
          outcome == obj$outcome,
          exposure == obj$exposure
        )
      if (nrow(model_match) == 0) next
    }

    res <- residuals(obj$model, type = "deviance")
    fitted_vals <- fitted(obj$model)
    n <- length(res)
    if (n < 50) next

    safe_name <- janitor::make_clean_names(
      paste(obj$macro_regiao, obj$outcome, obj$exposure, sep = "_"))

    # ACF data
    acf_data <- stats::acf(res, plot = FALSE, lag.max = 30, na.action = na.pass)
    acf_df <- data.frame(lag = acf_data$lag[-1], acf = acf_data$acf[-1])
    acf_ci <- 1.96 / sqrt(n)

    # PACF data
    pacf_data <- stats::pacf(res, plot = FALSE, lag.max = 30, na.action = na.pass)
    pacf_df <- data.frame(lag = pacf_data$lag, pacf = pacf_data$acf)

    # Build 4-panel diagnostic plot
    p1 <- ggplot2::ggplot(data.frame(res = res, fitted = fitted_vals),
      ggplot2::aes(x = fitted_vals, y = res)) +
      ggplot2::geom_point(alpha = 0.3, size = 0.5) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
      ggplot2::geom_smooth(method = "loess", se = TRUE, color = "blue", linewidth = 1) +
      ggplot2::labs(x = "Fitted values", y = "Deviance residuals",
                    title = "Residuals vs Fitted") +
      ggplot2::theme_minimal()

    p2 <- ggplot2::ggplot(data.frame(res = res),
      ggplot2::aes(sample = res)) +
      ggplot2::stat_qq(alpha = 0.3, size = 0.5) +
      ggplot2::stat_qq_line(color = "red") +
      ggplot2::labs(x = "Theoretical Quantiles", y = "Sample Quantiles",
                    title = "Q-Q Plot (Deviance Residuals)") +
      ggplot2::theme_minimal()

    p3 <- ggplot2::ggplot(acf_df, ggplot2::aes(x = lag, y = acf)) +
      ggplot2::geom_col(fill = "steelblue", width = 0.3) +
      ggplot2::geom_hline(yintercept = c(-acf_ci, acf_ci),
                          linetype = "dashed", color = "red") +
      ggplot2::geom_hline(yintercept = 0) +
      ggplot2::labs(x = "Lag (days)", y = "ACF",
                    title = paste0("Autocorrelation (Ljung-Box p=",
                      format(stats::Box.test(res, lag = 14, type = "Ljung-Box")$p.value,
                             digits = 2), ")")) +
      ggplot2::theme_minimal()

    p4 <- ggplot2::ggplot(pacf_df, ggplot2::aes(x = lag, y = pacf)) +
      ggplot2::geom_col(fill = "darkgreen", width = 0.3) +
      ggplot2::geom_hline(yintercept = c(-acf_ci, acf_ci),
                          linetype = "dashed", color = "red") +
      ggplot2::geom_hline(yintercept = 0) +
      ggplot2::labs(x = "Lag (days)", y = "PACF",
                    title = "Partial Autocorrelation") +
      ggplot2::theme_minimal()

    combined <- p1 + p2 + p3 + p4 +
      patchwork::plot_layout(ncol = 2, nrow = 2) +
      patchwork::plot_annotation(
        title = paste(obj$macro_regiao, "|", obj$outcome, "|", obj$exposure),
        subtitle = paste0("Family: ", obj$family,
          ", Dispersion: ", round(obj$dispersion, 2),
          ", n = ", n),
        theme = ggplot2::theme(plot.title = ggplot2::element_text(size = 11, face = "bold"))
      )

    ggplot2::ggsave(
      file.path(diag_dir, paste0("diagnostic_", safe_name, ".png")),
      combined, width = 12, height = 10, dpi = 150, bg = "white"
    )

    plotted <- plotted + 1
    log_msg("INFO", "  Diagnostic plot: ", safe_name)

    if (plotted >= max_models) break
  }

  log_msg("INFO", "Extended diagnostics complete: ", plotted, " plots generated")
  invisible(plotted)
}
