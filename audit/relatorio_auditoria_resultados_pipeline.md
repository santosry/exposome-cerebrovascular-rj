# RELATÓRIO DE AUDITORIA — RESULTADOS COMPLETOS DO PIPELINE DLNM
## Gerado em: 2026-06-21 14:05
### FDR com notação científica | PM2.5 pronto para execução
### https://github.com/santosry/exposome-cerebrovascular-rj

---

## 1. FDR — SIGNIFICÂNCIA ESTATÍSTICA (Benjamini-Hochberg)

A correção FDR está aplicada em `p_associacao_fdr` na tabela
`outputs/tables/tabela_auc_rr_dlnm_macrorregiao.csv`.

**Distribuição das 128 combinações testadas:**

| Classe FDR | N | % |
|---|---|---|
| `fdr_significativo` (p < 0.05) | 18 | 14.1% |
| `p_nominal` (p nominal < 0.05, FDR > 0.05) | 44 | 34.4% |
| `nao_sustentado` | 40 | 31.2% |
| `cautela_convergencia` | 26 | 20.3% |

---

## 2. 18 MODELOS FDR-SIGNIFICATIVOS (p < 0.05 após correção BH)

### Achados de alta confiança (FDR p < 1×10⁻⁶)

| Macrorregião | Desfecho | Exposição | RRmax | FDR p |
|---|---|---|---|---|
| Norte | internações I60-I69 | temp_med | 1.91 | **4.92×10⁻¹⁹** |
| Serrana | internações I60-I69 | temp_med | 1.79 | **2.13×10⁻¹⁴** |
| Serrana | internações I60-I69 | ur_med | 1.59 | **3.69×10⁻¹⁴** |
| Metropolitana I | internações I60-I64 | temp_med | 1.33 | **1.13×10⁻¹⁰** |
| Metropolitana I | óbitos I60-I69 | temp_med | 1.29 | **1.71×10⁻¹⁰** |

### Achados de confiança moderada (10⁻⁶ < FDR p < 0.01)

| Macrorregião | Desfecho | Exposição | RRmax | FDR p |
|---|---|---|---|---|
| Médio Paraíba | internações I60-I69 | ur_med | 1.65 | **4.08×10⁻⁷** |
| Médio Paraíba | internações I60-I69 | temp_med | 1.36 | **3.70×10⁻⁶** |
| Metropolitana I | óbitos I60-I64 | temp_med | 1.23 | **4.55×10⁻⁶** |
| Metropolitana I | internações I60-I64 | ur_med | 1.20 | **8.89×10⁻⁵** |

### Achados com significância limítrofe (0.01 < FDR p < 0.05)

| Macrorregião | Desfecho | Exposição | RRmax | FDR p |
|---|---|---|---|---|
| Metropolitana I | internações I60-I69 | temp_med | 1.40 | 1.90×10⁻³ |
| Norte | internações I60-I69 | ur_med | 1.91 | 4.70×10⁻³ |
| Metropolitana II | internações I60-I62 | ur_med | 1.72 | 1.31×10⁻² |
| Noroeste | internações I60-I69 | temp_med | 2.26 | 1.53×10⁻² |
| Médio Paraíba | óbitos I60-I64 | temp_med | 1.92 | 1.90×10⁻² |
| Noroeste | internações I60-I64 | temp_med | 1.89 | 1.95×10⁻² |
| Metropolitana I | internações I60-I62 | temp_med | 1.47 | 2.23×10⁻² |
| Metropolitana II | internações I60-I64 | temp_med | 1.14 | 3.59×10⁻² |
| Metropolitana I | internações I60-I69 | ur_med | 1.59 | 4.40×10⁻² |

---

## 3. RESUMO POR MACRORREGIÃO

| Macrorregião | Modelos FDR-sig | Principais achados |
|---|---|---|
| **Metropolitana I** | 6 | Ambas exposições, múltiplos desfechos (I60-I69, I60-I64, I60-I62, óbitos) |
| Médio Paraíba | 3 | Internações + óbitos, ambas exposições |
| Norte | 2 | Internações I60-I69, ambas exposições (RRmax=1.91) |
| Serrana | 2 | Internações I60-I69, ambas exposições |
| Noroeste | 2 | Internações, temp_med (RRmax=2.26) |
| Metropolitana II | 2 | Internações I60-I62/I64 |

---

## 4. PM2.5 — CONFIGURAÇÃO PARA EXECUÇÃO

**Status atual:** PM2.5 NÃO incluído nos resultados acima (`DLNM_ENABLE_AIR_QUALITY=false`).

**Para rodar o pipeline completo COM PM2.5:**
```powershell
cd C:\Users\oorie\OneDrive\Documentos\TRABALHOS\DLNM\05_publicacao_github
$env:DLNM_ENABLE_AIR_QUALITY = "true"
Rscript run_pipeline.R
```

**Correções já aplicadas no código:**
- `R/download.R`: `BrazilMet::download_brazil_met` → `download_AWS_INMET_daily`
- `R/download.R`: `BrazilMet::read_brazil_met` → `readr::read_delim`
- `.gitignore`: exceções para `data/raw/inmet_zip/*.zip`
- `data/raw/inmet_zip/`: 16 zips INMET como fallback

**O que muda com PM2.5 ativo:**
- `process_poluentes()` carrega `mp25_macroregiao_mensal_2010_2025.csv` (1728 linhas)
- Cada modelo DLNM inclui `+ pm25_mensal` como termo linear
- ~2-4 horas de execução total (192 SIH + 111 SIM + 26 INMET + 144 DLNMs)

---

## 5. CHECKS DE INTEGRIDADE

| Check | Status |
|---|---|
| FDR aplicado (BH, 128 testes) | ✅ |
| HAC Newey-West (21 lags) | ✅ |
| Quasi-Poisson / NB fallback | ✅ |
| MMT centering | ✅ |
| Diagnóstico Ljung-Box | ✅ |
| Moran's I espacial | ✅ Implementado |
| Validação temporal holdout | ✅ Implementado |
| Sensibilidade (5 análises) | ✅ |
| PM2.5 mensal (17.664 registros) | ⚠️ Não incluído — rodar com flag |
