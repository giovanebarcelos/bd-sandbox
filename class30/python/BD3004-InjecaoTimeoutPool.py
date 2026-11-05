"""
BD3004-InjecaoTimeoutPool.py
Aula 30 - Banco de Dados - UA12 (Conectividade) - Tutorial passo a passo
Prof. Giovane Barcelos

O MESMO codigo DB-API 2.0 (PEP 249) roda no PostgreSQL (psycopg2) e no
Oracle (python-oracledb): so mudam o import, a conexao e o estilo do
placeholder (%s x :nome). Tres experimentos:

    1. SQL Injection: concatenar texto x parametro bind
    2. Timeout de conexao: host inacessivel com e sem limite de espera
    3. Connection pool: emprestar, devolver e esgotar o pool

Pre-requisitos:
    pip install psycopg2-binary oracledb
    Banco preparado com class30/<sgbd>/BD3003-TutorialVetcare.sql

Execucao:
    python BD3004-InjecaoTimeoutPool.py postgres
    python BD3004-InjecaoTimeoutPool.py oracle

Credenciais por variavel de ambiente (mesmas dos programas BD3001/BD3002):
    PostgreSQL: PG_HOST, PG_PORT, PG_DATABASE, PG_USER, PG_PASSWORD
    Oracle:     ORACLE_DSN, ORACLE_USER, ORACLE_PASSWORD
"""

import os
import sys
import time

# Endereco privado que, na maioria das redes, nao responde: o pacote some e o
# cliente fica esperando uma resposta que nunca chega. Se a sua rede recusar na
# hora ("Connection refused"), troque com TIMEOUT_HOST=outro.endereco
HOST_INACESSIVEL = os.getenv("TIMEOUT_HOST", "10.255.255.1")


class Postgres:
    nome = "PostgreSQL (psycopg2)"
    placeholder = "%s"
    estilo = "format"        # paramstyle da PEP 249

    def __init__(self):
        import psycopg2
        import psycopg2.pool
        self.driver = psycopg2
        self.modulo_pool = psycopg2.pool
        self.config = dict(
            host=os.getenv("PG_HOST", "localhost"),
            port=int(os.getenv("PG_PORT", "5432")),
            dbname=os.getenv("PG_DATABASE", "vetcare"),
            user=os.getenv("PG_USER", "app_user"),
            password=os.getenv("PG_PASSWORD", "senha_segura"),
            application_name="BD3004-python",
        )

    def conectar(self, **extra):
        return self.driver.connect(**{**self.config, **extra})

    def conectar_inacessivel(self, timeout):
        extra = {"host": HOST_INACESSIVEL}
        if timeout:
            extra["connect_timeout"] = timeout
        return self.conectar(**extra)

    def bind(self, valor):
        return (valor,)

    def criar_pool(self, minimo, maximo):
        return self.modulo_pool.SimpleConnectionPool(minimo, maximo, **self.config)

    def emprestar(self, pool):
        return pool.getconn()

    def devolver(self, pool, con):
        pool.putconn(con)

    def fechar_pool(self, pool):
        pool.closeall()

    def sessoes_no_servidor(self, con):
        """O proprio app_user enxerga as linhas dele em pg_stat_activity."""
        with con.cursor() as cur:
            cur.execute("SELECT count(*) FROM pg_stat_activity "
                        "WHERE usename = current_user AND datname = current_database()")
            return cur.fetchone()[0]


class Oracle:
    nome = "Oracle (python-oracledb, modo thin)"
    placeholder = ":valor"
    estilo = "named"         # paramstyle da PEP 249

    def __init__(self):
        import oracledb
        self.driver = oracledb
        oracledb.defaults.program = "BD3004-python"
        self.usuario = os.getenv("ORACLE_USER", "app_user")
        self.senha = os.getenv("ORACLE_PASSWORD", "senha_segura")
        self.dsn = os.getenv("ORACLE_DSN", "localhost:1521/FREEPDB1")

    def conectar(self, **extra):
        return self.driver.connect(user=self.usuario, password=self.senha,
                                   dsn=self.dsn, **extra)

    def conectar_inacessivel(self, timeout):
        dsn = f"{HOST_INACESSIVEL}:1521/FREEPDB1"
        # o padrao do python-oracledb ja e 20 s; "sem timeout" aqui = 60 s
        return self.driver.connect(user=self.usuario, password=self.senha, dsn=dsn,
                                   tcp_connect_timeout=timeout or 60)

    def bind(self, valor):
        return {"valor": valor}

    def criar_pool(self, minimo, maximo):
        # getmode=TIMEDWAIT + wait_timeout: espera ate 2 s por uma conexao livre
        return self.driver.create_pool(user=self.usuario, password=self.senha,
                                       dsn=self.dsn, min=minimo, max=maximo, increment=1,
                                       getmode=self.driver.POOL_GETMODE_TIMEDWAIT,
                                       wait_timeout=2000)

    def emprestar(self, pool):
        return pool.acquire()

    def devolver(self, pool, con):
        pool.release(con)

    def fechar_pool(self, pool):
        pool.close(force=True)

    def sessoes_no_servidor(self, con):
        return None   # V$SESSION exige privilegio de DBA (veja o tutorial)


