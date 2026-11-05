"""
BD3002-ConexaoPostgres.py
Aula 30 - Banco de Dados - UA12 (Conectividade)

Demonstra a conexao com PostgreSQL via psycopg2, com um exemplo usando
try/finally (controle explicito de commit/rollback e fechamento) e outro
usando um pool de conexoes (psycopg2.pool).

Ambiente da disciplina (A1/DBTools/Docker): o script
class30/postgresql/BD3003-TutorialVetcare.sql cria o banco vetcare, a tabela
e o role app_user.

Credenciais por variavel de ambiente (nunca no codigo que vai para o Git):
    PG_HOST, PG_PORT, PG_DATABASE, PG_USER
    PG_PASSWORD (padrao senha_segura - senha do laboratorio)

Tabela de apoio (criar previamente no banco de teste):

    CREATE TABLE funcionarios (
        id       SERIAL PRIMARY KEY,
        nome     VARCHAR(100) NOT NULL,
        cargo    VARCHAR(50)  NOT NULL,
        salario  NUMERIC(10,2)
    );

Instalacao:
    pip install psycopg2-binary
"""

import os

import psycopg2
import psycopg2.pool

CONFIG_CONEXAO = dict(
    host=os.getenv("PG_HOST", "localhost"),
    port=int(os.getenv("PG_PORT", "5432")),
    dbname=os.getenv("PG_DATABASE", "vetcare"),
    user=os.getenv("PG_USER", "app_user"),
    password=os.getenv("PG_PASSWORD", "senha_segura"),
    application_name="BD3002-python",   # aparece em pg_stat_activity
    connect_timeout=5,                  # segundos: nao trava se o host sumir
)


def buscar_funcionarios_por_cargo(cargo):
    """Conecta, executa uma consulta parametrizada e imprime o resultado.

    Usa try/finally para garantir o fechamento do cursor e da conexao mesmo
    em caso de erro - alternativa ao `with`, util quando se quer controlar
    commit()/rollback() manualmente (nao necessario aqui, pois e uma consulta
    somente leitura).
    """
    connection = None
    cursor = None
    sql = "SELECT id, nome, cargo, salario FROM funcionarios WHERE cargo = %s"

    try:
        connection = psycopg2.connect(**CONFIG_CONEXAO)
        cursor = connection.cursor()
        cursor.execute(sql, (cargo,))

        print(f"Funcionarios com cargo = {cargo}:")
        print("-" * 40)

        linhas = cursor.fetchall()
        for id_, nome, cargo_bd, salario in linhas:
            print(f"{id_} | {nome} | {cargo_bd} | R$ {salario:.2f}")

        if not linhas:
            print("Nenhum funcionario encontrado para o cargo informado.")
        return True

    except psycopg2.OperationalError as erro:
        print("Erro ao conectar ao PostgreSQL (banco indisponivel ou credenciais invalidas).")
        print(f"Detalhe: {erro}")
    except psycopg2.Error as erro:
        print("Erro ao executar a consulta no PostgreSQL.")
        print(f"Detalhe: {erro}")
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()


def exemplo_com_pool():
    """Exemplo de uso de connection pool com psycopg2.pool.SimpleConnectionPool."""
    pool = psycopg2.pool.SimpleConnectionPool(minconn=2, maxconn=10, **CONFIG_CONEXAO)

    connection = pool.getconn()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM funcionarios")
            (total,) = cursor.fetchone()
            print(f"Total de funcionarios cadastrados: {total}")
    finally:
        pool.putconn(connection)  # devolve a conexao ao pool, nao fecha de verdade
        pool.closeall()


if __name__ == "__main__":
    # o exemplo de pool so roda se a primeira conexao funcionou
    if buscar_funcionarios_por_cargo("Veterinario"):
        print()
        exemplo_com_pool()
