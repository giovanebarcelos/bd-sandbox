-- ============================================================================
-- BD2201-RecuperacaoFalhas.sql
-- Aula 22 - Recuperacao de Falhas (PostgreSQL)
-- Tema: Write-Ahead Log (WAL), pg_wal, Point-in-Time Recovery (PITR)
-- Aula conceitual/arquitetural: os comandos abaixo sao ilustrativos e alguns
-- exigem privilegios de superusuario ou acesso ao sistema de arquivos do
-- servidor (fora do escopo de um cliente SQL comum).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Estrutura de apoio (mesma tabela usada na Aula 21)
-- ----------------------------------------------------------------------------
CREATE TABLE conta_corrente (
    id_conta   INTEGER        NOT NULL,
    titular    VARCHAR(100)   NOT NULL,
    saldo      NUMERIC(12,2)  NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente VALUES (2, 'Bruno Lima', 500.00);

-- ----------------------------------------------------------------------------
-- 2. WAL (Write-Ahead Log): toda mudanca e registrada em log ANTES de ser
-- aplicada nas paginas de dados em disco -- essa e a base da durabilidade
-- e da recuperacao apos crash no PostgreSQL.
-- ----------------------------------------------------------------------------

-- Posicao atual de gravacao do WAL (LSN - Log Sequence Number):
SELECT pg_current_wal_lsn();

-- Nome do arquivo de segmento de WAL correspondente a essa posicao:
SELECT pg_walfile_name(pg_current_wal_lsn());

-- Estatisticas globais de atividade de WAL desde o ultimo reset
-- (registros gerados, bytes escritos, quantidade de fsync):
SELECT wal_records, wal_bytes, wal_buffers_full, stats_reset
  FROM pg_stat_wal;

-- Listagem dos segmentos de WAL presentes no diretorio pg_wal (equivalente
-- ao comando de shell "ls $PGDATA/pg_wal", exposto via funcao de sistema):
SELECT * FROM pg_ls_waldir()
 ORDER BY modification DESC
 FETCH FIRST 10 ROWS ONLY;

-- ----------------------------------------------------------------------------
-- 3. Checkpoints: pontos em que as paginas sujas em memoria sao gravadas em
-- disco de forma consistente, limitando o WAL que precisa ser re-lido em
-- caso de crash recovery.
-- ----------------------------------------------------------------------------
SELECT checkpoints_timed, checkpoints_req, checkpoint_write_time,
       checkpoint_sync_time
  FROM pg_stat_bgwriter;

-- Forcar um checkpoint manual (uso administrativo, nao rotineiro):
-- CHECKPOINT;

-- ----------------------------------------------------------------------------
-- 4. Configuracao de arquivamento de WAL (postgresql.conf) -- pre-requisito
-- para PITR. Ilustrativo: exige edicao do arquivo de configuracao e reinicio
-- ou reload do servidor.
-- ----------------------------------------------------------------------------
-- wal_level = replica            -- ou 'logical' se usar replicacao logica
-- archive_mode = on
-- archive_command = 'cp %p /caminho/de/arquivamento/wal/%f'

SHOW wal_level;
SHOW archive_mode;
SHOW archive_command;

-- ----------------------------------------------------------------------------
-- 5. Point-in-Time Recovery (PITR): conceito
-- ----------------------------------------------------------------------------
-- PITR combina DOIS ingredientes:
--   (1) um backup fisico base (pg_basebackup), tirado em um instante T0
--   (2) todos os segmentos de WAL arquivados entre T0 e o instante desejado
--
-- Para restaurar ate um instante especifico (ex.: 5 minutos antes de um
-- DELETE acidental), cria-se um arquivo de sinalizacao de recovery e se
-- define o alvo no postgresql.conf (ou postgresql.auto.conf) da instancia
-- restaurada, NUNCA na instancia de producao original:
--
--   restore_command = 'cp /caminho/de/arquivamento/wal/%f %p'
--   recovery_target_time = '2026-07-06 14:32:00'
--   recovery_target_action = 'promote'
--
-- Ao iniciar essa instancia restaurada, o PostgreSQL cria o arquivo de
-- sinalizacao "recovery.signal" na pasta de dados e faz o REPLAY do WAL
-- arquivado a partir do backup base ate o instante definido, promovendo o
-- servidor a operar normalmente dali em diante (nao ha comando FLASHBACK
-- equivalente ao Oracle: a restauracao ocorre pela reconstrucao completa
-- de uma instancia a partir do backup + WAL).
--
-- O pg_basebackup, pg_dump/pg_restore e a rotina completa de backup serao
-- vistos em detalhe na Aula 26 - Backup e Recuperacao (UA10).

-- ----------------------------------------------------------------------------
-- 6. Monitoramento de replicacao/recovery (quando aplicavel)
-- ----------------------------------------------------------------------------
SELECT pg_is_in_recovery();

-- Em uma instancia em recovery/standby, mostra o progresso do replay do WAL:
-- SELECT pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();
