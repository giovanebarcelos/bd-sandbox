-- ============================================================================
-- BD2301-Catalogo.sql
-- Aula 23 - Catalogo do banco de dados (data dictionary) - POSTGRESQL
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Objetivo: introduzir o esquema de exemplo "BoaSaude" (clinica medica) e
-- demonstrar consultas ao catalogo do PostgreSQL via information_schema
-- (padrao SQL, portavel entre SGBDs) e pg_catalog (interno, especifico do
-- Postgres, usado pelo psql). Ao final, os meta-comandos do psql equivalentes.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Esquema de exemplo: clinica BoaSaude
-- ----------------------------------------------------------------------------
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
    percentual_cobertura  NUMERIC(5,2) NOT NULL CHECK (percentual_cobertura BETWEEN 0 AND 100)
);

CREATE TABLE paciente (
    paciente_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome             VARCHAR(120) NOT NULL,
    cpf              CHAR(11) NOT NULL UNIQUE,
    data_nascimento  DATE NOT NULL,
    sexo             CHAR(1) NOT NULL CHECK (sexo IN ('M', 'F', 'O')),
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

-- Comentarios de dicionario de dados (armazenados em pg_description,
-- expostos por information_schema e por \d+ no psql).
COMMENT ON TABLE paciente IS 'Cadastro de pacientes da clinica BoaSaude';
COMMENT ON COLUMN paciente.cpf IS 'CPF do paciente, somente digitos, unico';
COMMENT ON TABLE consulta IS 'Consultas agendadas/realizadas/canceladas na clinica';
COMMENT ON COLUMN consulta.status IS 'Situacao da consulta: AGENDADA, REALIZADA ou CANCELADA';

INSERT INTO especialidade (nome) VALUES ('Clinica Geral'), ('Cardiologia'), ('Pediatria');

INSERT INTO medico (nome, crm, especialidade_id) VALUES
    ('Dra. Ana Souza', 'CRM-11111', 1),
    ('Dr. Bruno Lima', 'CRM-22222', 2),
    ('Dra. Carla Melo', 'CRM-33333', 3);

INSERT INTO convenio (nome, percentual_cobertura) VALUES
    ('Particular', 0), ('SaudeBem', 80), ('VidaPlena', 100);

INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email) VALUES
    ('Joao Pereira', '11122233344', '1990-05-12', 'M', '51999990001', 'joao@exemplo.com'),
    ('Maria Santos', '22233344455', '1985-11-30', 'F', '51999990002', 'maria@exemplo.com');

INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor) VALUES
    (1, 1, 2, '2026-07-10 09:00:00', 'AGENDADA', 150.00),
    (2, 2, 3, '2026-07-10 10:30:00', 'AGENDADA', 250.00);

-- ----------------------------------------------------------------------------
-- 2) information_schema.tables / columns (padrao ANSI SQL, portavel)
-- ----------------------------------------------------------------------------
SELECT table_schema, table_name, table_type
FROM   information_schema.tables
WHERE  table_schema = 'public'
ORDER  BY table_name;

SELECT column_name, data_type, character_maximum_length,
       numeric_precision, numeric_scale, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'public' AND table_name = 'consulta'
ORDER  BY ordinal_position;

-- ----------------------------------------------------------------------------
-- 3) Constraints: table_constraints + key_column_usage + referential_constraints
-- ----------------------------------------------------------------------------
SELECT tc.constraint_name, tc.constraint_type, tc.table_name
FROM   information_schema.table_constraints tc
WHERE  tc.table_schema = 'public'
  AND  tc.table_name IN ('paciente', 'consulta', 'medico')
ORDER  BY tc.table_name, tc.constraint_type;

SELECT kcu.constraint_name, kcu.table_name, kcu.column_name, kcu.ordinal_position
FROM   information_schema.key_column_usage kcu
WHERE  kcu.table_schema = 'public' AND kcu.table_name = 'consulta'
ORDER  BY kcu.constraint_name, kcu.ordinal_position;

-- Fluxo tipico: descobrir a FK e a tabela referenciada (join com
-- constraint_column_usage, que traz a tabela do lado "pai")
SELECT tc.constraint_name AS fk_name,
       tc.table_name       AS tabela_filha,
       kcu.column_name     AS coluna_fk,
       ccu.table_name      AS tabela_pai,
       ccu.column_name     AS coluna_pai
FROM   information_schema.table_constraints tc
JOIN   information_schema.key_column_usage kcu
       ON kcu.constraint_name = tc.constraint_name
JOIN   information_schema.constraint_column_usage ccu
       ON ccu.constraint_name = tc.constraint_name
WHERE  tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
ORDER  BY tc.table_name;

-- ----------------------------------------------------------------------------
-- 4) pg_catalog: o catalogo NATIVO do Postgres (mais rico, porem nao-portavel)
-- ----------------------------------------------------------------------------
-- Tabelas do schema 'public' via pg_class + pg_namespace:
SELECT c.relname AS tabela, c.relkind, c.reltuples::bigint AS linhas_estimadas
FROM   pg_catalog.pg_class c
JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE  n.nspname = 'public' AND c.relkind = 'r'
ORDER  BY c.relname;

-- Indices (view pg_indexes eh uma leitura amigavel sobre pg_class/pg_index):
SELECT schemaname, tablename, indexname, indexdef
FROM   pg_catalog.pg_indexes
WHERE  schemaname = 'public'
ORDER  BY tablename, indexname;

-- Colunas via pg_attribute (equivalente de baixo nivel a information_schema.columns):
SELECT a.attname AS coluna, a.attnum AS posicao, t.typname AS tipo
FROM   pg_catalog.pg_attribute a
JOIN   pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN   pg_catalog.pg_type t  ON t.oid = a.atttypid
WHERE  c.relname = 'consulta' AND a.attnum > 0 AND NOT a.attisdropped
ORDER  BY a.attnum;

-- Estatisticas de uso (equivalente conceitual a monitoracao de acesso):
SELECT relname, seq_scan, idx_scan, n_live_tup, n_dead_tup
FROM   pg_stat_user_tables
WHERE  schemaname = 'public'
ORDER  BY relname;

-- Comentarios (equivalente a USER_TAB_COMMENTS/USER_COL_COMMENTS do Oracle):
SELECT obj_description('consulta'::regclass, 'pg_class') AS comentario_tabela;
SELECT col_description('consulta'::regclass, 6) AS comentario_coluna_status;

-- ----------------------------------------------------------------------------
-- 5) Meta-comandos do psql (NAO sao SQL padrao - sao atalhos do cliente psql
--    que internamente executam consultas equivalentes as acima)
-- ----------------------------------------------------------------------------
-- \dt              -> lista as tabelas do schema atual (equivale a consulta 2)
-- \dt+             -> lista tabelas com tamanho em disco e descricao
-- \d consulta       -> estrutura da tabela consulta: colunas, tipos, defaults,
--                      indices, constraints, FKs (visao consolidada)
-- \d+ consulta      -> igual ao \d, incluindo estatisticas de armazenamento
-- \di              -> lista todos os indices do schema atual
-- \dc              -> lista os "encodings" de conexao disponiveis
-- \dn              -> lista os schemas do banco atual
-- \df              -> lista as functions/procedures do schema atual
-- \dg              -> lista roles/grupos
-- \l               -> lista todos os bancos de dados do cluster
-- \x               -> alterna saida para o formato expandido (1 coluna por linha)
-- \timing          -> ativa a exibicao do tempo de execucao de cada comando
