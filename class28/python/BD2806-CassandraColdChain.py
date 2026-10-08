#!/usr/bin/env python3
"""
BD2806 - Cassandra na pratica: telemetria de caminhoes refrigerados (cassandra-driver)
Disciplina: Banco de Dados | Aula 28D - Cassandra em Profundidade
Prof. Giovane Barcelos

Problema real: a transportadora "ColdChain" leva vacinas e alimentos em
caminhoes refrigerados. Cada caminhao tem sensores que enviam temperatura,
umidade e GPS a cada 10 segundos. Com 2.000 sensores sao ~17 milhoes de
linhas por dia, quase todas ESCRITAS e raramente atualizadas. A vigilancia
sanitaria exige guardar 90 dias. E um caso classico de serie temporal com
altissima taxa de escrita - o ponto forte do Cassandra.

Passo a passo:
    1. Keyspace e tabelas modeladas pelas consultas (query-first)
    2. Cadastro de sensores com Lightweight Transaction (IF NOT EXISTS)
    3. Ingestao com prepared statements + escrita assincrona concorrente
    4. Deteccao de alertas e escrita desnormalizada (3 tabelas por leitura)
    5. Consultas pela partition key (ultimas N, faixa de horario, alertas)
    6. Contadores e paginacao
    7. Niveis de consistencia (ONE, QUORUM, ALL) e o que eles significam
    8. O que o Cassandra NAO deixa fazer (ALLOW FILTERING)

Pre-requisitos:
    pip install cassandra-driver
    docker run -d --name bd28-cassandra -p 9042:9042 cassandra:4.1
    (aguarde ~60 s ate o no aceitar conexoes)

Execucao:
    python3 BD2806-CassandraColdChain.py
"""

import random
import time
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from cassandra import ConsistencyLevel, InvalidRequest, Unavailable
from cassandra.cluster import Cluster, NoHostAvailable
from cassandra.concurrent import execute_concurrent_with_args
from cassandra.query import SimpleStatement

CONTATOS = ["127.0.0.1"]
KEYSPACE = "coldchain"
HOJE = date(2026, 10, 8)

DDL = [
    f"""CREATE KEYSPACE IF NOT EXISTS {KEYSPACE}
        WITH replication = {{'class': 'SimpleStrategy', 'replication_factor': 1}}""",
    f"USE {KEYSPACE}",
    "DROP TABLE IF EXISTS sensores",
    "DROP TABLE IF EXISTS leituras_por_sensor_dia",
    "DROP TABLE IF EXISTS alertas_por_dia",
    "DROP TABLE IF EXISTS ultima_leitura",
    "DROP TABLE IF EXISTS contagem_por_caminhao",
    """CREATE TABLE sensores (
           sensor_id text PRIMARY KEY, caminhao text, carga text,
           temp_min decimal, temp_max decimal)""",
    """CREATE TABLE leituras_por_sensor_dia (
           sensor_id text, dia date, ts timestamp,
           temperatura decimal, umidade decimal, lat double, lon double,
           PRIMARY KEY ((sensor_id, dia), ts)
       ) WITH CLUSTERING ORDER BY (ts DESC)
         AND default_time_to_live = 7776000
         AND compaction = {'class': 'TimeWindowCompactionStrategy',
                           'compaction_window_unit': 'DAYS',
                           'compaction_window_size': 1}""",
    """CREATE TABLE alertas_por_dia (
           dia date, ts timestamp, sensor_id text, caminhao text,
           temperatura decimal, limite text,
           PRIMARY KEY ((dia), ts, sensor_id)
       ) WITH CLUSTERING ORDER BY (ts DESC, sensor_id ASC)""",
    """CREATE TABLE ultima_leitura (
           sensor_id text PRIMARY KEY, caminhao text, ts timestamp,
           temperatura decimal)""",
    """CREATE TABLE contagem_por_caminhao (
           caminhao text, dia date, leituras counter,
           PRIMARY KEY ((caminhao), dia))""",
]

