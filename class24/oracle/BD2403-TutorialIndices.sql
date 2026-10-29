-- ============================================================================
-- BD2403-TutorialIndices.sql
-- Aula 24 - Tutorial passo a passo: indices e planos de execucao
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Passos 2 a 10 do tutorial Aula_24_..._Tutorial_Oracle.md. Rode antes a
-- carga BD2402-CargaBoaSaude.sql. Pre-requisito (uma vez so, como SYSTEM)
-- para o DBMS_XPLAN.DISPLAY_CURSOR e o AUTOTRACE:
--   GRANT SELECT_CATALOG_ROLE TO bd_aluno;
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";".
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON
COLUMN plan_table_output FORMAT A160
COLUMN column_name   FORMAT A12
COLUMN histogram     FORMAT A10
COLUMN segment_name  FORMAT A28
COLUMN index_name    FORMAT A28
COLUMN clustering_factor FORMAT 999999999
COLUMN visibility    FORMAT A10


-- ----------------------------------------------------------------------------
-- PASSO 2. EXPLAIN PLAN (estimado) x DISPLAY_CURSOR (real)
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- executa de verdade, guardando estatisticas de cada operacao do plano
SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*)
FROM   consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));


-- ----------------------------------------------------------------------------
-- PASSO 3. B-TREE COMPOSTO: a ORDEM das colunas importa
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_medico_data ON consulta (medico_id, data_hora);

-- 3a. medico_id (1a coluna) + data_hora (2a): INDEX RANGE SCAN
EXPLAIN PLAN FOR
SELECT consulta_id, data_hora, status
FROM   consulta
WHERE  medico_id = 42
AND    data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST +PREDICATE'));

-- 3b. so data_hora (2a coluna): o indice composto nao ajuda
EXPLAIN PLAN FOR
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- 3c. indice proprio para data_hora
CREATE INDEX idx_consulta_data ON consulta (data_hora);

EXPLAIN PLAN FOR
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- 3d. Por que o indice foi ignorado? CLUSTERING FACTOR: quantos blocos da
-- tabela seriam visitados lendo o indice em ordem (minimo = blocos da tabela,
-- maximo = numero de linhas)
SELECT i.index_name, i.clustering_factor, t.blocks AS blocos_tabela, t.num_rows
  FROM user_indexes i JOIN user_tables t ON t.table_name = i.table_name
 WHERE i.table_name = 'CONSULTA' AND i.index_type = 'NORMAL'
 ORDER BY i.index_name;

-- a mesma tabela, com as linhas gravadas EM ORDEM de data
CREATE TABLE consulta_ordenada AS SELECT * FROM consulta ORDER BY data_hora;
CREATE INDEX idx_consulta_ord_data ON consulta_ordenada (data_hora);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CONSULTA_ORDENADA')

SELECT i.index_name, i.clustering_factor, t.blocks AS blocos_tabela
  FROM user_indexes i JOIN user_tables t ON t.table_name = i.table_name
 WHERE i.index_name IN ('IDX_CONSULTA_DATA', 'IDX_CONSULTA_ORD_DATA');

EXPLAIN PLAN FOR
SELECT consulta_id, paciente_id, status, valor
FROM   consulta_ordenada
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

DROP TABLE consulta_ordenada PURGE;


-- ----------------------------------------------------------------------------
-- PASSO 4. CONSULTA RESOLVIDA SO PELO INDICE (sem TABLE ACCESS)
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM consulta WHERE medico_id = 42;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- valor nao esta no indice: precisa ir a tabela pelo ROWID
EXPLAIN PLAN FOR
SELECT SUM(valor) FROM consulta WHERE medico_id = 42;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));


-- ----------------------------------------------------------------------------
-- PASSO 5. INDICE BASEADO EM FUNCAO: UPPER(nome)
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

CREATE INDEX idx_paciente_nome_upper ON paciente (UPPER(nome));

EXPLAIN PLAN FOR
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));


-- ----------------------------------------------------------------------------
-- PASSO 6. SELETIVIDADE E HISTOGRAMA
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_status ON consulta (status);

-- 6a. Sem histograma, o Oracle supoe que os 3 status tem 1/3 das linhas cada
SELECT column_name, num_distinct, histogram
  FROM user_tab_col_statistics
 WHERE table_name = 'CONSULTA' AND column_name = 'STATUS';

EXPLAIN PLAN FOR SELECT * FROM consulta WHERE status = 'CANCELADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- 6b. Coleta de novo: como STATUS agora aparece em WHERE e e desbalanceada,
-- o DBMS_STATS cria um histograma de frequencia
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CONSULTA')

SELECT column_name, num_distinct, histogram
  FROM user_tab_col_statistics
 WHERE table_name = 'CONSULTA' AND column_name = 'STATUS';

