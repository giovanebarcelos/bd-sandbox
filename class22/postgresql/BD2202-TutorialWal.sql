-- ============================================================================
-- BD2202-TutorialWal.sql
-- Aula 22 - Tutorial passo a passo (parte A): WAL, LSN, checkpoint e crash
-- recovery
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro da parte A do tutorial Aula_22_..._Tutorial_PostgreSQL.md, banco
-- aula22. A parte B (PITR) esta em BD2203-LabPitr.sh e usa um container
-- descartavel, para nao mexer na configuracao do ambiente da disciplina.
-- Funcoes como pg_ls_waldir() exigem superusuario (postgres) ou pg_monitor.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. TABELA DE APOIO (a mesma da Aula 21)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS conta_corrente;

CREATE TABLE conta_corrente (
    id_conta   INTEGER        NOT NULL,
    titular    VARCHAR(100)   NOT NULL,
    saldo      NUMERIC(12,2)  NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente VALUES (1, 'Ana Souza', 1000.00), (2, 'Bruno Lima', 500.00);


-- ----------------------------------------------------------------------------
-- PASSO 2. LSN: a posicao atual no WAL e quanto WAL um comando gera
-- ----------------------------------------------------------------------------
SELECT pg_current_wal_lsn() AS lsn_atual,
       pg_walfile_name(pg_current_wal_lsn()) AS arquivo_de_wal;

-- guarda o LSN numa variavel do psql (\gset), gera atividade e mede a diferenca
SELECT pg_current_wal_lsn() AS lsn_antes \gset

INSERT INTO conta_corrente (id_conta, titular, saldo)
SELECT 100 + g, 'Cliente ' || g, 100 FROM generate_series(1, 10000) AS g;

SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), :'lsn_antes')) AS wal_gerado_pelo_insert;

DELETE FROM conta_corrente WHERE id_conta > 100;


-- ----------------------------------------------------------------------------
-- PASSO 3. ARQUIVOS DE WAL E ESTATISTICAS
-- ----------------------------------------------------------------------------
SELECT name, pg_size_pretty(size) AS tamanho, modification
  FROM pg_ls_waldir()
 ORDER BY modification DESC
 LIMIT 5;

SELECT wal_records, wal_fpi, pg_size_pretty(wal_bytes) AS wal_bytes, wal_buffers_full
  FROM pg_stat_wal;

SHOW wal_level;
SHOW archive_mode;
SHOW max_wal_size;
SHOW checkpoint_timeout;


-- ----------------------------------------------------------------------------
-- PASSO 4. CHECKPOINT
-- ----------------------------------------------------------------------------
-- No PostgreSQL 17 os contadores de checkpoint ficam em pg_stat_checkpointer
-- (antes ficavam em pg_stat_bgwriter.checkpoints_timed/checkpoints_req).
SELECT num_timed AS por_tempo, num_requested AS solicitados,
       buffers_written AS paginas_gravadas
  FROM pg_stat_checkpointer;

-- O "redo_lsn" e o ponto de onde um crash recovery comecaria o replay
SELECT redo_lsn, checkpoint_lsn, checkpoint_time FROM pg_control_checkpoint();

CHECKPOINT;

SELECT redo_lsn, checkpoint_lsn, checkpoint_time FROM pg_control_checkpoint();
SELECT num_timed AS por_tempo, num_requested AS solicitados FROM pg_stat_checkpointer;


-- ----------------------------------------------------------------------------
-- PASSO 5. PREPARANDO O CRASH (o crash em si e feito no terminal)
-- ----------------------------------------------------------------------------
-- 5a. Uma transacao CONFIRMADA depois do checkpoint
INSERT INTO conta_corrente VALUES (3, 'Carla Dias', 750.00);
SELECT redo_lsn FROM pg_control_checkpoint();
SELECT pg_current_wal_lsn();

-- 5b. Em OUTRO terminal, deixe uma transacao ABERTA:
--   BEGIN;
--   INSERT INTO conta_corrente VALUES (4, 'Nao Confirmado', 999.00);
--
-- 5c. No terminal do sistema operacional (fora do psql):
--   docker kill postgres
--   docker start postgres
--   docker logs postgres --tail 12
--
-- 5d. Reconecte e confira: a conta 3 existe, a conta 4 nao.
SELECT * FROM conta_corrente ORDER BY id_conta;