def titulo(texto):
    print(f"\n{'=' * 70}\n{texto}\n{'=' * 70}")


# ---------------------------------------------------------------------------
# 1. SQL Injection
# ---------------------------------------------------------------------------
def demo_injecao(bd):
    titulo("1. SQL Injection: concatenacao x parametro bind")
    # (coluna do filtro, valor digitado na tela de busca)
    entradas = [("cargo", "Veterinario"),       # uso normal
                ("cargo", "x' OR '1'='1"),      # ataque: devolve a tabela inteira
                ("nome", "Joana D'Arc")]        # nome legitimo com apostrofo
    with bd.conectar() as con:
        for coluna, entrada in entradas:
            print(f"\nBusca por {coluna}, valor digitado: {entrada!r}")

            # ERRADO: o valor vira parte do texto do SQL
            sql_errado = f"SELECT nome FROM funcionarios WHERE {coluna} = '{entrada}'"
            print(f"  concatenado -> {sql_errado}")
            cur = con.cursor()
            try:
                cur.execute(sql_errado)
                print(f"     {len(cur.fetchall())} linha(s)")
            except bd.driver.Error as erro:
                print(f"     ERRO: {str(erro).splitlines()[0]}")
                if isinstance(bd, Postgres):
                    con.rollback()   # no PostgreSQL o erro aborta a transacao
            finally:
                cur.close()

            # CERTO: SQL fixo + valor enviado separado
            sql_certo = f"SELECT nome FROM funcionarios WHERE {coluna} = {bd.placeholder}"
            with con.cursor() as cur:
                cur.execute(sql_certo, bd.bind(entrada))
                print(f"  bind        -> {sql_certo}   valor={entrada!r}")
                print(f"     {len(cur.fetchall())} linha(s)")


# ---------------------------------------------------------------------------
# 2. Timeout de conexao
# ---------------------------------------------------------------------------
def demo_timeout(bd):
    titulo(f"2. Timeout de conexao em um host que nao responde ({HOST_INACESSIVEL})")
    inicio = time.perf_counter()
    try:
        bd.conectar_inacessivel(timeout=3)
    except bd.driver.Error as erro:
        decorrido = time.perf_counter() - inicio
        print(f"Com timeout de 3 s: desistiu em {decorrido:.1f} s")
        print(f"   {str(erro).splitlines()[0][:110]}")
        if decorrido < 1:
            print("   (a sua rede RECUSOU na hora: rode de novo com TIMEOUT_HOST=<outro ip>)")
    print("Sem timeout, a mesma chamada esperaria o limite do sistema operacional"
          " (dezenas de segundos a minutos) - com a tela da aplicacao congelada.")


# ---------------------------------------------------------------------------
# 3. Connection pool
# ---------------------------------------------------------------------------
def demo_pool(bd):
    titulo("3. Connection pool (min=2, max=3)")
    inicio = time.perf_counter()
    for _ in range(20):
        bd.conectar().close()
    sem_pool = (time.perf_counter() - inicio) / 20 * 1000
    print(f"Abrir + fechar uma conexao nova: {sem_pool:.1f} ms por vez (media de 20)")

    pool = bd.criar_pool(2, 3)
    try:
        con = bd.emprestar(pool)
        print(f"Sessoes do app_user no servidor com o pool aberto: "
              f"{bd.sessoes_no_servidor(con) or 'veja V$SESSION como SYSTEM'}")
        bd.devolver(pool, con)

        inicio = time.perf_counter()
        for _ in range(20):
            con = bd.emprestar(pool)
            bd.devolver(pool, con)
        com_pool = (time.perf_counter() - inicio) / 20 * 1000
        print(f"Emprestar + devolver do pool:   {com_pool:.2f} ms por vez")

        emprestadas = [bd.emprestar(pool) for _ in range(3)]
        print(f"{len(emprestadas)} conexoes emprestadas (o maximo). Pedindo a 4a...")
        try:
            bd.emprestar(pool)
        except Exception as erro:          # PoolError (psycopg2) / DPY-4005 (oracledb)
            print(f"   pool esgotado: {type(erro).__name__}: {str(erro).splitlines()[0][:90]}")
        for con in emprestadas:
            bd.devolver(pool, con)
        print("Conexoes devolvidas: o pool volta a atender.")
    finally:
        bd.fechar_pool(pool)


def main():
    sgbd = sys.argv[1].lower() if len(sys.argv) > 1 else "postgres"
    if sgbd not in ("postgres", "oracle"):
        sys.exit("uso: python BD3004-InjecaoTimeoutPool.py postgres|oracle")
    bd = Postgres() if sgbd == "postgres" else Oracle()
    print(f"SGBD: {bd.nome} | paramstyle: {bd.estilo} ({bd.placeholder})")
    try:
        demo_injecao(bd)
        demo_timeout(bd)
        demo_pool(bd)
    except bd.driver.Error as erro:
        print(f"\nErro de banco: {str(erro).splitlines()[0]}")
        print("Confira se o container esta no ar e se o BD3003-TutorialVetcare.sql foi executado.")


if __name__ == "__main__":
    main()
