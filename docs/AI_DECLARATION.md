# Declaração de Uso de Inteligência Artificial

**Em conformidade com a Portaria CNPq nº 2.664, de 15 de maio de 2026**

---

## Identificação do Projeto

- **Título:** Exposição Climática e Afecções Cerebrovasculares no Rio de Janeiro (2010–2025): DLNM com Inferência Bayesiana Hierárquica
- **Pesquisador responsável:** Ryan de Paulo Santos
- **Equipe:** Camila Henriques Nunes, Karla Rangel Ribeiro, Enrique Medina-Acosta

---

## Tecnologias de IA Utilizadas — Uso Específico por Etapa

### DeepSeek v4-pro (DeepSeek AI)

| Etapa do Projeto | Descrição Específica do Uso | Arquivos/Componentes Gerados ou Modificados |
|---|---|---|
| **Refatoração do pipeline monolítico** | Transformação de `pipeline_DLNM_cerebrovascular_RJ_2010_2025.R` (~5.400 linhas em arquivo único) em arquitetura modular com 8 módulos independentes | `R/download.R`, `R/preprocessing.R`, `R/exposure_processing.R`, `R/dlnm_models.R`, `R/bayesian_models.R`, `R/reporting.R`, `R/visualization.R`, `R/utils.R` |
| **Documentação técnica** | Geração de fórmulas LaTeX para especificação dos modelos DLNM, GLM Quasi-Poisson e binomial negativa; redação da seção de metodologia estatística; criação do dicionário de dados e documentação FAIR | `docs/` (README científico, dicionário de dados), `config/config.R` (comentários técnicos) |
| **Estruturação do research compendium** | Organização de diretórios seguindo o padrão Turing Way; criação de Dockerfile, docker-compose.yml, Makefile | `docker/Dockerfile`, `docker/docker-compose.yml`, `Makefile` |
| **CI/CD e testes** | Criação de workflows de GitHub Actions para validação de código, testes unitários com testthat, e verificação de reprodutibilidade | `.github/workflows/`, `tests/` |
| **Geração de testes unitários** | Testes para funções de processamento de dados (parse_datasus_date, clean_cid3, normalize_municipio_key, etc.) e funções estatísticas (calibração de DLNM, validação bayesiana) | `tests/testthat/` |

### Codex (OpenAI)

| Etapa do Projeto | Descrição Específica do Uso | Arquivos/Componentes Gerados ou Modificados |
|---|---|---|
| **Assistência em funções epidemiológicas** | Sugestão de sintaxe para construção de crossbasis (`dlnm::crossbasis`), modelos GLM com distribuição Quasi-Poisson, fórmulas de offset populacional logarítmico, e estruturação de bases cruzadas com splines naturais | `R/dlnm_models.R`, `R/preprocessing.R` |
| **Debugging de scripts R** | Identificação e correção de erros em: (a) parse de datas do DATASUS com múltiplos formatos (ymd/dmy); (b) tratamento de encoding inválido em dados do INMET (Latin1 → UTF-8); (c) join espacial entre estações meteorológicas e macrorregiões de saúde | `R/download.R`, `R/exposure_processing.R`, `R/utils.R` |
| **Padrões de código para data lineage** | Implementação de funções de auditoria (`write_audit`, `assert_no_bad_encoding_object`, `record_parse_failures`) que registram a proveniência e transformações dos dados | `R/utils.R`, `config/config.R` |

### ChatGPT 5.5 (OpenAI)

