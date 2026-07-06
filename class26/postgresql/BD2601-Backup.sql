-- ============================================================================
-- BD2601-Backup.sql
-- Aula 26 - Backup e Recuperacao | PostgreSQL
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Este arquivo documenta os comandos de SHELL (pg_dump/pg_restore/
-- pg_basebackup) como comentarios de bloco, e o SQL/parametros de
-- configuracao envolvidos em cada etapa. Nao e um script .sql executavel
-- de ponta a ponta (comandos de shell nao rodam dentro do psql) - use-o
-- como roteiro de referencia, copiando cada bloco no terminal ou no
-- postgresql.conf conforme indicado.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. BACKUP LOGICO - pg_dump / pg_restore
-- ----------------------------------------------------------------------------

-- [SHELL] Backup logico de um unico banco, formato "custom" (compactado,
-- permite restore seletivo e paralelo)
--   $ pg_dump -U postgres -d meubanco -F c -f /backup/meubanco_full.dump

-- [SHELL] Backup logico em formato "plain" (script SQL puro, legivel,
-- ideal para versionamento e migracao entre versoes distintas)
--   $ pg_dump -U postgres -d meubanco -F p -f /backup/meubanco_full.sql

-- [SHELL] Backup logico de um schema especifico apenas
--   $ pg_dump -U postgres -d meubanco -n vendas -F c -f /backup/schema_vendas.dump

-- [SHELL] Backup logico de todo o cluster (todos os bancos + roles + tablespaces)
--   $ pg_dumpall -U postgres -f /backup/cluster_completo.sql

-- [SHELL] Restore a partir do formato custom, com paralelismo de 4 jobs
--   $ createdb -U postgres meubanco_novo
--   $ pg_restore -U postgres -d meubanco_novo -j 4 /backup/meubanco_full.dump

-- [SHELL] Restore de apenas uma tabela especifica do dump
--   $ pg_restore -U postgres -d meubanco_novo -t pedidos /backup/meubanco_full.dump

-- [SHELL] Restore do formato "plain" (script SQL), via psql
--   $ psql -U postgres -d meubanco_novo -f /backup/meubanco_full.sql


-- ----------------------------------------------------------------------------
-- 2. USUARIO DE REPLICACAO/BACKUP (SQL REAL)
-- ----------------------------------------------------------------------------

-- Cria um usuario dedicado com o privilegio minimo necessario para
-- pg_basebackup e streaming replication (Aula 27)
CREATE ROLE replicador WITH REPLICATION LOGIN PASSWORD 'troque_esta_senha';

-- pg_hba.conf precisa liberar a conexao de replicacao para este usuario:
--   host   replication   replicador   10.0.0.0/24   scram-sha-256


-- ----------------------------------------------------------------------------
-- 3. BACKUP FISICO - pg_basebackup
-- ----------------------------------------------------------------------------

-- [SHELL] Copia fisica completa do diretorio de dados (PGDATA), via
-- protocolo de replicacao
--   $ pg_basebackup -h localhost -U replicador -D /backup/base -Fp -Xs -P
--
--   -Fp : formato "plain" (diretorio com os arquivos como estao)
--   -Xs : inclui os WAL necessarios via streaming durante o backup
--   -P  : exibe barra de progresso

-- [SHELL] Backup fisico compactado em formato tar
--   $ pg_basebackup -h localhost -U replicador -D /backup/base_tar -Ft -z -Xs -P


-- ----------------------------------------------------------------------------
-- 4. WAL ARCHIVING - BASE DO BACKUP CONTINUO E DO PITR
-- ----------------------------------------------------------------------------

-- [postgresql.conf] Habilita o arquivamento continuo do WAL
--   wal_level = replica
--   archive_mode = on
--   archive_command = 'cp %p /mnt/wal_archive/%f'
--   max_wal_senders = 10
--   archive_timeout = 300

-- [SQL] Verifica se o archive_command esta em dia (failed_count deve
-- permanecer zero em um ambiente saudavel)
SELECT archived_count, failed_count, last_archived_time, last_failed_time
  FROM pg_stat_archiver;

-- [SQL] Forca a troca do segmento de WAL atual (util em testes/homologacao)
SELECT pg_switch_wal();


-- ----------------------------------------------------------------------------
-- 5. RECUPERACAO ATE UM PONTO NO TEMPO (PITR)
-- ----------------------------------------------------------------------------

-- [SHELL] 1) Restaura a base fisica mais recente no diretorio de dados
--   $ rm -rf /var/lib/postgresql/16/main/*
--   $ tar -xzf /backup/base_tar/base.tar.gz -C /var/lib/postgresql/16/main/

-- [postgresql.conf ou postgresql.auto.conf] 2) Configura a recuperacao
--   restore_command = 'cp /mnt/wal_archive/%f %p'
--   recovery_target_time = '2026-07-05 14:30:00'
--   recovery_target_action = 'promote'

-- [SHELL] 3) Sinaliza que este e um restore em modo recovery (PG 12+)
--   $ touch /var/lib/postgresql/16/main/recovery.signal

-- [SHELL] 4) Inicia o servico - o PostgreSQL aplica os WAL ate o
-- recovery_target_time e entao promove o banco para leitura/escrita
--   $ systemctl start postgresql


-- ----------------------------------------------------------------------------
-- 6. CRONOGRAMA RECOMENDADO (CRONTAB DO SERVIDOR)
-- ----------------------------------------------------------------------------

-- archive_mode = on permanece sempre ativo em producao (secao 4).
--
-- crontab sugerido no servidor PostgreSQL:
--   0 1 * * 0   pg_basebackup -h localhost -U replicador -D /backup/base_$(date +\%Y\%m\%d) -Fp -Xs   (fisico semanal)
--   0 2 * * 1-6 pg_dump -U postgres -d meubanco -F c -f /backup/logico_$(date +\%Y\%m\%d).dump          (logico diario)
--   0 3 * * *   find /backup -mtime +30 -delete                                                        (retencao 30 dias)
--
-- Alternativa recomendada para producao critica: usar pgBackRest ou
-- Barman, que automatizam backup incremental, paralelismo, compressao
-- e retencao com uma unica ferramenta (ver Slide 29 da Aula 26).