SENSORES = [
    # sensor, caminhao, carga, temp_min, temp_max
    ("SNS-001", "CAM-RS-01", "vacinas", Decimal("2.0"), Decimal("8.0")),
    ("SNS-002", "CAM-RS-01", "vacinas", Decimal("2.0"), Decimal("8.0")),
    ("SNS-003", "CAM-SC-02", "congelados", Decimal("-25.0"), Decimal("-18.0")),
    ("SNS-004", "CAM-PR-03", "laticinios", Decimal("0.0"), Decimal("7.0")),
]


def titulo(texto):
    print(f"\n{'=' * 70}\n{texto}\n{'=' * 70}")


# ---------------------------------------------------------------------------
# 1. Esquema
# ---------------------------------------------------------------------------
def criar_esquema(sessao):
    for comando in DDL:
        sessao.execute(comando)
    tabelas = sessao.execute(
        "SELECT table_name FROM system_schema.tables WHERE keyspace_name = %s",
        (KEYSPACE,))
    print("Tabelas no keyspace:", sorted(t.table_name for t in tabelas))


# ---------------------------------------------------------------------------
# 2. Cadastro com LWT
# ---------------------------------------------------------------------------
def cadastrar_sensores(sessao):
    """IF NOT EXISTS usa Paxos entre as replicas: e um 'compare-and-set'.
    Custa ~4 idas e voltas - use so quando realmente precisar de unicidade."""
    insert = sessao.prepare("""
        INSERT INTO sensores (sensor_id, caminhao, carga, temp_min, temp_max)
        VALUES (?, ?, ?, ?, ?) IF NOT EXISTS""")
    for s in SENSORES:
        sessao.execute(insert, s)
    # Segunda tentativa com o mesmo ID: aplicado = False, mostra a linha existente
    r = sessao.execute(insert, ("SNS-001", "CAM-XX-99", "outra", Decimal(0), Decimal(1))).one()
    print(f"Recadastro de SNS-001 aplicado? {r.applied} "
          f"(ja pertence ao {r.caminhao}, carga {r.carga})")


# ---------------------------------------------------------------------------
# 3 e 4. Ingestao
# ---------------------------------------------------------------------------
def gerar_leituras(qtd_por_sensor=360):
    """Gera 1 hora de leituras (a cada 10 s) para cada sensor, das 08:00 as 09:00.
    O SNS-002 sofre uma falha de refrigeracao as 08:40 (porta aberta)."""
    random.seed(28)
    inicio = datetime(2026, 10, 8, 8, 0, tzinfo=timezone.utc)
    for sensor_id, caminhao, _, tmin, tmax in SENSORES:
        base = float((tmin + tmax) / 2)
        for i in range(qtd_por_sensor):
            ts = inicio + timedelta(seconds=10 * i)
            temp = base + random.uniform(-1.2, 1.2)
            if sensor_id == "SNS-002" and 240 <= i < 270:   # 5 minutos de falha
                temp = 9.0 + (i - 240) * 0.12
            yield (sensor_id, caminhao, ts, Decimal(f"{temp:.2f}"),
                   Decimal(f"{random.uniform(40, 60):.1f}"),
                   -30.03 + i * 0.0005, -51.23 + i * 0.0004, tmin, tmax)