| Etapa do Projeto | Descrição Específica do Uso | Produto Entregue |
|---|---|---|
| **Auditoria técnica completa (14 etapas)** | Revisão sistemática de: (1) integridade dos downloads DATASUS, (2) qualidade das estações INMET, (3) mapeamento município→macrorregião, (4) consistência das séries temporais, (5) especificação dos DLNMs, (6) convergência dos modelos, (7) validação bayesiana, (8) análise de sensibilidade, (9) autocorrelação espacial (Moran's I — implementado via spdep::moran.test com matriz de vizinhança queen das 9 macrorregiões), (10) case-crossover validation, (11) estabilidade temporal (lag sensitivity), (12) sensibilidade a priors, (13) figuras e tabelas, (14) reprodutibilidade computacional | `audit/` (relatórios de auditoria), `04_AUDITORIA/` |
| **Benchmarking internacional** | Comparação da metodologia com padrões de publicação: *The Lancet* (checklist STROBE para estudos observacionais), *Nature* (diretrizes de reprodutibilidade), FAIR Principles (Findable, Accessible, Interoperable, Reusable), Turing Way (boas práticas de research software engineering) | `docs/AI_DECLARATION.md` (este documento), `audit/benchmark/` |
| **Relatórios executivos** | Geração de sumários executivos em português e inglês para cada etapa da auditoria, com identificação de riscos, falhas e recomendações priorizadas | `reports/` |
| **Tradução e revisão de documentação** | Tradução de documentação técnica (PT→EN) para submissão internacional; revisão gramatical e adequação ao estilo científico | `README.md` (EN), `docs/` (documentação bilíngue) |
| **Checklists de conformidade** | Elaboração de checklists de verificação para: STROBE (Strengthening the Reporting of Observational Studies in Epidemiology), RECORD (REporting of studies Conducted using Observational Routinely-collected health Data), TRIPOD (Transparent Reporting of a multivariable prediction model for Individual Prognosis Or Diagnosis) | `docs/` (checklists de conformidade) |
| **Roadmap de melhoria** | Sugestão de melhorias futuras baseadas nos achados da auditoria, incluindo: ampliação do grid de splines, inclusão de PM2.5 como covariável, validação com dados de outras UFs, e publicação em repositório de dados abertos | `docs/ROADMAP.md` |

### Script Python de Extração de PM2.5 (DeepSeek v4-pro + ChatGPT 5.5)

| Etapa | Descrição Específica | Arquivo |
|---|---|---|
| **Captura de dados Power BI** | DeepSeek gerou a estrutura de interceptação de API REST via Playwright; ChatGPT 5.5 auxiliou na depuração dos seletores de espera (`wait_for_selector`) e no tratamento de fallback entre navegadores (Chrome, Edge, Chromium) | `python/extrair_mp25_rj.py` |
| **Extração e parsing** | DeepSeek gerou o parser dos dados da API do Power BI (JSON → DataFrame), incluindo mapeamento de schemas variáveis (3 a 7 colunas) e normalização de nomes de municípios | `python/extrair_mp25_rj.py` |
| **Atribuição por vizinho mais próximo** | DeepSeek implementou o algoritmo de distância euclidiana LAT/LON para atribuir PM2.5 aos 18 municípios sem monitoramento, usando coordenadas IBGE 2022 | `python/extrair_mp25_rj.py` |
| **Downscaling temporal** | ChatGPT 5.5 sugeriu o modelo de downscaling proporcional (PM25_mun × PM25_nac / PM25_medio_nac) e a extrapolação linear para 2025 | `python/extrair_mp25_rj.py` |

---

## Natureza do Uso

As tecnologias de IA foram empregadas como **ferramentas de suporte técnico e científico**, atuando como assistentes para:

1. **Refatoração de código:** Transformação de script monolítico (~5.400 linhas) em arquitetura modular com 8 módulos independentes, Docker, CI/CD e testes automatizados
2. **Documentação:** Geração de documentação FAIR, dicionário de dados, data lineage, fórmulas matemáticas em LaTeX, e README científico
3. **Auditoria de qualidade:** Análise crítica independente de todas as etapas do projeto, identificação de falhas, riscos e oportunidades de melhoria
4. **Conformidade:** Verificação de aderência a diretrizes internacionais (STROBE, RECORD, TRIPOD, FAIR Principles, Turing Way)
5. **Infraestrutura computacional:** Criação de Dockerfile, docker-compose, Makefile, pipeline targets, e workflows de CI/CD
6. **Extração de dados ambientais:** Coleta de dados de PM2.5 do dashboard Power BI do INEA/MonitorAr via Playwright, com downscaling temporal 2010–2025

**Todas as decisões científicas, metodológicas e analíticas** — incluindo a escolha dos modelos DLNM, definição de parâmetros (lags, splines, priors bayesianos), interpretação dos resultados e validação epidemiológica — **foram tomadas exclusivamente pelos pesquisadores humanos**. As IAs não geraram hipóteses, não selecionaram variáveis, não interpretaram resultados clínicos e não redigiram conclusões científicas.

---

## Validação Humana

Todo o código gerado ou modificado com auxílio de IA foi revisado, testado e validado pelos pesquisadores. Os resultados das análises estatísticas foram conferidos manualmente. A documentação técnica foi verificada quanto à correção conceitual e adequação ao domínio da epidemiologia ambiental.

---

## Ambiente Computacional — Reprodutibilidade Total

### R (versão 4.6.0)

Pacotes utilizados no research compendium, com versões exatas registradas no `renv.lock`:

| Pacote | Versão | Finalidade |
|---|---|---|
| microdatasus | 2.5.0 | Download de dados SIH-RD e SIM-DO do DATASUS |
| BrazilMet | 0.4.0 | Download de dados meteorológicos das estações INMET |
| dlnm | 2.4.10 | Modelos de defasagem distribuída não-linear (DLNM) |
| MASS | 7.3-65 | GLM binomial negativa para sobredispersão |
| mgcv | 1.9-4 | Modelos aditivos generalizados (splines) |
| lmtest | 0.9-40 | Testes de diagnóstico para modelos lineares |
| sandwich | 3.1-1 | Erros-padrão robustos Newey-West HAC |
| survival | 3.8-6 | Análise de sobrevivência (validação case-crossover) |
| tidyverse | 2.0.0 | Ecossistema de manipulação e visualização de dados |
| dplyr | 1.2.1 | Manipulação de data frames |
| tidyr | 1.3.2 | Organização de dados (pivotagem) |
| readr | 2.2.0 | Leitura e escrita de CSVs |
| stringr | 1.6.0 | Manipulação de strings |
| stringi | 1.8.7 | Operações de string com suporte a Unicode |
| lubridate | 1.9.5 | Manipulação de datas |
| ggplot2 | 4.0.3 | Visualização de dados |
| patchwork | 1.3.2 | Composição de múltiplos gráficos |
| scales | 1.4.0 | Formatação de escalas em gráficos |
| ggrepel | —¹ | Rótulos não-sobrepostos em gráficos |
| plotly | 4.12.0 | Gráficos interativos 3D (superfícies RR) |
| htmlwidgets | 1.6.4 | Base para widgets HTML interativos |
| jsonlite | 2.0.0 | Parsing de JSON (APIs IBGE e SIDRA) |
| httr | 1.4.8 | Requisições HTTP |
| janitor | 2.2.1 | Limpeza de nomes de colunas e dados |
| data.table | 1.18.4 | Manipulação eficiente de grandes data frames |
| sidrar | 0.2.9 | Download de dados populacionais do SIDRA/IBGE |
| geobr | 1.9.1 | Download de geometrias municipais do IBGE |
| sf | 1.1-0 | Operações espaciais (Simple Features) |
| spdep | —¹ | Análise de autocorrelação espacial (teste de Moran) |
| igraph | 2.3.0 | Grafos para análise de vizinhança espacial |
| zoo | 1.8-15 | Séries temporais regulares e irregulares |
| knitr | 1.51 | Geração de relatórios dinâmicos |
| rmarkdown | 2.31 | Documentos R Markdown |
| kableExtra | —¹ | Tabelas formatadas em LaTeX/HTML |
| DT | —¹ | Tabelas interativas |
| pheatmap | —¹ | Heatmaps estáticos |
| splines | —² | Splines naturais (base R, incluso no R 4.6.0) |
| s2 | 1.1.9 | Geometria esférica para cálculos de distância |
| terra | 1.9-27 | Operações raster para dados geoespaciais |
| units | 1.0-1 | Conversão de unidades de medida |
| targets | 1.12.0 | Pipeline de workflow reprodutível |
| tarchetypes | 0.14.1 | Arquétipos para targets |
| testthat | —¹ | Testes unitários |
| broom | 1.0.12 | Sumarização de modelos estatísticos |
| tsModel | 0.6-2 | Estruturas de defasagem para séries temporais |
| read.dbc | 1.2.0 | Leitura de arquivos DBC do DATASUS |
| checkmate | 2.3.4 | Validação de argumentos de função |
| Rcpp | 1.1.1-1.1 | Interface R/C++ (dependência de baixo nível) |
| Matrix | 1.7-5 | Matrizes esparsas e densas |
| DBI | 1.3.0 | Interface de banco de dados R |
| KernSmooth | 2.23-26 | Suavização por kernel |
| class | 7.3-23 | Classificação (dependência de MASS) |
| classInt | 0.4-11 | Classificação de intervalos |
| e1071 | 1.7-17 | Funções estatísticas auxiliares |
| proxy | 0.4-29 | Matrizes de distância/proximidade |
| wk | 0.9.5 | Manipulação de geometrias well-known |
| uuid | 1.2-2 | Geração de identificadores únicos |

> ¹ Pacote com versão registrada apenas como dependência transitiva no `renv.lock`. A versão exata pode ser obtida com `renv::restore()`.
> ² `splines` é um pacote base do R, incluído na instalação padrão. A versão corresponde à do R 4.6.0.

### Python (versão 3.x)

Pacotes utilizados exclusivamente para extração de dados de PM2.5:

| Pacote | Versão | Finalidade |
|---|---|---|
| playwright | 1.60.0 | Automação de navegador para captura de dados do dashboard Power BI do INEA/MonitorAr |
| pandas | 3.0.3 | Manipulação e exportação de dados tabulares (CSV) |
| numpy | 2.4.6 | Operações numéricas (regressão linear para extrapolação 2025, distâncias euclidianas) |

Requisitos mínimos: `playwright>=1.40.0`, `pandas>=2.0.0`, `numpy>=1.24.0` (conforme `python/requirements.txt`).

---

## Responsabilidade

Os autores assumem integral responsabilidade pelo conteúdo científico, pela acurácia dos dados, pela validade das análises e pelas conclusões apresentadas neste trabalho, independentemente do uso de tecnologias de IA como ferramentas auxiliares.

---

**Data:** 20 de junho de 2026

**Referência:** BRASIL. Conselho Nacional de Desenvolvimento Científico e Tecnológico. Portaria nº 2.664, de 15 de maio de 2026. Dispõe sobre a declaração de uso de tecnologias de inteligência artificial em pesquisas financiadas pelo CNPq.
