# PM2.5 Granularity and Use in the Analytical Pipeline

## Summary

PM2.5 is not treated as a primary DLNM exposure in this compendium because the available processed product is monthly, whereas the main climate exposures (temperature and relative humidity) are daily macroregional time series.

> **Update 2026-06-21:** PM2.5 extraction was upgraded from annual to **monthly** granularity. The downscaling now uses two stages: (1) annual distribution via national VIGIAR series (2010–2024), and (2) seasonal distribution within each year via the national monthly profile for 2024 extracted directly from the INEA/MonitorAr Power BI dashboard (query `df_mensal.mes_nome`). The final product has 17,664 rows (92 municipalities × 16 years × 12 months), aggregated to 1,728 macroregional-monthly rows (9 macroregions × 192 months).

## Coverage

The PM2.5 extraction module covers all 92 municipalities of Rio de Janeiro state:

- 74 municipalities have direct values extracted from the INEA/MonitorAr/VIGIAR Power BI source;
- 18 municipalities receive the value of the nearest monitored municipality;
- all municipalities are mapped to one of the nine health macroregions;
- the final macroregional PM2.5 table has **1,728 rows** (9 macroregions × 16 years × 12 months).

Detailed coverage is documented in:

- `audit/air_quality/auditoria_mp25_cobertura_municipal.csv`;
- `audit/air_quality/auditoria_mp25_resumo_cobertura.csv`.

## Temporal Granularity

The climate exposure table has daily resolution:

- temperature and humidity: 52,596 rows (5,844 days × 9 macroregions);
- temporal unit: day;
- use in DLNM: exposure-lag cross-basis.

The PM2.5 table has **monthly** resolution (upgraded from annual on 2026-06-21):

- PM2.5: 1,728 rows (192 months × 9 macroregions);
- temporal unit: month;
- use in DLNM: monthly linear covariate for seasonal adjustment. Still not suitable for daily exposure-lag cross-basis.

## Seasonal Profile (INEA/MonitorAr national 2024)

| Month | Ratio to mean | Month | Ratio to mean |
|---|---|---|---|
| Jan | 0.64× | Jul | 0.83× |
| Feb | 0.68× | Aug | 1.56× |
| Mar | 0.71× | Sep | **2.59×** |
| Apr | 0.70× | Oct | 1.29× |
| May | 0.69× | Nov | 0.81× |
| Jun | 0.77× | Dec | 0.74× |

Peak in September corresponds to the dry season and biomass burning in South America.

## Default Analytical Decision

By default, `AIR_QUALITY_ENABLE` is set to `FALSE`. To include PM2.5 as a sensitivity covariate, run:

```bash
DLNM_ENABLE_AIR_QUALITY=true Rscript run_pipeline.R
```

This keeps the main analysis focused on daily climate exposures and prevents accidental overinterpretation of PM2.5 as if it had the same temporal granularity as INMET temperature and humidity.
