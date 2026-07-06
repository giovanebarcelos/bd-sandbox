-- ============================================================================
-- BD2201-RecuperacaoFalhas.sql
-- Aula 22 - Recuperacao de Falhas (Oracle Database)
-- Tema: redo log, undo segments, FLASHBACK QUERY/TABLE
-- Aula conceitual/arquitetural: os comandos abaixo sao ilustrativos e devem
-- ser adaptados ao ambiente (privilegios DBA, RMAN configurado etc.).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Estrutura de apoio (mesma tabela usada na Aula 21)
-- ----------------------------------------------------------------------------
CREATE TABLE conta_corrente (
    id_conta   NUMBER(10)      NOT NULL,
    titular    VARCHAR2(100)   NOT NULL,
    saldo      NUMBER(12,2)    NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente VALUES (2, 'Bruno Lima', 500.00);
COMMIT;

-- ----------------------------------------------------------------------------
-- 2. REDO LOG: onde ficam as mudancas ainda nao arquivadas
-- ----------------------------------------------------------------------------
-- Online redo log files (grupos de arquivos, gravados de forma circular):
SELECT group#, sequence#, bytes, members, status
  FROM v$log;

SELECT group#, member FROM v$logfile;

-- Archived redo logs (copia definitiva de um grupo de redo apos ele ser
-- reciclado, usada em recuperacao de longo prazo e por ferramentas como o
-- RMAN, estudado na Aula 26 - Backup e Recuperacao):
SELECT name, sequence#, completion_time
  FROM v$archived_log
 ORDER BY completion_time DESC
 FETCH FIRST 5 ROWS ONLY;

-- ----------------------------------------------------------------------------
-- 3. UNDO SEGMENTS: onde fica a versao ANTERIOR de uma linha alterada
-- ----------------------------------------------------------------------------
-- O undo e usado tanto para ROLLBACK quanto para "read consistency"
-- (permitir que outras sessoes leiam a versao anterior de uma linha ainda
-- nao commitada) e para FLASHBACK.
SELECT tablespace_name, status, segment_name
  FROM dba_rollback_segs
 WHERE tablespace_name LIKE 'UNDO%';

-- Estatisticas de uso do undo (tamanho, tempo de retencao efetivo):
SELECT begin_time, end_time, undoblks, maxquerylen
  FROM v$undostat
 ORDER BY begin_time DESC
 FETCH FIRST 5 ROWS ONLY;

-- Parametro que define por quanto tempo o undo e mantido antes de poder
-- ser sobrescrito (afeta ate onde o FLASHBACK QUERY pode "voltar no tempo"):
SHOW PARAMETER undo_retention;

-- ----------------------------------------------------------------------------
-- 4. FLASHBACK QUERY: consultar o estado passado de uma tabela
-- ----------------------------------------------------------------------------
-- Simula um erro: um UPDATE indevido que zera todos os saldos
UPDATE conta_corrente SET saldo = 0;
COMMIT;

-- Consultar o estado da tabela ANTES do erro, usando o undo ainda disponivel:
SELECT id_conta, titular, saldo
  FROM conta_corrente
  AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '5' MINUTE);

-- Reverter os dados usando o resultado do FLASHBACK QUERY:
MERGE INTO conta_corrente destino
USING (
    SELECT id_conta, saldo
      FROM conta_corrente
      AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '5' MINUTE)
) origem
   ON (destino.id_conta = origem.id_conta)
 WHEN MATCHED THEN
      UPDATE SET destino.saldo = origem.saldo;

COMMIT;

-- ----------------------------------------------------------------------------
-- 5. FLASHBACK TABLE: reverter uma tabela inteira para um ponto no tempo
-- ----------------------------------------------------------------------------
-- Pre-requisito: habilitar row movement na tabela
ALTER TABLE conta_corrente ENABLE ROW MOVEMENT;

FLASHBACK TABLE conta_corrente TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '5' MINUTE);

-- ----------------------------------------------------------------------------
-- 6. FLASHBACK TABLE ... TO BEFORE DROP: recuperar tabela excluida
-- ----------------------------------------------------------------------------
-- Ao usar DROP TABLE, o Oracle nao apaga fisicamente os dados de imediato:
-- a tabela e renomeada e movida para a "Recycle Bin" (lixeira).
DROP TABLE conta_corrente;

-- Consultar a lixeira:
SELECT object_name, original_name, droptime
  FROM recyclebin
 WHERE original_name = 'CONTA_CORRENTE';

-- Restaurar a tabela (e seus indices/constraints) para antes do DROP:
FLASHBACK TABLE conta_corrente TO BEFORE DROP;

-- Se necessario, esvaziar a lixeira definitivamente (irreversivel):
-- PURGE TABLE conta_corrente;
-- PURGE RECYCLEBIN;
