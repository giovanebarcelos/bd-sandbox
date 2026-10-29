-- ============================================================================
-- BD2302-TutorialCatalogo.sql
-- Aula 23 - Tutorial passo a passo: o catalogo do PostgreSQL
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro do tutorial Aula_23_..._Tutorial_PostgreSQL.md, banco aula23.
-- Usa o schema BoaSaude de BD2301-Catalogo.sql. O passo 4 usa meta-comandos
-- do psql (\set ECHO_HIDDEN, \d): rode no psql.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. SCHEMA BoaSaude (o mesmo da aula)
-- ----------------------------------------------------------------------------
SET client_min_messages = warning;
DROP VIEW  IF EXISTS vw_agenda;
DROP TABLE IF EXISTS consulta, paciente, convenio, medico, especialidade CASCADE;
RESET client_min_messages;

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

CREATE VIEW vw_agenda AS
SELECT c.data_hora, m.nome AS medico, p.nome AS paciente, c.status
  FROM consulta c
  JOIN medico m   ON m.medico_id = c.medico_id
  JOIN paciente p ON p.paciente_id = c.paciente_id;

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
-- PASSO 2. information_schema: a camada PORTAVEL (padrao SQL)
-- ----------------------------------------------------------------------------
SELECT table_name, table_type
  FROM information_schema.tables
 WHERE table_schema = 'public'
 ORDER BY table_name;

SELECT column_name, data_type, character_maximum_length AS tam,
       numeric_precision AS prec, numeric_scale AS esc, is_nullable, column_default
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'consulta'
 ORDER BY ordinal_position;


-- ----------------------------------------------------------------------------
-- PASSO 3. pg_catalog: a camada NATIVA (mais rica, nao portavel)
-- ----------------------------------------------------------------------------
-- relkind: r = tabela, v = view, i = indice, S = sequence
SELECT c.relname AS objeto, c.relkind, c.reltuples::bigint AS linhas_estimadas
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public'
 ORDER BY c.relkind, c.relname;

-- reltuples = -1 significa "nunca analisada": as estatisticas vem do ANALYZE
ANALYZE;

SELECT c.relname AS tabela, c.reltuples::bigint AS linhas_estimadas, c.relpages AS paginas
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind = 'r'
 ORDER BY c.relname;


-- ----------------------------------------------------------------------------
-- PASSO 4. O SQL ESCONDIDO ATRAS DOS META-COMANDOS DO psql
-- ----------------------------------------------------------------------------
\set ECHO_HIDDEN on
\dt
\set ECHO_HIDDEN off


-- ----------------------------------------------------------------------------
-- PASSO 5. CONSTRAINTS: information_schema x pg_constraint
-- ----------------------------------------------------------------------------
SELECT tc.table_name, tc.constraint_name, tc.constraint_type
  FROM information_schema.table_constraints tc
 WHERE tc.table_schema = 'public'
   AND tc.constraint_type <> 'CHECK'
 ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- FKs: tabela filha -> tabela pai
SELECT tc.table_name  AS tabela_filha,
       kcu.column_name AS coluna_fk,
       ccu.table_name  AS tabela_pai,
       ccu.column_name AS coluna_pai
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
 WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
 ORDER BY 1, 2;

-- pg_constraint + pg_get_constraintdef: a definicao completa, inclusive CHECK
SELECT conrelid::regclass AS tabela, conname AS constraint, contype,
       pg_get_constraintdef(oid) AS definicao
  FROM pg_catalog.pg_constraint
 WHERE connamespace = 'public'::regnamespace
 ORDER BY conrelid::regclass::text, contype, conname;


-- ----------------------------------------------------------------------------
-- PASSO 6. INDICES: os automaticos (PK/UNIQUE) e as FKs sem indice
-- ----------------------------------------------------------------------------
SELECT tablename, indexname, indexdef
  FROM pg_catalog.pg_indexes
 WHERE schemaname = 'public'
 ORDER BY tablename, indexname;

-- quem criou cada indice? (PK, UNIQUE ou CREATE INDEX)
SELECT i.indrelid::regclass AS tabela, i.indexrelid::regclass AS indice,
       CASE c.contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'u' THEN 'UNIQUE'
                      ELSE 'CREATE INDEX' END AS origem
  FROM pg_catalog.pg_index i
  -- conrelid = indrelid: so a constraint DA PROPRIA tabela (uma FK tambem
  -- aponta, em conindid, para o indice da PK da tabela-mae)
  LEFT JOIN pg_catalog.pg_constraint c ON c.conindid = i.indexrelid AND c.conrelid = i.indrelid
  JOIN pg_catalog.pg_class t ON t.oid = i.indrelid
 WHERE t.relnamespace = 'public'::regnamespace
 ORDER BY 1, 2;

