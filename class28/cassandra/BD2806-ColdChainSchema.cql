-- ============================================================================
-- BD2806 - Esquema Cassandra da "ColdChain": telemetria de caminhoes refrigerados
-- Disciplina: Banco de Dados | Aula 28D - Cassandra em Profundidade
-- Prof. Giovane Barcelos
--
-- Execucao:
--   docker cp BD2806-ColdChainSchema.cql bd28-cassandra:/tmp/
--   docker exec -it bd28-cassandra cqlsh -f /tmp/BD2806-ColdChainSchema.cql
--
-- Regra de ouro do Cassandra: MODELE PELAS CONSULTAS, nao pelas entidades.
-- Uma tabela por consulta; duplicar dado e normal.
--
--   Q1: ultimas N leituras de um sensor em um dia      -> leituras_por_sensor_dia
--   Q2: leituras de um sensor em uma faixa de horario  -> leituras_por_sensor_dia
--   Q3: alertas de temperatura de um dia (todos)       -> alertas_por_dia
--   Q4: ultima leitura de cada sensor (painel)         -> ultima_leitura
--   Q5: quantas leituras cada caminhao enviou por dia  -> contagem_por_caminhao
-- ============================================================================

-- Em producao: NetworkTopologyStrategy com RF=3 por data center
CREATE KEYSPACE IF NOT EXISTS coldchain
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE coldchain;

-- Registro de sensores (usado com LWT: IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS sensores (
    sensor_id   text PRIMARY KEY,
    caminhao    text,
    carga       text,
    temp_min    decimal,
    temp_max    decimal
);

-- Q1/Q2: partition key composta (sensor_id, dia) = "bucket" diario.
-- Evita partição gigante: 1 leitura a cada 10 s = 8.640 linhas/dia/sensor.
CREATE TABLE IF NOT EXISTS leituras_por_sensor_dia (
    sensor_id   text,
    dia         date,
    ts          timestamp,
    temperatura decimal,
    umidade     decimal,
    lat         double,
    lon         double,
    PRIMARY KEY ((sensor_id, dia), ts)
) WITH CLUSTERING ORDER BY (ts DESC)
  AND default_time_to_live = 7776000          -- 90 dias: expira sozinho
  AND compaction = {'class': 'TimeWindowCompactionStrategy',
                    'compaction_window_unit': 'DAYS',
                    'compaction_window_size': 1};

-- Q3: mesma informacao, organizada por dia (desnormalizacao proposital)
CREATE TABLE IF NOT EXISTS alertas_por_dia (
    dia         date,
    ts          timestamp,
    sensor_id   text,
    caminhao    text,
    temperatura decimal,
    limite      text,
    PRIMARY KEY ((dia), ts, sensor_id)
) WITH CLUSTERING ORDER BY (ts DESC, sensor_id ASC);

-- Q4: upsert - cada INSERT sobrescreve a linha do sensor
CREATE TABLE IF NOT EXISTS ultima_leitura (
    sensor_id   text PRIMARY KEY,
    caminhao    text,
    ts          timestamp,
    temperatura decimal
);

-- Q5: tabela de contadores (so pode ter colunas counter fora da chave)
CREATE TABLE IF NOT EXISTS contagem_por_caminhao (
    caminhao    text,
    dia         date,
    leituras    counter,
    PRIMARY KEY ((caminhao), dia)
);

-- Exemplos de consultas validas (sempre informando a partition key):
-- SELECT * FROM leituras_por_sensor_dia
--  WHERE sensor_id = 'SNS-001' AND dia = '2026-10-08' LIMIT 5;
-- SELECT ts, temperatura FROM leituras_por_sensor_dia
--  WHERE sensor_id = 'SNS-001' AND dia = '2026-10-08'
--    AND ts >= '2026-10-08 08:00:00+0000' AND ts < '2026-10-08 09:00:00+0000';
-- SELECT * FROM alertas_por_dia WHERE dia = '2026-10-08';
--
-- Consulta INVALIDA (sem partition key) - o Cassandra recusa:
-- SELECT * FROM leituras_por_sensor_dia WHERE temperatura > 8;
--   -> "Cannot execute this query as it might involve data filtering..."
