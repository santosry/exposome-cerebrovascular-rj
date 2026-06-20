# Zenodo Deposit Instructions

## How to deposit this compendium on Zenodo

### 1. Create a Zenodo account
- Go to https://zenodo.org/
- Sign up or log in with your GitHub account

### 2. Link GitHub to Zenodo
- Go to https://zenodo.org/account/settings/github/
- Enable Zenodo for the repository `santosry/exposome-cerebrovascular-rj`
- Flip the switch to "ON"

### 3. Create a release on GitHub
- Go to https://github.com/santosry/exposome-cerebrovascular-rj/releases
- Click "Create a new release"
- Tag version: `v1.0.0`
- Title: "v1.0.0 — Research Compendium"
- Describe the changes (use CHANGELOG content)
- Click "Publish release"

### 4. Zenodo will automatically archive
- After the release is published, Zenodo will automatically create an archive
- Go to https://zenodo.org/account/settings/github/ to check the status
- A DOI will be assigned automatically

### 5. Update the DOI
- Once the DOI is generated, update:
  - `CITATION.cff`: replace `doi: "a-depositar-via-Zenodo"` with the actual DOI
  - `README.md`: replace `doi: "em processo de deposito via Zenodo"` with the DOI badge

### 6. Add the DOI badge to README
```markdown
[![DOI](https://zenodo.org/badge/XXXXXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXXXXX)
```
Replace `XXXXXXXXXX` with your actual DOI suffix.

### Additional files to include in the deposit
The following files should be present in the GitHub release for Zenodo to archive:
- All source code (R/, config/, docker/)
- Documentation (README.md, CITATION.cff, docs/)
- Metadata (metadata/, COMPENDIUM_MANIFEST.yml)
- Key results (results/, figures/)
- Tests (tests/)

Files excluded from the deposit (via .gitignore):
- Raw data (data/raw/)
- Intermediate data (data/interim/)
- Large model objects (data/processed/*.rds)
- Execution logs (logs/)
- Article and presentation PDFs (reports/manuscript/, reports/presentations/)
