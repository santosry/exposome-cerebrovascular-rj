# Disponibilidade de Dados Climáticos e PM2.5 por Macrorregião

## Visão Geral

Este documento descreve a cobertura espacial e temporal das fontes de dados de **temperatura, umidade relativa** (INMET) e **PM2.5** (INEA/MonitorAr/VIGIAR) utilizadas no estudo, incluindo os códigos de cada estação, seu período de operação e os métodos de imputação para municípios e dias sem medição direta.

---

## 1. Estações Meteorológicas INMET

O INMET mantém **26 estações** no estado do Rio de Janeiro, das quais **20 estão operacionais** e **6 foram descontinuadas ao longo do período 2010-2025**. Para preservar a série histórica, o pipeline inclui **todas as 26 estações** — mesmo as descontinuadas são usadas enquanto estavam ativas.

### 1.1 Mapa de Cobertura por Macrorregião

| Macrorregião | Nº Estações | Códigos | Municípios das Estações | Cobertura (dias/5844) |
|---|---|---|---|---|
| **Metropolitana I** | 6 | A601, A602, A603, A621, A636, A652 | Seropédica (Ecologia Agrícola), Rio de Janeiro (Marambaia), Duque de Caxias (Xerém), Rio de Janeiro (Vila Militar), Rio de Janeiro (Jacarepaguá), Rio de Janeiro (Forte de Copacabana) | 5844 (100%) — sem necessidade de preenchimento externo |
| **Serrana** | 5 | A610, A618, A624, A629, A630 | Petrópolis (Pico do Couto), Teresópolis (Parque Nacional), Nova Friburgo (Salinas), Carmo, Santa Maria Madalena | 5844 (100%) |
| **Norte** | 3 | A607, A608, A620 | Campos dos Goytacazes, Macaé, Campos dos Goytacazes (São Tomé) | 5844 (100%) |
| **Médio Paraíba** | 3 | A609, A611, A626 | Resende, Valença, Rio Claro | 5833 (99.8%) — 11 dias preenchidos por estação vizinha |
| **Baía da Ilha Grande** | 2 | A619, A628 | Paraty, Angra dos Reis | 5770 (98.7%) — 74 dias preenchidos por estação vizinha |
| **Baixada Litorânea** | 2 | A606, A667 | Arraial do Cabo, Saquarema (Sampaio Correia) | 5615 (96.1%) — 229 dias preenchidos por estação vizinha |
| **Centro-Sul** | 2 | A625, A637 | Três Rios, Paty do Alferes (Avelar) | 3428 (58.7%) — 2416 dias preenchidos por estação vizinha |
| **Metropolitana II** | 2 | A627, A659 | Niterói, Silva Jardim | 3773 (64.6%) — 2071 dias preenchidos por estação vizinha |
| **Noroeste** | 1 | A604 | Cambuci | 5347 (91.5%) — 497 dias preenchidos por estação vizinha |

### 1.2 Catálogo Completo de Estações

