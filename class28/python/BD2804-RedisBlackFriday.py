#!/usr/bin/env python3
"""
BD2804 - Redis na pratica: sobrevivendo a Black Friday (redis-py)
Disciplina: Banco de Dados | Aula 28B - Redis em Profundidade
Prof. Giovane Barcelos

Problema real: na Black Friday a pagina de produto da TechStore recebe
milhares de acessos por segundo. Cada acesso faz uma consulta "cara" no banco
relacional (aqui simulado com SQLite + atraso de 150 ms). O banco relacional
continua sendo a FONTE DA VERDADE; o Redis entra como camada de apoio para:

    1. Cache-aside com TTL e invalidacao      (String + EX)
    2. Sessao/carrinho do usuario             (Hash + EXPIRE)
    3. Rate limiting por IP                   (INCR + EXPIRE, janela fixa)
    4. Ranking de mais vendidos em tempo real (Sorted Set)
    5. Visitantes unicos com 12 KB de memoria (HyperLogLog)
    6. Fila de processamento de pedidos       (Stream + consumer group)
    7. Lock distribuido para o ultimo item    (SET NX PX + script Lua)
    8. Pipeline: 1 ida e volta para N comandos

Pre-requisitos:
    pip install redis
    docker run -d --name bd28-redis -p 6379:6379 redis:7-alpine

Execucao:
    python3 BD2804-RedisBlackFriday.py
"""

import json
import sqlite3
import time
import uuid

import redis

REDIS = redis.Redis(host="localhost", port=6379, db=0, decode_responses=True)
ATRASO_BD = 0.150  # 150 ms por consulta "cara" no relacional


def titulo(texto):
    print(f"\n{'=' * 70}\n{texto}\n{'=' * 70}")


# ---------------------------------------------------------------------------
# Fonte da verdade: banco relacional (SQLite em memoria)
# ---------------------------------------------------------------------------
def criar_banco_relacional():
    con = sqlite3.connect(":memory:")
    con.execute("""CREATE TABLE produto (
                       id INTEGER PRIMARY KEY, nome TEXT, preco REAL, estoque INTEGER)""")
    con.executemany("INSERT INTO produto VALUES (?, ?, ?, ?)", [
        (1, "Notebook Pro 14", 7899.90, 12),
        (2, "Smartphone Z5", 2999.00, 40),
        (3, "Fone Bluetooth", 299.00, 150),
        (4, "Monitor 27 4K", 2199.00, 1),
    ])
    return con


def consultar_produto_bd(con, produto_id):
    time.sleep(ATRASO_BD)  # simula JOINs, rede, disco...
    linha = con.execute("SELECT id, nome, preco, estoque FROM produto WHERE id = ?",
                        (produto_id,)).fetchone()
    return dict(zip(("id", "nome", "preco", "estoque"), linha)) if linha else None


# ---------------------------------------------------------------------------
# 1. Cache-aside
# ---------------------------------------------------------------------------
def obter_produto(con, produto_id, ttl=60):
    """Padrao cache-aside (lazy loading):
    1) tenta o Redis; 2) se nao achou (cache miss) le do BD e grava no Redis
    com TTL; 3) devolve. O TTL garante que um dado esquecido expira sozinho.
    """
    chave = f"produto:{produto_id}"
    em_cache = REDIS.get(chave)
    if em_cache is not None:
        return json.loads(em_cache), "HIT"
    produto = consultar_produto_bd(con, produto_id)
    REDIS.set(chave, json.dumps(produto), ex=ttl)
    return produto, "MISS"


def atualizar_preco(con, produto_id, novo_preco):
    """Escrita: atualiza a fonte da verdade e INVALIDA o cache (nao atualiza).
    Invalidar e mais seguro: a proxima leitura busca o valor correto do BD."""
    con.execute("UPDATE produto SET preco = ? WHERE id = ?", (novo_preco, produto_id))
    con.commit()
    REDIS.delete(f"produto:{produto_id}")


def demo_cache(con):
    for tentativa in range(1, 4):
        inicio = time.perf_counter()
        produto, status = obter_produto(con, 1)
        ms = (time.perf_counter() - inicio) * 1000
        print(f"Acesso {tentativa}: {status:<4} {ms:7.2f} ms  -> {produto['nome']} "
              f"R$ {produto['preco']}")
    print("TTL restante de produto:1 =", REDIS.ttl("produto:1"), "s")

    atualizar_preco(con, 1, 6999.90)
    produto, status = obter_produto(con, 1)
    print(f"Apos UPDATE + invalidacao: {status} -> R$ {produto['preco']}")


