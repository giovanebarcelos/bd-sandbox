#!/usr/bin/env python3
"""Mede o efeito dos 3 índices (Etapa 5): carga em massa, plano ANTES, CREATE INDEX, plano DEPOIS, nos dois bancos.

Cada banco usa um esquema descartável (despensa_perf), então os dados de exemplo e os testes não são afetados.
Gera `performance/explain_antes_depois.txt` (planos reais) e imprime a tabela de tempos.

Variáveis: PG_ADMIN_DSN, ORACLE_ADMIN_USER, ORACLE_ADMIN_PASSWORD, ORACLE_DSN. Uso: python performance/medir.py
"""
from __future__ import annotations

import os
import statistics
import sys
import time
from pathlib import Path

import oracledb
import psycopg

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tests"))
from carregador import instrucoes_oracle  # noqa: E402

PG_ADMIN = os.environ.get("PG_ADMIN_DSN", "host=localhost port=5432 dbname=postgres user=despensa password=despensa_pwd")
ORA_ADMIN = dict(user=os.environ.get("ORACLE_ADMIN_USER", "system"), password=os.environ.get("ORACLE_ADMIN_PASSWORD", "bd_admin"),
                 dsn=os.environ.get("ORACLE_DSN", "localhost:1521/XEPDB1"))
REPETICOES = 100

CONSULTAS = {
    "FEFO: lotes de um insumo por validade": (
        "SELECT lote_id, data_validade, quantidade_atual FROM lote "
        "WHERE insumo_id = 500 AND data_validade >= {hoje} AND quantidade_atual > 0 ORDER BY data_validade, lote_id"),
    "FK: movimentações de um lote": "SELECT COUNT(*), SUM(quantidade) FROM movimentacao WHERE lote_id = 123456",
}


class Motor:
    nome = ""
    hoje = ""

    def __init__(self):
        self.cur = None

    def mede(self, sql: str) -> float:
        """Mediana, em ms, de REPETICOES execuções (a primeira, que aquece o cache, é descartada)."""
        def uma() -> float:
            inicio = time.perf_counter()
            self.cur.execute(sql)
            self.cur.fetchall()
            return (time.perf_counter() - inicio) * 1000
        uma()
        return statistics.median(uma() for _ in range(REPETICOES))


class Postgres(Motor):
    nome, hoje = "PostgreSQL", "CURRENT_DATE"

    def preparar(self) -> str:
        self.adm = psycopg.connect(PG_ADMIN, autocommit=True)
        self.adm.execute("DROP DATABASE IF EXISTS despensa_perf WITH (FORCE)")
        self.adm.execute("CREATE DATABASE despensa_perf")
        info = psycopg.conninfo.conninfo_to_dict(PG_ADMIN)
        info["dbname"] = "despensa_perf"
        self.con = psycopg.connect(psycopg.conninfo.make_conninfo(**info), autocommit=True)
        self.cur = self.con.cursor()
        self.cur.execute((RAIZ / "postgresql/01_ddl.sql").read_text(encoding="utf-8"))
        inicio = time.perf_counter()
        self.cur.execute((RAIZ / "performance/postgresql_carga.sql").read_text(encoding="utf-8"))
        seg = time.perf_counter() - inicio
        self.cur.execute("SELECT (SELECT COUNT(*) FROM lote), (SELECT COUNT(*) FROM movimentacao)")
        return "{:,} lotes e {:,} movimentações carregados em {:.1f} s".format(*self.cur.fetchone(), seg).replace(",", ".")

    def plano(self, sql: str) -> str:
        self.cur.execute("EXPLAIN (ANALYZE, BUFFERS) " + sql)
        return "\n".join(l[0] for l in self.cur.fetchall())

    def criar_indices(self) -> None:
        self.cur.execute((RAIZ / "postgresql/04_indices.sql").read_text(encoding="utf-8"))
        self.cur.execute("ANALYZE")

    def limpar(self) -> None:
        self.con.close()
        self.adm.execute("DROP DATABASE IF EXISTS despensa_perf WITH (FORCE)")


