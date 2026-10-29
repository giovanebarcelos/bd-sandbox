-- ============================================================================
-- BD2701-TutorialParticionamento.sql
-- Aula 27 - Tutorial passo a passo: particionamento no Oracle
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Roteiro do tutorial Aula_27_..._Tutorial_Oracle.md. O XE 21c inclui a
-- opcao Partitioning. RAC e GoldenGate (Slides 9-11) nao existem no XE: o
-- passo 9 so mostra as views GV$ que um RAC usaria.
-- Os passos 6 e 7 tem erros PROPOSITAIS.
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";".
-- ============================================================================

SET LINESIZE 180
SET PAGESIZE 100
SET FEEDBACK ON
COLUMN partition_name    FORMAT A16
COLUMN high_value        FORMAT A42
COLUMN plan_table_output FORMAT A150
COLUMN index_name        FORMAT A20
COLUMN host_name         FORMAT A20
COLUMN e_rac             FORMAT A6


-- ----------------------------------------------------------------------------
-- PASSO 1. PARTICIONAMENTO POR FAIXA COM INTERVALO AUTOMATICO
-- ----------------------------------------------------------------------------
SELECT value AS partitioning_disponivel FROM v$option WHERE parameter = 'Partitioning';

BEGIN
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('VENDA', 'CLIENTE_REGIAO', 'SESSAO')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/

-- so a particao de 2024 e declarada; as dos anos seguintes nascem sozinhas
CREATE TABLE venda (
    venda_id    NUMBER GENERATED ALWAYS AS IDENTITY,
    data_venda  DATE NOT NULL,
    regiao      CHAR(2) NOT NULL,
    valor       NUMBER(10,2) NOT NULL,
    CONSTRAINT pk_venda PRIMARY KEY (venda_id)
)
PARTITION BY RANGE (data_venda) INTERVAL (NUMTOYMINTERVAL(1, 'YEAR'))
(
    PARTITION p_2024 VALUES LESS THAN (DATE '2025-01-01')
);

-- 300 mil vendas entre 2024 e 2026
INSERT INTO venda (data_venda, regiao, valor)
SELECT DATE '2024-01-01' + MOD(LEVEL, 1095),
       DECODE(MOD(LEVEL, 5), 0, 'RS', 1, 'SC', 2, 'PR', 3, 'SP', 'RJ'),
       10 + MOD(LEVEL, 500)
  FROM dual CONNECT BY LEVEL <= 300000;
COMMIT;

-- uma venda de 2027: tambem ganha particao propria
INSERT INTO venda (data_venda, regiao, valor) VALUES (DATE '2027-03-01', 'RS', 1);
COMMIT;

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'VENDA')


-- ----------------------------------------------------------------------------
-- PASSO 2. AS PARTICOES NO CATALOGO
-- ----------------------------------------------------------------------------
-- HIGH_VALUE e do tipo LONG: o SET LONG limita quanto dele e exibido
SET LONG 32
SELECT partition_name, high_value, num_rows
  FROM user_tab_partitions
 WHERE table_name = 'VENDA'
 ORDER BY partition_position;


-- ----------------------------------------------------------------------------
-- PASSO 3. PARTITION PRUNING (Pstart / Pstop)
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT SUM(valor) FROM venda WHERE data_venda BETWEEN DATE '2025-03-01' AND DATE '2025-03-31';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +PARTITION'));

EXPLAIN PLAN FOR
SELECT SUM(valor) FROM venda WHERE regiao = 'RS';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +ROWS +PARTITION'));


-- ----------------------------------------------------------------------------
-- PASSO 4. INDICE LOCAL x INDICE GLOBAL
-- ----------------------------------------------------------------------------
-- LOCAL: um pedaco de indice por particao (como no PostgreSQL)
CREATE INDEX idx_venda_regiao ON venda (regiao) LOCAL;

-- a PK_VENDA e GLOBAL: um indice unico para a tabela inteira
SELECT index_name, partitioned, status FROM user_indexes WHERE table_name = 'VENDA' ORDER BY 1;
SELECT index_name, locality FROM user_part_indexes WHERE table_name = 'VENDA';


-- ----------------------------------------------------------------------------
-- PASSO 5. APAGAR UM ANO: DELETE x DROP PARTITION
-- ----------------------------------------------------------------------------
SET TIMING ON
DELETE FROM venda WHERE data_venda < DATE '2025-01-01';
ROLLBACK;

ALTER TABLE venda DROP PARTITION p_2024 UPDATE INDEXES;
SET TIMING OFF

SELECT index_name, status FROM user_indexes WHERE table_name = 'VENDA' ORDER BY 1;


-- ----------------------------------------------------------------------------
-- PASSO 6. A ARMADILHA DO INDICE GLOBAL (erro proposital)
-- ----------------------------------------------------------------------------
-- sem UPDATE INDEXES, o indice global perde as referencias da particao
ALTER TABLE venda DROP PARTITION FOR (DATE '2025-06-01');

SELECT index_name, status FROM user_indexes WHERE table_name = 'VENDA' ORDER BY 1;

INSERT INTO venda (data_venda, regiao, valor) VALUES (DATE '2026-05-05', 'RS', 1);

ALTER INDEX pk_venda REBUILD;
SELECT index_name, status FROM user_indexes WHERE table_name = 'VENDA' ORDER BY 1;
INSERT INTO venda (data_venda, regiao, valor) VALUES (DATE '2026-05-05', 'RS', 1);
COMMIT;


-- ----------------------------------------------------------------------------
-- PASSO 7. PARTICIONAMENTO POR LISTA, COM DEFAULT
-- ----------------------------------------------------------------------------
CREATE TABLE cliente_regiao (
    cliente_id  NUMBER NOT NULL,
    regiao      CHAR(2) NOT NULL
)
PARTITION BY LIST (regiao)
(
    PARTITION p_sul     VALUES ('RS', 'SC', 'PR'),
    PARTITION p_sudeste VALUES ('SP', 'RJ', 'MG', 'ES')
);

INSERT INTO cliente_regiao VALUES (1, 'RS');
-- BA nao esta em nenhuma lista: ORA-14400 (proposital)
INSERT INTO cliente_regiao VALUES (2, 'BA');

ALTER TABLE cliente_regiao ADD PARTITION p_outras VALUES (DEFAULT);
INSERT INTO cliente_regiao VALUES (2, 'BA');
COMMIT;


-- ----------------------------------------------------------------------------
-- PASSO 8. PARTICIONAMENTO POR HASH
-- ----------------------------------------------------------------------------
CREATE TABLE sessao (
    id     NUMBER NOT NULL,
    dados  VARCHAR2(10)
)
PARTITION BY HASH (id) PARTITIONS 4;

INSERT INTO sessao SELECT LEVEL, 'x' FROM dual CONNECT BY LEVEL <= 10000;
COMMIT;
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'SESSAO')

SELECT partition_name, num_rows FROM user_tab_partitions WHERE table_name = 'SESSAO' ORDER BY 1;


-- ----------------------------------------------------------------------------
-- PASSO 9. AS VIEWS DO RAC (GV$) NUMA INSTANCIA UNICA
-- ----------------------------------------------------------------------------
-- GV$ = "global V$": uma linha por instancia do cluster (aqui so ha uma)
SELECT inst_id, instance_name, host_name, status FROM gv$instance;
SELECT parallel AS e_rac FROM v$instance;
