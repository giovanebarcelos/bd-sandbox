#!/bin/bash
# Roda uma vez, na primeira subida do contêiner (docker-entrypoint-initdb.d). Qualquer erro aborta a inicialização.
set -euo pipefail
PSQL="psql -v ON_ERROR_STOP=1 --username $POSTGRES_USER --dbname $POSTGRES_DB"
$PSQL -f /scripts/postgresql/01_ddl.sql
$PSQL -f /scripts/postgresql/02_inserts.sql
$PSQL -f /scripts/procedures/postgresql_procedures.sql
$PSQL -f /scripts/postgresql/04_indices.sql