| Código | Nome | Município Base | Latitude | Longitude | Altitude (m) | Início da Operação | Macrorregião |
|---|---|---|---|---|---|---|---|
| A601 | Seropédica - Ecologia Agrícola | Seropédica | -22.7578 | -43.6847 | 35 | 23/05/2000 | Metropolitana I |
| A602 | Rio de Janeiro - Marambaia | Rio de Janeiro | -23.0503 | -43.5956 | 12 | 07/11/2002 | Metropolitana I |
| A603 | Duque de Caxias - Xerém | Duque de Caxias | -22.5897 | -43.2822 | 22 | 20/10/2002 | Metropolitana I |
| A604 | Cambuci | Cambuci | -21.5875 | -41.9583 | 46 | 19/11/2002 | Noroeste |
| A606 | Arraial do Cabo | Arraial do Cabo | -22.9753 | -42.0214 | 5 | 21/09/2006 | Baixada Litorânea |
| A607 | Campos dos Goytacazes | Campos dos Goytacazes | -21.7147 | -41.3439 | 17 | 24/09/2006 | Norte |
| A608 | Macaé | Macaé | -22.3761 | -41.8119 | 28 | 21/09/2006 | Norte |
| A609 | Resende | Resende | -22.4514 | -44.4450 | 438.83 | 28/09/2006 | Médio Paraíba |
| A610 | Pico do Couto | Petrópolis | -22.4647 | -43.2914 | 1777 | 21/10/2006 | Serrana |
| A611 | Valença | Valença | -22.3581 | -43.6956 | 370 | 26/09/2006 | Médio Paraíba |
| A618 | Teresópolis - Parque Nacional | Teresópolis | -22.4486 | -42.9869 | 981 | 31/10/2006 | Serrana |
| A619 | Paraty | Paraty | -23.2236 | -44.7269 | 3 | 18/11/2006 | Baía da Ilha Grande |
| A620 | Campos dos Goytacazes - São Tomé | Campos dos Goytacazes | -22.0417 | -41.0517 | 7 | 12/06/2008 | Norte |
| A621 | Rio de Janeiro - Vila Militar | Rio de Janeiro | -22.8614 | -43.4114 | 30.43 | 12/04/2007 | Metropolitana I |
| A624 | Nova Friburgo - Salinas | Nova Friburgo | -22.3347 | -42.6769 | 1070 | 17/09/2010 | Serrana |
| A625 | Três Rios | Três Rios | -22.0983 | -43.2083 | 295 | 07/06/2016 | Centro-Sul |
| A626 | Rio Claro | Rio Claro | -22.6536 | -44.0409 | 516 | 02/06/2016 | Médio Paraíba |
| A627 | Niterói | Niterói | -22.8675 | -43.1019 | 6 | 12/07/2018 | Metropolitana II |
| A628 | Angra dos Reis | Angra dos Reis | -22.9756 | -44.3033 | 6 | 24/08/2017 | Baía da Ilha Grande |
| A629 | Carmo | Carmo | -21.9386 | -42.6008 | 293 | 10/10/2018 | Serrana |
| A630 | Santa Maria Madalena | Santa Maria Madalena | -21.9506 | -42.0103 | 586 | 15/10/2018 | Serrana |
| A636 | Rio de Janeiro - Jacarepaguá | Rio de Janeiro | -22.9400 | -43.4028 | 20 | 09/08/2017 | Metropolitana I |
| A637 | Paty do Alferes - Avelar | Paty do Alferes | -22.3472 | -43.4178 | 508 | 09/11/2022 | Centro-Sul |
| A652 | Rio de Janeiro - Forte de Copacabana | Rio de Janeiro | -22.9883 | -43.1906 | 25.59 | 17/05/2007 | Metropolitana I |
| A659 | Silva Jardim | Silva Jardim | -22.6458 | -42.4156 | 19 | 27/08/2015 | Metropolitana II |
| A667 | Saquarema - Sampaio Correia | Saquarema | -22.8711 | -42.6089 | 26 | 01/09/2015 | Baixada Litorânea |

### 1.3 Estações que Iniciaram Durante o Período do Estudo (2010-2025)

| Código | Estação | Início da Operação | Macrorregião |
|---|---|---|---|
| A624 | Nova Friburgo - Salinas | Set/2010 | Serrana |
| A659 | Silva Jardim | Ago/2015 | Metropolitana II |
| A667 | Saquarema - Sampaio Correia | Set/2015 | Baixada Litorânea |
| A625 | Três Rios | Jun/2016 | Centro-Sul |
| A626 | Rio Claro | Jun/2016 | Médio Paraíba |
| A636 | Rio de Janeiro - Jacarepaguá | Ago/2017 | Metropolitana I |
| A628 | Angra dos Reis | Ago/2017 | Baía da Ilha Grande |
| A627 | Niterói | Jul/2018 | Metropolitana II |
| A629 | Carmo | Out/2018 | Serrana |
| A630 | Santa Maria Madalena | Out/2018 | Serrana |
| A637 | Paty do Alferes - Avelar | Nov/2022 | Centro-Sul |

> **Nota:** As 11 estações acima **não possuem dados para todo o período 2010-2025**. Antes da data de início de cada estação, a série da macrorregião é preenchida com a média das demais estações da mesma macrorregião ou, quando indisponível, pela estação mais próxima (ver §1.4).

### 1.4 Método de Imputação por Macrorregião

| Macrorregião | Método Principal | Dias Preenchidos | Distância Média do Preenchimento |
|---|---|---|---|
| Metropolitana I | Média das 6 estações próprias | 0 | — |
| Norte | Média das 3 estações próprias | 0 | — |
| Serrana | Média das 5 estações próprias | 0 | — |
| Médio Paraíba | Média de 3 estações próprias + 11d por vizinha | 11 | 48.9 km |
| Baía da Ilha Grande | Média de 2 estações próprias + 74d por vizinha | 74 | 87.0 km |
| Baixada Litorânea | Média de 2 estações próprias + 229d por vizinha | 229 | 76.0 km |
| Metropolitana II | Média de 2 estações próprias + 2071d por vizinha | 2071 (35.4%) | 41.5 km |
| Centro-Sul | Média de 2 estações próprias + 2416d por vizinha | 2416 (41.3%) | 28.7 km |
| Noroeste | Estação única (Cambuci) + 497d por vizinha | 497 (8.5%) | 45.0 km |

