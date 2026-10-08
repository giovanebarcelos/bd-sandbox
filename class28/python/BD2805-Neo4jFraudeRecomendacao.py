#!/usr/bin/env python3
"""
BD2805 - Neo4j na pratica: aneis de fraude e recomendacao de produtos (driver neo4j)
Disciplina: Banco de Dados | Aula 28C - Neo4j em Profundidade
Prof. Giovane Barcelos

Problema real: a equipe antifraude da TechStore percebeu que fraudadores
criam varias contas "diferentes" que, na verdade, compartilham o mesmo
celular, o mesmo dispositivo ou o mesmo endereco de entrega. Em SQL, achar
esses grupos exige self-joins recursivos sobre tabelas de identificadores;
em grafo, e uma travessia de caminhos.

O mesmo grafo serve ao marketing: "quem comprou este produto tambem comprou".

Passo a passo:
    1. Constraints e indices (unicidade e busca)
    2. Carga em lote com UNWIND + MERGE (idempotente)
    3. Consultas basicas de padrao (MATCH)
    4. Deteccao de aneis de fraude (componentes ligados por identificadores)
    5. Caminho mais curto entre duas contas (shortestPath)
    6. Recomendacao colaborativa (quem comprou X tambem comprou Y)
    7. Escrita transacional gerenciada (execute_write) - bloquear contas

Pre-requisitos:
    pip install neo4j
    docker run -d --name bd28-neo4j -p 7474:7474 -p 7687:7687 \
        -e NEO4J_AUTH=neo4j/bd28senha123 neo4j:5
    (Neo4j Browser em http://localhost:7474 para ver o grafo desenhado)

Execucao:
    python3 BD2805-Neo4jFraudeRecomendacao.py
"""

from neo4j import GraphDatabase
from neo4j.exceptions import Neo4jError, ServiceUnavailable

URI = "neo4j://localhost:7687"
AUTH = ("neo4j", "bd28senha123")


def titulo(texto):
    print(f"\n{'=' * 70}\n{texto}\n{'=' * 70}")


# ---------------------------------------------------------------------------
# Dados do problema
# ---------------------------------------------------------------------------
CLIENTES = [
    # id, nome, telefone, dispositivo, cep_entrega
    ("c01", "Ana Ribeiro",     "51-99001-0001", "dev-AAA", "90010-000"),
    ("c02", "Bruno Costa",     "51-99001-0002", "dev-BBB", "92010-000"),
    ("c03", "Carla Mendes",    "48-99001-0003", "dev-CCC", "88010-000"),
    # --- anel de fraude 1: tres "pessoas" ligadas por telefone e dispositivo
    ("c10", "Joao Silva",      "11-98888-7777", "dev-XYZ", "01001-000"),
    ("c11", "J. da Silva",     "11-98888-7777", "dev-QQQ", "01310-100"),
    ("c12", "Joana Silveira",  "21-97777-1111", "dev-QQQ", "01310-100"),
    ("c13", "Jonas Sil",       "21-97777-1111", "dev-ZZZ", "04538-133"),
    # --- anel de fraude 2: duas contas no mesmo endereco e dispositivo
    ("c20", "Marcos Paulo",    "31-96666-0000", "dev-MMM", "30130-010"),
    ("c21", "Marcos P. Lima",  "31-96666-9999", "dev-MMM", "30130-010"),
]

COMPRAS = [
    # cliente, sku, produto, categoria, valor
    ("c01", "NTB-0001", "Notebook Pro 14", "notebook", 7899.90),
    ("c01", "ACC-0001", "Mouse sem fio", "acessorio", 129.00),
    ("c01", "ACC-0002", "Mochila notebook", "acessorio", 249.00),
    ("c02", "NTB-0001", "Notebook Pro 14", "notebook", 7899.90),
    ("c02", "ACC-0001", "Mouse sem fio", "acessorio", 129.00),
    ("c02", "ACC-0003", "Suporte ergonomico", "acessorio", 189.00),
    ("c03", "NTB-0001", "Notebook Pro 14", "notebook", 7899.90),
    ("c03", "ACC-0002", "Mochila notebook", "acessorio", 249.00),
    ("c03", "LIV-0001", "Sistemas de Banco de Dados", "livro", 289.90),
    ("c10", "SMA-0001", "Smartphone Z5", "smartphone", 2999.00),
    ("c11", "SMA-0001", "Smartphone Z5", "smartphone", 2999.00),
    ("c12", "SMA-0001", "Smartphone Z5", "smartphone", 2999.00),
    ("c13", "SMA-0001", "Smartphone Z5", "smartphone", 2999.00),
    ("c20", "NTB-0002", "Notebook Gamer X", "notebook", 9499.00),
    ("c21", "NTB-0002", "Notebook Gamer X", "notebook", 9499.00),
]


