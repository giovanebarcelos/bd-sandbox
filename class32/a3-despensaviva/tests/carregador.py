"""Carrega os scripts SQL do projeto num banco VAZIO, pela própria aplicação (sem psql/sqlplus).

Usado pelo teste de mutação (`scripts/mutacao.py`), que precisa recriar o esquema várias vezes. Na subida normal do
Docker Compose quem carrega os scripts são `docker/postgres-init.sh` e `docker/oracle-init.sh`.
Formato dos arquivos Oracle: instruções SQL terminam em `;`; blocos PL/SQL terminam em uma linha só com `/`.
"""
from __future__ import annotations

import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ORDEM_POSTGRES = ["postgresql/01_ddl.sql", "postgresql/02_inserts.sql", "procedures/postgresql_procedures.sql", "postgresql/04_indices.sql"]
ORDEM_ORACLE = ["oracle/01_ddl.sql", "oracle/02_inserts.sql", "procedures/oracle_procedures.sql", "oracle/04_indices.sql"]


def carregar_postgres(con, raiz: Path = RAIZ) -> None:
    """O PostgreSQL aceita o arquivo inteiro numa chamada (protocolo simples, sem parâmetros)."""
    con.autocommit = True
    cur = con.cursor()
    for arq in ORDEM_POSTGRES:
        cur.execute((raiz / arq).read_text(encoding="utf-8"))


_PLSQL = re.compile(r"^\s*(BEGIN|DECLARE|CREATE\s+(OR\s+REPLACE\s+)?(PROCEDURE|FUNCTION|TRIGGER|PACKAGE|TYPE))\b", re.I)


def instrucoes_oracle(texto: str) -> list[str]:
    """Divide um script Oracle em instruções, na ordem: PL/SQL termina numa linha só com `/`; o resto termina em `;`."""
    saida, buf = [], []

    def fecha() -> None:
        bloco = "\n".join(buf).strip()
        buf.clear()
        if bloco.endswith(";") and not _PLSQL.match(bloco):
            bloco = bloco[:-1].rstrip()
        if bloco and bloco.upper() != "COMMIT":
            saida.append(bloco)

    for linha in texto.split("\n"):
        if linha.lstrip().startswith("--"):
            continue
        if linha.strip() == "/":
            fecha()
            continue
        if not linha.strip() and not buf:
            continue
        buf.append(linha)
        if linha.rstrip().endswith(";") and not _PLSQL.match("\n".join(buf)):
            fecha()
    fecha()
    return saida


def carregar_oracle(con, raiz: Path = RAIZ) -> None:
    cur = con.cursor()
    for arq in ORDEM_ORACLE:
        for instrucao in instrucoes_oracle((raiz / arq).read_text(encoding="utf-8")):
            cur.execute(instrucao)
    con.commit()
    cur.execute("SELECT COUNT(*) FROM user_errors")
    assert cur.fetchone()[0] == 0, "objetos PL/SQL com erro de compilação"
