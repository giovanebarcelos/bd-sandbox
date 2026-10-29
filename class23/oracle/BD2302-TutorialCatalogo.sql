-- ============================================================================
-- BD2302-TutorialCatalogo.sql
-- Aula 23 - Tutorial passo a passo: o dicionario de dados do Oracle
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Roteiro do tutorial Aula_23_..._Tutorial_Oracle.md. Usa o schema BoaSaude
-- de BD2301-Catalogo.sql. O passo 3 (USER x ALL x DBA com um segundo
-- usuario) exige comandos como SYSTEM e esta descrito no tutorial.
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";".
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET LONG 200
SET LONGCHUNKSIZE 4000
SET FEEDBACK ON
COLUMN table_name       FORMAT A14
COLUMN column_name      FORMAT A20
COLUMN owner            FORMAT A12
COLUMN de_constraint    FORMAT A13
COLUMN obrigatoria      FORMAT A11
COLUMN visao            FORMAT A30
COLUMN data_type        FORMAT A12
COLUMN constraint_name  FORMAT A26
COLUMN search_condition FORMAT A44
COLUMN index_name       FORMAT A20
COLUMN object_name      FORMAT A26
COLUMN object_type      FORMAT A12
COLUMN comments         FORMAT A56
COLUMN tabela_filha     FORMAT A12
COLUMN coluna_fk        FORMAT A16
COLUMN tabela_pai       FORMAT A14
COLUMN segment_name     FORMAT A20
COLUMN ddl              FORMAT A120
COLUMN tipo             FORMAT A16
COLUMN descricao        FORMAT A44


-- ----------------------------------------------------------------------------
-- PASSO 1. SCHEMA BoaSaude (o mesmo da aula)
-- ----------------------------------------------------------------------------
BEGIN
    FOR v IN (SELECT view_name FROM user_views WHERE view_name = 'VW_AGENDA') LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
    END LOOP;
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('PRONTUARIO', 'CONSULTA', 'PACIENTE', 'CONVENIO',
                                    'MEDICO', 'ESPECIALIDADE')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

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

CREATE VIEW vw_agenda AS
SELECT c.data_hora, m.nome AS medico, p.nome AS paciente, c.status
  FROM consulta c
  JOIN medico m   ON m.medico_id = c.medico_id
  JOIN paciente p ON p.paciente_id = c.paciente_id;

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
-- PASSO 2. USER_TABLES e USER_TAB_COLUMNS
-- ----------------------------------------------------------------------------
-- NUM_ROWS vazio: as estatisticas so existem depois do DBMS_STATS
SELECT table_name, num_rows, last_analyzed FROM user_tables
 WHERE table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA')
 ORDER BY table_name;

EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER)

SELECT table_name, num_rows, last_analyzed FROM user_tables
 WHERE table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA')
 ORDER BY table_name;

SELECT column_name, data_type, data_length, data_precision, data_scale, nullable,
       identity_column
  FROM user_tab_columns
 WHERE table_name = 'CONSULTA'
 ORDER BY column_id;


-- ----------------------------------------------------------------------------
-- PASSO 3. USER_* x ALL_* x DBA_*
-- ----------------------------------------------------------------------------
-- DBA_* exige privilegio: para o bd_aluno, ORA-00942 (erro proposital)
SELECT owner, table_name FROM dba_tables WHERE owner = 'BD_ALUNO';

-- ALL_* = os meus objetos + os que me concederam. Quantos objetos de cada dono?
SELECT owner, COUNT(*) AS tabelas FROM all_tables GROUP BY owner ORDER BY 2 DESC FETCH FIRST 5 ROWS ONLY;


-- ----------------------------------------------------------------------------
-- PASSO 4. CONSTRAINTS: o NOT NULL tambem e uma CHECK
-- ----------------------------------------------------------------------------
SELECT constraint_name, constraint_type, search_condition
  FROM user_constraints
 WHERE table_name = 'PACIENTE'
 ORDER BY constraint_type, constraint_name;

-- FKs: tabela filha -> tabela pai
SELECT a.table_name   AS tabela_filha,
       cc.column_name AS coluna_fk,
       c.table_name   AS tabela_pai,
       a.constraint_name
  FROM user_constraints a
  JOIN user_cons_columns cc ON cc.constraint_name = a.constraint_name
  JOIN user_constraints c   ON c.constraint_name  = a.r_constraint_name
 WHERE a.constraint_type = 'R'
 ORDER BY a.table_name, cc.column_name;


-- ----------------------------------------------------------------------------
-- PASSO 5. INDICES: os automaticos (PK/UNIQUE) e as FKs sem indice
-- ----------------------------------------------------------------------------
SELECT i.table_name, i.index_name, i.uniqueness, ic.column_name,
       NVL((SELECT c.constraint_type FROM user_constraints c
             WHERE c.index_name = i.index_name AND c.table_name = i.table_name), '-') AS de_constraint
  FROM user_indexes i
  JOIN user_ind_columns ic ON ic.index_name = i.index_name
 WHERE i.table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA')
 ORDER BY i.table_name, i.index_name, ic.column_position;

