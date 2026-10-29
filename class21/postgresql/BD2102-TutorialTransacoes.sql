-- ============================================================================
-- BD2102-TutorialTransacoes.sql
-- Aula 21 - Tutorial passo a passo: transacoes, ACID e concorrencia
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro do tutorial Aula_21_..._Tutorial_PostgreSQL.md, banco aula21.
--   * Passos 1 a 5: uma sessao so; podem ser executados direto (\i).
--   * Passos 6 a 12: precisam de DUAS sessoes (dois terminais). Estao aqui
--     como roteiro comentado: [A] = sessao A, [B] = sessao B, na ordem.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. TABELA DE APOIO
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS conta_corrente;

CREATE TABLE conta_corrente (
    id_conta   INTEGER        NOT NULL,
    titular    VARCHAR(100)   NOT NULL,
    saldo      NUMERIC(12,2)  NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES
    (1, 'Ana Souza', 1000.00),
    (2, 'Bruno Lima', 500.00);

SELECT * FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 2. ATOMICIDADE: BEGIN ... ROLLBACK e BEGIN ... COMMIT
-- ----------------------------------------------------------------------------
-- 2a. Transferencia desfeita
BEGIN;
UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;
ROLLBACK;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;

-- 2b. Transferencia confirmada
BEGIN;
UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2;
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 3. CONSISTENCIA: um erro ABORTA a transacao inteira no PostgreSQL
-- ----------------------------------------------------------------------------
BEGIN;
UPDATE conta_corrente SET saldo = saldo + 5000 WHERE id_conta = 2;
-- viola o CHECK (saldo >= 0): erro proposital
UPDATE conta_corrente SET saldo = saldo - 5000 WHERE id_conta = 1;
-- qualquer comando agora e recusado
SELECT * FROM conta_corrente;
-- o COMMIT de uma transacao abortada vira ROLLBACK
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 4. SAVEPOINT: desfazer so parte da transacao
-- ----------------------------------------------------------------------------
BEGIN;
UPDATE conta_corrente SET saldo = saldo - 100 WHERE id_conta = 1;
SAVEPOINT apos_debito;
-- valor errado!
UPDATE conta_corrente SET saldo = saldo + 1000 WHERE id_conta = 2;
ROLLBACK TO SAVEPOINT apos_debito;
UPDATE conta_corrente SET saldo = saldo + 100 WHERE id_conta = 2;
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;

-- 4b. O SAVEPOINT tambem "salva" a transacao de um erro
BEGIN;
UPDATE conta_corrente SET saldo = saldo - 50 WHERE id_conta = 1;
SAVEPOINT antes_do_arriscado;
-- erro proposital (CHECK)
UPDATE conta_corrente SET saldo = saldo - 99999 WHERE id_conta = 2;
ROLLBACK TO SAVEPOINT antes_do_arriscado;
UPDATE conta_corrente SET saldo = saldo + 50 WHERE id_conta = 2;
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 5. MVCC: cada UPDATE cria uma nova versao da linha
-- ----------------------------------------------------------------------------
SELECT ctid, xmin, xmax, id_conta, saldo FROM conta_corrente ORDER BY id_conta;

BEGIN;
SELECT pg_current_xact_id() AS minha_transacao;
UPDATE conta_corrente SET saldo = saldo WHERE id_conta = 1;
SELECT ctid, xmin, xmax, id_conta, saldo FROM conta_corrente ORDER BY id_conta;
COMMIT;


-- ============================================================================
-- DAQUI EM DIANTE: DUAS SESSOES. Abra dois terminais com
--   docker exec -it postgres psql -U postgres -d aula21
-- e antes de cada passo rode, em qualquer uma delas, o "reset":
--   UPDATE conta_corrente SET saldo = CASE id_conta WHEN 1 THEN 1000 ELSE 500 END;
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PASSO 6. NAO EXISTE LEITURA SUJA (nem em READ UNCOMMITTED)
-- ----------------------------------------------------------------------------
-- [A] BEGIN;
-- [A] UPDATE conta_corrente SET saldo = 0 WHERE id_conta = 1;
-- [B] BEGIN ISOLATION LEVEL READ UNCOMMITTED;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000.00
-- [A] ROLLBACK;
-- [B] COMMIT;

-- ----------------------------------------------------------------------------
-- PASSO 7. READ COMMITTED x REPEATABLE READ
-- ----------------------------------------------------------------------------
-- 7a. READ COMMITTED (padrao): leitura nao repetivel
-- [B] BEGIN;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000.00
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;  (autocommit)
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      ->  900.00
-- [B] COMMIT;
--
-- 7b. REPEATABLE READ: um snapshot so para a transacao inteira
-- [B] BEGIN ISOLATION LEVEL REPEATABLE READ;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      ->  900.00
-- [A] UPDATE conta_corrente SET saldo = 800 WHERE id_conta = 1;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      ->  900.00 (!)
-- [B] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      ->  800.00

-- ----------------------------------------------------------------------------
-- PASSO 8. ATUALIZACAO PERDIDA (lost update) e SELECT ... FOR UPDATE
-- ----------------------------------------------------------------------------
-- 8a. O problema: a aplicacao le, calcula e grava o valor calculado
-- [A] BEGIN;
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000 (saca 100)
-- [B] BEGIN;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000 (saca 50)
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = 950 WHERE id_conta = 1;  -> FICA ESPERANDO
-- [A] COMMIT;                                                    -> B e liberado
-- [B] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 950 (o saque de A sumiu)
--
-- 8b. A correcao: ler com FOR UPDATE (reset antes)
-- [A] BEGIN;
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;   -> 1000
-- [B] BEGIN;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;   -> FICA ESPERANDO
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;
-- [A] COMMIT;                                              -> B recebe 900
-- [B] UPDATE conta_corrente SET saldo = 850 WHERE id_conta = 1;
-- [B] COMMIT;                                              -> saldo final 850

-- ----------------------------------------------------------------------------
-- PASSO 9. CONFLITO DE ESCRITA EM SERIALIZABLE (SQLSTATE 40001)
-- ----------------------------------------------------------------------------
-- [A] BEGIN ISOLATION LEVEL SERIALIZABLE;
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000
-- [B] BEGIN ISOLATION LEVEL SERIALIZABLE;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 2;      ->  500
-- [A] UPDATE conta_corrente SET saldo = saldo - 50 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = saldo + 50 WHERE id_conta = 1;  -> FICA ESPERANDO
-- [A] COMMIT;
-- [B] -> ERROR: could not serialize access due to concurrent update (no UPDATE!)
-- [B] ROLLBACK;

-- ----------------------------------------------------------------------------
-- PASSO 10. WRITE SKEW: REPEATABLE READ deixa passar, SERIALIZABLE nao
-- ----------------------------------------------------------------------------
-- Regra da familia: a soma dos saldos precisa ficar >= 500.
-- 10a. REPEATABLE READ
-- [A] BEGIN ISOLATION LEVEL REPEATABLE READ;
-- [A] SELECT SUM(saldo) FROM conta_corrente;            -> 1500 (pode sacar 600)
-- [B] BEGIN ISOLATION LEVEL REPEATABLE READ;
-- [B] SELECT SUM(saldo) FROM conta_corrente;            -> 1500 (pode sacar 450)
-- [A] UPDATE conta_corrente SET saldo = saldo - 600 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = saldo - 450 WHERE id_conta = 2;
-- [A] COMMIT;
-- [B] COMMIT;
-- [A] SELECT SUM(saldo) FROM conta_corrente;            -> 450 (regra violada!)
--
-- 10b. SERIALIZABLE (reset antes): mesmos comandos, trocando o nivel
-- [B] COMMIT;  -> ERROR: could not serialize access due to read/write
--                dependencies among transactions (SO NO COMMIT)

-- ----------------------------------------------------------------------------
-- PASSO 11. DEADLOCK
-- ----------------------------------------------------------------------------
-- [A] BEGIN;
-- [A] UPDATE conta_corrente SET saldo = saldo - 10 WHERE id_conta = 1;
-- [B] BEGIN;
-- [B] UPDATE conta_corrente SET saldo = saldo - 20 WHERE id_conta = 2;
-- [A] UPDATE conta_corrente SET saldo = saldo + 10 WHERE id_conta = 2;  -> espera B
-- [B] UPDATE conta_corrente SET saldo = saldo + 20 WHERE id_conta = 1;  -> espera A: CICLO
--     ~1 s depois, uma delas recebe: ERROR: deadlock detected
-- [A] COMMIT;   [B] COMMIT;   (a vitima recebe ROLLBACK)

-- ----------------------------------------------------------------------------
-- PASSO 12. NOWAIT, SKIP LOCKED E MONITORAMENTO
-- ----------------------------------------------------------------------------
-- [A] BEGIN;
-- [A] SELECT * FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;
-- [B] SELECT * FROM conta_corrente WHERE id_conta = 1 FOR UPDATE NOWAIT;
--     -> ERROR: could not obtain lock on row in relation "conta_corrente"
-- [B] SELECT * FROM conta_corrente FOR UPDATE SKIP LOCKED;   -> so a conta 2
-- [B] UPDATE conta_corrente SET saldo = saldo WHERE id_conta = 1;   -> FICA ESPERANDO
-- [C] (terceiro terminal) consultas abaixo
-- [A] COMMIT;

-- Quem esta bloqueado por quem:
SELECT pid, pg_blocking_pids(pid) AS bloqueado_por, state, wait_event_type,
       left(query, 60) AS query
  FROM pg_stat_activity
 WHERE datname = current_database() AND pid <> pg_backend_pid()
 ORDER BY pid;

-- Locks concedidos (granted = true) e aguardados (false) dessas sessoes.
-- Quem espera por uma linha espera, na verdade, a TRANSACAO que a alterou
-- (locktype = 'transactionid', granted = false).
SELECT l.pid, l.locktype, l.relation::regclass AS tabela, l.transactionid, l.mode, l.granted
  FROM pg_locks l
  JOIN pg_stat_activity a ON a.pid = l.pid
 WHERE a.datname = current_database() AND l.pid <> pg_backend_pid()
   AND l.locktype IN ('relation', 'tuple', 'transactionid')
   AND (l.relation IS NULL OR l.relation = 'conta_corrente'::regclass)
 ORDER BY l.pid, l.granted DESC, l.locktype;
