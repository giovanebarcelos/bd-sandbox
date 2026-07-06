#!/usr/bin/env python3
"""
BD2802 - Exemplo pratico de Neo4j (banco de dados de grafo) com o driver neo4j
Disciplina: Banco de Dados | Aula 28 - Introducao a NoSQL
Prof. Giovane Barcelos

Cenario: continuacao do dominio "BookHub" - agora modelado como um grafo de
Autores que ESCREVERAM Livros, e Livros que PERTENCEM a Categorias. Um grafo
evidencia naturalmente relacionamentos (ex.: "quais autores escreveram livros
da mesma categoria?"), que em SQL exigiriam varios JOINs encadeados.

Pre-requisitos:
    pip install neo4j
    Um servidor Neo4j acessivel (local via Docker):
        docker run -d --name neo4j-bookhub -p 7474:7474 -p 7687:7687 \
            --env NEO4J_AUTH=neo4j/bookhub123 neo4j:5

Execucao:
    python3 BD2802-Neo4jExemplo.py
"""

from neo4j import GraphDatabase
from neo4j.exceptions import ServiceUnavailable

URI = "bolt://localhost:7687"
USUARIO = "neo4j"
SENHA = "bookhub123"


def limpar_e_popular(driver):
    """CREATE - remove o grafo anterior e cria nos (nodes) e relacionamentos.

    Terminologia Neo4j x modelo relacional:
        No (Node)          ~ linha de uma tabela
        Rotulo (Label)     ~ nome da tabela (ex.: :Autor, :Livro, :Categoria)
        Propriedade        ~ coluna
        Relacionamento     ~ chave estrangeira "materializada" como uma
                              aresta nomeada e percorrivel nos dois sentidos
    """
    with driver.session() as sessao:
        sessao.run("MATCH (n) DETACH DELETE n")

        sessao.run("""
            CREATE (a1:Autor {id: 1, nome: 'Paula Sousa', nacionalidade: 'Brasil'})
            CREATE (a2:Autor {id: 2, nome: 'John Marshall', nacionalidade: 'Reino Unido'})
            CREATE (a3:Autor {id: 3, nome: 'Aiko Tanaka', nacionalidade: 'Japao'})

            CREATE (c1:Categoria {nome: 'Tecnologia'})
            CREATE (c2:Categoria {nome: 'Ficcao'})

            CREATE (l1:Livro {id: 1, titulo: 'Programacao em Java - Avancado', preco: 120.00})
            CREATE (l2:Livro {id: 2, titulo: 'Introducao ao SQL', preco: 45.00})
            CREATE (l3:Livro {id: 3, titulo: 'Romance das Estacoes', preco: 35.50})
            CREATE (l5:Livro {id: 5, titulo: 'Aplicacoes em Rust', preco: 89.90})

            CREATE (a1)-[:ESCREVEU]->(l1)
            CREATE (a1)-[:ESCREVEU]->(l2)
            CREATE (a2)-[:ESCREVEU]->(l3)
            CREATE (a2)-[:ESCREVEU]->(l5)

            CREATE (l1)-[:PERTENCE_A]->(c1)
            CREATE (l2)-[:PERTENCE_A]->(c1)
            CREATE (l3)-[:PERTENCE_A]->(c2)
            CREATE (l5)-[:PERTENCE_A]->(c1)
        """)
        print("Grafo populado: 3 autores, 2 categorias, 4 livros e seus relacionamentos.")


def consulta_livros_por_autor(driver, nome_autor):
    """READ simples - equivalente a um JOIN de 1 tabela.

    SQL: SELECT l.titulo FROM livro l
         JOIN autor a ON a.id = l.id_autor
         WHERE a.nome = 'John Marshall';
    """
    cypher = """
        MATCH (a:Autor {nome: $nome})-[:ESCREVEU]->(l:Livro)
        RETURN l.titulo AS titulo, l.preco AS preco
    """
    with driver.session() as sessao:
        resultado = sessao.run(cypher, nome=nome_autor)
        print(f"\nLivros de {nome_autor}:")
        for registro in resultado:
            print(f"  {registro['titulo']} (R$ {registro['preco']:.2f})")


def consulta_autores_mesma_categoria(driver, nome_autor):
    """READ com travessia de 2 saltos (2-hop traversal).

    Pergunta: "quais outros autores escreveram livros da mesma categoria que
    um autor de referencia?" Em SQL, isso exigiria 2 JOINs encadeados
    (autor -> livro -> categoria -> livro -> autor) com um WHERE de exclusao
    do proprio autor. Em Cypher, o caminho e expresso diretamente no MATCH,
    de forma declarativa e proxima da linguagem natural.
    """
    cypher = """
        MATCH (a1:Autor {nome: $nome})-[:ESCREVEU]->(:Livro)-[:PERTENCE_A]->(c:Categoria)
              <-[:PERTENCE_A]-(:Livro)<-[:ESCREVEU]-(a2:Autor)
        WHERE a1 <> a2
        RETURN DISTINCT a2.nome AS autor, c.nome AS categoria_em_comum
    """
    with driver.session() as sessao:
        resultado = sessao.run(cypher, nome=nome_autor)
        print(f"\nAutores que compartilham categoria com {nome_autor}:")
        encontrou = False
        for registro in resultado:
            encontrou = True
            print(f"  {registro['autor']} (categoria: {registro['categoria_em_comum']})")
        if not encontrou:
            print("  Nenhum autor em comum encontrado.")


def atualizar_preco(driver, id_livro, novo_preco):
    """UPDATE - atualizacao de uma propriedade do no.

    SQL: UPDATE livro SET preco = 99.90 WHERE id = 5;
    """
    cypher = "MATCH (l:Livro {id: $id}) SET l.preco = $preco RETURN l.titulo AS titulo"
    with driver.session() as sessao:
        registro = sessao.run(cypher, id=id_livro, preco=novo_preco).single()
        if registro:
            print(f"\nPreco atualizado: {registro['titulo']} agora custa R$ {novo_preco:.2f}")


def remover_relacionamento(driver, nome_autor, titulo_livro):
    """DELETE - remocao de um relacionamento (aresta), preservando os nos.

    SQL equivalente: UPDATE livro SET id_autor = NULL WHERE titulo = '...';
    (ou remocao da linha de uma tabela associativa autor_livro, em um
    modelo N:N)
    """
    cypher = """
        MATCH (a:Autor {nome: $nome})-[r:ESCREVEU]->(l:Livro {titulo: $titulo})
        DELETE r
    """
    with driver.session() as sessao:
        sessao.run(cypher, nome=nome_autor, titulo=titulo_livro)
        print(f"\nRelacionamento ESCREVEU removido entre {nome_autor} e '{titulo_livro}'.")


def main():
    try:
        driver = GraphDatabase.driver(URI, auth=(USUARIO, SENHA))
        driver.verify_connectivity()
    except ServiceUnavailable as erro:
        print(f"Nao foi possivel conectar ao Neo4j: {erro}")
        print("Dica: suba um container com as portas 7474/7687 publicadas (ver docstring).")
        return

    limpar_e_popular(driver)
    consulta_livros_por_autor(driver, "John Marshall")
    consulta_autores_mesma_categoria(driver, "Paula Sousa")
    atualizar_preco(driver, 5, 99.90)
    remover_relacionamento(driver, "Paula Sousa", "Introducao ao SQL")

    driver.close()
    print("\nConexao encerrada.")


if __name__ == "__main__":
    main()
