#!/usr/bin/env python3
"""Teste de mutação dos SCRIPTS SQL: aplica UM defeito por vez, recria o esquema do zero e roda a suíte.

Para cada mutante, em cada banco: cria um banco/esquema descartável, carrega os scripts mutados (tests/carregador.py),
roda `pytest -x` apontando para ele e apaga tudo. Se nenhum teste fica vermelho, o mutante SOBREVIVEU.

Variáveis: PG_ADMIN_DSN (superusuário do PostgreSQL), ORACLE_ADMIN_USER/ORACLE_ADMIN_PASSWORD/ORACLE_DSN (SYSTEM).
Uso: python scripts/mutacao.py [--so postgresql|oracle]
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import oracledb
import psycopg

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tests"))
from carregador import carregar_oracle, carregar_postgres  # noqa: E402

PG_ADMIN = os.environ.get("PG_ADMIN_DSN", "host=localhost port=5432 dbname=postgres user=despensa password=despensa_pwd")
ORA_ADMIN = dict(user=os.environ.get("ORACLE_ADMIN_USER", "system"), password=os.environ.get("ORACLE_ADMIN_PASSWORD", "bd_admin"),
                 dsn=os.environ.get("ORACLE_DSN", "localhost:1521/XEPDB1"))


def ora(txt: str) -> str:
    """Traduz um trecho de SQL do PostgreSQL para o dialeto Oracle quando a mudança é só a data de hoje."""
    return txt.replace("CURRENT_DATE", "TRUNC(SYSDATE)")


# (id, descrição, arquivo-chave, (original_pg, mutante_pg) | None, (original_oracle, mutante_oracle) | None)
P, D, C = "procedimentos", "ddl", "consultas"
MUTANTES = [
    ("M01", "entrada aceita validade de 2 dias (procedure)", P, ("p_validade < CURRENT_DATE + 3", "p_validade < CURRENT_DATE + 2"), ("p_validade < TRUNC(SYSDATE) + 3", "p_validade < TRUNC(SYSDATE) + 2")),
    ("M02", "trigger de validade aceita 2 dias", P, ("NEW.data_validade < NEW.data_entrada + 3", "NEW.data_validade < NEW.data_entrada + 2"), (":NEW.data_validade < :NEW.data_entrada + 3", ":NEW.data_validade < :NEW.data_entrada + 2")),
    ("M03", "FEFO invertido (vence DEPOIS sai primeiro)", P, ("ORDER BY data_validade, lote_id\n                FOR UPDATE", "ORDER BY data_validade DESC, lote_id\n                FOR UPDATE"), ("ORDER BY data_validade, lote_id\n           FOR UPDATE", "ORDER BY data_validade DESC, lote_id\n           FOR UPDATE")),
    ("M04", "lote que vence HOJE passa a ser tratado como vencido (laço)", P, ("data_validade >= CURRENT_DATE AND quantidade_atual > 0", "data_validade > CURRENT_DATE AND quantidade_atual > 0"), ("data_validade >= TRUNC(SYSDATE) AND quantidade_atual > 0", "data_validade > TRUNC(SYSDATE) AND quantidade_atual > 0")),
    ("M05", "laço volta a visitar lote zerado", P, ("data_validade >= CURRENT_DATE AND quantidade_atual > 0", "data_validade >= CURRENT_DATE"), ("data_validade >= TRUNC(SYSDATE) AND quantidade_atual > 0", "data_validade >= TRUNC(SYSDATE)")),
    ("M06", "some a conferência final (DEF-BD-01)", P, ("IF v_restante > 0 THEN", "IF FALSE THEN"), ("IF v_restante > 0 THEN", "IF 1 = 0 THEN")),
    ("M07", "saldo exatamente igual ao pedido é recusado", P, ("IF v_saldo < p_quantidade THEN", "IF v_saldo <= p_quantidade THEN"), ("IF v_saldo < p_quantidade THEN", "IF v_saldo <= p_quantidade THEN")),
    ("M08", "some o FOR UPDATE (sem lock de linha)", P, ("ORDER BY data_validade, lote_id\n                FOR UPDATE", "ORDER BY data_validade, lote_id"), None),
    ("M09", "auditoria grava o saldo novo no lugar do antigo", P, ("OLD.quantidade_atual, NEW.quantidade_atual, current_user", "NEW.quantidade_atual, NEW.quantidade_atual, current_user"), (":OLD.quantidade_atual, :NEW.quantidade_atual, USER", ":NEW.quantidade_atual, :NEW.quantidade_atual, USER")),
    ("M10", "auditoria dispara em qualquer UPDATE", P, ("AFTER INSERT OR UPDATE OF quantidade_atual ON lote", "AFTER INSERT OR UPDATE ON lote"), ("AFTER INSERT OR UPDATE OF quantidade_atual ON lote", "AFTER INSERT OR UPDATE ON lote")),
    ("M11", "CHECK deixa o saldo passar da quantidade inicial", D, ("CHECK (quantidade_atual >= 0 AND quantidade_atual <= quantidade_inicial)", "CHECK (quantidade_atual >= 0)"), ("CHECK (quantidade_atual >= 0 AND quantidade_atual <= quantidade_inicial)", "CHECK (quantidade_atual >= 0)")),
    ("M12", "apagar receita deixa de levar os ingredientes", D, ("REFERENCES receita (receita_id) ON DELETE CASCADE", "REFERENCES receita (receita_id) ON DELETE RESTRICT"), ("REFERENCES receita (receita_id) ON DELETE CASCADE", "REFERENCES receita (receita_id)")),
    ("M13", "CHECK de tipo de fornecedor aceita 'OUTRO'", D, ("CHECK (tipo IN ('DOADOR', 'COMERCIO'))", "CHECK (tipo IN ('DOADOR', 'COMERCIO', 'OUTRO'))"), None),
    ("M14", "some a UNIQUE do nome do insumo", D, ("    CONSTRAINT uk_insumo_nome   UNIQUE (nome),\n", ""), None),
    ("M15", "Q01 trata o lote que vence hoje como vencido", C, ("l.data_validade >= CURRENT_DATE\n GROUP BY i.insumo_id, i.nome, i.unidade", "l.data_validade > CURRENT_DATE\n GROUP BY i.insumo_id, i.nome, i.unidade"), None),
    ("M16", "Q02 janela de 8 dias em vez de 7", C, ("CURRENT_DATE + 7", "CURRENT_DATE + 8"), None),
    ("M17", "Q03 mostra só os 4 primeiros", C, ("WHERE t.ranking <= 5", "WHERE t.ranking <= 4"), None),
    ("M18", "Q04 vira 'insumos já consumidos'", C, ("WHERE NOT EXISTS (SELECT 1\n                     FROM movimentacao m", "WHERE EXISTS (SELECT 1\n                     FROM movimentacao m"), None),
    ("M19", "Q05 acumula sem separar por insumo", C, ("OVER (PARTITION BY i.insumo_id ORDER BY", "OVER (ORDER BY"), None),
    ("M20", "Q06 alerta também quando saldo = mínimo", C, ("< i.estoque_minimo\n ORDER BY i.nome;", "<= i.estoque_minimo\n ORDER BY i.nome;"), None),
    ("M21", "Q09 calcula para 40 porções em vez de 50", C, ("ri.quantidade_por_porcao * 50", "ri.quantidade_por_porcao * 40"), None),
    ("M22", "Q10 conta também o lote que vence hoje como vencido", C, ("l.data_validade < CURRENT_DATE AND", "l.data_validade <= CURRENT_DATE AND"), None),
    ("M23", "Q03 troca RANK() por ROW_NUMBER()", C, ("RANK() OVER (ORDER BY", "ROW_NUMBER() OVER (ORDER BY"), None),
]
# Mutantes que sobrevivem POR MOTIVO CONHECIDO (não são lacuna de teste). Cada um precisa de justificativa.
EQUIVALENTES = {
    "M01": "o trigger trg_lote_validade repete a regra: a procedure deixa passar, o trigger barra com a MESMA mensagem (defesa em profundidade)",
}
ARQUIVOS = {  # chave -> (arquivo PostgreSQL, arquivo Oracle)
    P: ("procedures/postgresql_procedures.sql", "procedures/oracle_procedures.sql"),
    D: ("postgresql/01_ddl.sql", "oracle/01_ddl.sql"),
    C: ("postgresql/03_consultas.sql", "oracle/03_consultas.sql"),
}


def copia_mutada(banco: str, chave: str, original: str, mutante: str) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="mutante_"))
    shutil.copytree(RAIZ, tmp / "proj", ignore=shutil.ignore_patterns(".git", "__pycache__", "target", ".pytest_cache"))
    alvo = tmp / "proj" / ARQUIVOS[chave][0 if banco == "postgresql" else 1]
    texto = alvo.read_text(encoding="utf-8")
    if texto.count(original) != 1:
        raise SystemExit(f"{alvo.name}: o trecho aparece {texto.count(original)} vez(es): {original[:60]!r}")
    alvo.write_text(texto.replace(original, mutante), encoding="utf-8")
    return tmp / "proj"


def roda_pytest(proj: Path, banco: str, env_extra: dict) -> tuple[bool, str]:
    r = subprocess.run([sys.executable, "-m", "pytest", "-x", "-q", "-p", "no:cacheprovider", "-k", banco, "tests"],
                       cwd=proj, env={**os.environ, **env_extra, "PYTHONDONTWRITEBYTECODE": "1"}, capture_output=True, text=True, timeout=600)
    m = re.search(r"^FAILED \S*?([\w.]+\.py::\w+)", r.stdout, flags=re.M)
    return r.returncode == 0, (m.group(1) if m else "—")


def testa_postgres(mid: str, original: str, mutante: str, chave: str) -> tuple[bool, str]:
    nome = f"mut_{mid.lower()}"
    adm = psycopg.connect(PG_ADMIN, autocommit=True)
    adm.execute(f"DROP DATABASE IF EXISTS {nome} WITH (FORCE)")
    adm.execute(f"CREATE DATABASE {nome}")
    proj = copia_mutada("postgresql", chave, original, mutante)
    try:
        info = psycopg.conninfo.conninfo_to_dict(PG_ADMIN)
        info["dbname"] = nome
        dsn = psycopg.conninfo.make_conninfo(**info)
        try:
            with psycopg.connect(dsn) as con:
                carregar_postgres(con, proj)
        except Exception as e:                        # o mutante nem carrega: contado como detectado
            return False, f"não carrega: {str(e).splitlines()[0][:60]}"
        return roda_pytest(proj, "postgresql", {"PG_DSN": dsn})
    finally:
        adm.execute(f"DROP DATABASE IF EXISTS {nome} WITH (FORCE)")
        shutil.rmtree(proj.parent, ignore_errors=True)


def testa_oracle(mid: str, original: str, mutante: str, chave: str) -> tuple[bool, str]:
    nome = f"mut_{mid.lower()}"
    adm = oracledb.connect(**ORA_ADMIN)
    cur = adm.cursor()
    cur.execute("SELECT COUNT(*) FROM all_users WHERE username = :1", [nome.upper()])
    if cur.fetchone()[0]:
        cur.execute(f"DROP USER {nome} CASCADE")
    cur.execute(f"CREATE USER {nome} IDENTIFIED BY mut_pwd QUOTA UNLIMITED ON USERS")
    cur.execute(f"GRANT CONNECT, RESOURCE TO {nome}")
    proj = copia_mutada("oracle", chave, original, mutante)
    try:
        try:
            with oracledb.connect(user=nome, password="mut_pwd", dsn=ORA_ADMIN["dsn"]) as con:
                carregar_oracle(con, proj)
        except Exception as e:
            return False, f"não carrega: {str(e).splitlines()[0][:60]}"
        return roda_pytest(proj, "oracle", {"ORACLE_USER": nome, "ORACLE_PASSWORD": "mut_pwd"})
    finally:
        cur.execute(f"DROP USER {nome} CASCADE")
        adm.close()
        shutil.rmtree(proj.parent, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--so", choices=["postgresql", "oracle"])
    ap.add_argument("--mutantes", help="lista de ids separados por vírgula (padrão: todos)")
    args = ap.parse_args()
    escolhidos = set(args.mutantes.split(",")) if args.mutantes else None
    linhas, sobreviventes = [], []
    total = detectados = equivalentes = 0
    for mid, desc, chave, pg, orc in MUTANTES:
        if escolhidos and mid not in escolhidos:
            continue
        celulas = []
        for banco, par, fn in (("postgresql", pg, testa_postgres), ("oracle", orc or (pg and chave == C and (ora(pg[0]), ora(pg[1]))) or None, testa_oracle)):
            if args.so and args.so != banco or par is None:
                celulas.append("n/a")
                continue
            total += 1
            sobreviveu, quem = fn(mid, par[0], par[1], chave)
            if sobreviveu and mid in EQUIVALENTES:
                equivalentes += 1
                celulas.append("equivalente*")
            elif sobreviveu:
                sobreviventes.append(f"{mid}/{banco}")
                celulas.append("**SOBREVIVEU**")
            else:
                detectados += 1
                celulas.append(f"detectado (`{quem}`)")
        linhas.append(f"| {mid} | {desc} | {celulas[0]} | {celulas[1]} |")
        print(linhas[-1], flush=True)
    print("\n| # | Mutação | PostgreSQL | Oracle |\n|---|---|---|---|")
    print("\n".join(linhas))
    for mid, motivo in EQUIVALENTES.items():
        print(f"\n\\* {mid} equivalente: {motivo}")
    print(f"\nExecuções: {total} · detectadas: {detectados} · equivalentes: {equivalentes} · sobreviventes: {len(sobreviventes)} {sobreviventes}")
    return 1 if sobreviventes else 0


if __name__ == "__main__":
    sys.exit(main())
