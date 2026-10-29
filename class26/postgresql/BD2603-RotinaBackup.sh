#!/usr/bin/env bash
# ============================================================================
# BD2603-RotinaBackup.sh
# Aula 26 - Tutorial passo a passo: rotina de backup logico com verificacao
#
# Roda no computador (fora do container) e faz, para um banco do PostgreSQL
# que esta no container "postgres" do ambiente Docker da disciplina:
#   1. pg_dump em formato custom, com data e hora no nome do arquivo
#   2. pg_dumpall --globals-only (papeis/roles), que o pg_dump nao leva
#   3. copia os arquivos para fora do container (pasta ./backups)
#   4. gera o checksum SHA-256 de cada arquivo
#   5. verifica se o dump pode ser lido (pg_restore --list)
#   6. apaga os backups com mais de RETENCAO_DIAS dias
#
# Uso:   bash BD2603-RotinaBackup.sh [banco]          (padrao: aula26)
# Vars:  CONTAINER=postgres  DESTINO=./backups  RETENCAO_DIAS=7
# Agendar (Linux, todo dia as 2h):
#   0 2 * * * cd /caminho && bash BD2603-RotinaBackup.sh aula26 >> backup.log 2>&1
# ============================================================================
set -euo pipefail

BANCO="${1:-aula26}"
CONTAINER="${CONTAINER:-postgres}"
DESTINO="${DESTINO:-./backups}"
RETENCAO_DIAS="${RETENCAO_DIAS:-7}"
CARIMBO=$(date +%Y%m%d_%H%M%S)
DUMP="${BANCO}_${CARIMBO}.dump"
GLOBAIS="globais_${CARIMBO}.sql"

mkdir -p "$DESTINO"
echo "== $(date '+%F %T') backup do banco $BANCO (container $CONTAINER)"

echo "-- 1. pg_dump (formato custom)"
docker exec "$CONTAINER" pg_dump -U postgres -d "$BANCO" -F c -f "/tmp/$DUMP"

echo "-- 2. pg_dumpall --globals-only"
docker exec "$CONTAINER" pg_dumpall -U postgres --globals-only -f "/tmp/$GLOBAIS"

echo "-- 3. copia para fora do container"
docker cp "$CONTAINER:/tmp/$DUMP"    "$DESTINO/$DUMP"
docker cp "$CONTAINER:/tmp/$GLOBAIS" "$DESTINO/$GLOBAIS"
docker exec "$CONTAINER" rm -f "/tmp/$DUMP" "/tmp/$GLOBAIS"

echo "-- 4. checksum SHA-256"
( cd "$DESTINO" && sha256sum "$DUMP" "$GLOBAIS" > "${BANCO}_${CARIMBO}.sha256" && cat "${BANCO}_${CARIMBO}.sha256" )

echo "-- 5. verificacao: o dump pode ser lido?"
docker cp "$DESTINO/$DUMP" "$CONTAINER:/tmp/verifica.dump"
OBJETOS=$(docker exec "$CONTAINER" pg_restore --list /tmp/verifica.dump | grep -vc '^;')
docker exec "$CONTAINER" rm -f /tmp/verifica.dump
echo "   $OBJETOS objetos no indice do dump"

echo "-- 6. retencao: apaga backups com mais de $RETENCAO_DIAS dias"
find "$DESTINO" -maxdepth 1 -type f \( -name "${BANCO}_*" -o -name 'globais_*' \) \
     -mtime +"$RETENCAO_DIAS" -print -delete

echo "== concluido: $DESTINO/$DUMP ($(du -h "$DESTINO/$DUMP" | cut -f1))"
ls -1 "$DESTINO"