-- FKs cuja coluna nao lidera nenhum indice (Aula 25, passo 7)
SELECT c.table_name AS tabela_filha, cc.column_name AS coluna_fk
  FROM user_constraints c
  JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name AND cc.position = 1
 WHERE c.constraint_type = 'R'
   AND NOT EXISTS (SELECT 1 FROM user_ind_columns ic
                    WHERE ic.table_name = c.table_name
                      AND ic.column_name = cc.column_name
                      AND ic.column_position = 1)
 ORDER BY 1, 2;


-- ----------------------------------------------------------------------------
-- PASSO 6. DBMS_METADATA: o Oracle reescreve o DDL de qualquer objeto
-- ----------------------------------------------------------------------------
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
END;
/

SET LONG 4000
SELECT DBMS_METADATA.GET_DDL('TABLE', 'CONVENIO') AS ddl FROM dual;
SELECT DBMS_METADATA.GET_DDL('VIEW', 'VW_AGENDA') AS ddl FROM dual;
SET LONG 200


-- ----------------------------------------------------------------------------
-- PASSO 7. COMENTARIOS: documentacao que vive DENTRO do dicionario
-- ----------------------------------------------------------------------------
COMMENT ON TABLE paciente IS 'Cadastro de pacientes da clinica BoaSaude';
COMMENT ON COLUMN paciente.cpf IS 'CPF do paciente, somente digitos, unico';
COMMENT ON TABLE consulta IS 'Consultas agendadas/realizadas/canceladas na clinica';
COMMENT ON COLUMN consulta.status IS 'Situacao da consulta: AGENDADA, REALIZADA ou CANCELADA';

SELECT table_name, comments FROM user_tab_comments
 WHERE table_name IN ('PACIENTE', 'CONSULTA') ORDER BY 1;

SELECT table_name, column_name, comments FROM user_col_comments
 WHERE comments IS NOT NULL ORDER BY 1, 2;


-- ----------------------------------------------------------------------------
-- PASSO 8. USER_OBJECTS: inventario, sequences ocultas e LAST_DDL_TIME
-- ----------------------------------------------------------------------------
SELECT object_type, COUNT(*) AS quantidade
  FROM user_objects
 WHERE object_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA', 'VW_AGENDA')
    OR object_name LIKE 'PK\_%' ESCAPE '\'
    OR object_name LIKE 'UQ\_%' ESCAPE '\'
    OR object_name LIKE 'ISEQ$$%'
 GROUP BY object_type
 ORDER BY object_type;

-- cada coluna IDENTITY tem uma sequence "escondida" com nome ISEQ$$_...
SELECT table_name, column_name, sequence_name
  FROM user_tab_identity_cols
 WHERE table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA')
 ORDER BY 1;

-- o catalogo registra quando cada objeto mudou de estrutura
ALTER TABLE paciente ADD (cidade VARCHAR2(60));

SELECT object_name, object_type, TO_CHAR(created, 'HH24:MI:SS') AS criado,
       TO_CHAR(last_ddl_time, 'HH24:MI:SS') AS ultimo_ddl, status
  FROM user_objects
 WHERE object_name IN ('PACIENTE', 'VW_AGENDA', 'CONSULTA')
 ORDER BY 1;

ALTER TABLE paciente DROP COLUMN cidade;


-- ----------------------------------------------------------------------------
-- PASSO 9. DICTIONARY: o catalogo do catalogo
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS views_do_dicionario FROM dictionary;

-- as views de catalogo sobre colunas de tabela
SELECT table_name AS visao
  FROM dictionary
 WHERE table_name LIKE 'USER\_TAB\_COL%' ESCAPE '\'
 ORDER BY table_name;


-- ----------------------------------------------------------------------------
-- PASSO 10. TAMANHOS: USER_SEGMENTS
-- ----------------------------------------------------------------------------
SELECT segment_name, segment_type, ROUND(bytes / 1024) AS kb
  FROM user_segments
 WHERE segment_name IN ('PACIENTE', 'CONSULTA', 'PK_PACIENTE', 'UQ_PACIENTE_CPF')
 ORDER BY segment_name;


-- ----------------------------------------------------------------------------
-- PASSO 11. RELATORIO: O DICIONARIO DE DADOS DO PROJETO
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       CASE WHEN c.data_type IN ('VARCHAR2', 'CHAR') THEN c.data_type || '(' || c.char_length || ')'
            WHEN c.data_type = 'NUMBER' AND c.data_precision IS NOT NULL
                 THEN 'NUMBER(' || c.data_precision || NVL2(NULLIF(c.data_scale, 0), ',' || c.data_scale, '') || ')'
            ELSE c.data_type END AS tipo,
       DECODE(c.nullable, 'N', 'sim', '') AS obrigatoria,
       NVL((SELECT 'PK' FROM user_cons_columns cc
             JOIN user_constraints k ON k.constraint_name = cc.constraint_name
            WHERE k.constraint_type = 'P' AND cc.table_name = c.table_name
              AND cc.column_name = c.column_name), '') AS pk,
       SUBSTR(m.comments, 1, 44) AS descricao
  FROM user_tab_columns c
  JOIN user_tables t ON t.table_name = c.table_name
  LEFT JOIN user_col_comments m ON m.table_name = c.table_name AND m.column_name = c.column_name
 WHERE c.table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA')
 ORDER BY c.table_name, c.column_id;
