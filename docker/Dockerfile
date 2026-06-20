# Dockerfile — Reproducible computational environment for DLNM compendium
# =============================================================================
# Build:  docker build -t dlnm-cerebrovascular-rj -f docker/Dockerfile .
# Run:    docker run --rm -v $(pwd)/outputs:/home/rstudio/dlnm-compendium/outputs dlnm-cerebrovascular-rj

FROM rocker/geospatial:latest

LABEL description="DLNM Cerebrovascular RJ (2010-2025) — Fully Reproducible Research Compendium"
LABEL maintainer="Ryan de Paulo Santos"

ENV RENV_PATHS_CACHE=/home/rstudio/.cache/renv
ENV DLNM_PROJECT_ROOT=/home/rstudio/dlnm-compendium
ENV DLNM_FORCE_RAW_DOWNLOAD=false
ENV DLNM_ENABLE_AIR_QUALITY=false
ENV RUN_PIPELINE_ON_SOURCE=true

WORKDIR /home/rstudio/dlnm-compendium

# ── System dependencies ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    libudunits2-dev libgdal-dev libgeos-dev libproj-dev \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# ── Python environment for PM2.5 extraction ──
COPY python/requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && python3 -m playwright install chromium \
    && python3 -m playwright install-deps chromium

# ── Copy project files ──
COPY . .

# ── Create output directories ──
RUN mkdir -p data/raw data/interim data/processed outputs/figures outputs/tables \
    audit logs reports docs

# ── Restore R packages via renv ──
RUN Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")' \
    && Rscript -e 'renv::restore()'

CMD ["Rscript", "run_pipeline.R"]