-- CANCELADA = 5%: usa o indice
EXPLAIN PLAN FOR SELECT * FROM consulta WHERE status = 'CANCELADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- REALIZADA = 90%: TABLE ACCESS FULL
EXPLAIN PLAN FOR SELECT * FROM consulta WHERE status = 'REALIZADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));


-- ----------------------------------------------------------------------------
-- PASSO 7. INDICES BITMAP E BITMAP AND
-- ----------------------------------------------------------------------------
DROP INDEX idx_consulta_status;
CREATE BITMAP INDEX idx_consulta_status_bmp   ON consulta (status);
CREATE BITMAP INDEX idx_consulta_convenio_bmp ON consulta (convenio_id);

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM consulta WHERE status = 'REALIZADA' AND convenio_id = 2;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

-- bitmap x B-tree: tamanho
SELECT segment_name, ROUND(bytes / 1024) AS kb
  FROM user_segments
 WHERE segment_name IN ('IDX_CONSULTA_STATUS_BMP', 'IDX_CONSULTA_CONVENIO_BMP',
                        'IDX_CONSULTA_DATA', 'IDX_CONSULTA_MEDICO_DATA')
 ORDER BY bytes DESC;


-- ----------------------------------------------------------------------------
-- PASSO 8. INDICE INVISIVEL: testar o efeito de remover um indice sem remove-lo
-- ----------------------------------------------------------------------------
ALTER INDEX idx_consulta_data INVISIBLE;

SELECT index_name, visibility FROM user_indexes WHERE index_name = 'IDX_CONSULTA_DATA';

-- com o indice visivel, este COUNT(*) e um INDEX RANGE SCAN de custo 12
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +COST'));

ALTER INDEX idx_consulta_data VISIBLE;


-- ----------------------------------------------------------------------------
-- PASSO 9. AUTOTRACE: plano + estatisticas de execucao numa tacada so
-- ----------------------------------------------------------------------------
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS
SELECT consulta_id, data_hora, status
FROM   consulta
WHERE  medico_id = 42
AND    data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';
SET AUTOTRACE OFF


-- ----------------------------------------------------------------------------
-- PASSO 10. O CUSTO DOS INDICES: espaco e escrita
-- ----------------------------------------------------------------------------
SELECT segment_type, ROUND(SUM(bytes) / 1024 / 1024, 1) AS mb
  FROM user_segments
 WHERE segment_name = 'CONSULTA'
    OR segment_name IN (SELECT index_name FROM user_indexes WHERE table_name = 'CONSULTA')
 GROUP BY segment_type;

-- duas copias vazias de consulta, sem chaves estrangeiras: uma com os mesmos
-- indices, outra sem nenhum
CREATE TABLE consulta_com_indices AS SELECT * FROM consulta WHERE 1 = 0;
CREATE TABLE consulta_sem_indices AS SELECT * FROM consulta WHERE 1 = 0;
ALTER TABLE consulta_com_indices ADD CONSTRAINT pk_consulta_com PRIMARY KEY (consulta_id);
CREATE INDEX idx_com_medico_data ON consulta_com_indices (medico_id, data_hora);
CREATE INDEX idx_com_data        ON consulta_com_indices (data_hora);
CREATE BITMAP INDEX idx_com_status_bmp   ON consulta_com_indices (status);
CREATE BITMAP INDEX idx_com_convenio_bmp ON consulta_com_indices (convenio_id);

-- grave primeiro a copia SEM indices: a carga pesada com indices gera muito
-- redo e atrasaria o que viesse depois, distorcendo a comparacao
SET TIMING ON
INSERT INTO consulta_sem_indices (consulta_id, paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT LEVEL, MOD(LEVEL, 50000) + 1, MOD(LEVEL, 200) + 1, MOD(LEVEL, 3) + 1,
       TIMESTAMP '2026-01-01 00:00:00' + NUMTODSINTERVAL(LEVEL, 'MINUTE'), 'AGENDADA', 100
FROM   dual CONNECT BY LEVEL <= 50000;
COMMIT;

INSERT INTO consulta_com_indices (consulta_id, paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT LEVEL, MOD(LEVEL, 50000) + 1, MOD(LEVEL, 200) + 1, MOD(LEVEL, 3) + 1,
       TIMESTAMP '2026-01-01 00:00:00' + NUMTODSINTERVAL(LEVEL, 'MINUTE'), 'AGENDADA', 100
FROM   dual CONNECT BY LEVEL <= 50000;
COMMIT;
SET TIMING OFF

DROP TABLE consulta_com_indices PURGE;
DROP TABLE consulta_sem_indices PURGE;
