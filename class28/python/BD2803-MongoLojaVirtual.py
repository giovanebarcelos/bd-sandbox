#!/usr/bin/env python3
"""
BD2803 - MongoDB na pratica: catalogo e pedidos de uma loja virtual (pymongo)
Disciplina: Banco de Dados | Aula 28A - MongoDB em Profundidade
Prof. Giovane Barcelos

Problema real: a "TechStore" vende notebooks, smartphones e livros. Cada
categoria tem atributos diferentes (RAM e CPU para notebook, ISBN e autor
para livro...). No modelo relacional isso vira uma tabela com dezenas de
colunas NULL ou um EAV dificil de consultar. No MongoDB cada produto e um
documento com os campos que fazem sentido para ele.

O script resolve, passo a passo:
    1. Validacao de esquema ($jsonSchema) - flexivel, mas nao "terra de ninguem"
    2. Carga do catalogo com atributos heterogeneos
    3. Indices (simples, composto, multikey e texto) + explain()
    4. Consultas do dia a dia (filtros, projecao, ordenacao, paginacao)
    5. Checkout com TRANSACAO multi-documento (baixa estoque + cria pedido)
    6. Relatorio de vendas com aggregation pipeline
    7. Atualizacoes atomicas em arrays ($push com $slice, $inc, arrayFilters)

Pre-requisitos:
    pip install pymongo
    # Transacoes exigem replica set (mesmo que de um no so):
    docker run -d --name bd28-mongo -p 27017:27017 mongo:7 --replSet rs0
    docker exec bd28-mongo mongosh --quiet --eval "rs.initiate()"

Execucao:
    python3 BD2803-MongoLojaVirtual.py
"""

from datetime import datetime, timedelta, timezone

from pymongo import ASCENDING, DESCENDING, TEXT, MongoClient, ReturnDocument
from pymongo.errors import OperationFailure, PyMongoError, WriteError

MONGO_URI = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
NOME_BANCO = "techstore"


def titulo(texto):
    print(f"\n{'=' * 70}\n{texto}\n{'=' * 70}")


# ---------------------------------------------------------------------------
# PASSO 1 - Esquema validado
# ---------------------------------------------------------------------------
VALIDADOR_PRODUTOS = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["sku", "nome", "categoria", "preco", "estoque"],
        "properties": {
            "sku": {"bsonType": "string", "pattern": "^[A-Z]{3}-[0-9]{4}$"},
            "nome": {"bsonType": "string", "minLength": 3},
            "categoria": {"enum": ["notebook", "smartphone", "livro"]},
            "preco": {"bsonType": ["double", "int", "decimal"], "minimum": 0},
            "estoque": {"bsonType": "int", "minimum": 0},
            "tags": {"bsonType": "array", "items": {"bsonType": "string"}},
        },
    }
}


def criar_colecoes(db):
    """Equivalente ao DDL: a colecao existe com uma regra minima de validacao.

    Note que o validador so exige 5 campos. Qualquer outro campo (ram_gb,
    isbn, autor...) e aceito livremente - e isso que permite o catalogo
    heterogeneo sem 40 colunas NULL.
    """
    for nome in ("produtos", "pedidos", "clientes"):
        db.drop_collection(nome)
    db.create_collection("produtos", validator=VALIDADOR_PRODUTOS,
                         validationLevel="strict", validationAction="error")
    db.create_collection("pedidos")
    db.create_collection("clientes")
    print("Colecoes criadas: produtos (com $jsonSchema), pedidos, clientes")


