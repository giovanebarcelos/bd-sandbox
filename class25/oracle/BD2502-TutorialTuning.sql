-- ============================================================================
-- BD2502-TutorialTuning.sql
-- Aula 25 - Tutorial passo a passo: otimizacao e tuning
-- SGBD: Oracle Database XE 21c (container da Aula 03)
--
-- Roteiro do tutorial Aula_25_..._Tutorial_Oracle.md. Roda no usuario
-- AULA25 (para nao apagar as tabelas aluno/turma/matricula do tutorial da
-- Aula 20, que estao no bd_aluno). Crie o usuario uma vez, como SYSTEM:
--   CREATE USER aula25 IDENTIFIED BY aula25 QUOTA UNLIMITED ON users;
--   GRANT CONNECT, RESOURCE, SELECT_CATALOG_ROLE TO aula25;
-- Conecte: sqlplus aula25/aula25@//localhost/XEPDB1
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";".
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON
COLUMN plan_table_output FORMAT A190
COLUMN table_name   FORMAT A12
COLUMN stale_stats  FORMAT A11
COLUMN sql_text     FORMAT A60
COLUMN name         FORMAT A22
COLUMN value        FORMAT A16
COLUMN component    FORMAT A26
COLUMN tabela       FORMAT A12
COLUMN coluna_fk    FORMAT A12


-- ----------------------------------------------------------------------------
-- PASSO 1. SCHEMA COM POUCOS DADOS E ESTATISTICAS COLETADAS
-- ----------------------------------------------------------------------------
BEGIN
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('MATRICULA', 'TURMA', 'ALUNO', 'CURSO')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

CREATE TABLE curso (
    curso_id  NUMBER PRIMARY KEY,
    nome      VARCHAR2(100) NOT NULL
);

CREATE TABLE turma (
    turma_id  NUMBER PRIMARY KEY,
    curso_id  NUMBER NOT NULL REFERENCES curso (curso_id),
    horario   VARCHAR2(5) NOT NULL
);

CREATE TABLE aluno (
    aluno_id  NUMBER PRIMARY KEY,
    nome      VARCHAR2(200) NOT NULL,
    cidade    VARCHAR2(60)  NOT NULL
);

CREATE TABLE matricula (
    matricula_id    NUMBER PRIMARY KEY,
    aluno_id        NUMBER NOT NULL REFERENCES aluno (aluno_id),
    turma_id        NUMBER NOT NULL REFERENCES turma (turma_id),
    data_matricula  DATE   NOT NULL,
    situacao        VARCHAR2(10) NOT NULL
);

INSERT INTO curso SELECT LEVEL, 'Curso ' || LEVEL FROM dual CONNECT BY LEVEL <= 20;
INSERT INTO turma SELECT LEVEL, MOD(LEVEL, 20) + 1, LPAD(MOD(LEVEL, 14) + 8, 2, '0') || ':00'
  FROM dual CONNECT BY LEVEL <= 2000;

-- so 10 alunos e 10 matriculas por enquanto...
INSERT INTO aluno SELECT LEVEL, 'Aluno ' || LEVEL, 'Cidade ' || MOD(LEVEL, 50)
  FROM dual CONNECT BY LEVEL <= 10;
INSERT INTO matricula SELECT LEVEL, LEVEL, LEVEL, DATE '2024-01-01' + LEVEL, 'ATIVA'
  FROM dual CONNECT BY LEVEL <= 10;
COMMIT;

-- ...e as estatisticas sao coletadas AGORA, com as tabelas pequenas
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER)


-- ----------------------------------------------------------------------------
-- PASSO 2. A CARGA DE VERDADE (sem atualizar as estatisticas)
-- ----------------------------------------------------------------------------
INSERT INTO aluno
SELECT LEVEL + 10, 'Aluno ' || (LEVEL + 10), 'Cidade ' || MOD(LEVEL + 10, 50)
  FROM dual CONNECT BY LEVEL <= 49990;