class Oracle(Motor):
    nome, hoje = "Oracle", "TRUNC(SYSDATE)"

    def preparar(self) -> str:
        self.adm = oracledb.connect(**ORA_ADMIN)
        a = self.adm.cursor()
        a.execute("SELECT COUNT(*) FROM all_users WHERE username = 'DESPENSA_PERF'")
        if a.fetchone()[0]:
            a.execute("DROP USER despensa_perf CASCADE")
        a.execute("CREATE USER despensa_perf IDENTIFIED BY perf_pwd QUOTA UNLIMITED ON USERS")
        a.execute("GRANT CONNECT, RESOURCE TO despensa_perf")
        self.con = oracledb.connect(user="despensa_perf", password="perf_pwd", dsn=ORA_ADMIN["dsn"])
        self.cur = self.con.cursor()
        for instrucao in instrucoes_oracle((RAIZ / "oracle/01_ddl.sql").read_text(encoding="utf-8")):
            self.cur.execute(instrucao)
        inicio = time.perf_counter()
        for instrucao in instrucoes_oracle((RAIZ / "performance/oracle_carga.sql").read_text(encoding="utf-8")):
            self.cur.execute(instrucao)
        seg = time.perf_counter() - inicio
        self.cur.execute("SELECT (SELECT COUNT(*) FROM lote), (SELECT COUNT(*) FROM movimentacao) FROM dual")
        return "{:,} lotes e {:,} movimentações carregados em {:.1f} s".format(*self.cur.fetchone(), seg).replace(",", ".")

    def plano(self, sql: str) -> str:
        self.cur.execute("EXPLAIN PLAN FOR " + sql)
        self.cur.execute("SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +PREDICATE'))")
        return "\n".join(l[0] for l in self.cur.fetchall())

    def criar_indices(self) -> None:
        for instrucao in instrucoes_oracle((RAIZ / "oracle/04_indices.sql").read_text(encoding="utf-8")):
            self.cur.execute(instrucao)
        self.cur.execute("BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;")

    def limpar(self) -> None:
        self.con.close()
        self.adm.cursor().execute("DROP USER despensa_perf CASCADE")
        self.adm.close()


def main() -> int:
    txt: list[str] = ["DespensaViva — planos e tempos ANTES e DEPOIS dos índices (gerado por performance/medir.py)", ""]
    tabela = ["| Banco | Consulta | Sem índice | Com índice | Ganho |", "|---|---|---:|---:|---:|"]
    for motor in (Postgres(), Oracle()):
        txt += ["=" * 100, f"{motor.nome}", "=" * 100, motor.preparar(), ""]
        antes = {}
        for nome, modelo in CONSULTAS.items():
            sql = modelo.format(hoje=motor.hoje)
            antes[nome] = (motor.mede(sql), motor.plano(sql))
        motor.criar_indices()
        for nome, modelo in CONSULTAS.items():
            sql = modelo.format(hoje=motor.hoje)
            t_antes, p_antes = antes[nome]
            t_depois, p_depois = motor.mede(sql), motor.plano(sql)
            txt += [f"--- {nome}", sql, "", f">>> ANTES dos índices (mediana de {REPETICOES} execuções: {t_antes:.2f} ms)", p_antes, "",
                    f">>> DEPOIS dos índices (mediana de {REPETICOES} execuções: {t_depois:.2f} ms)", p_depois, ""]
            tabela.append(f"| {motor.nome} | {nome} | {t_antes:.2f} ms | {t_depois:.2f} ms | {100 * (1 - t_depois / t_antes):.1f}% ({t_antes / t_depois:.0f}x) |")
        motor.limpar()
    (RAIZ / "performance/explain_antes_depois.txt").write_text("\n".join(txt) + "\n", encoding="utf-8")
    print("\n".join(tabela))
    return 0


if __name__ == "__main__":
    sys.exit(main())
