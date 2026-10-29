-- ============================================================================
-- BD2202-TutorialFlashback.sql
-- Aula 22 - Tutorial passo a passo: redo, undo, FLASHBACK e recycle bin
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Roteiro do tutorial Aula_22_..._Tutorial_Oracle.md.
-- Pre-requisito (uma vez so, como SYSTEM), para ler as views V$:
--   GRANT SELECT_CATALOG_ROLE TO bd_aluno;
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";".
-- ============================================================================

SET SERVEROUTPUT ON
SET LINESIZE 160
SET PAGESIZE 60
SET VERIFY OFF
COLUMN member         FORMAT A40
COLUMN status         FORMAT A10
COLUMN titular        FORMAT A12
COLUMN object_name    FORMAT A32
COLUMN original_name  FORMAT A18
COLUMN constraint_name FORMAT A32
COLUMN type           FORMAT A6
COLUMN index_name     FORMAT A32
COLUMN operacao       FORMAT A8
COLUMN versao_inicio  FORMAT A10
COLUMN versao_fim     FORMAT A10


-- ----------------------------------------------------------------------------
-- PASSO 1. TABELA DE APOIO
-- ----------------------------------------------------------------------------
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'CONTA_CORRENTE') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE conta_corrente PURGE';
    END LOOP;
END;
/
PURGE RECYCLEBIN;