# ---------------------------------------------------------------------------
# 1. Esquema: constraints e indices
# ---------------------------------------------------------------------------
def criar_esquema(driver):
    comandos = [
        "CREATE CONSTRAINT cliente_id IF NOT EXISTS FOR (c:Cliente) REQUIRE c.id IS UNIQUE",
        "CREATE CONSTRAINT produto_sku IF NOT EXISTS FOR (p:Produto) REQUIRE p.sku IS UNIQUE",
        "CREATE CONSTRAINT telefone_num IF NOT EXISTS FOR (t:Telefone) REQUIRE t.numero IS UNIQUE",
        "CREATE CONSTRAINT disp_id IF NOT EXISTS FOR (d:Dispositivo) REQUIRE d.id IS UNIQUE",
        "CREATE CONSTRAINT end_cep IF NOT EXISTS FOR (e:Endereco) REQUIRE e.cep IS UNIQUE",
        "CREATE INDEX cliente_nome IF NOT EXISTS FOR (c:Cliente) ON (c.nome)",
    ]
    driver.execute_query("MATCH (n) DETACH DELETE n")  # recomeca do zero
    for cypher in comandos:
        driver.execute_query(cypher)
    registros, _, _ = driver.execute_query(
        "SHOW CONSTRAINTS YIELD name RETURN collect(name) AS nomes")
    print("Constraints:", sorted(registros[0]["nomes"]))


# ---------------------------------------------------------------------------
# 2. Carga em lote
# ---------------------------------------------------------------------------
def carregar(driver):
    """UNWIND transforma a lista Python em linhas; MERGE cria o no/relacao
    apenas se ainda nao existir (idempotente - pode rodar 2x sem duplicar).
    Um unico round-trip carrega todos os clientes: muito mais rapido do que
    um CREATE por cliente."""
    driver.execute_query("""
        UNWIND $clientes AS row
        MERGE (c:Cliente {id: row[0]}) SET c.nome = row[1]
        MERGE (t:Telefone {numero: row[2]})
        MERGE (d:Dispositivo {id: row[3]})
        MERGE (e:Endereco {cep: row[4]})
        MERGE (c)-[:USA_TELEFONE]->(t)
        MERGE (c)-[:USA_DISPOSITIVO]->(d)
        MERGE (c)-[:ENTREGA_EM]->(e)
        """, clientes=[list(c) for c in CLIENTES])

    driver.execute_query("""
        UNWIND $compras AS row
        MATCH (c:Cliente {id: row[0]})
        MERGE (p:Produto {sku: row[1]})
          ON CREATE SET p.nome = row[2], p.categoria = row[3], p.preco = row[4]
        MERGE (c)-[r:COMPROU]->(p)
          ON CREATE SET r.valor = row[4], r.data = date()
        """, compras=[list(c) for c in COMPRAS])

    registros, _, _ = driver.execute_query("""
        MATCH (n) WITH labels(n)[0] AS rotulo, count(*) AS qtd
        RETURN rotulo, qtd ORDER BY rotulo""")
    print("Nos por rotulo:", {r["rotulo"]: r["qtd"] for r in registros})
    registros, _, _ = driver.execute_query(
        "MATCH ()-[r]->() RETURN type(r) AS tipo, count(*) AS qtd ORDER BY tipo")
    print("Relacionamentos:", {r["tipo"]: r["qtd"] for r in registros})


# ---------------------------------------------------------------------------
# 3. Consultas basicas
# ---------------------------------------------------------------------------
def consultas_basicas(driver):
    print("[a] O que a Ana comprou?")
    registros, _, _ = driver.execute_query("""
        MATCH (:Cliente {nome: $nome})-[c:COMPROU]->(p:Produto)
        RETURN p.nome AS produto, c.valor AS valor ORDER BY valor DESC""",
        nome="Ana Ribeiro")
    for r in registros:
        print(f"    {r['produto']:<22} R$ {r['valor']:.2f}")

    print("[b] Identificadores compartilhados por mais de um cliente:")
    registros, _, _ = driver.execute_query("""
        MATCH (c:Cliente)-->(id)
        WHERE id:Telefone OR id:Dispositivo OR id:Endereco
        WITH id, labels(id)[0] AS tipo, collect(c.nome) AS clientes
        WHERE size(clientes) > 1
        RETURN tipo, coalesce(id.numero, id.id, id.cep) AS valor, clientes
        ORDER BY tipo""")
    for r in registros:
        print(f"    {r['tipo']:<12} {r['valor']:<15} {r['clientes']}")


