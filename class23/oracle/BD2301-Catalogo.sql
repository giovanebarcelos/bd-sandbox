-- ============================================================================
-- BD2301-Catalogo.sql
-- Aula 23 - Catalogo do banco de dados (data dictionary) - ORACLE
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Objetivo: introduzir o esquema de exemplo "BoaSaude" (clinica medica) e
-- demonstrar consultas ao catalogo/dicionario de dados do Oracle:
-- USER_TABLES, ALL_TAB_COLUMNS, USER_CONSTRAINTS, USER_INDEXES, DBA_* (visao
-- conceitual), USER_TAB_COMMENTS/USER_COL_COMMENTS, USER_OBJECTS.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Esquema de exemplo: clinica BoaSaude
-- ----------------------------------------------------------------------------
DROP TABLE consulta PURGE;
DROP TABLE paciente PURGE;
DROP TABLE convenio PURGE;
DROP TABLE medico PURGE;
DROP TABLE especialidade PURGE;

CREATE TABLE especialidade (
    especialidade_id NUMBER(6)   GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR2(80) NOT NULL,
    CONSTRAINT pk_especialidade PRIMARY KEY (especialidade_id)
);

CREATE TABLE medico (
    medico_id        NUMBER(6)    GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR2(120) NOT NULL,
    crm              VARCHAR2(20)  NOT NULL,
    especialidade_id NUMBER(6)    NOT NULL,
    CONSTRAINT pk_medico PRIMARY KEY (medico_id),
    CONSTRAINT uq_medico_crm UNIQUE (crm),
    CONSTRAINT fk_medico_especialidade FOREIGN KEY (especialidade_id)
        REFERENCES especialidade (especialidade_id)
);

CREATE TABLE convenio (
    convenio_id           NUMBER(6)   GENERATED ALWAYS AS IDENTITY,
    nome                  VARCHAR2(80) NOT NULL,
    percentual_cobertura  NUMBER(5,2) NOT NULL,
    CONSTRAINT pk_convenio PRIMARY KEY (convenio_id),
    CONSTRAINT ck_convenio_percentual CHECK (percentual_cobertura BETWEEN 0 AND 100)
);

CREATE TABLE paciente (
    paciente_id      NUMBER(10)   GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR2(120) NOT NULL,
    cpf              VARCHAR2(11)  NOT NULL,
    data_nascimento  DATE          NOT NULL,
    sexo             CHAR(1)       NOT NULL,
    telefone         VARCHAR2(20),
    email            VARCHAR2(120),
    CONSTRAINT pk_paciente PRIMARY KEY (paciente_id),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT ck_paciente_sexo CHECK (sexo IN ('M', 'F', 'O'))
);

CREATE TABLE consulta (
    consulta_id  NUMBER(12)    GENERATED ALWAYS AS IDENTITY,
    paciente_id  NUMBER(10)    NOT NULL,
    medico_id    NUMBER(6)     NOT NULL,
    convenio_id  NUMBER(6),
    data_hora    TIMESTAMP     NOT NULL,
    status       VARCHAR2(15)  NOT NULL,
    valor        NUMBER(10,2)  NOT NULL,
    CONSTRAINT pk_consulta PRIMARY KEY (consulta_id),
    CONSTRAINT fk_consulta_paciente FOREIGN KEY (paciente_id) REFERENCES paciente (paciente_id),
    CONSTRAINT fk_consulta_medico   FOREIGN KEY (medico_id)   REFERENCES medico (medico_id),
    CONSTRAINT fk_consulta_convenio FOREIGN KEY (convenio_id) REFERENCES convenio (convenio_id),
    CONSTRAINT ck_consulta_status CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA'))
);

-- Comentarios de dicionario de dados (ficam armazenados em USER_TAB_COMMENTS /
-- USER_COL_COMMENTS e sao um dos poucos artefatos de documentacao que vivem
-- DENTRO do proprio catalogo do banco).
COMMENT ON TABLE paciente IS 'Cadastro de pacientes da clinica BoaSaude';
COMMENT ON COLUMN paciente.cpf IS 'CPF do paciente, somente digitos, unico';
COMMENT ON TABLE consulta IS 'Consultas agendadas/realizadas/canceladas na clinica';
COMMENT ON COLUMN consulta.status IS 'Situacao da consulta: AGENDADA, REALIZADA ou CANCELADA';

INSERT INTO especialidade (nome) VALUES ('Clinica Geral');
INSERT INTO especialidade (nome) VALUES ('Cardiologia');
INSERT INTO especialidade (nome) VALUES ('Pediatria');

INSERT INTO medico (nome, crm, especialidade_id) VALUES ('Dra. Ana Souza', 'CRM-11111', 1);
INSERT INTO medico (nome, crm, especialidade_id) VALUES ('Dr. Bruno Lima', 'CRM-22222', 2);
INSERT INTO medico (nome, crm, especialidade_id) VALUES ('Dra. Carla Melo', 'CRM-33333', 3);

INSERT INTO convenio (nome, percentual_cobertura) VALUES ('Particular', 0);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('SaudeBem', 80);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('VidaPlena', 100);

INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
VALUES ('Joao Pereira', '11122233344', DATE '1990-05-12', 'M', '51999990001', 'joao@exemplo.com');
INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
VALUES ('Maria Santos', '22233344455', DATE '1985-11-30', 'F', '51999990002', 'maria@exemplo.com');

INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
VALUES (1, 1, 2, TIMESTAMP '2026-07-10 09:00:00', 'AGENDADA', 150.00);
INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
VALUES (2, 2, 3, TIMESTAMP '2026-07-10 10:30:00', 'AGENDADA', 250.00);

COMMIT;

-- ----------------------------------------------------------------------------
-- 2) USER_TABLES / ALL_TABLES / DBA_TABLES
--    USER_* -> objetos do proprio schema logado
--    ALL_*  -> objetos aos quais o usuario tem acesso (proprios + concedidos)
--    DBA_*  -> TODOS os objetos da instancia (exige privilegio DBA/SELECT
--              ANY DICTIONARY - normalmente indisponivel para alunos em
--              ambiente compartilhado; citado aqui apenas para contraste)
-- ----------------------------------------------------------------------------
SELECT table_name, num_rows, last_analyzed
FROM   user_tables
ORDER  BY table_name;

-- Equivalente com escopo mais amplo (mesma estrutura de colunas):
-- SELECT owner, table_name, num_rows FROM all_tables WHERE owner = 'BOASAUDE';
-- SELECT owner, table_name, num_rows FROM dba_tables  WHERE owner = 'BOASAUDE'; -- requer privilegio DBA

-- ----------------------------------------------------------------------------
-- 3) Colunas de uma tabela: USER_TAB_COLUMNS / ALL_TAB_COLUMNS
-- ----------------------------------------------------------------------------
SELECT column_name, data_type, data_length, data_precision, data_scale, nullable
FROM   user_tab_columns
WHERE  table_name = 'CONSULTA'
ORDER  BY column_id;

-- ALL_TAB_COLUMNS tem as MESMAS colunas de USER_TAB_COLUMNS, mais OWNER,
-- e enxerga tabelas de outros schemas caso haja GRANT de SELECT:
SELECT owner, column_name, data_type
FROM   all_tab_columns
WHERE  table_name = 'PACIENTE'
ORDER  BY column_id;

-- ----------------------------------------------------------------------------
-- 4) Constraints: USER_CONSTRAINTS + USER_CONS_COLUMNS
-- ----------------------------------------------------------------------------
SELECT c.constraint_name, c.constraint_type, c.table_name, c.search_condition,
       c.r_constraint_name
FROM   user_constraints c
WHERE  c.table_name IN ('PACIENTE', 'CONSULTA', 'MEDICO')
ORDER  BY c.table_name, c.constraint_type;

-- constraint_type: P = Primary Key, R = Foreign Key (References), U = Unique,
-- C = Check (inclui NOT NULL, que o Oracle materializa como CHECK implicito)

-- Colunas de cada constraint (necessario p/ constraints compostas):
SELECT cc.constraint_name, cc.table_name, cc.column_name, cc.position
FROM   user_cons_columns cc
WHERE  cc.table_name = 'CONSULTA'
ORDER  BY cc.constraint_name, cc.position;

-- Fluxo tipico: descobrir a FK e a tabela referenciada
SELECT a.constraint_name AS fk_name,
       a.table_name       AS tabela_filha,
       cc.column_name     AS coluna_fk,
       c.table_name       AS tabela_pai
FROM   user_constraints a
JOIN   user_cons_columns cc ON cc.constraint_name = a.constraint_name
JOIN   user_constraints c   ON c.constraint_name  = a.r_constraint_name
WHERE  a.constraint_type = 'R'
ORDER  BY a.table_name;

-- ----------------------------------------------------------------------------
-- 5) Indices: USER_INDEXES + USER_IND_COLUMNS
-- ----------------------------------------------------------------------------
SELECT index_name, table_name, uniqueness, index_type, status
FROM   user_indexes
WHERE  table_name IN ('PACIENTE', 'CONSULTA', 'MEDICO')
ORDER  BY table_name;

SELECT ic.index_name, ic.table_name, ic.column_name, ic.column_position
FROM   user_ind_columns ic
WHERE  ic.table_name = 'CONSULTA'
ORDER  BY ic.index_name, ic.column_position;

-- ----------------------------------------------------------------------------
-- 6) Sequences, comentarios e visao geral de objetos
-- ----------------------------------------------------------------------------
SELECT sequence_name, min_value, increment_by, last_number
FROM   user_sequences; -- sequences internas geradas pelas colunas IDENTITY

SELECT table_name, comments
FROM   user_tab_comments
WHERE  table_name IN ('PACIENTE', 'CONSULTA');

SELECT table_name, column_name, comments
FROM   user_col_comments
WHERE  table_name = 'CONSULTA' AND comments IS NOT NULL;

-- Inventario geral do schema logado (equivalente conceitual ao \d do psql)
SELECT object_type, COUNT(*) AS quantidade
FROM   user_objects
GROUP  BY object_type
ORDER  BY object_type;

-- Tablespaces do proprio banco (metadado de armazenamento fisico):
SELECT tablespace_name, contents, status
FROM   user_tablespaces
ORDER  BY tablespace_name;
