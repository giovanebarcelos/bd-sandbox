-- ============================================================================
-- BD2401-Indices.sql
-- Aula 24 - Indices: tipos e planos de execucao - POSTGRESQL
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Objetivo: reconstruir o schema BoaSaude com VOLUME de dados realista e
-- demonstrar, com EXPLAIN ANALYZE, o efeito de indices B-tree, Hash, GIN
-- e GiST sobre o plano de execucao.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Esquema BoaSaude (igual a Aula 23, + tabela PRONTUARIO)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS prontuario;
DROP TABLE IF EXISTS consulta;
DROP TABLE IF EXISTS paciente;
DROP TABLE IF EXISTS convenio;
DROP TABLE IF EXISTS medico;
DROP TABLE IF EXISTS especialidade;

CREATE TABLE especialidade (
    especialidade_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome              VARCHAR(80) NOT NULL
);

CREATE TABLE medico (
    medico_id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome              VARCHAR(120) NOT NULL,
    crm               VARCHAR(20) NOT NULL UNIQUE,
    especialidade_id  INTEGER NOT NULL REFERENCES especialidade (especialidade_id)
);

CREATE TABLE convenio (
    convenio_id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome                  VARCHAR(80) NOT NULL,
    percentual_cobertura  NUMERIC(5,2) NOT NULL
);

CREATE TABLE paciente (
    paciente_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome             VARCHAR(120) NOT NULL,
    cpf              CHAR(11) NOT NULL UNIQUE,
    data_nascimento  DATE NOT NULL,
    sexo             CHAR(1) NOT NULL,
    telefone         VARCHAR(20),
    email            VARCHAR(120)
);

CREATE TABLE consulta (
    consulta_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paciente_id  INTEGER NOT NULL REFERENCES paciente (paciente_id),
    medico_id    INTEGER NOT NULL REFERENCES medico (medico_id),
    convenio_id  INTEGER REFERENCES convenio (convenio_id),
    data_hora    TIMESTAMP NOT NULL,
    status       VARCHAR(15) NOT NULL CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
    valor        NUMERIC(10,2) NOT NULL
);

CREATE TABLE prontuario (
    prontuario_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paciente_id    INTEGER NOT NULL REFERENCES paciente (paciente_id),
    descricao      TEXT,
    data_registro  DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2) Massa de dados (generate_series produz volume realista rapidamente)
-- ----------------------------------------------------------------------------
INSERT INTO especialidade (nome) VALUES
    ('Clinica Geral'), ('Cardiologia'), ('Pediatria'), ('Ortopedia');

INSERT INTO convenio (nome, percentual_cobertura) VALUES
    ('Particular', 0), ('SaudeBem', 80), ('VidaPlena', 100);

-- 200 medicos
INSERT INTO medico (nome, crm, especialidade_id)
SELECT 'Dr(a). Medico ' || g,
       'CRM-' || LPAD(g::text, 6, '0'),
       (g % 4) + 1
FROM   generate_series(1, 200) AS g;

-- 50.000 pacientes
INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
SELECT 'Paciente ' || g,
       LPAD(g::text, 11, '0'),
       DATE '1950-01-01' + (g % 18000),
       CASE g % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
       '519' || LPAD(g::text, 8, '0'),
       'paciente' || g || '@boasaude.com.br'
FROM   generate_series(1, 50000) AS g;

-- 300.000 consultas (distribuidas nos ultimos ~2 anos)
INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT (g % 50000) + 1,
       (g % 200) + 1,
       (g % 3) + 1,
       TIMESTAMP '2024-01-01 08:00:00' + ((g % 730) || ' days')::interval
                                       + ((g % 10) || ' hours')::interval,
       CASE g % 20 WHEN 0 THEN 'CANCELADA' WHEN 1 THEN 'AGENDADA' ELSE 'REALIZADA' END,
       ROUND((80 + random() * 420)::numeric, 2)
FROM   generate_series(1, 300000) AS g;

INSERT INTO prontuario (paciente_id, descricao, data_registro)
SELECT (g % 50000) + 1,
       'Paciente relata dor de cabeca recorrente e cansaco. ' ||
       'Pressao arterial dentro da normalidade. Solicitado exame de sangue.',
       DATE '2024-01-01' + (g % 730)
