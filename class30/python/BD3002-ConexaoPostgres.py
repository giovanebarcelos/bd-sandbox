"""
BD3002-ConexaoPostgres.py
Aula 30 - Banco de Dados - UA12 (Conectividade)

Demonstra a conexao com PostgreSQL via psycopg2, com um exemplo usando
try/finally (controle explicito de commit/rollback e fechamento) e outro
usando um pool de conexoes (psycopg2.pool).

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

import psycopg2
import psycopg2.pool

# Ajuste host/porta/banco/usuario/senha conforme o ambiente de laboratorio.
CONFIG_CONEXAO = dict(
    host="localhost",
    port=5432,
    dbname="vetcare",
    user="app_user",
    password="senha_segura",
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
    buscar_funcionarios_por_cargo("Veterinario")
    print()
    exemplo_com_pool()
