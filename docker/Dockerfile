# Dockerfile — Reproducible computational environment for the DLNM compendium
# =============================================================================
# Build:  docker build -t dlnm-cerebrovascular-rj .
# Run:    docker run --rm -v ${PWD}/outputs:/home/rstudio/outputs dlnm-cerebrovascular-rj
#
# Uses rocker/geospatial for sf/geobr/spdep support.

FROM rocker/geospatial:latest

LABEL maintainer="Ryan de Paulo Santos <ryan.paulo@gsuite.iff.edu.br>"
LABEL description="DLNM Cerebrovascular RJ (2010–2025) — Reproducible Research Compendium"
LABEL version="1.0.0"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libgit2-dev \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# Install R packages from CRAN
RUN install2.r --error --skipinstalled \
    microdatasus \
    BrazilMet \
    tidyverse \
    data.table \
    lubridate \
    janitor \
    dlnm \
    MASS \
    mgcv \
    lmtest \
    ggplot2 \
    readr \
    rmarkdown \
    plotly \
    htmlwidgets \
    knitr \
    httr \
    ggrepel \
    scales \
    sidrar \
    geobr \
    sf \
    sandwich \
    spdep \
    igraph \
    zoo \
    survival \
    patchwork \
    stringr \
    stringi \
    forcats \
    purrr \
    tibble \
    tidyr \
    dplyr \
    jsonlite \
    pheatmap \
    renv \
    targets \
    tarchetypes \
    testthat \
    lintr \
    styler \
    && rm -rf /tmp/downloaded_packages

# Set working directory
WORKDIR /home/rstudio/dlnm-compendium

# Copy project files
COPY . .

# Create output directories
RUN mkdir -p data/raw data/interim data/processed outputs/figures outputs/tables \
    audit logs reports docs

# Set R options
RUN echo "options(repos = c(CRAN = 'https://cloud.r-project.org'))" >> /home/rstudio/.Rprofile

# Default command: run the full pipeline
CMD ["Rscript", "run_pipeline.R"]