# ---------------------------------------------------------------------------
# 4. Aneis de fraude
# ---------------------------------------------------------------------------
def detectar_aneis(driver):
    """Um anel e um conjunto de clientes alcancaveis uns pelos outros
    atraves de identificadores compartilhados, em qualquer numero de saltos.
    O padrao de comprimento variavel [:USA_TELEFONE|USA_DISPOSITIVO|ENTREGA_EM*]
    faz a travessia que em SQL exigiria uma CTE recursiva."""
    registros, _, _ = driver.execute_query("""
        MATCH (c:Cliente)
        MATCH (c)-[:USA_TELEFONE|USA_DISPOSITIVO|ENTREGA_EM*0..8]-(outro:Cliente)
        WITH c, collect(DISTINCT outro.id) AS anel
        WHERE size(anel) > 1
        RETURN anel""")
    # Cada membro devolve o mesmo anel: ordena e usa um set para deduplicar
    aneis = sorted({tuple(sorted(r["anel"])) for r in registros})
    for anel in aneis:
        total, _, _ = driver.execute_query("""
            MATCH (c:Cliente)-[r:COMPROU]->() WHERE c.id IN $ids
            RETURN sum(r.valor) AS exposicao, count(r) AS compras""", ids=list(anel))
        t = total[0]
        print(f"ANEL {list(anel)} -> {t['compras']} compras, "
              f"exposicao R$ {t['exposicao']:.2f}")
    return aneis


# ---------------------------------------------------------------------------
# 5. Caminho mais curto
# ---------------------------------------------------------------------------
def caminho_mais_curto(driver, origem, destino):
    registros, _, _ = driver.execute_query("""
        MATCH (a:Cliente {id: $origem}), (b:Cliente {id: $destino})
        MATCH p = shortestPath((a)-[:USA_TELEFONE|USA_DISPOSITIVO|ENTREGA_EM*]-(b))
        RETURN [n IN nodes(p) | coalesce(n.nome, n.numero, n.id, n.cep)] AS caminho,
               length(p) AS saltos""", origem=origem, destino=destino)
    if registros:
        r = registros[0]
        print(f"{origem} -> {destino} em {r['saltos']} saltos: "
              + " -- ".join(r["caminho"]))
    else:
        print(f"Nao ha caminho entre {origem} e {destino}")


# ---------------------------------------------------------------------------
# 6. Recomendacao
# ---------------------------------------------------------------------------
def recomendar(driver, cliente_id):
    """Filtragem colaborativa em 1 MATCH: produtos comprados por clientes que
    compraram o mesmo que eu, e que eu ainda nao comprei, ranqueados pelo
    numero de 'vizinhos' em comum."""
    registros, _, _ = driver.execute_query("""
        MATCH (eu:Cliente {id: $id})-[:COMPROU]->(p:Produto)<-[:COMPROU]-(viz:Cliente)
        MATCH (viz)-[:COMPROU]->(rec:Produto)
        WHERE NOT (eu)-[:COMPROU]->(rec) AND NOT coalesce(viz.bloqueado, false)
        RETURN rec.nome AS produto, count(DISTINCT viz) AS forca,
               collect(DISTINCT viz.nome) AS porque
        ORDER BY forca DESC, produto LIMIT 3""", id=cliente_id)
    for r in registros:
        print(f"    {r['produto']:<28} forca={r['forca']}  (compraram: {r['porque']})")


# ---------------------------------------------------------------------------
# 7. Escrita transacional
# ---------------------------------------------------------------------------
def bloquear_anel(tx, ids, motivo):
    resultado = tx.run("""
        MATCH (c:Cliente) WHERE c.id IN $ids
        SET c.bloqueado = true, c.motivo = $motivo, c.bloqueado_em = datetime()
        RETURN count(c) AS qtd""", ids=ids, motivo=motivo)
    return resultado.single()["qtd"]


def bloquear(driver, aneis):
    with driver.session(database="neo4j") as sessao:
        for anel in aneis:
            # execute_write: transacao com retry automatico em erros transitorios
            qtd = sessao.execute_write(bloquear_anel, list(anel), "anel de fraude")
            print(f"{qtd} conta(s) bloqueada(s): {list(anel)}")


def main():
    try:
        # notifications_min_severity="OFF": omite avisos informativos do servidor
        with GraphDatabase.driver(URI, auth=AUTH,
                                  notifications_min_severity="OFF") as driver:
            driver.verify_connectivity()
            titulo("1. Constraints e indices")
            criar_esquema(driver)
            titulo("2. Carga em lote (UNWIND + MERGE)")
            carregar(driver)
            titulo("3. Consultas basicas")
            consultas_basicas(driver)
            titulo("4. Deteccao de aneis de fraude")
            aneis = detectar_aneis(driver)
            titulo("5. Caminho mais curto entre contas suspeitas")
            caminho_mais_curto(driver, "c10", "c13")
            caminho_mais_curto(driver, "c01", "c10")
            titulo("6. Recomendacao: quem comprou tambem comprou")
            for cid in ("c02", "c03"):
                print(f"Para {cid}:")
                recomendar(driver, cid)
            titulo("7. Bloqueio transacional dos aneis")
            bloquear(driver, aneis)
    except ServiceUnavailable as erro:
        print("Neo4j indisponivel:", erro)
    except Neo4jError as erro:
        print("Erro Cypher:", erro.code, erro.message)


if __name__ == "__main__":
    main()