CREATE TABLE conta_corrente (
    id_conta   NUMBER(10)      NOT NULL,
    titular    VARCHAR2(100)   NOT NULL,
    saldo      NUMBER(12,2)    NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente VALUES (2, 'Bruno Lima', 500.00);
INSERT INTO conta_corrente VALUES (3, 'Carla Dias', 750.00);
COMMIT;


-- ----------------------------------------------------------------------------
-- PASSO 2. REDO LOG: grupos online, membros e modo de arquivamento
-- ----------------------------------------------------------------------------
SELECT group#, sequence#, bytes / 1024 / 1024 AS mb, members, archived, status
  FROM v$log
 ORDER BY group#;

SELECT group#, member FROM v$logfile ORDER BY group#;

SELECT log_mode FROM v$database;


-- ----------------------------------------------------------------------------
-- PASSO 3. UNDO: retencao e estatisticas
-- ----------------------------------------------------------------------------
SHOW PARAMETER undo

SELECT TO_CHAR(begin_time, 'HH24:MI') AS inicio, TO_CHAR(end_time, 'HH24:MI') AS fim,
       undoblks, txncount, maxquerylen, tuned_undoretention
  FROM v$undostat
 ORDER BY begin_time DESC
 FETCH FIRST 3 ROWS ONLY;


-- ----------------------------------------------------------------------------
-- PASSO 4. SCN: o "relogio" do Oracle. Anote o SCN ANTES do erro
-- ----------------------------------------------------------------------------
-- espera alguns segundos: um SCN muito proximo da criacao da tabela da ORA-01466
EXEC DBMS_SESSION.SLEEP(15)

COLUMN scn_antes NEW_VALUE scn_antes
SELECT current_scn AS scn_antes FROM v$database;

-- O ERRO: um UPDATE sem WHERE zera todos os saldos (e e confirmado)
UPDATE conta_corrente SET saldo = 0;
COMMIT;

SELECT id_conta, titular, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 5. FLASHBACK QUERY: consultar o passado
-- ----------------------------------------------------------------------------
SELECT id_conta, titular, saldo
  FROM conta_corrente AS OF SCN &scn_antes
 ORDER BY id_conta;

-- Comparar passado e presente lado a lado
SELECT agora.id_conta, antes.saldo AS saldo_antes, agora.saldo AS saldo_agora
  FROM conta_corrente agora
  JOIN conta_corrente AS OF SCN &scn_antes antes ON antes.id_conta = agora.id_conta
 ORDER BY agora.id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 6. FLASHBACK VERSION QUERY: o historico de uma linha
-- ----------------------------------------------------------------------------
UPDATE conta_corrente SET saldo = 50 WHERE id_conta = 1;
COMMIT;

SELECT versions_operation AS operacao,
       versions_startscn  AS scn_inicio,
       versions_endscn    AS scn_fim,
       saldo
  FROM conta_corrente VERSIONS BETWEEN SCN &scn_antes AND MAXVALUE
 WHERE id_conta = 1
 ORDER BY versions_startscn NULLS FIRST;


-- ----------------------------------------------------------------------------
-- PASSO 7. RESTAURAR COM MERGE (recuperacao de LINHAS, tabela continua online)
-- ----------------------------------------------------------------------------
MERGE INTO conta_corrente destino
USING (SELECT id_conta, saldo FROM conta_corrente AS OF SCN &scn_antes) origem
   ON (destino.id_conta = origem.id_conta)
 WHEN MATCHED THEN UPDATE SET destino.saldo = origem.saldo;
COMMIT;

SELECT id_conta, titular, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 8. FLASHBACK TABLE: voltar a TABELA INTEIRA (DELETE sem WHERE)
-- ----------------------------------------------------------------------------
-- uma pequena pausa garante que o SCN lido ja inclui o COMMIT anterior
EXEC DBMS_SESSION.SLEEP(2)
COLUMN scn_antes_delete NEW_VALUE scn_antes_delete
SELECT current_scn AS scn_antes_delete FROM v$database;

DELETE FROM conta_corrente;
COMMIT;
SELECT COUNT(*) AS linhas FROM conta_corrente;

-- sem ROW MOVEMENT: ORA-08189 (erro proposital)
FLASHBACK TABLE conta_corrente TO SCN &scn_antes_delete;

ALTER TABLE conta_corrente ENABLE ROW MOVEMENT;
FLASHBACK TABLE conta_corrente TO SCN &scn_antes_delete;

SELECT id_conta, titular, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 9. DROP TABLE, RECYCLE BIN E FLASHBACK TABLE ... TO BEFORE DROP
-- ----------------------------------------------------------------------------
DROP TABLE conta_corrente;

SELECT object_name, original_name, type, droptime
  FROM user_recyclebin
 ORDER BY type DESC, original_name;

FLASHBACK TABLE conta_corrente TO BEFORE DROP;

SELECT id_conta, titular, saldo FROM conta_corrente ORDER BY id_conta;

-- o indice e a PK voltam com nome de lixeira (BIN$...)
SELECT index_name FROM user_indexes WHERE table_name = 'CONTA_CORRENTE';
SELECT constraint_name, constraint_type FROM user_constraints WHERE table_name = 'CONTA_CORRENTE';

-- devolvendo os nomes originais a PK, ao indice e ao CHECK
BEGIN
    FOR c IN (SELECT constraint_name, constraint_type, search_condition_vc
                FROM user_constraints
               WHERE table_name = 'CONTA_CORRENTE') LOOP
        IF c.constraint_type = 'P' THEN
            EXECUTE IMMEDIATE 'ALTER TABLE conta_corrente RENAME CONSTRAINT "'
                              || c.constraint_name || '" TO pk_conta_corrente';
        ELSIF c.search_condition_vc = 'saldo >= 0' THEN
            EXECUTE IMMEDIATE 'ALTER TABLE conta_corrente RENAME CONSTRAINT "'
                              || c.constraint_name || '" TO ck_saldo_nao_negativo';
        END IF;
    END LOOP;
    FOR i IN (SELECT index_name FROM user_indexes WHERE table_name = 'CONTA_CORRENTE') LOOP
        EXECUTE IMMEDIATE 'ALTER INDEX "' || i.index_name || '" RENAME TO pk_conta_corrente';
    END LOOP;
END;
/

SELECT index_name FROM user_indexes WHERE table_name = 'CONTA_CORRENTE';
SELECT constraint_name, constraint_type FROM user_constraints
 WHERE table_name = 'CONTA_CORRENTE' AND constraint_name NOT LIKE 'BIN$%';


-- ----------------------------------------------------------------------------
-- PASSO 10. DROP ... PURGE: sem lixeira, sem volta
-- ----------------------------------------------------------------------------
CREATE TABLE tabela_descartavel AS SELECT * FROM conta_corrente;
DROP TABLE tabela_descartavel PURGE;

-- erro proposital: ORA-38305
FLASHBACK TABLE tabela_descartavel TO BEFORE DROP;