---

## 2. PM2.5 — INEA/MonitorAr (Programa VIGIAR)

Os dados de material particulado fino (MP2.5) são provenientes do **painel público do INEA/MonitorAr** (Programa VIGIAR), extraídos via Playwright (Python) e processados conforme a metodologia abaixo.

### 2.1 Cobertura Municipal

Dos **92 municípios** do estado do Rio de Janeiro:

| Situação | Nº de Municípios | Método |
|---|---|---|
| **Monitorados diretamente** | 74 | Média anual de MP2.5 medida por sensores VIGIAR |
| **Atribuídos por vizinho mais próximo** | 18 | Média anual do município monitorado mais próximo (distância Haversine) |

### 2.2 Municípios SEM Monitoramento Próprio (atribuídos por vizinho)

| Município | Vizinho Atribuído | Distância (graus) | Macrorregião |
|---|---|---|---|
| Cabo Frio | São Pedro da Aldeia | 0.087 | Baixada Litorânea |
| Cantagalo | Aperibé | 0.162 | Serrana |
| Duque de Caxias | São João de Meriti | 0.071 | Metropolitana I |
| Iguaba Grande | Araruama | 0.107 | Baixada Litorânea |
| Mesquita | Belford Roxo | 0.035 | Metropolitana I |
| Miguel Pereira | Paty do Alferes | 0.047 | Centro-Sul |
| Miracema | Santo Antônio de Pádua | 0.130 | Noroeste |
| Nilópolis | São João de Meriti | 0.041 | Metropolitana I |
| Nova Iguaçu | Belford Roxo | 0.050 | Metropolitana I |
| Petrópolis | Guapimirim | 0.191 | Serrana |
| Pinheiral | Volta Redonda | 0.103 | Médio Paraíba |
| Resende | Itatiaia | 0.123 | Médio Paraíba |
| Rio Bonito | Tanguá | 0.100 | Metropolitana II |
| Rio das Ostras | Macaé | 0.220 | Baixada Litorânea |
| Rio de Janeiro | Niterói | 0.073 | Metropolitana I |
| Seropédica | Japeri | 0.111 | Metropolitana I |
| Sumidouro | Carmo | 0.138 | Serrana |
| Teresópolis | Guapimirim | 0.125 | Serrana |

### 2.3 Atribuição Temporal e Macrorregional

| Etapa | Descrição |
|---|---|
| **Agregação municipal** | Média municipal de referência, posteriormente distribuída em escala mensal derivada |
| **Atribuição espacial** | 18 municípios sem monitoramento recebem o valor do vizinho mais próximo (distância de Haversine) |
| **Mapeamento macrorregional** | Cada município é associado à sua macrorregião de saúde (9 regiões) via lookup table (`lookup_municipio_macrorregiao.csv`) |
| **Downscaling temporal** | A série de referência anual 2010-2025 foi distribuída por mês com perfil sazonal nacional de 2024. O ano de 2025 é extrapolado via regressão linear (2020-2024) |
| **Integração nos modelos** | O PM2.5 mensal médio da macrorregião entra apenas como **termo linear opcional de sensibilidade**, desativado por padrão; não é usado como exposição diária com cross-basis |

### 2.4 Referência anual de PM2.5 usada no downscaling mensal por macrorregião (μg/m³)