# ---------------------------------------------------------------------------
# PASSO 2 - Carga do catalogo heterogeneo
# ---------------------------------------------------------------------------
def carregar_dados(db):
    produtos = [
        {"sku": "NTB-0001", "nome": "Notebook Pro 14", "categoria": "notebook",
         "preco": 7899.90, "estoque": 12, "tags": ["ultrafino", "trabalho"],
         "specs": {"cpu": "Ryzen 7 7840U", "ram_gb": 16, "ssd_gb": 512, "tela": 14.0},
         "avaliacoes": []},
        {"sku": "NTB-0002", "nome": "Notebook Gamer X", "categoria": "notebook",
         "preco": 9499.00, "estoque": 3, "tags": ["gamer", "rtx"],
         "specs": {"cpu": "Core i7 13700H", "ram_gb": 32, "ssd_gb": 1024,
                   "gpu": "RTX 4060", "tela": 15.6},
         "avaliacoes": []},
        {"sku": "SMA-0001", "nome": "Smartphone Z5", "categoria": "smartphone",
         "preco": 2999.00, "estoque": 40, "tags": ["5g", "camera"],
         "specs": {"armazenamento_gb": 256, "cores": ["preto", "azul"], "nfc": True},
         "avaliacoes": []},
        {"sku": "SMA-0002", "nome": "Smartphone Lite A", "categoria": "smartphone",
         "preco": 1299.00, "estoque": 0, "tags": ["entrada"],
         "specs": {"armazenamento_gb": 128, "cores": ["branco"], "nfc": False},
         "avaliacoes": []},
        {"sku": "LIV-0001", "nome": "Sistemas de Banco de Dados", "categoria": "livro",
         "preco": 289.90, "estoque": 25, "tags": ["sql", "modelagem", "nosql"],
         "isbn": "978-8543025001", "autores": ["Elmasri", "Navathe"], "paginas": 1152,
         "avaliacoes": []},
        {"sku": "LIV-0002", "nome": "MongoDB: The Definitive Guide", "categoria": "livro",
         "preco": 249.00, "estoque": 8, "tags": ["nosql", "mongodb"],
         "isbn": "978-1491954461", "autores": ["Bradshaw", "Brazil", "Chodorow"],
         "paginas": 514, "avaliacoes": []},
    ]
    db.produtos.insert_many(produtos)

    db.clientes.insert_many([
        {"_id": "cli-ana", "nome": "Ana Ribeiro", "email": "ana@email.com",
         "endereco": {"cidade": "Porto Alegre", "uf": "RS", "cep": "90010-000"}},
        {"_id": "cli-bruno", "nome": "Bruno Costa", "email": "bruno@email.com",
         "endereco": {"cidade": "Canoas", "uf": "RS", "cep": "92010-000"}},
        {"_id": "cli-carla", "nome": "Carla Mendes", "email": "carla@email.com",
         "endereco": {"cidade": "Florianopolis", "uf": "SC", "cep": "88010-000"}},
    ])
    print(f"{db.produtos.count_documents({})} produtos e "
          f"{db.clientes.count_documents({})} clientes inseridos")

    # A validacao em acao: documento sem 'estoque' e com SKU fora do padrao
    try:
        db.produtos.insert_one({"sku": "x1", "nome": "Produto invalido",
                                "categoria": "notebook", "preco": 10.0})
    except WriteError as erro:
        print("Validacao bloqueou documento invalido:",
              erro.details.get("errmsg", "Document failed validation"))


# ---------------------------------------------------------------------------
# PASSO 3 - Indices
# ---------------------------------------------------------------------------
def criar_indices(db):
    db.produtos.create_index([("sku", ASCENDING)], unique=True, name="ux_sku")
    # ESR (Equality, Sort, Range): categoria (igualdade) + preco (ordenacao/faixa)
    db.produtos.create_index([("categoria", ASCENDING), ("preco", ASCENDING)],
                             name="ix_categoria_preco")
    db.produtos.create_index([("tags", ASCENDING)], name="ix_tags_multikey")
    db.produtos.create_index([("nome", TEXT), ("tags", TEXT)],
                             default_language="portuguese", name="ix_texto")
    db.pedidos.create_index([("cliente_id", ASCENDING), ("criado_em", DESCENDING)],
                            name="ix_cliente_data")
    print("Indices:", sorted(db.produtos.index_information().keys()))

    plano = db.produtos.find({"categoria": "notebook", "preco": {"$lt": 9000}}) \
        .explain()["queryPlanner"]["winningPlan"]
    estagio = plano.get("inputStage", plano)
    print("explain() -> estagio:", estagio.get("stage"),
          "| indice:", estagio.get("indexName", "-"))


# ---------------------------------------------------------------------------
# PASSO 4 - Consultas do dia a dia
# ---------------------------------------------------------------------------
def consultas(db):
    print("\n[a] Notebooks com 16 GB de RAM ou mais (campo aninhado):")
    for p in db.produtos.find({"categoria": "notebook", "specs.ram_gb": {"$gte": 16}},
                              {"_id": 0, "nome": 1, "specs.ram_gb": 1, "preco": 1}):
        print("   ", p)

    print("\n[b] Produtos com a tag 'nosql' OU preco < 1500, em estoque:")
    filtro = {"$or": [{"tags": "nosql"}, {"preco": {"$lt": 1500}}],
              "estoque": {"$gt": 0}}
    for p in db.produtos.find(filtro, {"_id": 0, "sku": 1, "nome": 1}):
        print("   ", p)

    print("\n[c] Busca textual 'banco dados':")
    for p in db.produtos.find({"$text": {"$search": "banco dados"}},
                              {"_id": 0, "nome": 1, "score": {"$meta": "textScore"}}) \
            .sort([("score", {"$meta": "textScore"})]):
        print("   ", p)

    print("\n[d] Paginacao (pagina 2, 2 itens/pagina, mais caros primeiro):")
    pagina, tamanho = 2, 2
    for p in db.produtos.find({}, {"_id": 0, "nome": 1, "preco": 1}) \
            .sort("preco", DESCENDING).skip((pagina - 1) * tamanho).limit(tamanho):
        print("   ", p)

    print("\n[e] Produtos que tem o campo 'isbn' ($exists):",
          db.produtos.count_documents({"isbn": {"$exists": True}}))