-- FKs cuja coluna nao lidera nenhum indice (Aula 25, passo 7)
SELECT c.conrelid::regclass AS tabela, a.attname AS coluna_fk
  FROM pg_catalog.pg_constraint c
  JOIN pg_catalog.pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
 WHERE c.contype = 'f'
   AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_index i
                    WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1])
 ORDER BY 1, 2;


-- ----------------------------------------------------------------------------
-- PASSO 7. COMENTARIOS: documentacao que vive DENTRO do catalogo
-- ----------------------------------------------------------------------------
COMMENT ON TABLE paciente IS 'Cadastro de pacientes da clinica BoaSaude';
COMMENT ON COLUMN paciente.cpf IS 'CPF do paciente, somente digitos, unico';
COMMENT ON TABLE consulta IS 'Consultas agendadas/realizadas/canceladas na clinica';
COMMENT ON COLUMN consulta.status IS 'Situacao da consulta: AGENDADA, REALIZADA ou CANCELADA';

SELECT c.relname AS tabela, obj_description(c.oid, 'pg_class') AS comentario
  FROM pg_catalog.pg_class c
 WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
 ORDER BY 1;

-- comentario de coluna pelo NOME (col_description pede o numero da coluna)
SELECT a.attname AS coluna, col_description(a.attrelid, a.attnum) AS comentario
  FROM pg_catalog.pg_attribute a
 WHERE a.attrelid = 'consulta'::regclass AND a.attnum > 0 AND NOT a.attisdropped
 ORDER BY a.attnum;


-- ----------------------------------------------------------------------------
-- PASSO 8. O CATALOGO E ATUALIZADO NA HORA, E DENTRO DA TRANSACAO
-- ----------------------------------------------------------------------------
ALTER TABLE paciente ADD COLUMN cidade VARCHAR(60);

SELECT column_name, data_type FROM information_schema.columns
 WHERE table_name = 'paciente' AND column_name = 'cidade';

-- DDL transacional: o DROP so vale para os outros depois do COMMIT
BEGIN;
DROP TABLE convenio CASCADE;
SELECT COUNT(*) AS convenio_existe FROM information_schema.tables WHERE table_name = 'convenio';
ROLLBACK;
SELECT COUNT(*) AS convenio_existe FROM information_schema.tables WHERE table_name = 'convenio';

ALTER TABLE paciente DROP COLUMN cidade;


-- ----------------------------------------------------------------------------
-- PASSO 9. TAMANHOS E ESTATISTICAS DE USO
-- ----------------------------------------------------------------------------
SELECT relname AS tabela,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid))       AS dados,
       pg_size_pretty(pg_indexes_size(relid))        AS indices,
       seq_scan, idx_scan, n_live_tup
  FROM pg_stat_user_tables
 ORDER BY pg_total_relation_size(relid) DESC;

-- DDL de view e de funcao: o catalogo guarda o codigo-fonte
SELECT pg_get_viewdef('vw_agenda'::regclass, true) AS definicao_da_view;


-- ----------------------------------------------------------------------------
-- PASSO 10. PRIVILEGIOS NO CATALOGO
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'recepcao') THEN
        CREATE ROLE recepcao LOGIN PASSWORD 'recepcao';
    END IF;
END;
$$;
GRANT SELECT ON paciente, vw_agenda TO recepcao;

SELECT grantee, table_name, privilege_type
  FROM information_schema.table_privileges
 WHERE grantee = 'recepcao'
 ORDER BY table_name;


-- ----------------------------------------------------------------------------
-- PASSO 11. RELATORIO: O DICIONARIO DE DADOS DO PROJETO
-- ----------------------------------------------------------------------------
SELECT c.table_name AS tabela,
       c.column_name AS coluna,
       CASE WHEN c.character_maximum_length IS NOT NULL
            THEN c.data_type || '(' || c.character_maximum_length || ')'
            WHEN c.data_type = 'numeric'
            THEN 'numeric(' || c.numeric_precision || ',' || c.numeric_scale || ')'
            ELSE c.data_type END AS tipo,
       CASE c.is_nullable WHEN 'NO' THEN 'sim' ELSE '' END AS obrigatoria,
       CASE WHEN pk.column_name IS NOT NULL THEN 'PK' ELSE '' END AS pk,
       COALESCE(col_description((quote_ident(c.table_schema) || '.' || quote_ident(c.table_name))::regclass,
                                c.ordinal_position::int), '') AS descricao
  FROM information_schema.columns c
  JOIN information_schema.tables t
    ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
  LEFT JOIN (SELECT kcu.table_schema, kcu.table_name, kcu.column_name
               FROM information_schema.table_constraints tc
               JOIN information_schema.key_column_usage kcu
                 ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
              WHERE tc.constraint_type = 'PRIMARY KEY') pk
    ON pk.table_schema = c.table_schema AND pk.table_name = c.table_name AND pk.column_name = c.column_name
 WHERE c.table_schema = 'public'
 ORDER BY c.table_name, c.ordinal_position;
