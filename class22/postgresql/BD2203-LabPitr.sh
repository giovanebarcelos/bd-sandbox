#!/usr/bin/env bash
# ============================================================================
# BD2203-LabPitr.sh
# Aula 22 - Tutorial passo a passo (parte B): Point-in-Time Recovery (PITR)
#
# Laboratorio completo e automatico, num container DESCARTAVEL ("pitr-lab"),
# separado do ambiente Docker da disciplina:
#   1. sobe um PostgreSQL com arquivamento de WAL ligado
#   2. cria dados e tira um backup base (pg_basebackup)
#   3. grava mais dados, anota a hora e faz um DELETE "acidental"
#   4. restaura o backup numa SEGUNDA instancia (porta 5433), aplicando o WAL
#      arquivado ate o instante anterior ao DELETE
#   5. compara a instancia original (vazia) com a restaurada (com os dados)
#
# O tutorial Aula_22_..._Tutorial_PostgreSQL.md faz os mesmos passos a mao.
# Uso:   bash BD2203-LabPitr.sh            (imagem postgres:17)
#        IMAGEM=postgres:17-alpine bash BD2203-LabPitr.sh
# Limpa: docker rm -f pitr-lab
# ============================================================================
set -euo pipefail

IMAGEM="${IMAGEM:-postgres:17}"
LAB=pitr-lab
BASE=/var/lib/postgresql
EXEC="docker exec -i -u postgres $LAB"

echo "== 1. Subindo o container $LAB ($IMAGEM) com archive_mode = on"
docker rm -f "$LAB" >/dev/null 2>&1 || true
docker run -d --name "$LAB" -e POSTGRES_PASSWORD=postgres -e TZ=America/Sao_Paulo "$IMAGEM" \
    -c wal_level=replica \
    -c archive_mode=on \
    -c "archive_command=mkdir -p $BASE/arquivo_wal && test ! -f $BASE/arquivo_wal/%f && cp %p $BASE/arquivo_wal/%f" \
    >/dev/null
until docker exec "$LAB" pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
sleep 2

echo "== 2. Dados iniciais e backup base"
$EXEC psql -q <<'SQL'
CREATE TABLE conta_corrente (
    id_conta INTEGER PRIMARY KEY,
    titular  VARCHAR(100) NOT NULL,
    saldo    NUMERIC(12,2) NOT NULL
);
INSERT INTO conta_corrente VALUES (1, 'Ana Souza', 1000.00), (2, 'Bruno Lima', 500.00);
SQL
$EXEC pg_basebackup -D "$BASE/backup_base" -X stream -c fast
$EXEC cat "$BASE/backup_base/backup_label"

echo "== 3. Mais dados DEPOIS do backup, anotacao da hora e o desastre"
$EXEC psql -q -c "INSERT INTO conta_corrente VALUES (3, 'Carla Dias', 750.00);"
sleep 1
ALVO=$($EXEC psql -At -c "SELECT now();")
echo "   instante alvo (antes do desastre): $ALVO"
sleep 1
$EXEC psql -q -c "DELETE FROM conta_corrente;"
$EXEC psql -At -c "SELECT pg_switch_wal();" >/dev/null
sleep 2
$EXEC psql -c "SELECT archived_count, last_archived_wal, failed_count FROM pg_stat_archiver;"
$EXEC psql -c "SELECT COUNT(*) AS linhas_na_instancia_original FROM conta_corrente;"

echo "== 4. Restaurando numa segunda instancia (porta 5433) ate $ALVO"
$EXEC sh -c "rm -rf $BASE/restaurado && cp -a $BASE/backup_base $BASE/restaurado"
$EXEC sh -c "cat >> $BASE/restaurado/postgresql.auto.conf" <<CONF
port = 5433
archive_mode = off
restore_command = 'cp $BASE/arquivo_wal/%f %p'
recovery_target_time = '$ALVO'
recovery_target_action = 'promote'
CONF
$EXEC touch "$BASE/restaurado/recovery.signal"
$EXEC pg_ctl -D "$BASE/restaurado" -l "$BASE/restaurado.log" -w start

echo "== 5. Resultado"
$EXEC grep -E "starting point-in-time|redo starts|recovery stopping|archive recovery complete" "$BASE/restaurado.log"
echo "-- instancia ORIGINAL (porta 5432):"
$EXEC psql -c "SELECT * FROM conta_corrente ORDER BY id_conta;"
echo "-- instancia RESTAURADA (porta 5433):"
$EXEC psql -p 5433 -c "SELECT * FROM conta_corrente ORDER BY id_conta;"

echo "Pronto. Para remover o laboratorio: docker rm -f $LAB"
