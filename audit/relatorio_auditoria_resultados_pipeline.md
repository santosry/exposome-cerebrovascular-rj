# RELATÓRIO DE AUDITORIA — RESULTADOS DO PIPELINE DLNM (ATUALIZADO)
## Gerado em: 2026-06-21 13:30
### Repositório: https://github.com/santosry/exposome-cerebrovascular-rj

---

## 1. FDR — SIGNIFICÂNCIA ESTATÍSTICA (JÁ APLICADA)

A correção Benjamini-Hochberg (FDR) está aplicada na coluna `p_associacao_fdr` 
da tabela `tabela_auc_rr_dlnm_macrorregiao.csv`. 

**Resultados:**

| Classe FDR | N | % |
|---|---|---|
| fdr_significativo | 18 | 14.1% |
| p_nominal | 44 | 34.4% |
| nao_sustentado | 40 | 31.2% |
| cautela_convergencia | 26 | 20.3% |
| **Total** | **128** | **100%** |

### 18 modelos FDR-significativos (p < 0.05 após correção BH)

| Macrorregião | Desfecho | Exposição | RRmax | FDR p |
|---|---|---|---|---|
| Medio Paraiba | internacoes_i60_i69 | temp_med | 1.36 | 0.0000 |
| Medio Paraiba | internacoes_i60_i69 | ur_med | 1.65 | 0.0000 |
| Metropolitana I | internacoes_i60_i69 | temp_med | 1.40 | 0.0019 |
| Metropolitana I | obitos_i60_i69 | temp_med | 1.29 | 0.0000 |
| Metropolitana I | internacoes_i60_i64 | temp_med | 1.33 | 0.0000 |
| Metropolitana I | obitos_i60_i64 | temp_med | 1.23 | 0.0000 |
| Metropolitana I | internacoes_i60_i69 | ur_med | 1.59 | 0.0440 |
| Metropolitana I | internacoes_i60_i64 | ur_med | 1.20 | 0.0001 |
| Norte | internacoes_i60_i69 | temp_med | 1.91 | 0.0000 |
| Norte | internacoes_i60_i69 | ur_med | 1.91 | 0.0047 |
| Serrana | internacoes_i60_i69 | temp_med | 1.79 | 0.0000 |
| Serrana | internacoes_i60_i69 | ur_med | 1.59 | 0.0000 |
| Noroeste | internacoes_i60_i69 | temp_med | 2.26 | 0.0153 |
| Noroeste | internacoes_i60_i64 | temp_med | 1.89 | 0.0195 |
| Medio Paraiba | obitos_i60_i64 | temp_med | 1.92 | 0.0190 |
| Metropolitana II | internacoes_i60_i64 | temp_med | 1.14 | 0.0359 |
| Metropolitana II | internacoes_i60_i62 | ur_med | 1.72 | 0.0131 |
| Metropolitana I | internacoes_i60_i62 | temp_med | 1.47 | 0.0223 |

---

## 2. PM2.5 — STATUS

**PM2.5 NÃO foi incluído nos modelos acima** (`DLNM_ENABLE_AIR_QUALITY=false`).

Para rodar COM PM2.5:
```bash
cd C:\Users\oorie\OneDrive\Documentos\TRABALHOS\DLNM\05_publicacao_github
$env:DLNM_ENABLE_AIR_QUALITY = "true"
Rscript run_pipeline.R
```

**Correções aplicadas para viabilizar a execução:**
- `R/download.R`: `BrazilMet::download_brazil_met` → `BrazilMet::download_AWS_INMET_daily` (API mudou)
- `R/download.R`: `BrazilMet::read_brazil_met` → `readr::read_delim` (função removida)
- `data/raw/inmet_zip/`: 16 arquivos ZIP restaurados como fallback
- `.gitignore`: exceção `!data/raw/inmet_zip/*.zip` adicionada

---

## 3. RESUMO EXECUTIVO

| Métrica | Valor |
|---|---|
| Modelos DLNM | 128 combinações (9 macros × 8 desfechos × 2 exposições) |
| FDR-significativos | 18 (14.1%) |
| Macrorregiões com achados | Médio Paraíba, Metropolitana I, Metropolitana II, Noroeste, Norte, Serrana |
| Exposição mais associada | temp_med (12/18) vs ur_med (6/18) |
| Desfecho mais sensível | internações I60-I69 (8/18) |
| RRmax mais alto | 2.26 (Noroeste, internações, temp_med) |
| PM2.5 | Não incluído — disponível para re-execução |
| Autocorrelação residual | >89% modelos (lag 14+) — HAC Newey-West (21 lags) aplicado |
