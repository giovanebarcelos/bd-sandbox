"""Fixtures: uma conexão por banco (PostgreSQL e Oracle) e um adaptador mínimo para escrever o teste UMA vez.

Cada teste roda numa transação que é DESFEITA no final (rollback): os dados de `02_inserts.sql` voltam sempre ao estado
original, e as procedures, que não fazem COMMIT, podem ser chamadas à vontade. Nenhum teste executa DDL (no Oracle, DDL
faz COMMIT implícito e não dá para desfazer).
"""
from __future__ import annotations

import os
import re
from pathlib import Path

from decimal import Decimal

import oracledb
import psycopg
import pytest

RAIZ = Path(__file__).resolve().parent.parent
PG_DSN = os.environ.get("PG_DSN", "host=localhost port=5432 dbname=despensa user=despensa password=despensa_pwd")
ORACLE = dict(user=os.environ.get("ORACLE_USER", "despensa"), password=os.environ.get("ORACLE_PASSWORD", "despensa_pwd"),
              dsn=os.environ.get("ORACLE_DSN", "localhost:1521/XEPDB1"))

DbError = (psycopg.Error, oracledb.Error)


class Banco:
    """Adaptador: SQL com `?` como marcador vira %s (PostgreSQL) ou :1, :2... (Oracle)."""

    def __init__(self, nome: str, con):
        self.nome, self.con = nome, con
        self.pasta = RAIZ / nome
        self.hoje = "CURRENT_DATE" if nome == "postgresql" else "TRUNC(SYSDATE)"

    def _sql(self, sql: str) -> str:
        if self.nome == "postgresql":
            return sql.replace("?", "%s")
        n = iter(range(1, 100))
        return re.sub(r"\?", lambda _: f":{next(n)}", sql)

    def consulta(self, sql: str, *params) -> list[tuple]:
        cur = self.con.cursor()
        cur.execute(self._sql(sql), params)
        return [tuple(float(v) if hasattr(v, "as_tuple") else v for v in linha) for linha in cur.fetchall()]

    def um(self, sql: str, *params):
        return self.consulta(sql, *params)[0][0]

    def executa(self, sql: str, *params) -> None:
        self.con.cursor().execute(self._sql(sql), params)

    def chama(self, procedure: str, *args) -> None:
        cur = self.con.cursor()
        if self.nome == "postgresql":
            # float do Python vira double precision no servidor, e CALL não acha a procedure de parâmetro NUMERIC:
            # para NUMERIC, mande Decimal.
            args = tuple(Decimal(str(a)) if isinstance(a, float) else a for a in args)
            cur.execute(f"CALL {procedure}({', '.join(['%s'] * len(args))})", args)
        else:
            cur.callproc(procedure, list(args))

    def rollback(self) -> None:
        self.con.rollback()


def nova_conexao(nome: str) -> Banco:
    """Conexão independente (outra sessão), para os testes de concorrência."""
    return Banco(nome, psycopg.connect(PG_DSN) if nome == "postgresql" else oracledb.connect(**ORACLE))


@pytest.fixture(scope="session", params=["postgresql", "oracle"])
def conexao(request):
    banco = nova_conexao(request.param)
    yield banco
    banco.con.close()


@pytest.fixture
def db(conexao):
    """O mesmo teste roda nos dois bancos; o rollback no final devolve os dados ao estado original."""
    yield conexao
    conexao.rollback()


def consultas_do_arquivo(banco: Banco) -> dict[str, str]:
    """Lê `03_consultas.sql`: blocos iniciados por `-- @Qnn`, cada um terminado em `;`."""
    texto = (banco.pasta / "03_consultas.sql").read_text(encoding="utf-8")
    partes = re.split(r"^-- @(Q\d\d) .*$", texto, flags=re.M)
    return {partes[i]: partes[i + 1].strip().rstrip(";").strip() for i in range(1, len(partes), 2)}
