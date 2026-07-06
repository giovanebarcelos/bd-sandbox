-- ============================================================================
-- BD2601-Backup.sql
-- Aula 26 - Backup e Recuperacao | Oracle RMAN
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Script de referencia para execucao via RMAN (Recovery Manager).
-- Uso: conectar ao alvo e colar os blocos desejados no prompt do RMAN.
--
--   $ rman target /
--   RMAN> @BD2601-Backup.sql
--
-- Ajuste os parametros (retencao, paralelismo, diretorios) ao seu ambiente.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. CONFIGURACAO DO AMBIENTE RMAN
-- ----------------------------------------------------------------------------

-- Janela de recuperacao: RMAN mantem backups suficientes para recuperar o
-- banco para qualquer ponto nos ultimos 7 dias
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Backup automatico da controlfile (e do spfile) a cada operacao de backup
CONFIGURE CONTROLFILE AUTOBACKUP ON;

-- Paralelismo de canais em disco (2 processos simultaneos)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;

-- Compressao do backup set (reduz espaco em disco as custas de CPU)
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

-- Ativa o rastreamento de blocos alterados: acelera backups incrementais,
-- pois evita varrer o datafile inteiro para descobrir o que mudou
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING;

-- Consultar a configuracao atual
SHOW ALL;


-- ----------------------------------------------------------------------------
-- 2. BACKUP FULL (NIVEL 0) - BASE DE QUALQUER ESTRATEGIA
-- ----------------------------------------------------------------------------

-- Backup completo do banco + archivelogs necessarios, removendo os
-- archivelogs ja copiados para liberar espaco (DELETE INPUT)
BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;

-- Equivalente explicito como nivel 0 (registra no catalogo como base
-- de uma cadeia incremental subsequente)
BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'FULL_SEMANAL';


-- ----------------------------------------------------------------------------
-- 3. BACKUP INCREMENTAL (NIVEL 1)
-- ----------------------------------------------------------------------------

-- Incremental NAO-cumulativo: copia apenas o que mudou desde o ultimo
-- backup de QUALQUER nivel (0 ou 1) - menor volume, restore mais longo
BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'INCREMENTAL_DIARIO';

-- Incremental CUMULATIVO: copia tudo que mudou desde o ultimo nivel 0
-- (equivalente ao "differential" da industria) - restore mais simples
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE TAG 'DIFERENCIAL_DIARIO';

-- Backup apenas dos archivelogs gerados desde o ultimo backup
BACKUP ARCHIVELOG ALL DELETE INPUT;


-- ----------------------------------------------------------------------------
-- 4. VALIDACAO E GESTAO DE BACKUPS
-- ----------------------------------------------------------------------------

-- Lista resumida de todos os backups conhecidos pelo RMAN
LIST BACKUP SUMMARY;

-- Valida se o backup mais recente pode ser restaurado sem de fato
-- restaurar (le os blocos e verifica integridade/checksum)
RESTORE DATABASE VALIDATE;

-- Verifica se os arquivos de backup catalogados ainda existem fisicamente
CROSSCHECK BACKUP;

-- Remove do catalogo os backups considerados obsoletos pela retention policy
DELETE NOPROMPT OBSOLETE;


-- ----------------------------------------------------------------------------
-- 5. FLUXO DE RESTORE + RECOVER (RECUPERACAO COMPLETA)
-- ----------------------------------------------------------------------------

-- 1) Banco precisa estar em MOUNT para um restore completo dos datafiles
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- 2) Restaura os datafiles a partir do backup mais recente disponivel
RESTORE DATABASE;

-- 3) Aplica redo/archivelogs para trazer o banco ao estado mais atual
RECOVER DATABASE;

-- 4) Reabre o banco normalmente
ALTER DATABASE OPEN;


-- ----------------------------------------------------------------------------
-- 6. RECUPERACAO ATE UM PONTO NO TEMPO (PITR)
-- ----------------------------------------------------------------------------

-- Uso tipico apos um erro humano (ex.: DELETE sem WHERE) ocorrido em um
-- horario conhecido - recupera o banco para o instante imediatamente
-- anterior ao incidente
RUN {
  SET UNTIL TIME "TO_DATE('2026-07-05 14:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}

-- RESETLOGS e obrigatorio apos um recover incompleto: reinicia a linha
-- do tempo (thread) de redo do banco
ALTER DATABASE OPEN RESETLOGS;


-- ----------------------------------------------------------------------------
-- 7. CRONOGRAMA RECOMENDADO (EXECUCAO VIA CRONTAB DO SISTEMA OPERACIONAL)
-- ----------------------------------------------------------------------------

-- ARCHIVELOG mode deve permanecer sempre ativo em producao:
--   ALTER DATABASE ARCHIVELOG;   -- (executado uma unica vez, em MOUNT)
--
-- crontab sugerido no servidor Oracle:
--   0 2 * * 0   rman target / cmdfile=/scripts/BD2601_full.rman      (full semanal)
--   0 2 * * 1-6 rman target / cmdfile=/scripts/BD2601_incremental.rman (incremental diario)
--   */30 * * * * rman target / cmdfile=/scripts/BD2601_archivelog.rman (archivelog a cada 30min)
--
-- Retencao: RECOVERY WINDOW OF 7 DAYS (configurado na secao 1), com copia
-- adicional para storage externo/nuvem seguindo a regra 3-2-1.
