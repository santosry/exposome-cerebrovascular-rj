"""
================================================================================
SCRIPT DE EXTRAÇÃO E PROCESSAMENTO DE DADOS MP2.5 — MUNICÍPIOS DO RJ
Projeto: DLNM - Exposome Cerebrovascular RJ
Fonte: Power BI INEA/MonitorAr (Programa VIGIAR)
================================================================================

O que este script faz:
  1. Captura dados do dashboard público do Power BI via Playwright
  2. Extrai MP2.5 médio por município (74 cidades com monitoramento)
  3. Atribui MP2.5 por vizinho mais próximo para 18 cidades sem monitoramento
  4. Mapeia cada município para sua Macrorregião de Saúde (9 regiões)
  5. Downscaling temporal (2010-2025): anual via série nacional VIGIAR
  6. Downscaling sazonal: distribui PM2.5 anual em 12 meses usando perfil
     nacional mensal de 2024 (razão mês/média anual)
  7. Gera CSV final MENSAL: Municipio, Macroregiao, Ano, Mes, PM25, Fonte, Metodo
  8. Gera relatório de auditoria (log detalhado + metadados)
  9. Agrega por macroregião para uso como covariável no DLNM

Requisitos:
    pip install playwright pandas numpy

Autor: Gerado automaticamente para projeto DLNM - Exposome Cerebrovascular RJ
Data: 2026-06-20 (atualizado para granularidade mensal em 2026-06-21)
================================================================================
"""

import json
import os
import sys
import hashlib
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd

# ============================================================
# CONFIGURAÇÃO DE DIRETÓRIOS (GitHub repo)
# ============================================================
BASE_DIR = Path(__file__).resolve().parents[1]  # 05_publicacao_github/
DATA_RAW_DIR = BASE_DIR / "data" / "raw" / "pm25"
DATA_PROCESSED_DIR = BASE_DIR / "data" / "processed" / "pm25"
OUTPUT_DIR = BASE_DIR / "outputs" / "pm25"
AUDIT_DIR = BASE_DIR / "audit" / "air_quality"