def ingerir(sessao):
    ins_leitura = sessao.prepare("""
        INSERT INTO leituras_por_sensor_dia
            (sensor_id, dia, ts, temperatura, umidade, lat, lon)
        VALUES (?, ?, ?, ?, ?, ?, ?)""")
    ins_ultima = sessao.prepare("""
        INSERT INTO ultima_leitura (sensor_id, caminhao, ts, temperatura)
        VALUES (?, ?, ?, ?)""")
    ins_alerta = sessao.prepare("""
        INSERT INTO alertas_por_dia (dia, ts, sensor_id, caminhao, temperatura, limite)
        VALUES (?, ?, ?, ?, ?, ?) USING TTL 31536000""")
    inc_contador = sessao.prepare("""
        UPDATE contagem_por_caminhao SET leituras = leituras + 1
        WHERE caminhao = ? AND dia = ?""")

    leituras, ultimas, alertas, contadores = [], {}, [], []
    for (sid, cam, ts, temp, umid, lat, lon, tmin, tmax) in gerar_leituras():
        dia = ts.date()
        leituras.append((sid, dia, ts, temp, umid, lat, lon))
        ultimas[sid] = (sid, cam, ts, temp)       # so a mais recente importa
        contadores.append((cam, dia))
        if temp > tmax or temp < tmin:
            alertas.append((dia, ts, sid, cam, temp, f"{tmin}..{tmax}"))

    # execute_concurrent: ate 100 requisicoes em voo ao mesmo tempo.
    # E assim que se escreve rapido no Cassandra - NAO com BATCH gigante.
    inicio = time.perf_counter()
    resultados = execute_concurrent_with_args(sessao, ins_leitura, leituras,
                                              concurrency=100)
    segundos = time.perf_counter() - inicio
    falhas = sum(1 for ok, _ in resultados if not ok)
    print(f"{len(leituras)} leituras gravadas em {segundos:.2f} s "
          f"({len(leituras) / segundos:,.0f} escritas/s) - falhas: {falhas}")

    execute_concurrent_with_args(sessao, ins_ultima, list(ultimas.values()))
    execute_concurrent_with_args(sessao, ins_alerta, alertas)
    execute_concurrent_with_args(sessao, inc_contador, contadores, concurrency=50)
    print(f"{len(alertas)} alertas gravados em alertas_por_dia (desnormalizado)")


# ---------------------------------------------------------------------------
# 5. Consultas
# ---------------------------------------------------------------------------
def consultas(sessao):
    print("[Q1] Ultimas 3 leituras do SNS-002 hoje (ja vem em ordem DESC):")
    for r in sessao.execute("""
            SELECT ts, temperatura FROM leituras_por_sensor_dia
            WHERE sensor_id = %s AND dia = %s LIMIT 3""", ("SNS-002", HOJE)):
        print(f"     {r.ts:%H:%M:%S}  {r.temperatura} C")

    print("[Q2] SNS-002 entre 08:39:30 e 08:41:00 (faixa na clustering key):")
    rows = sessao.execute("""
            SELECT ts, temperatura FROM leituras_por_sensor_dia
            WHERE sensor_id = %s AND dia = %s AND ts >= %s AND ts < %s""",
                          ("SNS-002", HOJE,
                           datetime(2026, 10, 8, 8, 39, 30, tzinfo=timezone.utc),
                           datetime(2026, 10, 8, 8, 41, 0, tzinfo=timezone.utc)))
    print("     ", [f"{r.ts:%H:%M:%S}={r.temperatura}" for r in rows])

    print("[Q3] Alertas do dia (primeiro e ultimo da falha):")
    alertas = list(sessao.execute(
        "SELECT ts, sensor_id, caminhao, temperatura, limite FROM alertas_por_dia "
        "WHERE dia = %s", (HOJE,)))
    for r in (alertas[-1], alertas[0]):
        print(f"     {r.ts:%H:%M:%S} {r.sensor_id} ({r.caminhao}) "
              f"{r.temperatura} C fora de {r.limite}")
    print(f"     total de alertas: {len(alertas)} -> falha durou "
          f"{(alertas[0].ts - alertas[-1].ts).seconds + 10} s")

    print("[Q4] Painel - ultima leitura de cada sensor:")
    for r in sessao.execute("SELECT * FROM ultima_leitura"):
        print(f"     {r.sensor_id} {r.caminhao} {r.ts:%H:%M:%S} {r.temperatura} C")