INSERT INTO matricula
SELECT LEVEL + 10,
       MOD(LEVEL + 10, 50000) + 1,
       MOD(LEVEL + 10, 2000) + 1,
       DATE '2023-01-01' + MOD(LEVEL + 10, 1000),
       CASE WHEN MOD(LEVEL + 10, 10) = 0 THEN 'TRANCADA' ELSE 'ATIVA' END
  FROM dual CONNECT BY LEVEL <= 199990;
COMMIT;

-- o que o dicionario "acha" x o que mudou desde a ultima coleta
SELECT table_name, num_rows, last_analyzed, stale_stats
  FROM user_tab_statistics
 WHERE table_name IN ('ALUNO', 'MATRICULA')
 ORDER BY table_name;

SELECT table_name, inserts, updates, deletes
  FROM user_tab_modifications
 WHERE table_name IN ('ALUNO', 'MATRICULA')
 ORDER BY table_name;


-- ----------------------------------------------------------------------------
-- PASSO 3. PLANO COM ESTATISTICAS VELHAS x NOVAS (E-Rows x A-Rows)
-- ----------------------------------------------------------------------------
SELECT /*+ GATHER_PLAN_STATISTICS */ a.cidade, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE m.situacao = 'ATIVA'
 GROUP BY a.cidade
 ORDER BY a.cidade
 FETCH FIRST 3 ROWS ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));

-- NO_INVALIDATE => FALSE descarta na hora os planos ja em cache que usavam
-- as estatisticas antigas (o padrao e invalida-los aos poucos)
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER, no_invalidate => FALSE)

SELECT table_name, num_rows, stale_stats
  FROM user_tab_statistics
 WHERE table_name IN ('ALUNO', 'MATRICULA')
 ORDER BY table_name;

SELECT /*+ GATHER_PLAN_STATISTICS */ a.cidade, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE m.situacao = 'ATIVA'
 GROUP BY a.cidade
 ORDER BY a.cidade
 FETCH FIRST 3 ROWS ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));


-- ----------------------------------------------------------------------------
-- PASSO 4. O EXERCICIO DO SLIDE 23: FULL SCAN + SORT EM DISCO
-- ----------------------------------------------------------------------------
-- memoria de trabalho MANUAL e minuscula, so nesta sessao, para forcar o disco
ALTER SESSION SET workarea_size_policy = MANUAL;
ALTER SESSION SET sort_area_size = 65536;

EXPLAIN PLAN FOR
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > DATE '2025-09-01'
 ORDER BY a.nome;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST +PREDICATE'));

SET AUTOTRACE TRACEONLY STATISTICS
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > DATE '2025-09-01'
 ORDER BY a.nome;
SET AUTOTRACE OFF


-- ----------------------------------------------------------------------------
-- PASSO 5. CORRECAO 1: indice no filtro
-- ----------------------------------------------------------------------------
CREATE INDEX idx_matricula_data ON matricula (data_matricula);

EXPLAIN PLAN FOR
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > DATE '2025-09-01'
 ORDER BY a.nome;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));


-- ----------------------------------------------------------------------------
-- PASSO 6. CORRECAO 2: memoria de trabalho automatica (PGA)
-- ----------------------------------------------------------------------------
ALTER SESSION SET workarea_size_policy = AUTO;

SET AUTOTRACE TRACEONLY STATISTICS
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > DATE '2025-09-01'
 ORDER BY a.nome;
SET AUTOTRACE OFF


-- ----------------------------------------------------------------------------
-- PASSO 7. CHAVE ESTRANGEIRA SEM INDICE (o Oracle tambem nao cria sozinho)
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT matricula_id, data_matricula FROM matricula WHERE aluno_id = 4242;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

CREATE INDEX idx_matricula_aluno ON matricula (aluno_id);

