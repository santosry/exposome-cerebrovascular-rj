# Workflow Notes

The DLNM-only pipeline is organized into reproducible stages:

1. Download SIH-RD and SIM-DO outcome data.
2. Download INMET climate data.
3. Build SIDRA/IBGE population offsets.
4. Prepare macroregional daily time series.
5. Run DLNM models and sensitivity analyses.
6. Stabilize estimates with hierarchical Bayesian modeling.
7. Generate figures and tables.
8. Generate reports, audits, quality-control files and benchmark outputs.

The full operational implementation is preserved in `scripts/pipeline_integrado_full.R`.
