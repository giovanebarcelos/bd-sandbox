#!/usr/bin/env python3
"""
BD2801 - Exemplo pratico de MongoDB (banco de dados de documentos) com pymongo
Disciplina: Banco de Dados | Aula 28 - Introducao a NoSQL
Prof. Giovane Barcelos

Cenario: "BookHub" - uma livraria online, com as colecoes:
    autores, livros, clientes, vendas

Objetivo: demonstrar operacoes de CRUD (Create, Read, Update, Delete) e um
pipeline de agregacao em MongoDB, contrastando com o equivalente em SQL
(Oracle/PostgreSQL) estudado nas aulas anteriores do curso.

Pre-requisitos:
    pip install pymongo
    Um servidor MongoDB acessivel (local via Docker ou Atlas):
        docker run -d --name mongo-bookhub -p 27017:27017 mongo:7

Execucao:
    python3 BD2801-MongoExemplo.py
"""

from datetime import datetime

from pymongo import MongoClient
from pymongo.errors import PyMongoError

MONGO_URI = "mongodb://localhost:27017"
NOME_BANCO = "bookhubdb"


def conectar():
    """Abre a conexao com o MongoDB e retorna o objeto do banco 'bookhubdb'.

    Equivalente conceitual a abrir uma conexao JDBC/oracledb/psycopg2 em um
    banco relacional - mas aqui nao ha um "schema" fixo: cada documento de
    uma colecao pode ter campos diferentes.
    """
    cliente = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    return cliente, cliente[NOME_BANCO]


def popular_dados(db):
    """CREATE - insere os documentos iniciais nas 4 colecoes.

    Em SQL, isso corresponderia a 4 INSERTs em tabelas normalizadas
    (autores, livros, clientes, vendas + itens_venda). Aqui, "vendas" ja
    guarda os itens como um array embutido (desnormalizacao proposital,
    tipica de bancos de documentos - otimiza a leitura de uma venda
    completa em uma unica consulta, sem JOIN).
    """
    db.autores.drop()
    db.livros.drop()
    db.clientes.drop()
    db.vendas.drop()

    db.autores.insert_many([
        {"_id": 1, "nome": "Paula Sousa", "nacionalidade": "Brasil",
         "data_nascimento": datetime(1978, 5, 12)},
        {"_id": 2, "nome": "John Marshall", "nacionalidade": "Reino Unido",
         "data_nascimento": datetime(1965, 11, 2)},
        {"_id": 3, "nome": "Aiko Tanaka", "nacionalidade": "Japao",
         "data_nascimento": datetime(1985, 7, 20)},
    ])

    db.livros.insert_many([
        {"_id": 1, "titulo": "Programacao em Java - Avancado", "genero": "Tecnologia",
         "preco": 120.00, "tipo": "fisico", "ano_publicacao": 2019, "id_autor": 1},
        {"_id": 2, "titulo": "Introducao ao SQL", "genero": "Tecnologia",
         "preco": 45.00, "tipo": "fisico", "ano_publicacao": 2015, "id_autor": 1},
        {"_id": 3, "titulo": "Romance das Estacoes", "genero": "Ficcao",
         "preco": 35.50, "tipo": "digital", "ano_publicacao": 2021, "id_autor": 2},
        {"_id": 4, "titulo": "Historias do Oriente", "genero": "Ficcao",
         "preco": 55.00, "tipo": "fisico", "ano_publicacao": 1998, "id_autor": 3},
        {"_id": 5, "titulo": "Aplicacoes em Rust", "genero": "Tecnologia",
         "preco": 89.90, "tipo": "digital", "ano_publicacao": 2022, "id_autor": 2},
    ])

    db.clientes.insert_many([
        {"_id": 1, "nome": "Mariana Lima", "email": "mariana.lima@email.com",
         "telefone": "+55-11-99999-0001", "data_cadastro": datetime(2023, 2, 10)},
        {"_id": 2, "nome": "Carlos Souza", "email": "carlos.souza@email.com",
         "telefone": "+55-21-98888-1111", "data_cadastro": datetime(2022, 11, 5)},
        {"_id": 3, "nome": "Ana Pereira", "email": "ana.pereira@email.com",
         "telefone": "+55-41-97777-2222", "data_cadastro": datetime(2024, 1, 3)},
    ])

    db.vendas.insert_many([
        {"_id": 1, "id_cliente": 1, "data_venda": datetime(2025, 8, 10, 10, 15),
         "forma_pagamento": "cartao", "valor_total": 165.00,
         "itens": [
             {"id_livro": 1, "quantidade": 1, "preco_unit": 120.00},
             {"id_livro": 2, "quantidade": 1, "preco_unit": 45.00},
         ]},
        {"_id": 2, "id_cliente": 2, "data_venda": datetime(2025, 8, 12, 15, 30),
         "forma_pagamento": "boleto", "valor_total": 160.90,
         "itens": [
             {"id_livro": 3, "quantidade": 2, "preco_unit": 35.50},
             {"id_livro": 5, "quantidade": 1, "preco_unit": 89.90},
         ]},
    ])
    print("Dados iniciais inseridos (autores, livros, clientes, vendas).")


