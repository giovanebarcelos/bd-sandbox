#!/bin/bash
# BD2702-init-primario.sh
# Aula 27 - executado UMA vez pelo container pg-primario, na criacao do banco
# (pasta /docker-entrypoint-initdb.d da imagem oficial do PostgreSQL).
#
# 1. cria o usuario "replicador", so com o privilegio de replicacao
# 2. libera, no pg_hba.conf, conexoes de replicacao vindas da rede Docker
set -e

psql -v ON_ERROR_STOP=1 -U postgres <<'SQL'
CREATE ROLE replicador WITH REPLICATION LOGIN PASSWORD 'replicador';
SQL

echo "host  replication  replicador  all  scram-sha-256" >> "$PGDATA/pg_hba.conf"