# ---------------------------------------------------------------------------
# PASSO 5 - Checkout transacional
# ---------------------------------------------------------------------------
class EstoqueInsuficiente(Exception):
    pass


def checkout(cliente_mongo, db, cliente_id, itens):
    """Cria um pedido baixando o estoque de cada item - tudo ou nada.

    itens: lista de (sku, quantidade)

    Em SQL seria:  BEGIN; UPDATE produto SET estoque = estoque - q
                   WHERE sku = ? AND estoque >= q; ... INSERT INTO pedido ...; COMMIT;
    O MongoDB (>= 4.0) oferece transacoes ACID multi-documento com a mesma
    semantica - mas o ideal e modelar para nao precisar delas sempre.
    """
    with cliente_mongo.start_session() as sessao:
        with sessao.start_transaction():
            linhas, total = [], 0.0
            for sku, qtd in itens:
                # Baixa condicional: so decrementa se houver estoque suficiente
                produto = db.produtos.find_one_and_update(
                    {"sku": sku, "estoque": {"$gte": qtd}},
                    {"$inc": {"estoque": -qtd}},
                    projection={"_id": 0, "sku": 1, "nome": 1, "preco": 1},
                    return_document=ReturnDocument.AFTER,
                    session=sessao,
                )
                if produto is None:
                    # Excecao dentro do 'with' => abort_transaction automatico
                    raise EstoqueInsuficiente(f"sem estoque para {sku} (qtd {qtd})")
                subtotal = round(produto["preco"] * qtd, 2)
                total += subtotal
                # Snapshot do nome/preco: o pedido guarda o preco DO MOMENTO da compra
                linhas.append({"sku": sku, "nome": produto["nome"], "qtd": qtd,
                               "preco_unit": produto["preco"], "subtotal": subtotal})
            cliente = db.clientes.find_one({"_id": cliente_id}, session=sessao)
            pedido = {
                "cliente_id": cliente_id,
                "entrega": cliente["endereco"],      # copia do endereco (historico)
                "itens": linhas,                      # array embutido
                "total": round(total, 2),
                "status": "PAGO",
                "criado_em": datetime.now(timezone.utc),
            }
            return db.pedidos.insert_one(pedido, session=sessao).inserted_id


def simular_vendas(cliente_mongo, db):
    compras = [
        ("cli-ana", [("NTB-0001", 1), ("LIV-0001", 2)]),
        ("cli-bruno", [("SMA-0001", 2)]),
        ("cli-carla", [("LIV-0002", 1), ("LIV-0001", 1), ("SMA-0001", 1)]),
        ("cli-ana", [("NTB-0002", 5)]),          # vai falhar: so ha 3 em estoque
        ("cli-bruno", [("NTB-0002", 2), ("LIV-0002", 1)]),
    ]
    for cliente_id, itens in compras:
        try:
            pid = checkout(cliente_mongo, db, cliente_id, itens)
            print(f"Pedido {pid} criado para {cliente_id}")
        except EstoqueInsuficiente as erro:
            print(f"Pedido de {cliente_id} ABORTADO (rollback): {erro}")
    est = db.produtos.find_one({"sku": "NTB-0002"}, {"_id": 0, "estoque": 1})
    print("Estoque final de NTB-0002 (esperado 1):", est["estoque"])

    # Datas retroativas para o relatorio mensal ficar interessante
    for i, pedido in enumerate(db.pedidos.find().sort("_id", ASCENDING)):
        db.pedidos.update_one({"_id": pedido["_id"]},
                              {"$set": {"criado_em": datetime.now(timezone.utc)
                                        - timedelta(days=35 * (i % 2))}})


