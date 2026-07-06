-- ============================================================================
-- BD2101-Transacoes.sql
-- Aula 21 - ACID e Controle de Concorrencia (PostgreSQL)
-- Tema: transacoes, COMMIT/ROLLBACK, MVCC, niveis de isolamento
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Estrutura de apoio: conta corrente para demonstrar transferencia bancaria
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS conta_corrente;

CREATE TABLE conta_corrente (
    id_conta   INTEGER        NOT NULL,
    titular    VARCHAR(100)   NOT NULL,
    saldo      NUMERIC(12,2)  NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (2, 'Bruno Lima', 500.00);

-- ----------------------------------------------------------------------------
-- 2. ATOMICIDADE: transacao explicita com BEGIN/COMMIT
-- ----------------------------------------------------------------------------
-- No PostgreSQL, fora de uma transacao explicita cada comando roda em
-- "modo autocommit" (uma mini-transacao por comando). Para agrupar varios
-- comandos como unidade atomica, usa-se BEGIN ... COMMIT.

BEGIN;

UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1; -- debito
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2; -- credito

-- Se algo der errado antes do COMMIT, a transacao inteira pode ser desfeita:
-- ROLLBACK;

COMMIT;

-- ----------------------------------------------------------------------------
-- 3. CONSISTENCIA: a CHECK constraint impede estado invalido
-- ----------------------------------------------------------------------------
BEGIN;
    UPDATE conta_corrente SET saldo = saldo - 5000 WHERE id_conta = 1;
    -- ERROR: new row for relation "conta_corrente" violates check
    -- constraint "ck_saldo_nao_negativo"
    -- O PostgreSQL aborta a transacao automaticamente; qualquer comando
    -- seguinte devolve "current transaction is aborted" ate um ROLLBACK.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 4. ISOLAMENTO: MVCC (Multi-Version Concurrency Control)
-- ----------------------------------------------------------------------------
-- O PostgreSQL nao usa locking pessimista para leituras. Cada linha fisica
-- carrega metadados de versao (xmin/xmax = id da transacao que criou/expirou
-- aquela versao). Um SELECT nunca bloqueia um UPDATE, e vice-versa: leitores
-- enxergam a versao da linha valida no momento do seu snapshot, enquanto
-- escritores criam novas versoes (tuplas) em vez de sobrescrever no lugar.

-- Niveis de isolamento suportados (padrao SQL): READ COMMITTED (default),
-- REPEATABLE READ, SERIALIZABLE. READ UNCOMMITTED existe apenas como sinonimo
-- de READ COMMITTED (o PostgreSQL nunca permite dirty read).

SHOW default_transaction_isolation; -- 'read committed'

-- READ COMMITTED: cada comando dentro da transacao tira um novo snapshot.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT saldo FROM conta_corrente WHERE id_conta = 1;
-- ... outra sessao faz UPDATE + COMMIT na mesma linha nesse meio tempo ...
SELECT saldo FROM conta_corrente WHERE id_conta = 1; -- ja enxerga o novo valor
COMMIT;

-- REPEATABLE READ: um unico snapshot para toda a transacao (nao ve mudancas
-- committed por outras transacoes depois que a sua comecou).
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT saldo FROM conta_corrente WHERE id_conta = 1; -- ex.: 800
-- ... outra sessao faz UPDATE + COMMIT na mesma linha nesse meio tempo ...
SELECT saldo FROM conta_corrente WHERE id_conta = 1; -- ainda 800 (mesmo snapshot)
COMMIT;

-- SERIALIZABLE: implementa SSI (Serializable Snapshot Isolation) -- detecta
-- padroes de conflito entre transacoes concorrentes e aborta uma delas com
-- SQLSTATE 40001 (serialization_failure) quando o resultado final nao seria
-- equivalente a alguma ordem serial de execucao.
BEGIN ISOLATION LEVEL SERIALIZABLE;
UPDATE conta_corrente SET saldo = saldo - 50 WHERE id_conta = 1;
-- Se outra transacao concorrente tambem SERIALIZABLE tiver mexido em dados
-- relacionados de forma incompativel:
-- ERROR: could not serialize access due to concurrent update
COMMIT;

-- ----------------------------------------------------------------------------
-- 5. Locking explicito quando MVCC nao basta: SELECT ... FOR UPDATE
-- ----------------------------------------------------------------------------
-- MVCC resolve bem leitura x escrita, mas duas transacoes que querem
-- MODIFICAR a mesma linha ainda precisam de coordenacao. FOR UPDATE bloqueia
-- a linha para outras transacoes que tambem tentem UPDATE/DELETE/FOR UPDATE
-- nela, sem impedir leituras simples (SELECT sem FOR UPDATE continuam livres).

BEGIN;
SELECT saldo
  FROM conta_corrente
 WHERE id_conta = 1
   FOR UPDATE; -- trava a linha para escrita ate o fim da transacao

UPDATE conta_corrente SET saldo = saldo - 100 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 100 WHERE id_conta = 2;
COMMIT;

-- Variante NOWAIT: falha imediatamente em vez de esperar
-- SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE NOWAIT;

-- Variante SKIP LOCKED: ignora linhas ja travadas por outra transacao (util
-- em filas de processamento concorrente)
-- SELECT * FROM conta_corrente FOR UPDATE SKIP LOCKED;

-- ----------------------------------------------------------------------------
-- 6. CENARIO DE CONFLITO DE CONCORRENCIA (duas sessoes simuladas)
-- ----------------------------------------------------------------------------
-- Abra duas sessoes psql para reproduzir o cenario abaixo em SERIALIZABLE.
--
-- SESSAO A (T1)                              SESSAO B (T2)
-- ------------------------------------------  ------------------------------
-- BEGIN ISOLATION LEVEL SERIALIZABLE;         BEGIN ISOLATION LEVEL SERIALIZABLE;
-- SELECT saldo FROM conta_corrente
--  WHERE id_conta = 1;  -> 700 (snapshot)
--                                              SELECT saldo FROM conta_corrente
--                                               WHERE id_conta = 2; -> 300 (snapshot)
-- UPDATE conta_corrente SET saldo = saldo - 50
--  WHERE id_conta = 1;
--                                              UPDATE conta_corrente SET saldo = saldo + 50
--                                               WHERE id_conta = 1;  -- mesma linha!
-- COMMIT; -- sucesso, saldo vira 650
--                                              COMMIT;
--                                              -- ERROR: could not serialize access
--                                              -- due to concurrent update
--                                              -- SQLSTATE 40001
--
-- Conclusao: diferente do locking pessimista do Oracle, o PostgreSQL NAO
-- bloqueia B enquanto A esta rodando (MVCC deixa ambos avancarem lendo
-- snapshots proprios). O conflito so eh detectado na hora do COMMIT de B,
-- que recebe erro de serializacao e deve reexecutar a transacao (retry).
-- Isso troca "espera bloqueante" (Oracle locking) por "otimismo com
-- possibilidade de abortar e repetir" (Postgres SERIALIZABLE).

-- ----------------------------------------------------------------------------
-- 7. Monitoramento de transacoes e locks ativos
-- ----------------------------------------------------------------------------
SELECT pid, usename, state, query, wait_event_type, wait_event
  FROM pg_stat_activity
 WHERE state <> 'idle';

-- Locks concedidos e aguardados no momento:
SELECT locktype, relation::regclass, mode, granted, pid
  FROM pg_locks
 WHERE relation IS NOT NULL;
