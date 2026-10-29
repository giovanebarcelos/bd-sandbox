-- ============================================================================
-- BD2703-TutorialParticionamento.sql
-- Aula 27 - Tutorial passo a passo (parte A): particionamento declarativo
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Parte A do tutorial Aula_27_..._Tutorial_PostgreSQL.md, banco aula27.
-- A parte B (streaming replication) usa BD2702-DockerComposeReplicacao.yml.
-- Os passos 2, 6 e 7 tem erros PROPOSITAIS (o psql segue em frente).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. TABELA PARTICIONADA POR FAIXA (RANGE) DE DATA
-- ----------------------------------------------------------------------------
SET client_min_messages = warning;
DROP TABLE IF EXISTS venda, cliente, sessao CASCADE;
RESET client_min_messages;

-- a chave primaria PRECISA conter a coluna de particionamento
CREATE TABLE venda (
    venda_id    BIGINT GENERATED ALWAYS AS IDENTITY,
    data_venda  DATE NOT NULL,
    regiao      CHAR(2) NOT NULL,
    valor       NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (venda_id, data_venda)
) PARTITION BY RANGE (data_venda);

CREATE TABLE venda_2024 PARTITION OF venda FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE venda_2025 PARTITION OF venda FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE venda_2026 PARTITION OF venda FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- 300 mil vendas entre 2024 e 2026
INSERT INTO venda (data_venda, regiao, valor)
SELECT DATE '2024-01-01' + (g % 1095),
       (ARRAY['RS', 'SC', 'PR', 'SP', 'RJ'])[g % 5 + 1],
       10 + g % 500
  FROM generate_series(1, 300000) AS g;


-- ----------------------------------------------------------------------------
-- PASSO 2. UMA LINHA SEM PARTICAO E A PARTICAO DEFAULT
-- ----------------------------------------------------------------------------
-- 2027 nao tem particao: erro proposital
INSERT INTO venda (data_venda, regiao, valor) VALUES ('2027-03-01', 'RS', 1);

CREATE TABLE venda_default PARTITION OF venda DEFAULT;
INSERT INTO venda (data_venda, regiao, valor) VALUES ('2027-03-01', 'RS', 1);

ANALYZE venda;

-- onde cada linha foi parar
SELECT tableoid::regclass AS particao, COUNT(*) FROM venda GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- PASSO 3. PARTITION PRUNING
-- ----------------------------------------------------------------------------
-- filtro pela chave de particionamento: so a particao de 2025 e lida
EXPLAIN (COSTS OFF)
SELECT SUM(valor) FROM venda WHERE data_venda BETWEEN '2025-03-01' AND '2025-03-31';

-- filtro por outra coluna: todas as particoes sao lidas
EXPLAIN (COSTS OFF)
SELECT SUM(valor) FROM venda WHERE regiao = 'RS';


-- ----------------------------------------------------------------------------
-- PASSO 4. INDICE NA TABELA-MAE = UM INDICE EM CADA PARTICAO
-- ----------------------------------------------------------------------------
CREATE INDEX idx_venda_regiao ON venda (regiao);

SELECT indexrelid::regclass AS indice, indrelid::regclass AS tabela
  FROM pg_index
 WHERE indexrelid::regclass::text LIKE '%regiao%'
 ORDER BY 2;


-- ----------------------------------------------------------------------------
-- PASSO 5. APAGAR UM ANO INTEIRO: DELETE x DETACH + DROP
-- ----------------------------------------------------------------------------
\timing on
DELETE FROM venda WHERE data_venda < '2025-01-01';
\timing off

-- recarrega 2024 para comparar com o DETACH
INSERT INTO venda (data_venda, regiao, valor)
SELECT DATE '2024-01-01' + (g % 366), 'RS', 1 FROM generate_series(1, 100000) AS g;

\timing on
ALTER TABLE venda DETACH PARTITION venda_2024;
\timing off

-- a particao desanexada vira uma tabela comum (pode ir para backup/arquivo)
SELECT COUNT(*) AS linhas_em_venda_2024 FROM venda_2024;
DROP TABLE venda_2024;


-- ----------------------------------------------------------------------------
-- PASSO 6. CRIAR A PARTICAO DO PROXIMO ANO
-- ----------------------------------------------------------------------------
-- a default tem uma linha de 2027: o PostgreSQL confere e recusa (proposital)
CREATE TABLE venda_2027 PARTITION OF venda FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

-- solucao: tirar a linha da default antes, e recoloca-la depois
BEGIN;
CREATE TEMP TABLE pendentes AS SELECT data_venda, regiao, valor FROM venda_default;
DELETE FROM venda_default;
CREATE TABLE venda_2027 PARTITION OF venda FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
INSERT INTO venda (data_venda, regiao, valor) SELECT * FROM pendentes;
COMMIT;

SELECT tableoid::regclass AS particao, COUNT(*) FROM venda GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- PASSO 7. PARTICIONAMENTO POR LISTA (LIST)
-- ----------------------------------------------------------------------------
CREATE TABLE cliente (
    cliente_id  INT NOT NULL,
    regiao      CHAR(2) NOT NULL
) PARTITION BY LIST (regiao);

CREATE TABLE cliente_sul     PARTITION OF cliente FOR VALUES IN ('RS', 'SC', 'PR');
CREATE TABLE cliente_sudeste PARTITION OF cliente FOR VALUES IN ('SP', 'RJ', 'MG', 'ES');

INSERT INTO cliente VALUES (1, 'RS'), (2, 'SP'), (3, 'SC');

-- BA nao esta em nenhuma lista: erro proposital
INSERT INTO cliente VALUES (4, 'BA');


-- ----------------------------------------------------------------------------
-- PASSO 8. PARTICIONAMENTO POR HASH: distribuicao uniforme
-- ----------------------------------------------------------------------------
CREATE TABLE sessao (id BIGINT NOT NULL, dados JSONB) PARTITION BY HASH (id);
CREATE TABLE sessao_p0 PARTITION OF sessao FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessao_p1 PARTITION OF sessao FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessao_p2 PARTITION OF sessao FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessao_p3 PARTITION OF sessao FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO sessao SELECT g, '{}' FROM generate_series(1, 10000) AS g;

SELECT tableoid::regclass AS particao, COUNT(*) FROM sessao GROUP BY 1 ORDER BY 1;
