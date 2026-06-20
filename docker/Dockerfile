# Dockerfile -- Reproducible computational environment
# =============================================================================
FROM rocker/geospatial:latest

LABEL description="DLNM Cerebrovascular RJ (2010-2025) Research Compendium"

WORKDIR /home/rstudio/dlnm-compendium
COPY . .

RUN mkdir -p data/raw data/interim data/processed outputs/figures outputs/tables \
    audit logs reports docs

RUN Rscript -e ' \
  options(repos = c(CRAN = "https://cloud.r-project.org")); \
  pkgs <- c("testthat"); \
  install.packages(pkgs) \
'

RUN echo "options(repos = c(CRAN = 'https://cloud.r-project.org'))" >> /home/rstudio/.Rprofile
CMD ["Rscript", "run_pipeline.R"]
