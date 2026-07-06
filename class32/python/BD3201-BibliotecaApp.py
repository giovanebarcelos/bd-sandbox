#!/usr/bin/env python3
# BD3201-BibliotecaApp.py
# Python: Conexao com procedures da Biblioteca via psycopg2 e oracledb
# UA12 - Aula 32 - Projeto Integrador Final

import sys

# ============================================================
# CONEXAO POSTGRESQL (psycopg2)
# ============================================================
def conectar_postgresql():
    try:
        import psycopg2
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            dbname="biblioteca",
            user="postgres",
            password="postgres"
        )
        print("Conectado ao PostgreSQL - Sistema de Biblioteca")
        return conn
    except ImportError:
        print("psycopg2 nao instalado. Instale com: pip install psycopg2-binary")
        return None
    except Exception as e:
        print(f"Erro ao conectar PostgreSQL: {e}")
        return None


# ============================================================
# CONEXAO ORACLE (oracledb)
# ============================================================
def conectar_oracle():
    try:
        import oracledb
        conn = oracledb.connect(
            user="system",
            password="oracle",
            dsn="localhost:1521/XEPDB1"
        )
        print("Conectado ao Oracle - Sistema de Biblioteca")
        return conn
    except ImportError:
        print("oracledb nao instalado. Instale com: pip install oracledb")
        return None
    except Exception as e:
        print(f"Erro ao conectar Oracle: {e}")
        return None


# ============================================================
# OPERACOES DO SISTEMA
# ============================================================
def realizar_emprestimo(conn, usuario_id, livro_id, sgbd="postgresql"):
    """Registra um emprestimo chamando a procedure no banco."""
    cursor = conn.cursor()
    try:
        if sgbd == "postgresql":
            cursor.execute("CALL realizar_emprestimo(%s, %s)", (usuario_id, livro_id))
        else:
            cursor.callproc("realizar_emprestimo", [usuario_id, livro_id])
        conn.commit()
        print(f"Emprestimo registrado: usuario={usuario_id}, livro={livro_id}")
    except Exception as e:
        conn.rollback()
        print(f"Erro ao registrar emprestimo: {e}")
    finally:
        cursor.close()


def devolver_livro(conn, emprestimo_id, sgbd="postgresql"):
    """Registra a devolucao de um livro e calcula multa se atrasado."""
    cursor = conn.cursor()
    try:
        if sgbd == "postgresql":
            cursor.execute("CALL devolver_livro(%s)", (emprestimo_id,))
        else:
            cursor.callproc("devolver_livro", [emprestimo_id])
        conn.commit()
        print(f"Livro devolvido: emprestimo_id={emprestimo_id}")
    except Exception as e:
        conn.rollback()
        print(f"Erro ao devolver livro: {e}")
    finally:
        cursor.close()


def listar_emprestimos(conn):
    """Lista os ultimos 10 emprestimos."""
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT e.emprestimo_id, u.nome AS usuario, l.titulo AS livro,
                   e.data_retirada, e.data_prevista, e.data_devolucao, e.multa
              FROM emprestimo e
              JOIN usuario u ON u.usuario_id = e.usuario_id
              JOIN livro l ON l.livro_id = e.livro_id
             ORDER BY e.data_retirada DESC
             LIMIT 10
        """)
        print("\n--- Ultimos emprestimos ---")
        for row in cursor.fetchall():
            print(f"#{row[0]} | {row[1]} | {row[2]} | Retirada: {row[3]} | Multa: R$ {row[6]:.2f}")
    except Exception as e:
        print(f"Erro ao listar emprestimos: {e}")
    finally:
        cursor.close()


def inserir_dados_exemplo(conn):
    """Insere dados de exemplo para teste."""
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO editora (nome) VALUES ('Editora Tech') ON CONFLICT DO NOTHING")
        cursor.execute("INSERT INTO editora (nome) VALUES ('Editora Ciencia') ON CONFLICT DO NOTHING")
        cursor.execute("""
            INSERT INTO livro (isbn, titulo, editora_id, ano) VALUES
            ('978-85-365-0001-0', 'Banco de Dados: Fundamentos', 1, 2024),
            ('978-85-365-0002-7', 'SQL Avancado', 1, 2025)
            ON CONFLICT DO NOTHING
        """)
        cursor.execute("""
            INSERT INTO usuario (matricula, nome, email, tipo) VALUES
            ('2026001', 'Aluno Teste', 'aluno@email.com', 'ALUNO')
            ON CONFLICT DO NOTHING
        """)
        conn.commit()
        print("Dados de exemplo inseridos com sucesso.")
    except Exception as e:
        conn.rollback()
        print(f"Dados de exemplo ja existem ou erro: {e}")
    finally:
        cursor.close()


# ============================================================
# MAIN
# ============================================================
def main():
    sgbd = sys.argv[1] if len(sys.argv) > 1 else "postgresql"

    if sgbd == "oracle":
        conn = conectar_oracle()
    else:
        conn = conectar_postgresql()

    if conn is None:
        print("Nao foi possivel conectar ao banco de dados.")
        return

    try:
        inserir_dados_exemplo(conn)
        realizar_emprestimo(conn, 1, 1, sgbd)
        devolver_livro(conn, 1, sgbd)
        listar_emprestimos(conn)
        print(f"\nTodas as operacoes concluidas com sucesso no {sgbd.upper()}!")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
