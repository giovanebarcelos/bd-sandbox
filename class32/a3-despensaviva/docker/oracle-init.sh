#!/bin/bash
# Roda uma vez, na primeira subida do contêiner (gvenzl/oracle-xe executa os .sh de /container-entrypoint-initdb.d).
# Qualquer erro SQL aborta a inicialização; erros de compilação de PL/SQL são conferidos em USER_ERRORS no final.
set -euo pipefail
export NLS_LANG=.AL32UTF8
CONN="$APP_USER/$APP_USER_PASSWORD@//localhost/XEPDB1"

rodar() {
    sqlplus -s -L "$CONN" <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
SET DEFINE OFF
@$1
EXIT
SQL
}

rodar /scripts/oracle/01_ddl.sql
rodar /scripts/oracle/02_inserts.sql
rodar /scripts/procedures/oracle_procedures.sql
rodar /scripts/oracle/04_indices.sql

erros=$(sqlplus -s -L "$CONN" <<SQL
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT COUNT(*) FROM user_errors;
EXIT
SQL
)
if [ "$(echo "$erros" | tr -d '[:space:]')" != "0" ]; then
    echo "ERRO: objetos PL/SQL com erro de compilação" >&2
    sqlplus -s -L "$CONN" <<SQL
SELECT name, line, text FROM user_errors;
EXIT
SQL
    exit 1
fi
echo "DespensaViva: esquema, dados, procedures, triggers e índices criados no Oracle."