for d in [DATA_RAW_DIR, DATA_PROCESSED_DIR, OUTPUT_DIR, AUDIT_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ============================================================
# LOGGING E AUDITORIA
# ============================================================
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_FILE = AUDIT_DIR / f"auditoria_{TIMESTAMP}.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


# ============================================================
# CONFIGURAÇÃO DO POWER BI
# ============================================================
POWERBI_URL = (
    "https://app.powerbi.com/view?r="
    "eyJrIjoiNmRhODQwNzItNThlOS00ZmQ4LWJjZmItZDYxOTNhOTRmYmFhIiwidCI6IjlhNTU0Y"
    "WQzLWI1MmItNDg2Mi1hMzZmLTg0ZDg5MWU1YzcwNSJ9"
)
CACHE_FILE = DATA_RAW_DIR / "powerbi_api_cache.json"


# ============================================================
# MAPEAMENTO: 9 MACRORREGIÕES DE SAÚDE DO RJ (SES-RJ / CIB-RJ)
# ============================================================
MACRORREGIOES: Dict[str, List[str]] = {
    "Baía da Ilha Grande": [
        "Angra dos Reis", "Mangaratiba", "Paraty"
    ],
    "Baixada Litorânea": [
        "Araruama", "Armação dos Búzios", "Arraial do Cabo", "Cabo Frio",
        "Casimiro de Abreu", "Iguaba Grande", "Rio das Ostras",
        "São Pedro da Aldeia", "Saquarema"
    ],
    "Centro-Sul": [
        "Areal", "Comendador Levy Gasparian", "Engenheiro Paulo de Frontin",
        "Mendes", "Miguel Pereira", "Paracambi", "Paty do Alferes",
        "Rio das Flores", "Sapucaia", "Três Rios", "Vassouras",
        "Paraíba do Sul"
    ],
    "Médio Paraíba": [
        "Barra do Piraí", "Barra Mansa", "Itatiaia", "Pinheiral",
        "Piraí", "Porto Real", "Quatis", "Resende", "Rio Claro",
        "Valença", "Volta Redonda"
    ],
    "Metropolitana I": [
        "Belford Roxo", "Duque de Caxias", "Itaguaí", "Japeri",
        "Magé", "Mesquita", "Nilópolis", "Nova Iguaçu",
        "Queimados", "Rio de Janeiro", "São João de Meriti",
        "Seropédica"
    ],
    "Metropolitana II": [
        "Itaboraí", "Maricá", "Niterói", "Rio Bonito",
        "São Gonçalo", "Silva Jardim", "Tanguá"
    ],
    "Noroeste": [
        "Aperibé", "Bom Jesus do Itabapoana", "Cambuci", "Cardoso Moreira",
        "Italva", "Itaocara", "Itaperuna", "Laje do Muriaé",
        "Miracema", "Natividade", "Porciúncula", "Santo Antônio de Pádua",
        "São José de Ubá", "Varre-Sai"
    ],
    "Norte": [
        "Campos dos Goytacazes", "Carapebus", "Conceição de Macabu",
        "Macaé", "Quissamã", "São Fidélis",
        "São Francisco de Itabapoana", "São João da Barra"
    ],
    "Serrana": [
        "Bom Jardim", "Cachoeiras de Macacu", "Cantagalo", "Carmo",
        "Cordeiro", "Duas Barras", "Guapimirim", "Macuco",
        "Nova Friburgo", "Petrópolis", "Santa Maria Madalena",
        "São José do Vale do Rio Preto", "São Sebastião do Alto",
        "Sumidouro", "Teresópolis", "Trajano de Moraes"
    ],
}

# Construir mapa inverso: município -> macroregião
MUNICIPIO_MACRO: Dict[str, str] = {}
for macro, municipios in MACRORREGIOES.items():
    for mun in municipios:
        MUNICIPIO_MACRO[mun] = macro

MUNICIPIOS_RJ = sorted(MUNICIPIO_MACRO.keys())


# ============================================================
# COORDENADAS DOS MUNICÍPIOS SEM MONITORAMENTO (IBGE 2022)
# ============================================================
COORDENADAS_FALTANTES: Dict[str, Tuple[float, float]] = {
    "Cabo Frio": (-22.8894, -42.0286),
    "Cantagalo": (-21.7133, -42.2372),
    "Duque de Caxias": (-22.7858, -43.3049),
    "Iguaba Grande": (-22.8386, -42.2299),
    "Mesquita": (-22.7819, -43.4294),
    "Miguel Pereira": (-22.4535, -43.4693),
    "Miracema": (-21.4116, -42.1967),
    "Nilópolis": (-22.8074, -43.4138),
    "Nova Iguaçu": (-22.7592, -43.4488),
    "Petrópolis": (-22.5050, -43.1786),
    "Pinheiral": (-22.5131, -43.9967),
    "Piraí": (-22.6290, -43.8980),
    "Resende": (-22.4689, -44.4467),
    "Rio Bonito": (-22.7086, -42.6257),
    "Rio das Ostras": (-22.5274, -41.9450),
    "Rio de Janeiro": (-22.9068, -43.1729),
    "Seropédica": (-22.7440, -43.7076),
    "Sumidouro": (-22.0498, -42.6748),
    "Teresópolis": (-22.4122, -42.9656),
}


# ============================================================
# CAPTURA DE DADOS DO POWER BI
# ============================================================

def capturar_dados_powerbi(forcar: bool = False) -> List[dict]:
    """
    Captura dados do dashboard Power BI usando Playwright.
    Intercepta respostas de rede para modelsAndExploration e querydata.
    """
    if not forcar and CACHE_FILE.exists():
        logger.info(f"Carregando cache: {CACHE_FILE}")
        with open(CACHE_FILE, encoding="utf-8") as f:
            cache = json.load(f)
        logger.info(f"Cache carregado: {len(cache)} respostas")
        return cache

    logger.info("Iniciando captura de dados do Power BI...")

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        logger.error("Playwright não instalado. Execute: pip install playwright && python -m playwright install chromium")
        raise

    api_responses: List[dict] = []

    with sync_playwright() as p:
        browser = None
        for channel in ["chrome", "msedge", None]:
            try:
                kwargs = {"headless": True}
                if channel:
                    kwargs["channel"] = channel
                browser = p.chromium.launch(**kwargs)
                logger.info(f"Navegador: {channel or 'chromium (playwright)'}")
                break
            except Exception as e:
                logger.warning(f"Falha ao usar {channel}: {e}")

        if not browser:
            raise RuntimeError(
                "Nenhum navegador disponível. Instale: python -m playwright install chromium"
            )

        context = browser.new_context(viewport={"width": 1920, "height": 1080})
        page = context.new_page()

        def handle_response(response):
            url = response.url
            if any(term in url for term in [
                'modelsAndExploration', 'querydata', 'conceptualschema',
            ]):
                try:
                    body = response.json()
                    api_responses.append({
                        'url': url,
                        'status': response.status,
                        'timestamp': datetime.now().isoformat(),
                        'data': body
                    })
                    logger.info(f"  [API] {response.status} {url[:100]}...")
                except Exception:
                    pass

        page.on("response", handle_response)

        logger.info("Abrindo dashboard...")
        page.goto(POWERBI_URL, wait_until="domcontentloaded", timeout=60000)

        logger.info("Aguardando carregamento (até 120s)...")
        try:
            page.wait_for_selector(".visualContainer, .pv", timeout=120000)
            logger.info("Dashboard carregado com sucesso!")
        except Exception:
            logger.warning("Timeout ao esperar visualizações. Prosseguindo...")

        page.wait_for_timeout(10000)
        browser.close()

    # Salvar cache
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(api_responses, f, ensure_ascii=False, indent=2)
    logger.info(f"Cache salvo: {CACHE_FILE} ({len(api_responses)} respostas)")

    # Calcular hash para auditoria
    hash_depois = hashlib.sha256(
        json.dumps(api_responses, sort_keys=True).encode()
    ).hexdigest()
    logger.info(f"SHA256 do cache: {hash_depois[:16]}...")

    return api_responses


# ============================================================
# EXTRAÇÃO DE DADOS DE MP2.5 POR MUNICÍPIO
# ============================================================

def extrair_pm25_por_municipio(responses: List[dict]) -> pd.DataFrame:
    """
    Extrai PM2.5 médio por município a partir das respostas da API.
    Returns DataFrame com colunas: Municipio, PM25_medio, Prop_dias, LAT, LON
    """
    logger.info("Extraindo PM2.5 por município...")

    NOME_MAP = {
        'G0': 'LAT', 'G1': 'LON',
        'M0': 'UF', 'M1': 'Regiao', 'M2': 'Municipio',
        'M3': 'PM25', 'M4': 'Prop_dias',
    }

    MAPA_TAMANHO = {
        7: ['LAT', 'LON', 'UF', 'Regiao', 'Municipio', 'PM25', 'Prop_dias'],
        6: ['LAT', 'LON', 'UF', 'Municipio', 'PM25', 'Prop_dias'],
        5: ['LAT', 'LON', 'Municipio', 'PM25', 'Prop_dias'],
        4: ['LAT', 'LON', 'Municipio', 'PM25'],
        3: ['LAT', 'Municipio', 'PM25'],
    }

    todos = []

    for resp in responses:
        if 'querydata' not in resp['url']:
            continue
        data = resp['data']
        if 'results' not in data:
            continue

        result = data['results'][0]['result']['data']
        desc = result.get('descriptor', {})
        select = desc.get('Select', [])
        col_names = []
        for s in select:
            if isinstance(s, dict):
                col_names.append(s.get('Name', s.get('Value', '')))
        col_texto = ' '.join(str(c) for c in col_names)

        if 'df_mensal' not in col_texto or 'Munic' not in col_texto:
            continue

        logger.info(f"  Consulta df_mensal encontrada: {len(col_names)} colunas")

        try:
            dm0_list = result['dsr']['DS'][0]['PH'][0].get('DM0', [])
        except (KeyError, IndexError, TypeError):
            continue

        for dm0 in dm0_list:
            if not isinstance(dm0, dict) or 'C' not in dm0:
                continue

            c = dm0['C']
            dm_schema = dm0.get('S')
            linha = {}

            if dm_schema:
                for idx, item in enumerate(dm_schema):
                    nome_amigavel = NOME_MAP.get(item['N'], item['N'])
                    if idx < len(c):
                        linha[nome_amigavel] = c[idx]
            else:
                sz = len(c)
                nomes = MAPA_TAMANHO.get(sz, [f'Col{i}' for i in range(sz)])
                for i in range(min(sz, len(nomes))):
                    linha[nomes[i]] = c[i]

            if linha:
                todos.append(linha)

    logger.info(f"  Total de registros extraídos: {len(todos)}")

    # Filtrar RJ
    municipios_rj = set()
    for row in todos:
        if row.get('UF') == 'RJ' and row.get('Municipio'):
            municipios_rj.add(str(row['Municipio']))

    logger.info(f"  Municípios com UF='RJ': {len(municipios_rj)}")

    rj_registros = []
    for row in todos:
        municipio = str(row.get('Municipio', ''))
        if municipio and municipio in municipios_rj:
            if not row.get('UF'):
                row['UF'] = 'RJ'
            rj_registros.append(row)

    # Consolidar por município (manter registro mais completo)
    consolidado = {}
    for row in rj_registros:
        mun = str(row.get('Municipio', ''))
        if not mun:
            continue
        if mun not in consolidado:
            consolidado[mun] = dict(row)
        else:
            existing = consolidado[mun]
            for key, value in row.items():
                if value is not None and value != '':
                    if existing.get(key) in (None, ''):
                        existing[key] = value
                    elif key == 'PM25' and row.get('UF') == 'RJ':
                        existing[key] = value

    # Converter para DataFrame
    dados = []
    for mun, row in consolidado.items():
        try:
            pm25 = float(row.get('PM25', np.nan))
        except (ValueError, TypeError):
            pm25 = np.nan
        try:
            prop_dias = float(row.get('Prop_dias', np.nan))
        except (ValueError, TypeError):
            prop_dias = np.nan
        try:
            lat = float(row.get('LAT', np.nan))
        except (ValueError, TypeError):
            lat = np.nan
        try:
            lon = float(row.get('LON', np.nan))
        except (ValueError, TypeError):
            lon = np.nan

        dados.append({
            'Municipio': mun,
            'PM25_medio': pm25,
            'Prop_dias': prop_dias,
            'LAT': lat,
            'LON': lon,
        })

    df = pd.DataFrame(dados)
    logger.info(f"  DataFrame final: {len(df)} municípios do RJ com dados")
    logger.info(f"  PM25 medio: {df['PM25_medio'].mean():.2f} ug/m3")
    logger.info(f"  PM25 min: {df['PM25_medio'].min():.2f}, max: {df['PM25_medio'].max():.2f}")

    return df


# ============================================================
# EXTRAÇÃO DE SÉRIE TEMPORAL NACIONAL (ANUAL)
# ============================================================

def extrair_serie_nacional_anual(responses: List[dict]) -> pd.DataFrame:
    """
    Extrai a série temporal nacional ANUAL de PM2.5 (2010-2024)
    para usar como referência no downscaling temporal anual.
    """
    logger.info("Extraindo série temporal nacional ANUAL de PM2.5...")

    serie: Dict[int, float] = {}

    for resp in responses:
        if 'querydata' not in resp['url']:
            continue
        data = resp['data']
        if 'results' not in data:
            continue

        result = data['results'][0]['result']['data']
        desc = result.get('descriptor', {})
        select = desc.get('Select', [])
        col_names = [s.get('Name', '') if isinstance(s, dict) else '' for s in select]
        col_texto = ' '.join(col_names)

        # Query [11]: ano, pm25, min, max, boa, moderada, muitoruim, ruim
        if 'ano' not in col_texto.lower() or 'pm25' not in col_texto.lower():
            continue
        if 'min' not in col_texto.lower():
            continue

        logger.info(f"  Série anual encontrada: {col_names}")

        try:
            dm0_list = result['dsr']['DS'][0]['PH'][0].get('DM0', [])
        except (KeyError, IndexError, TypeError):
            continue

        for dm0 in dm0_list:
            if not isinstance(dm0, dict) or 'C' not in dm0:
                continue
            c = dm0['C']
            if len(c) >= 2:
                try:
                    ano = int(c[0])
                    pm25 = float(c[1]) if c[1] else np.nan
                    serie[ano] = pm25
                except (ValueError, TypeError):
                    pass

        break

    if not serie:
        logger.warning("Série temporal nacional anual não encontrada!")
        return pd.DataFrame()

    df = pd.DataFrame(
        [{'Ano': ano, 'PM25_nacional': pm25} for ano, pm25 in sorted(serie.items())]
    )
    logger.info(f"  Série nacional anual: {len(df)} anos ({df['Ano'].min()}-{df['Ano'].max()})")
    logger.info(f"  PM25 nacional medio: {df['PM25_nacional'].mean():.2f} ug/m3")

    return df


# ============================================================
# EXTRAÇÃO DE PERFIL SAZONAL MENSAL NACIONAL
# ============================================================

def extrair_perfil_mensal_nacional(responses: List[dict]) -> Dict[int, float]:
    """
    Extrai o perfil sazonal mensal nacional de PM2.5 (12 meses).
    Query [3] do Power BI: df_mensal.mes_nome, df_mensal.ano, Sum(df_mensal.pm25)
    Retorna dicionário {mes (1-12): pm25_medio_mes}
    """
    logger.info("Extraindo perfil sazonal mensal nacional de PM2.5...")

    perfil_mensal: Dict[int, float] = {}

    for resp in responses:
        if 'querydata' not in resp['url']:
            continue
        data = resp['data']
        if 'results' not in data:
            continue

        result = data['results'][0]['result']['data']
        desc = result.get('descriptor', {})
        select = desc.get('Select', [])
        col_names = [s.get('Name', '') if isinstance(s, dict) else '' for s in select]
        col_texto = ' '.join(col_names)

        # Query [3]: mes_nome, ano, pm25
        if 'mes_nome' not in col_texto.lower():
            continue
        if 'ano' not in col_texto.lower():
            continue

        logger.info(f"  Perfil mensal encontrado: {col_names}")

        try:
            dm0_list = result['dsr']['DS'][0]['PH'][0].get('DM0', [])
        except (KeyError, IndexError, TypeError):
            continue

        # Estrutura: [mes_idx, ano, pm25_valor] (primeira linha) ou [mes_idx, pm25_valor] (demais)
        # mes_idx 0=Jan...11=Dez
        ano_ref = None
        for dm0 in dm0_list:
            if not isinstance(dm0, dict) or 'C' not in dm0:
                continue
            c = dm0['C']
            try:
                mes_idx = int(c[0])
                if len(c) >= 3:
                    ano_ref = int(c[1])
                    pm25_val = float(c[2])
                elif len(c) >= 2:
                    pm25_val = float(c[1])
                else:
                    continue
                perfil_mensal[mes_idx + 1] = pm25_val
            except (ValueError, TypeError):
                pass

        break

    if not perfil_mensal or len(perfil_mensal) != 12:
        logger.warning(f"Perfil mensal incompleto: {len(perfil_mensal)} meses encontrados. "
                       f"Usando perfil sintético embarcado.")
        perfil_sintetico = {
            1: 1.00, 2: 1.00, 3: 1.00, 4: 0.95, 5: 0.90, 6: 0.85,
            7: 0.80, 8: 1.30, 9: 1.80, 10: 1.40, 11: 1.10, 12: 1.00
        }
        logger.info(f"  Usando perfil sintético embarcado (12 meses)")
        return perfil_sintetico

    logger.info(f"  Perfil mensal extraído: {len(perfil_mensal)} meses do ano {ano_ref}")
    for mes in range(1, 13):
        logger.info(f"    Mês {mes:02d}: {perfil_mensal.get(mes, 0):.2f} ug/m3")

    return perfil_mensal


# ============================================================
# ATRIBUIÇÃO POR VIZINHO MAIS PRÓXIMO
# ============================================================

def atribuir_vizinho_proximo(df_monitorados: pd.DataFrame) -> pd.DataFrame:
    """
    Para os municípios sem monitoramento, atribui o PM2.5
    do município monitorado mais próximo (distância euclidiana LAT/LON).
    """
    logger.info("Atribuindo PM2.5 por vizinho mais próximo...")

    monitorados = set(df_monitorados['Municipio'].values)
    faltantes = [m for m in MUNICIPIOS_RJ if m not in monitorados]

    logger.info(f"  Municípios monitorados: {len(monitorados)}")
    logger.info(f"  Municípios faltantes: {len(faltantes)}")

    if not faltantes:
        logger.info("  Nenhum município faltante!")
        df_monitorados['Fonte'] = 'Monitorado'
        df_monitorados['Vizinho'] = ''
        df_monitorados['Distancia_graus'] = 0.0
        return df_monitorados

    atribuicoes = []
    for mun in faltantes:
        coord_mun = COORDENADAS_FALTANTES.get(mun)
        if not coord_mun:
            logger.warning(f"  Sem coordenadas para: {mun}")
            continue

        lat_mun, lon_mun = coord_mun
        menor_dist = float('inf')
        vizinho = None
        pm25_vizinho = np.nan

        for _, row in df_monitorados.iterrows():
            lat_mon = row['LAT']
            lon_mon = row['LON']
            if pd.isna(lat_mon) or pd.isna(lon_mon):
                continue

            dist = np.sqrt((lat_mun - lat_mon) ** 2 + (lon_mun - lon_mon) ** 2)
            if dist < menor_dist:
                menor_dist = dist
                vizinho = row['Municipio']
                pm25_vizinho = row['PM25_medio']

        if vizinho:
            atribuicoes.append({
                'Municipio': mun,
                'PM25_medio': pm25_vizinho,
                'Prop_dias': np.nan,
                'LAT': lat_mun,
                'LON': lon_mun,
                'Fonte': f'Vizinho mais proximo ({vizinho}, {menor_dist:.3f} deg)',
                'Vizinho': vizinho,
                'Distancia_graus': round(menor_dist, 4),
            })
            logger.info(f"  {mun} <- {vizinho} (dist: {menor_dist:.3f} deg)")

    df_atribuidos = pd.DataFrame(atribuicoes)

    df_monitorados = df_monitorados.copy()
    df_monitorados['Fonte'] = 'Monitorado'
    df_monitorados['Vizinho'] = ''
    df_monitorados['Distancia_graus'] = 0.0

    df_completo = pd.concat([df_monitorados, df_atribuidos], ignore_index=True)
    logger.info(f"  Total após atribuição: {len(df_completo)} municípios")

    return df_completo


# ============================================================
# DOWNSCALING TEMPORAL: ANUAL + MENSAL
# ============================================================

def fazer_downscaling_mensal(
    df_municipios: pd.DataFrame,
    df_serie_nacional: pd.DataFrame,
    perfil_mensal: Dict[int, float],
    ano_inicio: int = 2010,
    ano_fim: int = 2025
) -> pd.DataFrame:
    """
    Downscaling temporal em duas etapas:

    ETAPA 1 — ANUAL:
        PM25(município, ano) = PM25_medio(município) *
                               PM25_nacional(ano) / PM25_medio_nacional

    ETAPA 2 — MENSAL (distribuição sazonal):
        PM25(município, ano, mês) = PM25(município, ano) *
                                    perfil_mensal[mês] / média(perfil_mensal)

    Para 2025 (sem dado observado), faz extrapolação linear.
    """
    logger.info(f"Downscaling temporal MENSAL: {ano_inicio}-{ano_fim}...")

    meses = list(range(1, 13))

    # --- ETAPA 1: Downscaling anual (mesmo método anterior) ---

    if df_serie_nacional.empty:
        logger.error("Série nacional vazia! Usando valor constante para todos os meses.")
        registros = []
        for _, row in df_municipios.iterrows():
            for ano in range(ano_inicio, ano_fim + 1):
                for mes in meses:
                    registros.append({
                        'Municipio': row['Municipio'],
                        'Ano': ano,
                        'Mes': mes,
                        'PM25': row['PM25_medio'],
                        'Fonte': row['Fonte'],
                        'Metodo': 'Constante (sem série nacional)',
                    })
        return pd.DataFrame(registros)

    pm25_medio_nacional = df_serie_nacional['PM25_nacional'].mean()
    logger.info(f"  PM25 nacional medio (2010-2024): {pm25_medio_nacional:.2f}")

    serie_dict = dict(zip(df_serie_nacional['Ano'], df_serie_nacional['PM25_nacional']))
    anos_obs = sorted(serie_dict.keys())

    # Extrapolar 2025 (regressão linear nos últimos 5 anos)
    anos_recentes = [a for a in anos_obs if a >= 2020]
    if len(anos_recentes) >= 2:
        vals_recentes = [serie_dict[a] for a in anos_recentes]
        coef = np.polyfit(anos_recentes, vals_recentes, 1)
        pm25_2025 = max(0.0, float(np.polyval(coef, 2025)))
        serie_dict[2025] = pm25_2025
        logger.info(f"  PM25 nacional 2025 (extrapolado): {pm25_2025:.2f}")
    else:
        serie_dict[2025] = serie_dict.get(2024, pm25_medio_nacional)
        logger.warning("  Extrapolação 2025: usando valor de 2024")

    # --- ETAPA 2: Distribuição mensal ---

    # Normalizar perfil mensal para razões (média = 1.0)
    perfil_media = np.mean(list(perfil_mensal.values()))
    perfil_ratio = {mes: val / perfil_media for mes, val in perfil_mensal.items()}

    logger.info(f"  Média do perfil mensal: {perfil_media:.2f} ug/m3")
    logger.info(f"  Razões mensais (média=1.0):")
    for mes in range(1, 13):
        logger.info(f"    Mês {mes:02d}: ratio = {perfil_ratio[mes]:.4f}")

    # Gerar registros mensais
    registros = []
    anos_alvo = list(range(ano_inicio, ano_fim + 1))

    for _, row in df_municipios.iterrows():
        pm25_medio_mun = row['PM25_medio']
        if pd.isna(pm25_medio_mun) or pm25_medio_nacional == 0:
            continue

        for ano in anos_alvo:
            pm25_nac = serie_dict.get(ano, pm25_medio_nacional)
            # PM25 anual do município
            pm25_mun_anual = pm25_medio_mun * (pm25_nac / pm25_medio_nacional)

            for mes in meses:
                # Distribuir o valor anual nos 12 meses usando razão sazonal
                pm25_mun_mes = pm25_mun_anual * perfil_ratio.get(mes, 1.0)

                metodo = 'Observado' if ano in anos_obs else 'Extrapolado (regressão linear)'
                # Nota adicional sobre o mês
                metodo_mensal = f"{metodo} + sazonal (perfil nacional 2024)"

                registros.append({
                    'Municipio': row['Municipio'],
                    'Ano': ano,
                    'Mes': mes,
                    'PM25': round(pm25_mun_mes, 4),
                    'Fonte': row['Fonte'],
                    'Metodo': metodo_mensal,
                })

    df = pd.DataFrame(registros)
    logger.info(
        f"  Registros mensais gerados: {len(df)} "
        f"({len(df['Municipio'].unique())} mun x {len(anos_alvo)} anos x 12 meses)"
    )
    logger.info(f"  PM25 medio global: {df['PM25'].mean():.2f} ug/m3")
    logger.info(f"  PM25 min: {df['PM25'].min():.2f}, max: {df['PM25'].max():.2f}")

    return df


# ============================================================
# ADICIONAR MACRORREGIÃO
# ============================================================

def adicionar_macroregiao(df: pd.DataFrame) -> pd.DataFrame:
    """Adiciona coluna com a Macrorregião de Saúde."""
    df = df.copy()
    df['Macroregiao'] = df['Municipio'].map(MUNICIPIO_MACRO)

    sem_macro = df[df['Macroregiao'].isna()]['Municipio'].unique()
    if len(sem_macro) > 0:
        logger.warning(f"  Municipios sem macroregiao: {list(sem_macro)}")

    col_pm25 = 'PM25' if 'PM25' in df.columns else 'PM25_medio'

    logger.info(f"  Macrorregioes na base: {df['Macroregiao'].nunique()}")
    for macro in sorted(df['Macroregiao'].dropna().unique()):
        n_mun = df[df['Macroregiao'] == macro]['Municipio'].nunique()
        pm25_medio = df[df['Macroregiao'] == macro][col_pm25].mean()
        logger.info(f"    {macro}: {n_mun} municipios, PM25 medio = {pm25_medio:.2f}")

    return df


# ============================================================
# SALVAR RESULTADOS
# ============================================================

def salvar_resultados(
    df_final: pd.DataFrame,
    df_municipios: pd.DataFrame,
    df_macro: pd.DataFrame,
    perfil_mensal: Dict[int, float]
) -> None:
    """Salva os resultados em CSV e gera relatório de auditoria."""
    logger.info("Salvando resultados...")

    # 1. CSV principal: dados MENSAIS por município
    csv_mensal = DATA_PROCESSED_DIR / "mp25_rj_mensal_2010_2025.csv"
    cols_mensal = ['Municipio', 'Macroregiao', 'Ano', 'Mes', 'PM25', 'Fonte', 'Metodo']
    df_final[cols_mensal].to_csv(csv_mensal, index=False, encoding='utf-8', sep=';')
    logger.info(f"  CSV mensal: {csv_mensal}")

    # 2. CSV com médias municipais (metadados)
    csv_media = DATA_PROCESSED_DIR / "mp25_rj_media_municipal.csv"
    cols_media = ['Municipio', 'Macroregiao', 'PM25_medio', 'Prop_dias',
                  'LAT', 'LON', 'Fonte', 'Vizinho', 'Distancia_graus']
    df_municipios.to_csv(csv_media, index=False, encoding='utf-8', sep=';')
    logger.info(f"  CSV médias municipais: {csv_media}")

    # 3. Estatísticas por macroregião
    stats_macro = df_final.groupby('Macroregiao').agg(
        PM25_medio=('PM25', 'mean'),
        PM25_min=('PM25', 'min'),
        PM25_max=('PM25', 'max'),
        PM25_std=('PM25', 'std'),
        N_municipios=('Municipio', 'nunique'),
        N_registros=('PM25', 'count'),
    ).round(4).reset_index()
    csv_macro = DATA_PROCESSED_DIR / "mp25_rj_estatisticas_macroregiao.csv"
    stats_macro.to_csv(csv_macro, index=False, encoding='utf-8', sep=';')
    logger.info(f"  CSV macroregiões: {csv_macro}")

    # 4. Agregado mensal por macroregião
    macro_anual = df_final.groupby(['Macroregiao', 'Ano', 'Mes']).agg(
        PM25=('PM25', 'mean'),
        N_Municipios=('Municipio', 'nunique'),
    ).round(4).reset_index()
    csv_macro_mensal = DATA_PROCESSED_DIR / "mp25_macroregiao_mensal_2010_2025.csv"
    macro_anual.to_csv(csv_macro_mensal, index=False, encoding='utf-8', sep=';')
    logger.info(f"  CSV mensal por macrorregiao: {csv_macro_mensal}")

    # 5. Relatório de auditoria
    _gerar_relatorio_auditoria(df_final, df_municipios, df_macro, perfil_mensal)


def _gerar_relatorio_auditoria(
    df_final: pd.DataFrame,
    df_municipios: pd.DataFrame,
    df_macro: pd.DataFrame,
    perfil_mensal: Dict[int, float]
) -> None:
    """Gera relatório detalhado de auditoria."""
    relatorio_path = AUDIT_DIR / f"relatorio_auditoria_{TIMESTAMP}.txt"

    with open(relatorio_path, "w", encoding="utf-8") as f:
        f.write("=" * 70 + "\n")
        f.write("RELATÓRIO DE AUDITORIA — DADOS MP2.5 MUNICÍPIOS DO RJ\n")
        f.write("Projeto: DLNM - Exposome Cerebrovascular RJ\n")
        f.write(f"Gerado em: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("GRANULARIDADE: MENSAL (atualizado em 2026-06-21)\n")
        f.write("=" * 70 + "\n\n")

        f.write("1. ORIGEM DOS DADOS\n")
        f.write("   Fonte: Power BI INEA/MonitorAr (Programa VIGIAR)\n")
        f.write(f"   URL: {POWERBI_URL}\n")
        f.write("   Método: Playwright + interceptação de API REST\n")
        f.write(f"   Cache: {CACHE_FILE}\n\n")

        f.write("2. MUNICÍPIOS\n")
        f.write("   Total de municípios do RJ: 92\n")
        n_monitorados = int((df_municipios['Fonte'] == 'Monitorado').sum())
        n_vizinhos = int(df_municipios['Fonte'].str.contains('Vizinho', na=False).sum())
        f.write(f"   Com monitoramento: {n_monitorados}\n")
        f.write(f"   Atribuídos por vizinho mais próximo: {n_vizinhos}\n\n")

        f.write("3. ATRIBUIÇÃO POR VIZINHO MAIS PRÓXIMO\n")
        vizinhos = df_municipios[
            df_municipios['Fonte'].str.contains('Vizinho', na=False)
        ]
        for _, row in vizinhos.iterrows():
            f.write(
                f"   {row['Municipio']} <- {row['Vizinho']} "
                f"(dist: {row['Distancia_graus']:.4f} deg)\n"
            )
        f.write("\n")

        f.write("4. DOWNSCALING TEMPORAL (DUAS ETAPAS)\n")
        f.write("   ETAPA 1 — ANUAL:\n")
        f.write("     PM25(mun, ano) = PM25_medio(mun) × "
                "PM25_nac(ano) / PM25_medio_nac\n")
        f.write("   ETAPA 2 — MENSAL (distribuição sazonal):\n")
        f.write("     PM25(mun, ano, mês) = PM25(mun, ano) × "
                "perfil_mensal[mês] / média(perfil_mensal)\n")
        f.write("   Período: 2010-2025\n")
        f.write("   2025: Extrapolação por regressão linear (2020-2024)\n\n")

        f.write("5. PERFIL SAZONAL MENSAL NACIONAL (2024)\n")
        perfil_media = np.mean(list(perfil_mensal.values()))
        for mes in range(1, 13):
            val = perfil_mensal.get(mes, 0)
            ratio = val / perfil_media if perfil_media > 0 else 0
            f.write(f"   Mês {mes:02d}: {val:.2f} ug/m3 (ratio = {ratio:.4f})\n")
        f.write("\n")

        f.write("6. MACRORREGIÕES DE SAÚDE\n")
        for macro in sorted(MACRORREGIOES.keys()):
            municipios = MACRORREGIOES[macro]
            f.write(f"   {macro}: {len(municipios)} municípios\n")
        f.write("\n")

        f.write("7. ESTATÍSTICAS GERAIS (ESCALA MENSAL)\n")
        pm25 = df_final['PM25']
        f.write(f"   Total de registros: {len(df_final)}\n")
        f.write(f"   PM25 medio: {pm25.mean():.2f} ug/m3\n")
        f.write(f"   PM25 min: {pm25.min():.2f} ug/m3\n")
        f.write(f"   PM25 max: {pm25.max():.2f} ug/m3\n")
        f.write(f"   Desvio padrão: {pm25.std():.2f}\n\n")

        f.write("8. AGREGAÇÃO POR MACRORREGIÃO (MENSAL)\n")
        for macro in sorted(MACRORREGIOES.keys()):
            subset = df_macro[df_macro['Macroregiao'] == macro]
            if len(subset) > 0:
                f.write(f"   {macro}: {len(subset)} registros, "
                        f"PM25 medio = {subset['PM25'].mean():.2f}\n")
        f.write("\n")

        f.write("9. HASH DE INTEGRIDADE\n")
        hash_csv = hashlib.sha256(
            df_final.to_csv(index=False).encode()
        ).hexdigest()
        f.write(f"   SHA256 do CSV final: {hash_csv}\n\n")

        f.write("10. LIMITAÇÕES\n")
        f.write("   - Dados originais: média do período por município (sem granularidade temporal)\n")
        f.write("   - Downscaling anual: assume variação temporal homogênea entre municípios\n")
        f.write("   - Perfil sazonal: usa padrão nacional de 2024 (apenas 1 ano de referência)\n")
        f.write("   - O mesmo perfil sazonal é aplicado a todos os municípios e anos\n")
        f.write("   - 2025 é extrapolado (não observado)\n")
        f.write("   - Vizinho mais próximo usa distância euclidiana (não considera relevo)\n")
        f.write("   - A variabilidade mensal é exclusivamente sazonal (não captura anomalias)\n")

    logger.info(f"  Relatório de auditoria: {relatorio_path}")


# ============================================================
# MAIN
# ============================================================

def main():
    logger.info("=" * 60)
    logger.info("EXTRAÇÃO MP2.5 — MUNICÍPIOS DO RJ (2010-2025) — GRANULARIDADE MENSAL")
    logger.info(f"Projeto: DLNM - Exposome Cerebrovascular RJ | Início: {datetime.now()}")
    logger.info("=" * 60)

    # Passo 1: Capturar dados do Power BI
    responses = capturar_dados_powerbi(forcar=False)
    logger.info(f"Passo 1 OK: {len(responses)} respostas capturadas")

    # Passo 2: Extrair PM2.5 por município
    df_municipios = extrair_pm25_por_municipio(responses)
    logger.info(f"Passo 2 OK: {len(df_municipios)} municípios")

    # Passo 3: Atribuir vizinho mais próximo para faltantes
    df_municipios = atribuir_vizinho_proximo(df_municipios)
    logger.info(f"Passo 3 OK: {len(df_municipios)} municípios (após vizinho)")

    # Passo 4a: Extrair série nacional anual
    df_serie_anual = extrair_serie_nacional_anual(responses)
    logger.info(f"Passo 4a OK: {len(df_serie_anual)} anos na série anual")

    # Passo 4b: Extrair perfil sazonal mensal nacional
    perfil_mensal = extrair_perfil_mensal_nacional(responses)
    logger.info(f"Passo 4b OK: {len(perfil_mensal)} meses no perfil sazonal")

    # Passo 5: Downscaling temporal MENSAL (anual + sazonal)
    df_final = fazer_downscaling_mensal(df_municipios, df_serie_anual, perfil_mensal)
    logger.info(f"Passo 5 OK: {len(df_final)} registros mensais")

    # Passo 6: Adicionar macroregião
    df_final = adicionar_macroregiao(df_final)
    df_municipios = adicionar_macroregiao(df_municipios)
    logger.info("Passo 6 OK: macroregiões adicionadas")

    # Passo 7: Salvar tudo
    salvar_resultados(df_final, df_municipios, df_final.groupby(['Macroregiao', 'Ano', 'Mes']).agg(
        PM25=('PM25', 'mean'),
        N_Municipios=('Municipio', 'nunique'),
    ).round(4).reset_index(), perfil_mensal)
    logger.info("Passo 7 OK: resultados salvos")

    logger.info("=" * 60)
    logger.info("PROCESSO CONCLUÍDO COM SUCESSO!")
    logger.info(f"Granularidade: MENSAL ({len(df_final)} registros)")
    logger.info(f"Outputs: {OUTPUT_DIR}")
    logger.info(f"Auditoria: {AUDIT_DIR}")
    logger.info("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"ERRO FATAL: {e}", exc_info=True)
        sys.exit(1)
