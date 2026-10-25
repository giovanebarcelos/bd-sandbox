"""DespensaViva — aplicação Python que usa os dois bancos (PostgreSQL via psycopg, Oracle via python-oracledb, modo thin).

Mostra o essencial da conexão pela DB-API: conectar, consultar com parâmetros (bind), chamar procedure, tratar o
erro de negócio que o banco devolve e controlar a transação. Por padrão tudo é DESFEITO no final (modo demonstração);
com `--efetivar` as alterações são gravadas.

    python despensa_app.py                 # demonstração nos dois bancos
    python despensa_app.py --so postgres   # só um deles
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date, timedelta
from decimal import Decimal

import oracledb
import psycopg

CODIGO_ERRO = "DESPENSA-"

PG_DSN = os.environ.get("PG_DSN", "host=localhost port=5432 dbname=despensa user=despensa password=despensa_pwd")
ORACLE_USER = os.environ.get("ORACLE_USER", "despensa")
ORACLE_PASSWORD = os.environ.get("ORACLE_PASSWORD", "despensa_pwd")
ORACLE_DSN = os.environ.get("ORACLE_DSN", "localhost:1521/XEPDB1")


class ErroDeNegocio(Exception):
    """Erro DESPENSA-00x devolvido pelas procedures/triggers, já sem o ruído de cada driver."""

    def __init__(self, mensagem: str):
        super().__init__(mensagem)
        self.codigo = mensagem[:12]


def _traduz(erro: Exception) -> Exception:
    texto = str(erro)
    i = texto.find(CODIGO_ERRO)
    return ErroDeNegocio(texto[i:].split("\n")[0].strip()) if i >= 0 else erro


class Despensa:
    """Operações da despensa sobre uma conexão aberta. O SQL difere pouco entre os dois bancos."""

    def __init__(self, conexao, dialeto: str):
        self.con, self.dialeto = conexao, dialeto

    def _executa(self, sql: str, params: tuple = ()):
        """Executa e traduz o erro de negócio.

        PostgreSQL × Oracle: no PostgreSQL um erro DENTRO da transação a deixa "abortada" (todo comando seguinte
        falha até o ROLLBACK); no Oracle só o comando que falhou é desfeito. O SAVEPOINT iguala o comportamento:
        o erro desfaz só este comando e a transação continua.
        """
        cur = self.con.cursor()
        pg = self.dialeto == "postgresql"
        try:
            if pg:
                cur.execute("SAVEPOINT antes_do_comando")
            cur.execute(sql, params)
        except (psycopg.Error, oracledb.Error) as e:
            if pg:
                cur.execute("ROLLBACK TO SAVEPOINT antes_do_comando")
            raise _traduz(e) from e
        return cur

    def saldo(self, insumo_id: int) -> float:
        """Saldo de lotes não vencidos. Parâmetro por bind (:1 no Oracle, %s no PostgreSQL): nunca concatene valores."""
        hoje = "CURRENT_DATE" if self.dialeto == "postgresql" else "TRUNC(SYSDATE)"
        marca = "%s" if self.dialeto == "postgresql" else ":1"
        cur = self._executa(
            f"SELECT COALESCE(SUM(quantidade_atual), 0) FROM lote WHERE insumo_id = {marca} AND data_validade >= {hoje}",
            (insumo_id,))
        return float(cur.fetchone()[0])

    def registrar_entrada(self, insumo_id: int, fornecedor_id: int, quantidade: float, validade: date) -> None:
        if self.dialeto == "postgresql":
            # Decimal, não float: float vai como double precision e o CALL não encontra a procedure de parâmetro NUMERIC.
            self._executa("CALL registrar_entrada_lote(%s, %s, %s, %s)",
                          (insumo_id, fornecedor_id, Decimal(str(quantidade)), validade))
        else:
            cur = self.con.cursor()
            try:
                cur.callproc("registrar_entrada_lote", [insumo_id, fornecedor_id, quantidade, validade])
            except oracledb.Error as e:
                raise _traduz(e) from e

    def consumir(self, insumo_id: int, quantidade: float, motivo: str = "Consumo") -> None:
        if self.dialeto == "postgresql":
            self._executa("CALL consumir_insumo(%s, %s, %s)", (insumo_id, Decimal(str(quantidade)), motivo))
        else:
            cur = self.con.cursor()
            try:
                cur.callproc("consumir_insumo", [insumo_id, quantidade, motivo])
            except oracledb.Error as e:
                raise _traduz(e) from e

    def lotes(self, insumo_id: int) -> list[tuple[int, float]]:
        marca = "%s" if self.dialeto == "postgresql" else ":1"
        cur = self._executa(f"SELECT lote_id, quantidade_atual FROM lote WHERE insumo_id = {marca} ORDER BY lote_id", (insumo_id,))
        return [(int(a), float(b)) for a, b in cur.fetchall()]


def conectar_postgres():
    return psycopg.connect(PG_DSN)          # autocommit desligado: a transação é nossa


def conectar_oracle():
    return oracledb.connect(user=ORACLE_USER, password=ORACLE_PASSWORD, dsn=ORACLE_DSN)


def demonstracao(d: Despensa, efetivar: bool) -> list[str]:
    """Roteiro único, igual nos dois bancos. Devolve as linhas impressas (para os testes conferirem)."""
    saida: list[str] = []

    def dizer(texto: str) -> None:
        saida.append(texto)
        print(texto)

    TOMATE, FORNECEDOR = 3, 2
    dizer(f"[{d.dialeto}] saldo de tomate antes: {d.saldo(TOMATE):g} kg")
    d.consumir(TOMATE, 6, "Sopa do almoço")
    dizer(f"[{d.dialeto}] depois de consumir 6 kg (FEFO): saldo {d.saldo(TOMATE):g} kg, lotes {d.lotes(TOMATE)}")
    try:
        d.consumir(TOMATE, 100)
    except ErroDeNegocio as e:
        dizer(f"[{d.dialeto}] pedido de 100 kg recusado: {e}")
    try:
        d.registrar_entrada(TOMATE, FORNECEDOR, 5, date.today() + timedelta(days=2))
    except ErroDeNegocio as e:
        dizer(f"[{d.dialeto}] entrada com validade em 2 dias recusada: {e}")
    d.registrar_entrada(TOMATE, FORNECEDOR, 5, date.today() + timedelta(days=3))
    dizer(f"[{d.dialeto}] entrada com validade em 3 dias aceita: saldo {d.saldo(TOMATE):g} kg")
    if efetivar:
        d.con.commit()
        dizer(f"[{d.dialeto}] alterações GRAVADAS (commit)")
    else:
        d.con.rollback()
        dizer(f"[{d.dialeto}] modo demonstração: tudo DESFEITO (rollback); saldo volta a {d.saldo(TOMATE):g} kg")
    return saida


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--so", choices=["postgres", "oracle"], help="usa só um dos bancos")
    ap.add_argument("--efetivar", action="store_true", help="grava as alterações (padrão: desfaz)")
    args = ap.parse_args(argv)
    if args.so != "oracle":
        with conectar_postgres() as con:
            demonstracao(Despensa(con, "postgresql"), args.efetivar)
    if args.so != "postgres":
        with conectar_oracle() as con:
            demonstracao(Despensa(con, "oracle"), args.efetivar)
    return 0


if __name__ == "__main__":
    sys.exit(main())