EXPLAIN PLAN FOR
SELECT matricula_id, data_matricula FROM matricula WHERE aluno_id = 4242;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- FKs sem indice cuja primeira coluna nao lidera nenhum indice
SELECT c.table_name AS tabela, cc.column_name AS coluna_fk
  FROM user_constraints c
  JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name AND cc.position = 1
 WHERE c.constraint_type = 'R'
   AND NOT EXISTS (SELECT 1 FROM user_ind_columns ic
                    WHERE ic.table_name = c.table_name
                      AND ic.column_name = cc.column_name
                      AND ic.column_position = 1)
 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- PASSO 8. HINTS: forcando um plano (ultimo recurso)
-- ----------------------------------------------------------------------------
-- 8a. o plano escolhido pelo otimizador
EXPLAIN PLAN FOR
SELECT a.nome FROM aluno a JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE a.cidade = 'Cidade 7';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- 8b. forcando Nested Loop com acesso pelo indice da FK
EXPLAIN PLAN FOR
SELECT /*+ LEADING(a) USE_NL(m) INDEX(m idx_matricula_aluno) */ a.nome
  FROM aluno a JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE a.cidade = 'Cidade 7';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- 8c. forcando FULL numa busca que tem indice otimo
EXPLAIN PLAN FOR
SELECT /*+ FULL(m) */ matricula_id FROM matricula m WHERE aluno_id = 4242;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));


-- ----------------------------------------------------------------------------
-- PASSO 9. TOP SQL EM V$SQL E PLANO PELO SQL_ID
-- ----------------------------------------------------------------------------
SELECT sql_id, executions,
       ROUND(elapsed_time / 1000, 1) AS elapsed_ms,
       buffer_gets,
       SUBSTR(sql_text, 1, 60) AS sql_text
  FROM v$sql
 WHERE parsing_schema_name = USER
   AND UPPER(sql_text) LIKE '%MATRICULA%'
   AND sql_text NOT LIKE '%v$sql%'
   AND sql_text NOT LIKE '/*%'
   AND LOWER(sql_text) NOT LIKE '%user_tab%'
   AND command_type = 3
 ORDER BY elapsed_time DESC
 FETCH FIRST 5 ROWS ONLY;


-- ----------------------------------------------------------------------------
-- PASSO 10. ESPACO DESPERDICADO E SHRINK (o "bloat" do Oracle)
-- ----------------------------------------------------------------------------
SELECT ROUND(bytes / 1024 / 1024, 1) AS mb_antes FROM user_segments WHERE segment_name = 'MATRICULA';

DELETE FROM matricula WHERE MOD(matricula_id, 2) = 0;
COMMIT;

-- o DELETE nao devolve espaco: o segmento continua do mesmo tamanho
SELECT ROUND(bytes / 1024 / 1024, 1) AS mb_depois_delete FROM user_segments WHERE segment_name = 'MATRICULA';

ALTER TABLE matricula ENABLE ROW MOVEMENT;
ALTER TABLE matricula SHRINK SPACE CASCADE;

SELECT ROUND(bytes / 1024 / 1024, 1) AS mb_depois_shrink FROM user_segments WHERE segment_name = 'MATRICULA';
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'MATRICULA')


-- ----------------------------------------------------------------------------
-- PASSO 11. MEMORIA: SGA, PGA E PARAMETROS
-- ----------------------------------------------------------------------------
SELECT name, display_value AS value, isdefault
  FROM v$parameter
 WHERE name IN ('sga_target', 'pga_aggregate_target', 'db_cache_size',
                'shared_pool_size', 'optimizer_mode', 'workarea_size_policy')
 ORDER BY name;

SELECT component, ROUND(current_size / 1024 / 1024) AS mb
  FROM v$sga_dynamic_components
 WHERE current_size > 0
 ORDER BY current_size DESC;

SELECT name, ROUND(value / 1024 / 1024, 1) AS mb
  FROM v$pgastat
 WHERE name IN ('total PGA allocated', 'maximum PGA allocated');
