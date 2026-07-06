#!/usr/bin/env python3
"""
BD1201-DmlExemplo.py
Aula 12 - DML via DB-API: INSERT / UPDATE / DELETE / upsert (Oracle e PostgreSQL)
Estudo de caso: BookHub - livraria online
Prof. Giovane Barcelos

Equivalente Python do BD1201-DmlExemplo.java: mesma logica, mesmas operacoes,
usando python-oracledb (Oracle) e psycopg2 (PostgreSQL). O SQL parametrizado e
quase identico entre os dois bancos, exceto pelo comando de upsert
(MERGE x INSERT ... ON CONFLICT) e pelo marcador de parametro (":1" no Oracle
vs "%s" no psycopg2).

Dependencias:
    pip install oracledb psycopg2-binary
"""

from datetime import date

import oracledb
import psycopg2

ORACLE_DSN = "localhost:1521/XEPDB1"
POSTGRES_DSN = dict(host="localhost", port=5432, dbname="bookhub")
USER = "bookhub_user"
PASSWORD = "bookhub_pass"


def inserir_cliente_oracle(conn, nome, email, telefone, data_cadastro):
    """INSERT com RETURNING para recuperar a chave gerada (identity) - Oracle."""
    with conn.cursor() as cur:
        novo_id = cur.var(int)
        cur.execute(
            """
            INSERT INTO Cliente (nome, email, telefone, data_cadastro)
            VALUES (:1, :2, :3, :4)
            RETURNING cliente_id INTO :5
            """,
            [nome, email, telefone, data_cadastro, novo_id],
        )
        return novo_id.getvalue()[0]


def inserir_cliente_postgres(conn, nome, email, telefone, data_cadastro):
    """INSERT com RETURNING para recuperar a chave gerada (identity) - PostgreSQL."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO Cliente (nome, email, telefone, data_cadastro)
            VALUES (%s, %s, %s, %s)
            RETURNING cliente_id
            """,
            (nome, email, telefone, data_cadastro),
        )
        return cur.fetchone()[0]


def reajustar_preco_livros_fisicos(conn, percentual, marcador):
    """UPDATE parametrizado - a unica diferenca entre bancos e o marcador de bind."""
    sql = f"UPDATE Livro SET preco = ROUND(preco * (1 + {marcador}), 2) WHERE tipo = 'F'"
    with conn.cursor() as cur:
        cur.execute(sql, (percentual,) if marcador == "%s" else [percentual])
        return cur.rowcount


def remover_livros_antigos(conn, ano_limite, marcador):
    """DELETE parametrizado - identico em ambos os bancos, exceto o marcador."""
    sql = f"DELETE FROM Livro WHERE ano_publicacao < {marcador}"
    with conn.cursor() as cur:
        cur.execute(sql, (ano_limite,) if marcador == "%s" else [ano_limite])
        return cur.rowcount


def upsert_estoque_oracle(conn, livro_id, quantidade):
    """Upsert via MERGE - sintaxe Oracle."""
    with conn.cursor() as cur:
        cur.execute(
            """
            MERGE INTO Estoque tgt
            USING (SELECT :1 AS livro_id, :2 AS quantidade_nova FROM dual) src
               ON (tgt.livro_id = src.livro_id)
            WHEN MATCHED THEN
                 UPDATE SET tgt.quantidade_disponivel = src.quantidade_nova,
                            tgt.ultima_atualizacao = SYSDATE
            WHEN NOT MATCHED THEN
                 INSERT (livro_id, quantidade_disponivel, ultima_atualizacao)
                 VALUES (src.livro_id, src.quantidade_nova, SYSDATE)
            """,
            [livro_id, quantidade],
        )


def upsert_estoque_postgres(conn, livro_id, quantidade):
    """Upsert via INSERT ... ON CONFLICT - sintaxe PostgreSQL."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao)
            VALUES (%s, %s, CURRENT_DATE)
            ON CONFLICT (livro_id) DO UPDATE
            SET quantidade_disponivel = EXCLUDED.quantidade_disponivel,
                ultima_atualizacao = EXCLUDED.ultima_atualizacao
            """,
            (livro_id, quantidade),
        )


def executar_demonstracao_oracle():
    print("=== Executando DML no Oracle ===")
    conn = oracledb.connect(user=USER, password=PASSWORD, dsn=ORACLE_DSN)
    try:
        novo_id = inserir_cliente_oracle(
            conn, "Diego Ponteiro", "diego.ponteiro@email.com", "+55-31-95555-4444", date.today()
        )
        print(f"Cliente inserido com id: {novo_id}")

        linhas = reajustar_preco_livros_fisicos(conn, 0.10, ":1")
        print(f"Livros fisicos reajustados: {linhas}")

        removidos = remover_livros_antigos(conn, 1990, ":1")
        print(f"Livros antigos removidos: {removidos}")

        upsert_estoque_oracle(conn, 3, 25)

        conn.commit()
        print("Transacao confirmada (COMMIT) em oracle")
    except oracledb.Error as exc:
        conn.rollback()
        print(f"Erro na demonstracao DML (oracle): {exc}")
    finally:
        conn.close()


def executar_demonstracao_postgres():
    print("=== Executando DML no PostgreSQL ===")
    conn = psycopg2.connect(user=USER, password=PASSWORD, **POSTGRES_DSN)
    try:
        novo_id = inserir_cliente_postgres(
            conn, "Diego Ponteiro", "diego.ponteiro@email.com", "+55-31-95555-4444", date.today()
        )
        print(f"Cliente inserido com id: {novo_id}")

        linhas = reajustar_preco_livros_fisicos(conn, 0.10, "%s")
        print(f"Livros fisicos reajustados: {linhas}")

        removidos = remover_livros_antigos(conn, 1990, "%s")
        print(f"Livros antigos removidos: {removidos}")

        upsert_estoque_postgres(conn, 3, 25)

        conn.commit()
        print("Transacao confirmada (COMMIT) em postgresql")
    except psycopg2.Error as exc:
        conn.rollback()
        print(f"Erro na demonstracao DML (postgresql): {exc}")
    finally:
        conn.close()


def main():
    executar_demonstracao_oracle()
    print()
    executar_demonstracao_postgres()


if __name__ == "__main__":
    main()