def exemplos_create(db):
    """CREATE - insercao de um novo documento e insercao em lote.

    SQL equivalente: INSERT INTO livros (...) VALUES (...);
    """
    print("\n--- CREATE ---")
    novo_livro = {
        "_id": 6, "titulo": "Modelagem NoSQL na Pratica", "genero": "Tecnologia",
        "preco": 75.00, "tipo": "digital", "ano_publicacao": 2026, "id_autor": 2,
    }
    resultado = db.livros.insert_one(novo_livro)
    print(f"Livro inserido com _id={resultado.inserted_id}")


def exemplos_read(db):
    """READ - consultas equivalentes a SELECT ... WHERE ... em SQL.

    Observe que o "esquema" de filtro e um documento JSON (BSON), nao uma
    clausula textual - e o proprio MongoDB que interpreta os operadores
    ($gt, $eq, $and, $or) como predicados.
    """
    print("\n--- READ ---")

    print("Livros com preco > 100 (projecao apenas de titulo e preco):")
    # SQL: SELECT titulo, preco FROM livros WHERE preco > 100;
    for livro in db.livros.find({"preco": {"$gt": 100}}, {"_id": 1, "titulo": 1, "preco": 1}):
        print(f"  {livro}")

    print("\nLivros digitais de Ficcao (condicao AND implicita):")
    # SQL: SELECT * FROM livros WHERE genero = 'Ficcao' AND tipo = 'digital';
    for livro in db.livros.find({"genero": "Ficcao", "tipo": "digital"}):
        print(f"  {livro['titulo']}")

    print("\nLivros ordenados por preco decrescente:")
    # SQL: SELECT * FROM livros ORDER BY preco DESC;
    for livro in db.livros.find().sort("preco", -1):
        print(f"  {livro['titulo']}: R$ {livro['preco']:.2f}")


def exemplos_update(db):
    """UPDATE - atualizacao de campos existentes ou criacao de novos campos.

    SQL equivalente: UPDATE livros SET preco = preco * 0.9 WHERE _id = 3;
    Em MongoDB, o operador $set atualiza (ou cria) um campo sem exigir que
    ele exista previamente no esquema - reforcando a flexibilidade de
    schema (schemaless) tipica de bancos de documentos.
    """
    print("\n--- UPDATE ---")
    resultado = db.livros.update_one(
        {"_id": 3},
        {"$set": {"preco": 31.95, "em_promocao": True}},
    )
    print(f"Documentos modificados: {resultado.modified_count}")

    # update_many: reajuste de preco em todos os livros fisicos (multi=True)
    resultado_multi = db.livros.update_many(
        {"tipo": "fisico"},
        {"$inc": {"preco": 5.00}},
    )
    print(f"Livros fisicos reajustados: {resultado_multi.modified_count}")


def exemplos_delete(db):
    """DELETE - remocao de documentos.

    SQL equivalente: DELETE FROM livros WHERE ano_publicacao < 2000;
    """
    print("\n--- DELETE ---")
    resultado = db.livros.delete_many({"ano_publicacao": {"$lt": 2000}})
    print(f"Livros removidos (publicados antes de 2000): {resultado.deleted_count}")


def exemplo_aggregate(db):
    """Pipeline de agregacao ($lookup + $unwind + $group).

    SQL equivalente (Oracle/PostgreSQL):
        SELECT v.id, c.nome, v.valor_total
        FROM vendas v
        JOIN clientes c ON c.id = v.id_cliente;

    O $lookup e o analogo do JOIN em MongoDB: junta documentos de outra
    colecao com base em uma chave, mas o resultado fica embutido em um
    array dentro do documento (nao "achatado" como no SQL) - por isso o
    uso de $unwind para desfazer o array quando necessario.
    """
    print("\n--- AGGREGATE (equivalente a JOIN em SQL) ---")
    pipeline = [
        {"$lookup": {
            "from": "clientes",
            "localField": "id_cliente",
            "foreignField": "_id",
            "as": "cliente",
        }},
        {"$unwind": "$cliente"},
        {"$project": {
            "_id": 1,
            "cliente": "$cliente.nome",
            "valor_total": 1,
            "forma_pagamento": 1,
        }},
    ]
    for venda in db.vendas.aggregate(pipeline):
        print(f"  Venda {venda['_id']}: {venda['cliente']} pagou "
              f"R$ {venda['valor_total']:.2f} ({venda['forma_pagamento']})")

    print("\nQuantidade de vendas por forma de pagamento ($group):")
    # SQL: SELECT forma_pagamento, COUNT(*) FROM vendas GROUP BY forma_pagamento;
    for grupo in db.vendas.aggregate([
        {"$group": {"_id": "$forma_pagamento", "total_vendas": {"$sum": 1}}}
    ]):
        print(f"  {grupo['_id']}: {grupo['total_vendas']} venda(s)")


def main():
    try:
        cliente, db = conectar()
        cliente.admin.command("ping")
    except PyMongoError as erro:
        print(f"Nao foi possivel conectar ao MongoDB: {erro}")
        print("Dica: suba um container com 'docker run -d -p 27017:27017 mongo:7'")
        return

    popular_dados(db)
    exemplos_create(db)
    exemplos_read(db)
    exemplos_update(db)
    exemplos_delete(db)
    exemplo_aggregate(db)

    cliente.close()
    print("\nConexao encerrada.")


if __name__ == "__main__":
    main()