# ---------------------------------------------------------------------------
# 6. Contadores e paginacao
# ---------------------------------------------------------------------------
def contadores_e_paginacao(sessao):
    for r in sessao.execute("SELECT caminhao, dia, leituras FROM contagem_por_caminhao"):
        print(f"Contador {r.caminhao} em {r.dia}: {r.leituras} leituras")

    # fetch_size: o driver busca 100 linhas por vez; paging_state permite
    # retomar exatamente do ponto onde parou (ex.: botao "proxima pagina")
    stmt = SimpleStatement("SELECT ts FROM leituras_por_sensor_dia "
                           "WHERE sensor_id = %s AND dia = %s", fetch_size=100)
    pagina1 = sessao.execute(stmt, ("SNS-001", HOJE))
    linhas = pagina1.current_rows
    print(f"Pagina 1: {len(linhas)} linhas ({linhas[0].ts:%H:%M:%S} .. "
          f"{linhas[-1].ts:%H:%M:%S}); ha mais paginas? {pagina1.has_more_pages}")
    pagina2 = sessao.execute(stmt, ("SNS-001", HOJE), paging_state=pagina1.paging_state)
    print(f"Pagina 2 comeca em {pagina2.current_rows[0].ts:%H:%M:%S}")


# ---------------------------------------------------------------------------
# 7. Consistencia ajustavel
# ---------------------------------------------------------------------------
def consistencia(sessao):
    """Em um cluster real com RF=3:
        ONE    -> responde com 1 replica   (mais rapido, pode ler dado velho)
        QUORUM -> maioria (2 de 3)         (escrita QUORUM + leitura QUORUM = forte)
        ALL    -> todas as replicas        (cai se 1 no estiver fora)
    Aqui o cluster tem 1 no e RF=1, entao todos os niveis funcionam - exceto
    pedir mais replicas do que existem (TWO), o que gera Unavailable."""
    for nivel in (ConsistencyLevel.ONE, ConsistencyLevel.QUORUM,
                  ConsistencyLevel.ALL, ConsistencyLevel.TWO):
        stmt = SimpleStatement("SELECT temperatura FROM ultima_leitura WHERE sensor_id = %s",
                               consistency_level=nivel)
        nome = ConsistencyLevel.value_to_name[nivel]
        try:
            r = sessao.execute(stmt, ("SNS-003",)).one()
            print(f"Leitura com {nome:<6} -> OK ({r.temperatura} C)")
        except NoHostAvailable as erro:
            # o driver tenta outros nos e entrega a causa original por host
            causa = next(iter(erro.errors.values()))
            if isinstance(causa, Unavailable):
                print(f"Leitura com {nome:<6} -> Unavailable: exige "
                      f"{causa.required_replicas} replicas, vivas {causa.alive_replicas}")
            else:
                raise


# ---------------------------------------------------------------------------
# 8. Limites do modelo
# ---------------------------------------------------------------------------
def limites(sessao):
    try:
        sessao.execute("SELECT * FROM leituras_por_sensor_dia WHERE temperatura > 8")
    except InvalidRequest as erro:
        print("Consulta sem partition key RECUSADA:\n    ",
              str(erro).split("message=")[-1][:110], "...")
    print("Solucao: criar uma tabela para essa consulta (ex.: alertas_por_dia) "
          "- e nao usar ALLOW FILTERING em producao.")


def main():
    cluster = Cluster(CONTATOS, protocol_version=5)
    try:
        sessao = cluster.connect()
        titulo("1. Keyspace e tabelas (query-first)")
        criar_esquema(sessao)
        titulo("2. Cadastro de sensores com LWT")
        cadastrar_sensores(sessao)
        titulo("3/4. Ingestao concorrente + alertas desnormalizados")
        ingerir(sessao)
        titulo("5. Consultas pela partition key")
        consultas(sessao)
        titulo("6. Contadores e paginacao")
        contadores_e_paginacao(sessao)
        titulo("7. Niveis de consistencia")
        consistencia(sessao)
        titulo("8. O que o Cassandra nao deixa fazer")
        limites(sessao)
    finally:
        cluster.shutdown()


if __name__ == "__main__":
    main()
