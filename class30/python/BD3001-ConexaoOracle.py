"""
BD3001-ConexaoOracle.py
Aula 30 - Banco de Dados - UA12 (Conectividade)

Demonstra a conexao com Oracle Database via python-oracledb (sucessor do
cx_Oracle), em modo "thin" (sem exigir Oracle Instant Client instalado),
usando gerenciadores de contexto (with) para garantir o fechamento da
conexao e do cursor, alem de um exemplo de connection pool.

Tabela de apoio (criar previamente no schema de teste):

    CREATE TABLE funcionarios (
        id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        nome     VARCHAR2(100) NOT NULL,
        cargo    VARCHAR2(50)  NOT NULL,
        salario  NUMBER(10,2)
    );

Instalacao:
    pip install oracledb
"""

import oracledb

# Ajuste usuario/senha/dsn conforme o ambiente de laboratorio.
USUARIO = "app_user"
SENHA = "senha_segura"
DSN = "localhost:1521/XEPDB1"  # host:porta/service_name


def buscar_funcionarios_por_cargo(cargo):
    """Conecta, executa uma consulta parametrizada e imprime o resultado.

    Usa `with` tanto na conexao quanto no cursor: ao sair do bloco `with`,
    ambos sao fechados automaticamente, mesmo se ocorrer uma excecao.
    """
    sql = "SELECT id, nome, cargo, salario FROM funcionarios WHERE cargo = :cargo"

    try:
        with oracledb.connect(user=USUARIO, password=SENHA, dsn=DSN) as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, cargo=cargo)

                print(f"Funcionarios com cargo = {cargo}:")
                print("-" * 40)

                total = 0
                for id_, nome, cargo_bd, salario in cursor:
                    print(f"{id_} | {nome} | {cargo_bd} | R$ {salario:.2f}")
                    total += 1

                if total == 0:
                    print("Nenhum funcionario encontrado para o cargo informado.")

    except oracledb.DatabaseError as erro:
        (erro_obj,) = erro.args
        print("Erro ao conectar/consultar o Oracle Database.")
        print(f"Codigo: {erro_obj.code} | Mensagem: {erro_obj.message}")


def exemplo_com_pool():
    """Exemplo de uso de connection pool nativo do python-oracledb.

    Util quando a aplicacao faz varias operacoes ao longo do tempo (ex.: uma
    API web) - evita abrir/fechar uma conexao fisica a cada requisicao.
    """
    pool = oracledb.create_pool(
        user=USUARIO, password=SENHA, dsn=DSN, min=2, max=10, increment=1
    )

    try:
        with pool.acquire() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM funcionarios")
                (total,) = cursor.fetchone()
                print(f"Total de funcionarios cadastrados: {total}")
    finally:
        pool.close()


if __name__ == "__main__":
    buscar_funcionarios_por_cargo("Veterinario")
    print()
    exemplo_com_pool()