FROM   generate_series(1, 20000) AS g;

ANALYZE especialidade;
ANALYZE medico;
ANALYZE convenio;
ANALYZE paciente;
ANALYZE consulta;
ANALYZE prontuario;

-- ----------------------------------------------------------------------------
-- 3) ANTES do indice: consulta por data faz Seq Scan
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';
-- Esperado: Seq Scan on consulta (sem indice na coluna data_hora)

-- ----------------------------------------------------------------------------
-- 4) Indice B-TREE composto (medico_id, data_hora) — agenda por medico
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_medico_data ON consulta (medico_id, data_hora);

EXPLAIN ANALYZE
SELECT consulta_id, data_hora, status
FROM   consulta
WHERE  medico_id = 42
AND    data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';
-- Esperado: Index Scan/Bitmap Index Scan em idx_consulta_medico_data

-- ----------------------------------------------------------------------------
-- 5) Indice HASH — igualdade exata em status (nao serve para BETWEEN/ORDER BY)
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT * FROM consulta WHERE status = 'CANCELADA';
-- Esperado (antes): Seq Scan

CREATE INDEX idx_consulta_status_hash ON consulta USING HASH (status);

EXPLAIN ANALYZE
SELECT * FROM consulta WHERE status = 'CANCELADA';
-- Esperado (depois): Bitmap Heap Scan + Bitmap Index Scan em idx_consulta_status_hash
-- (Hash so aceita operador de igualdade "="; nao serve para <, >, BETWEEN, ORDER BY)

-- ----------------------------------------------------------------------------
-- 6) Indice GIN — busca textual em prontuario.descricao (full text search)
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT prontuario_id FROM prontuario
WHERE  to_tsvector('portuguese', descricao) @@ to_tsquery('portuguese', 'dor & cabeca');
-- Esperado (antes): Seq Scan, recalculando to_tsvector() linha a linha

CREATE INDEX idx_prontuario_descricao_gin
    ON prontuario USING GIN (to_tsvector('portuguese', descricao));

EXPLAIN ANALYZE
SELECT prontuario_id FROM prontuario
WHERE  to_tsvector('portuguese', descricao) @@ to_tsquery('portuguese', 'dor & cabeca');
-- Esperado (depois): Bitmap Heap Scan + Bitmap Index Scan em idx_prontuario_descricao_gin
-- Equivalente conceitual no Oracle: indice de texto (Oracle Text / CONTEXT),
-- recurso separado que exige o componente Oracle Text instalado.

-- ----------------------------------------------------------------------------
-- 7) Indice GiST + EXCLUDE — impedir conflito de horario do mesmo medico
--    (recurso sem equivalente direto no Oracle: tipos de intervalo (range
--    types) e constraint EXCLUDE sao exclusivos do PostgreSQL)
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE consulta ADD COLUMN periodo tsrange
    GENERATED ALWAYS AS (tsrange(data_hora, data_hora + interval '30 minutes')) STORED;

CREATE INDEX idx_consulta_periodo_gist ON consulta USING GIST (medico_id, periodo);

-- A constraint abaixo so pode ser adicionada em ambiente limpo (sem overlaps
-- pre-existentes na massa gerada); em aula, demonstrar em uma tabela menor:
-- ALTER TABLE consulta ADD CONSTRAINT excl_consulta_sem_conflito
--     EXCLUDE USING GIST (medico_id WITH =, periodo WITH &&)
--     WHERE (status <> 'CANCELADA');

EXPLAIN ANALYZE
SELECT consulta_id FROM consulta
WHERE  medico_id = 42
AND    periodo && tsrange('2025-06-02 09:00:00', '2025-06-02 09:30:00');
-- Esperado: Index Scan em idx_consulta_periodo_gist usando o operador && (overlap)

-- ----------------------------------------------------------------------------
-- 8) Uso de EXPLAIN (ANALYZE, BUFFERS) para inspecionar E/S
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT m.nome, COUNT(*) AS total_consultas
FROM   consulta c
JOIN   medico m ON m.medico_id = c.medico_id
WHERE  c.data_hora >= '2025-01-01'
GROUP  BY m.nome
ORDER  BY total_consultas DESC
LIMIT  10;