| Ano | Baía da Ilha Grande | Baixada Litorânea | Centro-Sul | Médio Paraíba | Metrop. I | Metrop. II | Noroeste | Norte | Serrana |
|---|---|---|---|---|---|---|---|---|---|
| 2010 | 23.27 | 12.18 | 22.61 | 23.91 | 27.17 | 19.79 | 13.08 | 11.05 | 16.17 |
| 2011 | 18.12 | 9.48 | 17.60 | 18.62 | 21.15 | 15.41 | 10.19 | 8.60 | 12.59 |
| 2012 | 18.77 | 9.82 | 18.23 | 19.29 | 21.91 | 15.96 | 10.55 | 8.91 | 13.04 |
| 2013 | 16.66 | 8.72 | 16.18 | 17.12 | 19.44 | 14.17 | 9.37 | 7.91 | 11.58 |
| 2014 | 18.81 | 9.84 | 18.27 | 19.33 | 21.96 | 16.00 | 10.57 | 8.93 | 13.07 |
| 2015 | 20.27 | 10.61 | 19.69 | 20.83 | 23.66 | 17.24 | 11.40 | 9.63 | 14.09 |
| 2016 | 19.81 | 10.37 | 19.25 | 20.36 | 23.12 | 16.85 | 11.14 | 9.41 | 13.77 |
| 2017 | 19.25 | 10.07 | 18.70 | 19.78 | 22.47 | 16.37 | 10.82 | 9.14 | 13.38 |
| 2018 | 18.31 | 9.58 | 17.79 | 18.82 | 21.38 | 15.58 | 10.30 | 8.70 | 12.73 |
| 2019 | 20.00 | 10.47 | 19.44 | 20.56 | 23.35 | 17.02 | 11.25 | 9.50 | 13.90 |
| 2020 | 20.43 | 10.69 | 19.85 | 20.99 | 23.85 | 17.37 | 11.48 | 9.70 | 14.20 |
| 2021 | 21.07 | 11.03 | 20.47 | 21.66 | 24.60 | 17.93 | 11.85 | 10.01 | 14.65 |
| 2022 | 21.44 | 11.22 | 20.83 | 22.03 | 25.03 | 18.24 | 12.06 | 10.18 | 14.90 |
| 2023 | 19.26 | 10.08 | 18.71 | 19.79 | 22.48 | 16.38 | 10.83 | 9.15 | 13.38 |
| 2024 | 25.64 | 13.42 | 24.91 | 26.35 | 29.93 | 21.81 | 14.42 | 12.18 | 17.82 |
| 2025* | 24.15 | 12.64 | 23.46 | 24.82 | 28.19 | 20.54 | 13.58 | 11.47 | 16.78 |

> *2025: valor **extrapolado** via regressão linear sobre a tendência 2020-2024. A série mensal usada no pipeline é derivada dessa referência anual e do perfil sazonal nacional de 2024.

---

## 3. Limitações Conhecidas

| Limitação | Detalhe |
|---|---|
| **Noroeste — 1 estação INMET** | Apenas a estação A604 (Cambuci) cobre a macrorregião. Sem redundância espacial para validação cruzada ou imputação interna. |
| **Centro-Sul — 41% dos dias imputados** | As estações A625 (Três Rios, 2016) e A637 (Paty do Alferes, 2022) iniciaram durante o período. Antes disso, ~41% dos dias usam dados de estações vizinhas. |
| **Metropolitana II — 35% dos dias imputados** | As estações A659 (Silva Jardim, 2015) e A627 (Niterói, 2018) iniciaram durante o período. |
| **PM2.5 - granularidade mensal derivada** | A série de PM2.5 é mensal por macrorregião. Ela não possui resolução diária observada e, por isso, não é usada como exposição-lag principal. |
| **PM2.5 — 18 municípios sem medição** | Recebem o valor do vizinho mais próximo. A acurácia depende da distância e da homogeneidade espacial do PM2.5. |
| **PM2.5 — 2025 extrapolado** | O valor de 2025 é extrapolação linear da tendência 2020-2024. Não reflete medições reais. |
| **Agregação climática** | A temperatura e umidade de cada macrorregião é a **média simples** das estações disponíveis no dia — sem ponderação populacional ou por distância. |
| **Estações descontinuadas** | 6 das 26 estações catalogadas foram descontinuadas. Seus dados são usados apenas no período em que estavam operacionais. |

---

## 4. Fontes dos Dados

| Fonte | Descrição | Acesso | Método de Extração |
|---|---|---|---|
| **INMET** | Estações meteorológicas de superfície | API `BrazilMet` v0.4.0 + fallback ZIP local | Download automático via R |
| **INEA/MonitorAr** | Painel VIGIAR de MP2.5 | Power BI público do INEA | Playwright (Python) — `extrair_mp25_rj.py` |
| **geobr** | Geometrias municipais (IBGE) | API `geobr` v1.9.1 + fallback IBGE Malhas + tabela estática | Download automático via R |

---

*Documento gerado automaticamente a partir dos arquivos de auditoria do pipeline.*
*Data: 20 de junho de 2026*
