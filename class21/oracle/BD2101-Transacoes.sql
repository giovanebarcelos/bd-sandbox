-- ============================================================================
-- BD2101-Transacoes.sql
-- Aula 21 - ACID e Controle de Concorrencia (Oracle Database)
-- Tema: transacoes, COMMIT/ROLLBACK, locking pessimista, niveis de isolamento
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Estrutura de apoio: conta corrente para demonstrar transferencia bancaria
-- ----------------------------------------------------------------------------
DROP TABLE conta_corrente PURGE;

CREATE TABLE conta_corrente (
    id_conta   NUMBER(10)      NOT NULL,
    titular    VARCHAR2(100)   NOT NULL,
    saldo      NUMBER(12,2)    NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (2, 'Bruno Lima', 500.00);
COMMIT;

-- ----------------------------------------------------------------------------
-- 2. ATOMICIDADE: transferencia como unidade indivisivel (tudo ou nada)
-- ----------------------------------------------------------------------------
-- No Oracle, toda sessao inicia uma transacao implicitamente na primeira DML.
-- Nao existe "BEGIN TRANSACTION" explicito: a transacao comeca no primeiro
-- INSERT/UPDATE/DELETE e termina em COMMIT, ROLLBACK ou DDL implicito.

UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1; -- debito
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2; -- credito

-- Se qualquer uma das duas linhas falhar (ex.: violacao do CHECK de saldo
-- nao-negativo), a transacao inteira deve ser desfeita:
-- ROLLBACK;

COMMIT; -- confirma as duas atualizacoes como uma unidade atomica

-- ----------------------------------------------------------------------------
-- 3. CONSISTENCIA: a CHECK constraint impede estado invalido
-- ----------------------------------------------------------------------------
-- Tentativa de deixar o saldo negativo (violaria a regra de negocio):
BEGIN
    UPDATE conta_corrente SET saldo = saldo - 5000 WHERE id_conta = 1;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK; -- desfaz a tentativa, banco permanece consistente
        DBMS_OUTPUT.PUT_LINE('Transacao revertida: ' || SQLERRM);
END;
/

-- ----------------------------------------------------------------------------
-- 4. ISOLAMENTO: niveis suportados pelo Oracle
-- ----------------------------------------------------------------------------
-- Oracle so implementa dois niveis ANSI SQL: READ COMMITTED (padrao) e
-- SERIALIZABLE. READ UNCOMMITTED e REPEATABLE READ nao existem como tal,
-- pois o motor de consistencia de leitura do Oracle (read consistency via
-- undo) ja evita dirty reads por padrao.

-- Nivel padrao (nao precisa declarar):
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Cada comando SELECT enxerga apenas dados committed no instante em que o
-- proprio SELECT comeca (nao no instante em que a transacao comecou).

-- Nivel SERIALIZABLE: a transacao inteira enxerga uma unica "foto" (snapshot)
-- do banco, tirada no inicio da transacao. Escritas concorrentes que
-- conflitam geram erro ORA-08177.
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT saldo FROM conta_corrente WHERE id_conta = 1; -- fixa o snapshot

-- ... outra sessao altera e faz COMMIT da linha id_conta = 1 nesse meio tempo ...

UPDATE conta_corrente SET saldo = saldo - 50 WHERE id_conta = 1;
-- Se a outra sessao ja tiver committado uma mudanca na mesma linha:
-- ORA-08177: can't serialize access for this transaction
COMMIT;

-- ----------------------------------------------------------------------------
-- 5. LOCKING PESSIMISTA: SELECT ... FOR UPDATE
-- ----------------------------------------------------------------------------
-- O Oracle usa controle de concorrencia baseado em locks de linha (row-level
-- locking) combinado com read consistency via undo segments. FOR UPDATE
-- solicita explicitamente um lock exclusivo nas linhas selecionadas, que so
-- e liberado em COMMIT ou ROLLBACK.

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT saldo
  FROM conta_corrente
 WHERE id_conta = 1
   FOR UPDATE; -- bloqueia a linha ate o fim da transacao

UPDATE conta_corrente SET saldo = saldo - 100 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 100 WHERE id_conta = 2;

COMMIT; -- libera os locks

-- Variante NOWAIT: falha imediatamente em vez de esperar o lock ser liberado
-- (ORA-00054: resource busy and acquire with NOWAIT specified)
-- SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE NOWAIT;

-- Variante WAIT n: espera no maximo n segundos antes de retornar erro
-- SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE WAIT 5;

-- ----------------------------------------------------------------------------
-- 6. CENARIO DE CONFLITO DE CONCORRENCIA (duas sessoes simuladas)
-- ----------------------------------------------------------------------------
-- Abra duas sessoes SQL*Plus/SQL Developer para reproduzir o cenario abaixo.
--
-- SESSAO A (T1)                              SESSAO B (T2)
-- ------------------------------------------  ------------------------------
-- SELECT saldo FROM conta_corrente
--  WHERE id_conta = 1 FOR UPDATE;
-- -> retorna 700, linha 1 fica bloqueada
--
--                                              SELECT saldo FROM conta_corrente
--                                               WHERE id_conta = 1 FOR UPDATE;
--                                              -> BLOQUEIA (aguarda o lock de A)
--
-- UPDATE conta_corrente SET saldo = saldo - 50
--  WHERE id_conta = 1;
-- COMMIT;
-- -> libera o lock, saldo passa a 650
--
--                                              -- B eh liberado e enxerga 650
--                                              -- (read committed, sem dirty read)
--                                              UPDATE conta_corrente SET saldo = saldo - 30
--                                               WHERE id_conta = 1;
--                                              COMMIT;
--
-- Conclusao: o locking pessimista do Oracle SERIALIZA o acesso a mesma linha.
-- B espera A terminar; nao ha leitura suja, mas ha espera (blocking), o que
-- pode gerar deadlocks se duas transacoes tentam travar linhas em ordem
-- cruzada (A trava linha 1 depois pede linha 2; B trava linha 2 depois pede
-- linha 1). O Oracle detecta automaticamente e aborta uma das transacoes com
-- ORA-00060: deadlock detected while waiting for resource.

-- ----------------------------------------------------------------------------
-- 7. Monitoramento de locks ativos (view do dicionario de dados)
-- ----------------------------------------------------------------------------
SELECT s.sid, s.serial#, s.username, o.object_name, l.locked_mode
  FROM v$locked_object l
  JOIN dba_objects o ON l.object_id = o.object_id
  JOIN v$session s ON l.session_id = s.sid;

-- Sessoes bloqueadas aguardando outra sessao liberar um lock:
SELECT blocking_session, sid, serial#, wait_class, seconds_in_wait
  FROM v$session
 WHERE blocking_session IS NOT NULL;