# ---------------------------------------------------------------------------
# PASSO 6 - Relatorio com aggregation pipeline
# ---------------------------------------------------------------------------
def relatorios(db):
    print("\n[a] Faturamento por categoria (unwind + lookup + group):")
    pipeline = [
        {"$unwind": "$itens"},
        {"$lookup": {"from": "produtos", "localField": "itens.sku",
                     "foreignField": "sku", "as": "prod"}},
        {"$unwind": "$prod"},
        {"$group": {"_id": "$prod.categoria",
                    "faturamento": {"$sum": "$itens.subtotal"},
                    "unidades": {"$sum": "$itens.qtd"}}},
        {"$sort": {"faturamento": -1}},
    ]
    for linha in db.pedidos.aggregate(pipeline):
        print(f"    {linha['_id']:<12} R$ {linha['faturamento']:>10.2f}"
              f"  ({linha['unidades']} un.)")

    print("\n[b] Faturamento por mes e por UF de entrega:")
    pipeline = [
        {"$group": {"_id": {"mes": {"$dateToString": {"format": "%Y-%m",
                                                       "date": "$criado_em"}},
                            "uf": "$entrega.uf"},
                    "pedidos": {"$sum": 1}, "total": {"$sum": "$total"}}},
        {"$sort": {"_id.mes": 1, "total": -1}},
    ]
    for linha in db.pedidos.aggregate(pipeline):
        print(f"    {linha['_id']['mes']}  {linha['_id']['uf']}  "
              f"{linha['pedidos']} pedido(s)  R$ {linha['total']:.2f}")

    print("\n[c] Top clientes ($facet: ranking + estatisticas na mesma passada):")
    pipeline = [
        {"$facet": {
            "ranking": [
                {"$group": {"_id": "$cliente_id", "gasto": {"$sum": "$total"}}},
                {"$sort": {"gasto": -1}}, {"$limit": 2},
            ],
            "estatisticas": [
                {"$group": {"_id": None, "ticket_medio": {"$avg": "$total"},
                            "maior_pedido": {"$max": "$total"}}},
            ],
        }}
    ]
    resultado = next(db.pedidos.aggregate(pipeline))
    print("    ranking:", resultado["ranking"])
    est = resultado["estatisticas"][0]
    print(f"    ticket medio R$ {est['ticket_medio']:.2f} | "
          f"maior pedido R$ {est['maior_pedido']:.2f}")


# ---------------------------------------------------------------------------
# PASSO 7 - Atualizacoes atomicas em arrays
# ---------------------------------------------------------------------------
def avaliacoes_e_precos(db):
    # $push com $each/$sort/$slice: mantem SO as 3 avaliacoes mais recentes
    # embutidas (padrao "subset"), evitando documento crescendo sem limite.
    for nota, texto, dias in [(5, "Excelente", 3), (4, "Bom", 2),
                              (2, "Esquentou", 1), (5, "Perfeito", 0)]:
        db.produtos.update_one(
            {"sku": "NTB-0001"},
            {"$push": {"avaliacoes": {"$each": [{
                "nota": nota, "texto": texto,
                "data": datetime.now(timezone.utc) - timedelta(days=dias)}],
                "$sort": {"data": -1}, "$slice": 3}},
             "$inc": {"qtd_avaliacoes": 1, "soma_notas": nota}},
        )
    p = db.produtos.find_one({"sku": "NTB-0001"})
    print("Avaliacoes embutidas (max 3):", [a["texto"] for a in p["avaliacoes"]])
    print(f"Media calculada pelos contadores: {p['soma_notas'] / p['qtd_avaliacoes']:.2f}"
          f" em {p['qtd_avaliacoes']} avaliacoes")

    # Reajuste de 10% so nos livros. Um simples {"$mul": {"preco": 1.10}}
    # deixaria 249.00 * 1.10 = 273.90000000000003 (double binario). O update
    # com pipeline (lista) permite usar $round no proprio servidor.
    # Em producao, prefira Decimal128 (bson.decimal128) para valores monetarios.
    r = db.produtos.update_many(
        {"categoria": "livro"},
        [{"$set": {"preco": {"$round": [{"$multiply": ["$preco", 1.10]}, 2]}}}])
    print(f"Reajuste de 10% aplicado em {r.modified_count} livro(s):",
          [(p["sku"], p["preco"]) for p in
           db.produtos.find({"categoria": "livro"}, {"_id": 0, "sku": 1, "preco": 1})])

    # arrayFilters: atualiza um elemento especifico de um array
    db.produtos.update_one({"sku": "SMA-0001"},
                           {"$set": {"specs.cores.$[c]": "azul-marinho"}},
                           array_filters=[{"c": "azul"}])
    print("Cores do SMA-0001:",
          db.produtos.find_one({"sku": "SMA-0001"})["specs"]["cores"])


def main():
    try:
        cliente = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        cliente.admin.command("ping")
        db = cliente[NOME_BANCO]

        titulo("PASSO 1 - Colecoes e validacao de esquema")
        criar_colecoes(db)
        titulo("PASSO 2 - Carga do catalogo heterogeneo")
        carregar_dados(db)
        titulo("PASSO 3 - Indices e explain()")
        criar_indices(db)
        titulo("PASSO 4 - Consultas")
        consultas(db)
        titulo("PASSO 5 - Checkout com transacao")
        simular_vendas(cliente, db)
        titulo("PASSO 6 - Relatorios (aggregation pipeline)")
        relatorios(db)
        titulo("PASSO 7 - Atualizacoes atomicas em arrays")
        avaliacoes_e_precos(db)
        cliente.close()
    except OperationFailure as erro:
        print("Falha de operacao (o replica set foi iniciado?):", erro)
    except PyMongoError as erro:
        print("Erro ao acessar o MongoDB:", erro)


if __name__ == "__main__":
    main()