# ---------------------------------------------------------------------------
# 2. Sessao e carrinho
# ---------------------------------------------------------------------------
def demo_sessao():
    sid = uuid.uuid4().hex[:12]
    chave_sessao, chave_carrinho = f"sessao:{sid}", f"carrinho:{sid}"
    REDIS.hset(chave_sessao, mapping={"usuario": "ana", "nome": "Ana Ribeiro",
                                      "logado_em": time.strftime("%H:%M:%S")})
    REDIS.expire(chave_sessao, 1800)  # 30 min de inatividade

    # Carrinho: campo = id do produto, valor = quantidade (HINCRBY e atomico)
    REDIS.hincrby(chave_carrinho, "produto:2", 1)
    REDIS.hincrby(chave_carrinho, "produto:3", 2)
    REDIS.hincrby(chave_carrinho, "produto:3", 1)
    REDIS.expire(chave_carrinho, 1800)

    print("Sessao :", REDIS.hgetall(chave_sessao))
    print("Carrinho:", REDIS.hgetall(chave_carrinho),
          "| expira em", REDIS.ttl(chave_carrinho), "s")


# ---------------------------------------------------------------------------
# 3. Rate limiting
# ---------------------------------------------------------------------------
def permitir_requisicao(ip, limite=5, janela_s=10):
    """Janela fixa: no maximo 'limite' requisicoes por IP a cada 'janela_s'.
    INCR e atomico - funciona mesmo com 50 servidores web em paralelo."""
    janela = int(time.time() // janela_s)
    chave = f"rl:{ip}:{janela}"
    pipe = REDIS.pipeline()
    pipe.incr(chave)
    pipe.expire(chave, janela_s)
    contagem, _ = pipe.execute()
    return contagem <= limite, contagem


def demo_rate_limit():
    for i in range(1, 8):
        ok, n = permitir_requisicao("200.10.1.7")
        print(f"Requisicao {i} do IP 200.10.1.7 -> {'200 OK' if ok else '429 Too Many Requests'}"
              f" (contador={n})")


# ---------------------------------------------------------------------------
# 4. Ranking em tempo real
# ---------------------------------------------------------------------------
def demo_ranking():
    REDIS.delete("ranking:vendas:bf")
    vendas = [("Smartphone Z5", 3), ("Fone Bluetooth", 10), ("Notebook Pro 14", 1),
              ("Smartphone Z5", 4), ("Monitor 27 4K", 1), ("Fone Bluetooth", 2)]
    for produto, qtd in vendas:
        REDIS.zincrby("ranking:vendas:bf", qtd, produto)
    print("Top 3 mais vendidos:")
    for pos, (produto, total) in enumerate(
            REDIS.zrevrange("ranking:vendas:bf", 0, 2, withscores=True), start=1):
        print(f"   {pos}o {produto:<16} {int(total)} un.")
    print("Posicao do Notebook Pro 14:",
          REDIS.zrevrank("ranking:vendas:bf", "Notebook Pro 14") + 1)


# ---------------------------------------------------------------------------
# 5. Visitantes unicos
# ---------------------------------------------------------------------------
def demo_hyperloglog():
    REDIS.delete("visitantes:2026-11-27")
    pipe = REDIS.pipeline()
    for i in range(100_000):
        pipe.pfadd("visitantes:2026-11-27", f"user-{i % 25_000}")  # 25 mil distintos
    pipe.execute()
    estimado = REDIS.pfcount("visitantes:2026-11-27")
    memoria = REDIS.memory_usage("visitantes:2026-11-27")
    print(f"100.000 acessos, 25.000 usuarios distintos -> HLL estima {estimado} "
          f"(erro {abs(estimado - 25_000) / 250:.2f}%) usando {memoria} bytes")


# ---------------------------------------------------------------------------
# 6. Fila de pedidos com Streams
# ---------------------------------------------------------------------------
def demo_stream():
    stream, grupo = "pedidos:novos", "faturamento"
    REDIS.delete(stream)
    REDIS.xgroup_create(stream, grupo, id="0", mkstream=True)

    # Produtor: a API web so registra o pedido e responde rapido ao cliente
    for pedido_id, total in [(1001, 299.0), (1002, 7899.9), (1003, 598.0)]:
        REDIS.xadd(stream, {"pedido_id": pedido_id, "total": total})
    print("Pedidos na fila:", REDIS.xlen(stream))

    # Consumidor: um worker processa em segundo plano (nota fiscal, e-mail...)
    mensagens = REDIS.xreadgroup(grupo, "worker-1", {stream: ">"}, count=10)
    for _, itens in mensagens:
        for msg_id, campos in itens:
            print(f"   worker-1 processou pedido {campos['pedido_id']} "
                  f"(R$ {campos['total']}) msg={msg_id}")
            REDIS.xack(stream, grupo, msg_id)  # confirma: nao sera reentregue
    pendentes = REDIS.xpending(stream, grupo)["pending"]
    print("Mensagens pendentes de confirmacao:", pendentes)


# ---------------------------------------------------------------------------
# 7. Lock distribuido
# ---------------------------------------------------------------------------
LIBERAR_LOCK = """
if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
end
return 0
"""


def comprar_ultimo_item(con, cliente, produto_id=4):
    """Dois clientes clicam em 'comprar' no ultimo Monitor ao mesmo tempo.
    SET NX garante que so um entra na secao critica; o token unico e o script
    Lua garantem que ninguem libera o lock de outro cliente."""
    chave, token = f"lock:produto:{produto_id}", uuid.uuid4().hex
    if not REDIS.set(chave, token, nx=True, px=5000):
        return f"{cliente}: produto em processamento por outro cliente, tente de novo"
    try:
        estoque = con.execute("SELECT estoque FROM produto WHERE id = ?",
                              (produto_id,)).fetchone()[0]
        if estoque <= 0:
            return f"{cliente}: esgotado"
        con.execute("UPDATE produto SET estoque = estoque - 1 WHERE id = ?", (produto_id,))
        con.commit()
        REDIS.delete(f"produto:{produto_id}")
        return f"{cliente}: COMPRA CONFIRMADA"
    finally:
        REDIS.eval(LIBERAR_LOCK, 1, chave, token)


def demo_lock(con):
    # Simula a concorrencia: o lock do cliente A ainda esta ativo quando B tenta
    REDIS.set("lock:produto:4", "token-do-cliente-A", nx=True, px=5000)
    print(comprar_ultimo_item(con, "cliente B"))
    REDIS.delete("lock:produto:4")
    print(comprar_ultimo_item(con, "cliente A"))
    print(comprar_ultimo_item(con, "cliente B"))


# ---------------------------------------------------------------------------
# 8. Pipeline
# ---------------------------------------------------------------------------
def demo_pipeline():
    n = 5000
    inicio = time.perf_counter()
    for i in range(n):
        REDIS.set(f"tmp:{i}", i)
    sem = time.perf_counter() - inicio

    inicio = time.perf_counter()
    pipe = REDIS.pipeline(transaction=False)
    for i in range(n):
        pipe.set(f"tmp:{i}", i)
    pipe.execute()
    com = time.perf_counter() - inicio
    print(f"{n} SETs sem pipeline: {sem * 1000:.0f} ms | com pipeline: {com * 1000:.0f} ms"
          f" ({sem / com:.0f}x mais rapido)")
    REDIS.delete(*[f"tmp:{i}" for i in range(n)])


def main():
    try:
        REDIS.ping()
    except redis.ConnectionError as erro:
        print("Redis indisponivel:", erro)
        return
    con = criar_banco_relacional()
    REDIS.delete("produto:1", "produto:4")

    titulo("1. Cache-aside com TTL e invalidacao")
    demo_cache(con)
    titulo("2. Sessao e carrinho (Hash + EXPIRE)")
    demo_sessao()
    titulo("3. Rate limiting (INCR + EXPIRE)")
    demo_rate_limit()
    titulo("4. Ranking de mais vendidos (Sorted Set)")
    demo_ranking()
    titulo("5. Visitantes unicos (HyperLogLog)")
    demo_hyperloglog()
    titulo("6. Fila de pedidos (Stream + consumer group)")
    demo_stream()
    titulo("7. Lock distribuido para o ultimo item")
    demo_lock(con)
    titulo("8. Pipeline")
    demo_pipeline()


if __name__ == "__main__":
    main()
