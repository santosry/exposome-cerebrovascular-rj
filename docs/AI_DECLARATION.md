# Declaração de Uso de Inteligência Artificial

**Em conformidade com a Portaria CNPq nº 2.664, de 15 de maio de 2026**

---

## Identificação do Projeto

- **Título:** Exposição Climática e Afecções Cerebrovasculares no Rio de Janeiro (2010–2025): DLNM com Inferência Bayesiana Hierárquica
- **Pesquisador responsável:** Ryan de Paulo Santos
- **Equipe:** Camila Henriques Nunes, Karla Rangel Ribeiro, Enrique Medina-Acosta
- **Processo CNPq:** [a declarar]

---

## Tecnologias de IA Utilizadas

| Tecnologia | Versão | Fornecedor | Finalidade |
|------------|--------|------------|------------|
| **DeepSeek** | v4-pro | DeepSeek AI | Refatoração de código R monolítico em arquitetura modular; geração de documentação técnica (formulas LaTeX, metodologia); estruturação do research compendium; criação de pipelines de CI/CD (GitHub Actions); geração de testes unitários |
| **Codex** | — | OpenAI | Assistência na escrita de funções R para processamento de dados epidemiológicos (DLNM, crossbasis, GLM); debugging de scripts de análise estatística; sugestão de padrões de código para data lineage e FAIR metadata |
| **ChatGPT** | 5.5 | OpenAI | Auditoria técnica completa do projeto (14 etapas); benchmarking contra padrões internacionais (Nature, Lancet, FAIR, Turing Way); geração de relatórios executivos; tradução e revisão de documentação para inglês; elaboração de checklists de conformidade (STROBE, RECORD, TRIPOD); sugestão de roadmap de melhoria |

---

## Natureza do Uso

As tecnologias de IA foram empregadas como **ferramentas de suporte técnico e científico**, atuando como assistentes para:

1. **Refatoração de código:** Transformação de script monolítico (~5.400 linhas) em arquitetura modular com 8 módulos independentes, Docker, CI/CD e testes automatizados
2. **Documentação:** Geração de documentação FAIR, dicionário de dados, data lineage, fórmulas matemáticas em LaTeX, e README científico
3. **Auditoria de qualidade:** Análise crítica independente de todas as etapas do projeto, identificação de falhas, riscos e oportunidades de melhoria
4. **Conformidade:** Verificação de aderência a diretrizes internacionais (STROBE, RECORD, TRIPOD, FAIR Principles, Turing Way)
5. **Infraestrutura computacional:** Criação de Dockerfile, docker-compose, Makefile, pipeline targets, e workflows de CI/CD

**Todas as decisões científicas, metodológicas e analíticas** — incluindo a escolha dos modelos DLNM, definição de parâmetros (lags, splines, priors bayesianos), interpretação dos resultados e validação epidemiológica — **foram tomadas exclusivamente pelos pesquisadores humanos**. As IAs não geraram hipóteses, não selecionaram variáveis, não interpretaram resultados clínicos e não redigiram conclusões científicas.

---

## Validação Humana

Todo o código gerado ou modificado com auxílio de IA foi revisado, testado e validado pelos pesquisadores. Os resultados das análises estatísticas conferidos manualmente. A documentação técnica foi verificada quanto à correção conceitual e adequação ao domínio da epidemiologia ambiental.

---

## Responsabilidade

Os autores assumem integral responsabilidade pelo conteúdo científico, pela acurácia dos dados, pela validade das análises e pelas conclusões apresentadas neste trabalho, independentemente do uso de tecnologias de IA como ferramentas auxiliares.

---

**Data:** 19 de junho de 2026

**Referência:** BRASIL. Conselho Nacional de Desenvolvimento Científico e Tecnológico. Portaria nº 2.664, de 15 de maio de 2026. Dispõe sobre a declaração de uso de tecnologias de inteligência artificial em pesquisas financiadas pelo CNPq.
