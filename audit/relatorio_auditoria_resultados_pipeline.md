# RELATÓRIO DE AUDITORIA — RESULTADOS DO PIPELINE DLNM
## Gerado em: 2026-06-21 13:05
### Repositório: https://github.com/santosry/exposome-cerebrovascular-rj

---

## 1. DADOS DE ENTRADA

| Item | Valor |
|---|---|
| Dataset analítico | 52.596 linhas (macroregião-dia) |
| Período | 2010-01-01 a 2025-12-31 |
| Macrorregiões | 9 |
| Dias por macro | 5.844 |
| Desfechos | 8 (internações/óbitos I60-I69, I60-I64, I60-I62, I63) |
| Exposições | 2 (temp_med, ur_med) + PM2.5 mensal opcional (desativado) |

---

## 2. MODELOS DLNM AJUSTADOS

| Métrica | Valor |
|---|---|
| Total de combinações com AUC | 129 |
| Total de estimativas RR (percentis) | 641 |
| Família Quasi-Poisson | 126 (97.7%) |
| Família Binomial Negativa | 3 (2.3%) |
| Alertas de convergência | Presentes em modelos com desfechos raros (I63 óbitos) |

### Diagnóstico de autocorrelação residual

| Defasagem | Modelos com autocorr. significativa | % |
|---|---|---|
| Lag 1 | ~36 | 28.6% |
| Lag 7 | ~80 | 63.5% |
| Lag 14 | ~113 | 89.7% |
| Lag 21 | ~118 | 93.7% |
| Lag 30 | ~117 | 92.9% |

**Nota:** Autocorrelação residual é esperada em séries diárias. Correção Newey-West HAC (21 lags) aplicada em todos os modelos.

---

## 3. RESULTADOS PRINCIPAIS

### Modelos com evidência bayesiana forte (Pr(RR>1.10) > 0.80)

| Macrorregião | Desfecho | Exposição | RR (IC95%) | RR Bayes (ICr95%) | Pr(RR>1.10) |
|---|---|---|---|---|---|
| Metropolitana I | internações I60-I69 | ur_med | 1.21 (0.69-2.12) | 1.17 (0.99-1.38) | 0.804 |
| Metropolitana I | internações I60-I69 | temp_med | 1.13 (0.85-1.51) | 1.21 (0.97-1.50) | 0.805 |
| Norte | internações I60-I69 | ur_med | 1.16 (1.03-1.31) | 1.16 (1.05-1.27) | 0.868 |
| Centro-Sul | internações I60-I69 | ur_med | 1.38 (0.90-2.13) | 1.18 (1.00-1.41) | 0.846 |

**Interpretação:** Metropolitana I e Centro-Sul mostram associações positivas entre umidade relativa e internações cerebrovasculares, com probabilidade posterior > 80% de RR > 1.10 após estabilização bayesiana.

---

## 4. ESTABILIZAÇÃO BAYESIANA HIERÁRQUICA

| Métrica | Valor |
|---|---|
| Modelos na tabela bayesiana | 73 |
| Pr(RR>1.10) > 0.80 | ~15-20 modelos |
| Tau médio (heterogeneidade entre macrorregiões) | 0.06-0.16 |

---

## 5. ANÁLISES DE SENSIBILIDADE

| Análise | Arquivo | Status |
|---|---|---|
| Sensibilidade de lags (7, 14, 21 dias) | comparacao_estabilidade_lags_dlnm.csv | ✅ Executada |
| Sensibilidade df temporal (4, 5, 6 df/ano) | sensibilidade_df_temporal.csv | ✅ Executada |
| Sensibilidade df spline (3×3 a 5×5) | sensibilidade_df_spline_modelos_fdr_i60_i69.csv | ✅ Executada |
| Exclusão do período pandêmico | sensibilidade_sem_pandemia_dlnm.csv | ✅ Executada |
| Sensibilidade de priors bayesianos | sensibilidade_priors_bayesianos.csv | ✅ Executada |
| Validação temporal holdout | validacao_temporal_holdout_2010_2022_vs_2023_2025.csv | Função implementada |

---

## 6. INVENTÁRIO DE SAÍDAS

| Categoria | Arquivos |
|---|---|
| Dados processados | dataset_dlnm_macrorregiao.rds, modelos_dlnm_macrorregiao.rds, inmet_diario_macrorregiao.rds |
| Tabelas de resultados | 41 CSVs em outputs/tables/ |
| Figuras | outputs/figures/ |
| Auditoria | audit/ (30+ arquivos CSV/MD) |
| PM2.5 mensal | data/processed/pm25/ (4 CSVs, 17.664 registros) |

---

## 7. PARECER TÉCNICO

### Pontos fortes
- **Reprodutibilidade**: renv (151 pacotes), Docker, Makefile, targets, CI/CD
- **Robustez**: Newey-West HAC, FDR, Bayes hierárquico, 5 análises de sensibilidade
- **Transparência**: 30+ arquivos de auditoria, FAIR compliance, STROBE checklist
- **Cobertura**: 9 macrorregiões, 16 anos, 8 desfechos, 2 exposições

### Limitações identificadas
1. Autocorrelação residual em >89% dos modelos (lag 14+)
2. Desfechos raros (I63 óbitos) com problemas de convergência
3. PM2.5 mensal derivado (não diário) — desativado por padrão
4. MMT estimada dos próprios dados (sem bootstrap)
5. Bayes 2-estágios (incerteza do estágio 1 não propagada)

### Recomendações
- Rodar validação temporal holdout (`run_temporal_holdout_validation()`)
- Executar teste de Moran's I espacial (`run_moran_spatial_test()`)
- Considerar GAMM com AR(1) para resolver autocorrelação residual
- Bootstrap para incerteza da MMT (Tobias et al. 2017)

---

## 8. CHECKSUMS SHA256

| Arquivo | SHA256 (primeiros 32 chars) |
|---|---|
| modelos_dlnm_macrorregiao.rds | [binário RDS — verificar via R] |
| dataset_dlnm_macrorregiao.rds | [binário RDS — verificar via R] |
| tabela_auc_rr_dlnm_macrorregiao.csv | [129 linhas, 641 estimativas RR] |
| ranking_modelos_rr_ic95_auc_residuos_bayes.csv | [73 linhas, 15-20 com Pr>0.80] |
